import Foundation
import Combine

// MARK: - Coordinator Wrapper (Bridge between protocol and SwiftUI)

/// Wrapper to make AppCoordinatorProtocol compatible with SwiftUI @EnvironmentObject
/// This is a thin bridge - all logic remains in AppCoordinator (DRY principle)
final class CoordinatorWrapper: ObservableObject {
    private let coordinator: AppCoordinatorProtocol
    
    init(_ coordinator: AppCoordinatorProtocol) {
        self.coordinator = coordinator
    }
    
    // MARK: - Connection Methods (forwarded to coordinator)
    
    func connect(to server: VPNServer, completion: @escaping (Result<Void, Error>) -> Void) {
        print("🚀 [CoordinatorWrapper] Connecting to server: \(server)")
        coordinator.connectToServer(server, completion: completion)
    }
    
    func disconnect(completion: @escaping (Result<Void, Error>) -> Void) {
        print("🚀 [CoordinatorWrapper] Disconnecting from server")
        coordinator.disconnect(completion: completion)
    }
    
    // MARK: - State Access
    
    var connectionState: VPNConnectionState {
        coordinator.getCurrentConnectionState()
    }
}
