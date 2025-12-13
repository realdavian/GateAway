import Foundation

// MARK: - Connection State

enum VPNConnectionState: Equatable {
    case disconnected
    case connecting(VPNServer)
    case connected(VPNServer)
    case disconnecting
    case error(String)
}

// MARK: - Protocol (ISP: Interface segregation - only connection management)

protocol VPNConnectionManagerProtocol {
    var currentState: VPNConnectionState { get }
    func connect(to server: VPNServer, completion: @escaping (Result<Void, Error>) -> Void)
    func disconnect(completion: @escaping (Result<Void, Error>) -> Void)
}

// MARK: - Implementation (SRP: Single responsibility - VPN lifecycle management)

final class VPNConnectionManager: VPNConnectionManagerProtocol {
    private let controller: VPNControlling
    private(set) var currentState: VPNConnectionState = .disconnected {
        didSet {
            if oldValue != currentState {
                print("🔄 [VPNConnectionManager] State changed: \(oldValue) → \(currentState)")
                onStateChange?(currentState)
            }
        }
    }
    var onStateChange: ((VPNConnectionState) -> Void)?
    
    init(controller: VPNControlling, backend: UserPreferences.VPNProvider = .openVPN) {
        self.controller = controller
        print("🎯 [VPNConnectionManager] Initialized with \(backend.displayName) backend")
    }
    
    func connect(to server: VPNServer, completion: @escaping (Result<Void, Error>) -> Void) {
        print("🔗 [VPNConnectionManager] Connecting to: \(server.countryLong)")
        currentState = .connecting(server)
        
        controller.connect(server: server) { [weak self] result in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                switch result {
                case .success:
                    print("✅ [VPNConnectionManager] Connected successfully")
                    self.currentState = .connected(server)
                    completion(.success(()))
                    
                case .failure(let error):
                    print("❌ [VPNConnectionManager] Connection failed: \(error.localizedDescription)")
                    self.currentState = .error(error.localizedDescription)
                    completion(.failure(error))
                }
            }
        }
    }
    
    func disconnect(completion: @escaping (Result<Void, Error>) -> Void) {
        print("🔌 [VPNConnectionManager] Disconnecting...")
        currentState = .disconnecting
        
        controller.disconnect { [weak self] result in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                switch result {
                case .success:
                    print("✅ [VPNConnectionManager] Disconnected successfully")
                    self.currentState = .disconnected
                    completion(.success(()))
                    
                case .failure(let error):
                    print("❌ [VPNConnectionManager] Disconnect failed: \(error.localizedDescription)")
                    self.currentState = .error(error.localizedDescription)
                    completion(.failure(error))
                }
            }
        }
    }
}

