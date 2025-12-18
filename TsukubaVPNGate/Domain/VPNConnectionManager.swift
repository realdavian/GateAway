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
    func connect(to server: VPNServer) async throws
    func disconnect() async throws
}

// MARK: - Implementation (SRP: Single responsibility - VPN lifecycle management)

final class VPNConnectionManager: VPNConnectionManagerProtocol {
    private let controller: VPNControlling
    private(set) var currentState: VPNConnectionState = .disconnected {
        didSet {
            if oldValue != currentState {
                print("🔄 [VPNConnectionManager] State changed: \(oldValue.idString) → \(currentState.idString)")
                onStateChange?(currentState)
            }
        }
    }
    var onStateChange: ((VPNConnectionState) -> Void)?
    
    init(controller: VPNControlling, backend: UserPreferences.VPNProvider = .openVPN) {
        self.controller = controller
        print("🎯 [VPNConnectionManager] Initialized with \(backend.displayName) backend")
    }
    
    func connect(to server: VPNServer) async throws {
        print("🔗 [VPNConnectionManager] Connecting to: \(server.countryLong)")
        
        await MainActor.run {
            currentState = .connecting(server)
        }
        
        do {
            // Heavy work runs on background thread - doesn't block UI!
            try await controller.connect(server: server)
            print("✅ [VPNConnectionManager] Connected successfully")
            
            await MainActor.run {
                currentState = .connected(server)
            }
        } catch {
            print("❌ [VPNConnectionManager] Connection failed: \(error.localizedDescription)")
            
            await MainActor.run {
                currentState = .error(error.localizedDescription)
            }
            throw error
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

