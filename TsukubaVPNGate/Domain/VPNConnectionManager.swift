import Foundation

// MARK: - Protocol (ISP: Interface segregation - only connection management)

protocol VPNConnectionManagerProtocol {
    var currentState: ConnectionState { get }
    func connect(to server: VPNServer, enableRetry: Bool) async throws
    func disconnect() async throws
    func cancelConnection() async
}

// MARK: - Implementation (SRP: Single responsibility - VPN lifecycle management)

/// Manages VPN connection lifecycle.
/// Owns the connection state - sets it directly on MonitoringStore.
/// Controls VPNMonitor lifecycle (start/stop monitoring).
final class VPNConnectionManager: VPNConnectionManagerProtocol {
    private let controller: VPNControlling
    private let telemetry: TelemetryProtocol
    private let monitoringStore: MonitoringStore
    private let vpnMonitor: VPNMonitor
    
    /// Tracks the current connection Task for cancellation support
    private var connectionTask: Task<Void, Error>?
    
    /// Current server (for retry and reconnect logic)
    private var currentServer: VPNServer?
    
    var currentState: ConnectionState {
        monitoringStore.connectionState
    }
    
    var onStateChange: ((ConnectionState) -> Void)?
    
    init(
        controller: VPNControlling,
        backend: UserPreferences.VPNProvider = .openVPN,
        telemetry: TelemetryProtocol,
        monitoringStore: MonitoringStore,
        vpnMonitor: VPNMonitor
    ) {
        self.controller = controller
        self.telemetry = telemetry
        self.monitoringStore = monitoringStore
        self.vpnMonitor = vpnMonitor
        print("🎯 [VPNConnectionManager] Initialized with \(backend.displayName) backend")
    }
    
    
    func connect(to server: VPNServer, enableRetry: Bool = true) async throws {
        print("🔗 [VPNConnectionManager] Connecting to: \(server.countryLong)")
        
        // Cancel any existing connection attempt
        connectionTask?.cancel()
        currentServer = server
        
        // Store the current task for cancellation
        let task = Task {
            try await performConnection(to: server, enableRetry: enableRetry)
        }
        connectionTask = task
        
        // Wait for completion or cancellation
        try await task.value
    }
    
    /// Internal connection logic (extracted for Task wrapping)
    private func performConnection(to server: VPNServer, enableRetry: Bool) async throws {
        let startTime = Date()
        var actualRetryCount = 0
        
        // Set state and start monitoring
        await MainActor.run {
            monitoringStore.setConnecting(server: server)
            onStateChange?(.connecting)
        }
        vpnMonitor.startMonitoring()
        
        do {
            // Check for cancellation before starting
            try Task.checkCancellation()
            
            // Use retry logic for better reliability with flaky servers
            if enableRetry, let openVPNController = controller as? OpenVPNController {
                try await openVPNController.connectWithRetry(server: server)
            } else {
                try await controller.connect(server: server)
            }
            
            let connectionTime = Date().timeIntervalSince(startTime)
            print("✅ [VPNConnectionManager] Connected successfully in \(String(format: "%.2f", connectionTime))s")
            
            // Record successful connection
            await MainActor.run {
                telemetry.recordAttempt(
                    serverID: server.id,
                    success: true,
                    connectionTime: connectionTime,
                    retryCount: actualRetryCount,
                    failureReason: nil
                )
                monitoringStore.setConnected()
                onStateChange?(.connected)
            }
        } catch is CancellationError {
            print("🛑 [VPNConnectionManager] Connection cancelled by user")
            vpnMonitor.forceStop()
            await MainActor.run {
                monitoringStore.setDisconnected()
                onStateChange?(.disconnected)
            }
            // Don't throw - user cancellation is intentional, not an error
            return
        } catch {
            let connectionTime = Date().timeIntervalSince(startTime)
            print("❌ [VPNConnectionManager] Connection failed: \(error.localizedDescription)")
            
            vpnMonitor.forceStop()
            
            // Record failed connection
            await MainActor.run {
                telemetry.recordAttempt(
                    serverID: server.id,
                    success: false,
                    connectionTime: nil,
                    retryCount: actualRetryCount,
                    failureReason: error.localizedDescription
                )
                monitoringStore.setError(error.localizedDescription)
                onStateChange?(.error(error.localizedDescription))
            }
            throw error
        }
    }
    
    func cancelConnection() async {
        print("🛑 [VPNConnectionManager] Cancelling connection...")
        
        // Cancel the connection Task (this will trigger CancellationError in retry loop)
        connectionTask?.cancel()
        connectionTask = nil
        
        // Stop monitoring immediately
        vpnMonitor.forceStop()
        
        await MainActor.run {
            monitoringStore.setDisconnecting()
            onStateChange?(.disconnecting)
        }
        
        // Kill any running openvpn process
        controller.cancelConnection()
        
        await MainActor.run {
            monitoringStore.setDisconnected()
            onStateChange?(.disconnected)
        }
        
        currentServer = nil
    }
    
    func disconnect() async throws {
        print("🔌 [VPNConnectionManager] Disconnecting...")
        
        await MainActor.run {
            monitoringStore.setDisconnecting()
            onStateChange?(.disconnecting)
        }
        
        // Stop monitoring
        vpnMonitor.forceStop()
        
        do {
            // Heavy work on background thread
            try await controller.disconnect()
            print("✅ [VPNConnectionManager] Disconnected successfully")
            
            await MainActor.run {
                monitoringStore.setDisconnected()
                onStateChange?(.disconnected)
            }
        } catch {
            print("❌ [VPNConnectionManager] Disconnect failed: \(error.localizedDescription)")
            
            await MainActor.run {
                monitoringStore.setError(error.localizedDescription)
                onStateChange?(.error(error.localizedDescription))
            }
            throw error
        }
        
        currentServer = nil
    }
}
