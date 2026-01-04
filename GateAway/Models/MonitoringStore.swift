import Combine
import Foundation

@MainActor
final class MonitoringStore: ObservableObject {

  // MARK: - Published Properties

  @Published var connectionState: ConnectionState = .disconnected
  @Published var stats: VPNStats = .empty
  @Published var serverInfo: VPNServerInfo = .empty

  // MARK: - Subscription

  private var cancellables = Set<AnyCancellable>()

  init() {
    Log.debug("MonitoringStore initialized")
  }

  func subscribe(to statsPublisher: AnyPublisher<VPNStats, Never>) {
    statsPublisher
      .receive(on: DispatchQueue.main)
      .sink { [weak self] newStats in
        guard let self else { return }
        let preservedConnectedSince = self.stats.connectedSince ?? newStats.connectedSince
        self.stats = VPNStats(
          bytesReceived: newStats.bytesReceived,
          bytesSent: newStats.bytesSent,
          downloadSpeed: newStats.downloadSpeed,
          uploadSpeed: newStats.uploadSpeed,
          vpnIP: newStats.vpnIP,
          remoteIP: newStats.remoteIP,
          connectedSince: preservedConnectedSince,
          openVPNState: newStats.openVPNState
        )
      }
      .store(in: &cancellables)
    Log.debug("Subscribed to stats publisher")
  }

  // MARK: - State Management

  func setConnecting(server: VPNServer) {
    connectionState = .connecting
    serverInfo = .from(server: server)
    stats = .empty
    Log.debug("State: connecting to \(server.countryLong)")
  }

  func setConnected() {
    connectionState = .connected
    stats = VPNStats(
      bytesReceived: stats.bytesReceived,
      bytesSent: stats.bytesSent,
      downloadSpeed: stats.downloadSpeed,
      uploadSpeed: stats.uploadSpeed,
      vpnIP: stats.vpnIP,
      remoteIP: stats.remoteIP,
      connectedSince: Date(),
      openVPNState: .connected
    )
    Log.success("State: connected at \(Date())")
  }

  func setDisconnecting() {
    connectionState = .disconnecting
    Log.debug("State: disconnecting")
  }

  func setDisconnected() {
    connectionState = .disconnected
    stats = .empty
    Log.debug("State: disconnected")
  }

  func setError(_ message: String) {
    connectionState = .error(message)
    Log.error("State: error - \(message)")
  }

  func setReconnecting() {
    connectionState = .reconnecting
    Log.debug("State: reconnecting")
  }
}
