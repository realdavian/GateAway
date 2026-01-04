import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

  // MARK: - Services

  private let keychainManager = KeychainManager()
  private let passwordPromptService: PasswordPromptServiceProtocol = PasswordPromptService.shared
  private let permissionService: PermissionServiceProtocol = PermissionService.shared
  private lazy var scriptRunner = ScriptRunner(
    keychainManager: keychainManager,
    passwordPromptService: passwordPromptService
  )
  private let cacheManager = ServerCacheManager()
  private let telemetry = ConnectionTelemetry()
  private let vpnGateAPI: VPNGateAPIProtocol = VPNGateAPI(session: URLSession.shared)

  // MARK: - Stores

  private let monitoringStore = MonitoringStore()
  private lazy var serverStore = ServerStore(api: vpnGateAPI, cache: cacheManager)
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
    Log.info("App terminating - cleaning up...")
    scriptRunner.clearCredentials()
    Task {
      try? await connectionManager?.disconnect()
    }
  }

  func applicationDidFinishLaunching(_ notification: Notification) {
    #if !DEBUG
      NSApp.setActivationPolicy(.accessory)
    #endif

    self.preferencesManager = PreferencesManager()
    setupVPNBackend()

    Task { serverStore.warmupCache() }

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleBackendSwitchNotification(_:)),
      name: NSNotification.Name("SwitchVPNBackend"),
      object: nil
    )
  }

  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
  }

  // MARK: - Backend Switching

  @objc private func handleBackendSwitchNotification(_ notification: Notification) {
    guard let provider = notification.userInfo?["provider"] as? UserPreferences.VPNProvider else {
      return
    }

    switchVPNBackend(to: provider)
  }

  func switchVPNBackend(to newBackend: UserPreferences.VPNProvider) {
    Log.info("Switching VPN backend to: \(newBackend.displayName)")

    Task {
      do {
        try await connectionManager?.disconnect()
        await MainActor.run {
          self.setupVPNBackend()
        }
      } catch {
        Log.warning("Failed to disconnect: \(error)")
        await MainActor.run {
          self.setupVPNBackend()
        }
      }
    }
  }

  private func setupVPNBackend() {
    guard let preferencesManager = preferencesManager else { return }

    let preferences = preferencesManager.loadPreferences()

    if let currentBackend = currentBackend, currentBackend == preferences.vpnProvider {
      Log.debug("Backend unchanged (\(preferences.vpnProvider.displayName))")
      return
    }

    self.currentBackend = preferences.vpnProvider

    let vpnController: VPNControlling = OpenVPNController(
      vpnMonitor: vpnMonitor,
      keychainManager: keychainManager,
      scriptRunner: scriptRunner,
      permissionService: permissionService
    )
    Log.debug("Using OpenVPN CLI backend")

    let connectionManager = VPNConnectionManager(
      controller: vpnController,
      backend: preferences.vpnProvider,
      telemetry: telemetry,
      monitoringStore: monitoringStore,
      vpnMonitor: vpnMonitor
    )
    self.connectionManager = connectionManager

    Task { @MainActor in
      monitoringStore.subscribe(to: vpnMonitor.statsPublisher)
    }

    let selectionService: ServerSelectionServiceProtocol = ServerSelectionService()

    let coordinator = AppCoordinator(
      serverStore: serverStore,
      selectionService: selectionService,
      connectionManager: connectionManager,
      preferencesManager: preferencesManager
    )
    self.coordinator = coordinator

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

      Log.info("Starting initial server refresh...")
      Task {
        do {
          try await coordinator.refreshServerList()
          Log.success("Initial refresh succeeded, rebuilding menu...")
          await MainActor.run {
            controller.rebuildMenu()
          }
        } catch {
          Log.warning("Initial server refresh failed: \(error.localizedDescription)")
        }
      }
    } else {
      statusBarController?.updateCoordinator(coordinator)

      Log.debug("Refreshing server list after backend switch...")
      Task {
        do {
          try await coordinator.refreshServerList()
          Log.success("Refresh succeeded")
          await MainActor.run {
            self.statusBarController?.rebuildMenu()
          }
        } catch {
          Log.warning("Refresh failed: \(error.localizedDescription)")
        }
      }
    }

    connectionManager.onStateChange = { [weak self] newState in
      Log.debug("UI update triggered for state: \(newState.idString)")
      Task { @MainActor in
        self?.statusBarController?.rebuildMenu()
        self?.vpnMonitor.startMonitoring()
      }
    }
  }
}
