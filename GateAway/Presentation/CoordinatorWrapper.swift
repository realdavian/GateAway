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
        print("🚀 [CoordinatorWrapper] Connecting to server: \(server.countryLong)")
        Task {
            do {
                try await coordinator.connectToServer(server)
                await MainActor.run {
                    completion(.success(()))
                }
            } catch {
                await MainActor.run {
                    completion(.failure(error))
                }
            }
        }
    }
    
    func disconnect(completion: @escaping (Result<Void, Error>) -> Void) {
        print("🚀 [CoordinatorWrapper] Disconnecting from server")
        Task {
            do {
                try await coordinator.disconnect()
                await MainActor.run {
                    completion(.success(()))
                }
            } catch {
                await MainActor.run {
                    completion(.failure(error))
                }
            }
        }
    }
    
    func cancelConnection() async {
        await coordinator.cancelConnection()
    }
    
    // MARK: - State Access
    
    var connectionState: ConnectionState {
        coordinator.getCurrentConnectionState()
    }
}
