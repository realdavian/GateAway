import Foundation

// MARK: - Connection State

enum VPNConnectionState: Equatable {
    case disconnected
    case connecting(VPNServer)
    case connected(VPNServer)
    case disconnecting
    case error(String)
}

extension VPNConnectionState {
    var idString: String {
        switch self {
        case .disconnected: return "disconnected"
        case .connecting(let server): return "connecting_\(server.id)"
        case .connected(let server): return "connected_\(server.id)"
        case .disconnecting: return "disconnecting"
        case .error(let message): return "error_\(message)"
        }
    }
}

// MARK: - Protocol (ISP: Interface segregation - only connection management)

protocol VPNConnectionManagerProtocol {
    var currentState: VPNConnectionState { get }
    func connect(to server: VPNServer, enableRetry: Bool) async throws
    func disconnect() async throws
    func cancelConnection() async
}

// MARK: - Implementation (SRP: Single responsibility - VPN lifecycle management)

final class VPNConnectionManager: VPNConnectionManagerProtocol {
    private let controller: VPNControlling
    private let telemetry: TelemetryProtocol
    
    private(set) var currentState: VPNConnectionState = .disconnected {
        didSet {
            if oldValue != currentState {
                print("🔄 [VPNConnectionManager] State changed: \(oldValue.idString) → \(currentState.idString)")
                onStateChange?(currentState)
            }
        }
    }
    var onStateChange: ((VPNConnectionState) -> Void)?
    
    init(
        controller: VPNControlling,
        backend: UserPreferences.VPNProvider = .openVPN,
        telemetry: TelemetryProtocol
    ) {
        self.controller = controller
        self.telemetry = telemetry
        print("🎯 [VPNConnectionManager] Initialized with \(backend.displayName) backend")
    }
    
    
    func connect(to server: VPNServer, enableRetry: Bool = true) async throws {
        print("🔗 [VPNConnectionManager] Connecting to: \(server.countryLong)")
        
        let startTime = Date()
        var actualRetryCount = 0
        
        await MainActor.run {
            currentState = .connecting(server)
        }
        
        do {
            // Use retry logic for better reliability with flaky servers
            if enableRetry, let openVPNController = controller as? OpenVPNController {
                try await openVPNController.connectWithRetry(server: server)
                // TODO: Get actual retry count from policy if needed
            } else {
                // Fallback to direct connection (for non-OpenVPN controllers or when retry disabled)
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
                currentState = .connected(server)
            }
        } catch {
            let connectionTime = Date().timeIntervalSince(startTime)
            print("❌ [VPNConnectionManager] Connection failed: \(error.localizedDescription)")
            
            // Record failed connection
            await MainActor.run {
                telemetry.recordAttempt(
                    serverID: server.id,
                    success: false,
                    connectionTime: nil,
                    retryCount: actualRetryCount,
                    failureReason: error.localizedDescription
                )
                currentState = .error(error.localizedDescription)
            }
            throw error
        }
    }
    
    func cancelConnection() async {
        print("🛑 [VPNConnectionManager] Cancelling connection...")
        
        await MainActor.run {
            currentState = .disconnecting
        }
        
        // Cancel the controller's connection
        controller.cancelConnection()
        
        await MainActor.run {
            currentState = .disconnected
        }
    }
    
    func disconnect() async throws {
        print("🔌 [VPNConnectionManager] Disconnecting...")
        
        await MainActor.run {
            currentState = .disconnecting
        }
        
        do {
            // Heavy work on background thread
            try await controller.disconnect()
            print("✅ [VPNConnectionManager] Disconnected successfully")
            
            await MainActor.run {
                currentState = .disconnected
            }
        } catch {
            print("❌ [VPNConnectionManager] Disconnect failed: \(error.localizedDescription)")
            
            await MainActor.run {
                currentState = .error(error.localizedDescription)
            }
            throw error
        }
    }
}

