import Combine
import Foundation

/// Bridge between AppCoordinatorProtocol and SwiftUI @EnvironmentObject
final class CoordinatorWrapper: ObservableObject {
  private let coordinator: AppCoordinatorProtocol

  init(_ coordinator: AppCoordinatorProtocol) {
    self.coordinator = coordinator
  }

  // MARK: - Connection Methods

  func connect(to server: VPNServer, completion: @escaping (Result<Void, Error>) -> Void) {
    Log.debug("Connecting to server: \(server.countryLong)")
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
    Log.debug("Disconnecting from server")
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
