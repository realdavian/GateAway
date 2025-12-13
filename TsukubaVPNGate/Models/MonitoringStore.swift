import Foundation
import Combine

/// Central store for VPN statistics and connection state.
/// Acts as the single source of truth for the UI.
@MainActor
final class MonitoringStore: ObservableObject {
    
    // MARK: - Shared Instance
    static let shared = MonitoringStore()
    
    // MARK: - Published Properties
    @Published var vpnStatistics: VPNStatistics = .empty
    
    // Derived property for easy access to connection state
    var connectionState: VPNStatistics.ConnectionState {
        vpnStatistics.connectionState
    }
    
    private init() {
        print("🏗️ [MonitoringStore] Initialized")
    }
    
    // MARK: - Update Methods
    
    /// Called by VPNMonitor to update statistics
    func updateStatistics(_ stats: VPNStatistics) {
        print("🔄 [MonitoringStore] UPDATE: state=\(stats.connectionState), bytes=\(stats.bytesReceived)")
        self.vpnStatistics = stats
        print("✅ [MonitoringStore] Published new stats")
    }
    
    /// Called by OpenVPNController when connecting to a server
    func setConnectedServer(country: String?, countryShort: String?, serverName: String?) {
        print("🌍 [MonitoringStore] Connected server: \(country ?? "Unknown") - \(serverName ?? "Unknown")")
        // Update current stats with server info
        self.vpnStatistics = VPNStatistics(
            connectionState: vpnStatistics.connectionState,
            connectedSince: vpnStatistics.connectedSince,
            vpnIP: vpnStatistics.vpnIP,
            publicIP: vpnStatistics.publicIP,
            connectedCountry: country,
            connectedCountryShort: countryShort,
            connectedServerName: serverName,
            bytesReceived: vpnStatistics.bytesReceived,
            bytesSent: vpnStatistics.bytesSent,
            currentDownloadSpeed: vpnStatistics.currentDownloadSpeed,
            currentUploadSpeed: vpnStatistics.currentUploadSpeed,
            ping: vpnStatistics.ping,
            protocolType: vpnStatistics.protocolType,
            port: vpnStatistics.port,
            cipher: vpnStatistics.cipher
        )
    }
}
