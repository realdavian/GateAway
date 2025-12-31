import AppKit

// MARK: - App Delegate (Presentation Layer - SRP: App lifecycle & dependency injection)

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    // MARK: - Services (Composition Root - all dependencies created here)
    private let keychainManager = KeychainManager()
    private let cacheManager = ServerCacheManager()
    private let telemetry = ConnectionTelemetry()
    
    // MARK: - Stores (ObservableObjects shared with Views)
    private let monitoringStore = MonitoringStore()
    private lazy var serverStore = ServerStore(cache: cacheManager)
    private lazy var vpnMonitor = VPNMonitor()
    
    // MARK: - UI Components
    private var statusBarController: StatusBarController?
    private var coordinator: AppCoordinator?
    private var connectionManager: VPNConnectionManager?
    private var preferencesManager: PreferencesManagerProtocol?
    private var currentBackend: UserPreferences.VPNProvider?
    
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Cleanup: disconnect VPN on app quit (best-effort, no password prompt)
        print("🧹 [AppDelegate] App terminating - cleaning up VPN...")
        Task {
            try? await connectionManager?.disconnect()
        }
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide Dock icon in Release builds (menu-bar-only app)
#if !DEBUG
        NSApp.setActivationPolicy(.accessory)
#endif
        
        // Store preferences manager for backend switching
        self.preferencesManager = PreferencesManager()
        
        // Setup VPN backend
        setupVPNBackend()
        
        // Pre-fetch server list for instant availability
        Task { serverStore.warmupCache() }
        
        // Listen for backend switch notifications from Settings
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleBackendSwitchNotification(_:)),
            name: NSNotification.Name("SwitchVPNBackend"),
            object: nil
        )
        
        // Initial server list refresh (moved to setupVPNBackend)
        // Will happen after coordinator is created
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Menu-bar apps should keep running without windows
        return false
    }
    
    // MARK: - Dynamic Backend Switching
    
    @objc private func handleBackendSwitchNotification(_ notification: Notification) {
        guard let provider = notification.userInfo?["provider"] as? UserPreferences.VPNProvider else {
            return
        }
        
        switchVPNBackend(to: provider)
    }
    
    func switchVPNBackend(to newBackend: UserPreferences.VPNProvider) {
        print("🔄 [AppDelegate] Switching VPN backend to: \(newBackend.displayName)")
        
        
        // Disconnect current VPN if connected
        Task {
            do {
                try await connectionManager?.disconnect()
                await MainActor.run {
                    self.setupVPNBackend()
                }
            } catch {
                print("⚠️ [AppDelegate] Failed to disconnect: \(error)")
                await MainActor.run {
                    self.setupVPNBackend()
                }
            }
        }
    }
    
    private func setupVPNBackend() {
        guard let preferencesManager = preferencesManager else { return }
        
        let preferences = preferencesManager.loadPreferences()
        
        // Check if backend changed
        if let currentBackend = currentBackend, currentBackend == preferences.vpnProvider {
            print("ℹ️ [AppDelegate] Backend unchanged (\(preferences.vpnProvider.displayName))")
            return
        }
        
        self.currentBackend = preferences.vpnProvider
        
        // Create OpenVPN controller with injected dependencies
        let vpnController: VPNControlling = OpenVPNController(
            vpnMonitor: vpnMonitor,
            keychainManager: keychainManager
        )
        print("🔧 [AppDelegate] Using OpenVPN CLI backend")
        
        let connectionManager = VPNConnectionManager(
            controller: vpnController,
            backend: preferences.vpnProvider,
            telemetry: telemetry,
            monitoringStore: monitoringStore,
            vpnMonitor: vpnMonitor
        )
        self.connectionManager = connectionManager
        
        // Set up MonitoringStore subscription to VPNMonitor stats
        Task { @MainActor in
            monitoringStore.subscribe(to: vpnMonitor.statsPublisher)
        }
        
        // Create or update coordinator
        let selectionService: ServerSelectionServiceProtocol = ServerSelectionService()
        
        let coordinator = AppCoordinator(
            serverStore: serverStore,
            selectionService: selectionService,
            connectionManager: connectionManager,
            preferencesManager: preferencesManager
        )
        self.coordinator = coordinator
        
        // Create or update UI
        if statusBarController == nil {
            let controller = StatusBarController(
                coordinator: coordinator,
                monitoringStore: monitoringStore,
                serverStore: serverStore,
                vpnMonitor: vpnMonitor,
                keychainManager: keychainManager,
                cacheManager: cacheManager,
                telemetry: telemetry
            )
            self.statusBarController = controller
            
            // Initial server list refresh
            print("🚀 [AppDelegate] Starting initial server refresh...")
            Task {
                do {
                    try await coordinator.refreshServerList()
                    print("✅ [AppDelegate] Initial refresh succeeded, rebuilding menu...")
                    await MainActor.run {
                        controller.rebuildMenu()
                    }
                } catch {
                    print("⚠️ [AppDelegate] Initial server refresh failed: \(error.localizedDescription)")
                }
            }
        } else {
            // Update existing status bar controller with new coordinator
            statusBarController?.updateCoordinator(coordinator)
            
            // Refresh server list for updated coordinator
            print("🚀 [AppDelegate] Refreshing server list after backend switch...")
            Task {
                do {
                    try await coordinator.refreshServerList()
                    print("✅ [AppDelegate] Refresh succeeded")
                    await MainActor.run {
                        self.statusBarController?.rebuildMenu()
                    }
                } catch {
                    print("⚠️ [AppDelegate] Refresh failed: \(error.localizedDescription)")
                }
            }
        }
        // Monitor connection state changes and update UI
        // (Must be outside if/else to work on both first init and backend switch)
        connectionManager.onStateChange = { [weak self] newState in
            print("🎨 [AppDelegate] UI update triggered for state: \(newState.idString)")
            Task { @MainActor in
                self?.statusBarController?.rebuildMenu()
                
                // Immediately start monitoring to update UI
                // Note: Settings tabs manage VPNMonitor.startMonitoring() via onAppear/onDisappear
                self?.vpnMonitor.startMonitoring()
            }
        }
    }
}
