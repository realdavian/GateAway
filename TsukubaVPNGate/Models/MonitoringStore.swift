import Foundation
import Combine

/// Central store for VPN connection data.
/// Acts as the single source of truth for the UI.
///
/// Data Ownership:
/// - `connectionState` - Set by VPNConnectionManager ONLY
/// - `stats` - Updated by subscribing to VPNMonitor's publisher
/// - `serverInfo` - Set by VPNConnectionManager when connecting
@MainActor
final class MonitoringStore: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Connection state owned by VPNConnectionManager
    @Published var connectionState: ConnectionState = .disconnected
    
    /// Real-time stats from VPNMonitor
    @Published var stats: VPNStats = .empty
    
    /// Server info set when connecting
    @Published var serverInfo: VPNServerInfo = .empty
    
    // MARK: - Subscription
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        print("🏗️ [MonitoringStore] Initialized")
    }
    
    /// Subscribe to VPNMonitor's stats publisher
    func subscribe(to statsPublisher: AnyPublisher<VPNStats, Never>) {
        statsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newStats in
                guard let self else { return }
                // Preserve connectedSince that was set by setConnected()
                // VPNMonitor doesn't know when connection started
                let preservedConnectedSince = self.stats.connectedSince ?? newStats.connectedSince
                self.stats = VPNStats(
                    bytesReceived: newStats.bytesReceived,
                    bytesSent: newStats.bytesSent,
                    downloadSpeed: newStats.downloadSpeed,
                    uploadSpeed: newStats.uploadSpeed,
                    vpnIP: newStats.vpnIP,
                    connectedSince: preservedConnectedSince
                )
            }
            .store(in: &cancellables)
        print("📡 [MonitoringStore] Subscribed to stats publisher")
    }
    
    // MARK: - State Management (Called by VPNConnectionManager)
    
    func setConnecting(server: VPNServer) {
        connectionState = .connecting
        serverInfo = .from(server: server)
        stats = .empty
        print("🔄 [MonitoringStore] State: connecting to \(server.countryLong)")
    }
    
    func setConnected() {
        connectionState = .connected
        // Set connected time - stats will be updated by VPNMonitor but we need the start time
        stats = VPNStats(
            bytesReceived: stats.bytesReceived,
            bytesSent: stats.bytesSent,
            downloadSpeed: stats.downloadSpeed,
            uploadSpeed: stats.uploadSpeed,
            vpnIP: stats.vpnIP,
            connectedSince: Date()  // Set connection start time
        )
        print("✅ [MonitoringStore] State: connected at \(Date())")
    }
    
    func setDisconnecting() {
        connectionState = .disconnecting
        print("🔄 [MonitoringStore] State: disconnecting")
    }
    
    func setDisconnected() {
        connectionState = .disconnected
        stats = .empty
        print("⭕ [MonitoringStore] State: disconnected")
    }
    
    func setError(_ message: String) {
        connectionState = .error(message)
        print("❌ [MonitoringStore] State: error - \(message)")
    }
    
    func setReconnecting() {
        connectionState = .reconnecting
        print("🔄 [MonitoringStore] State: reconnecting")
    }
}
