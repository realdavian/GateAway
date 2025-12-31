import Foundation
import SwiftUI

// MARK: - VPN Statistics Model

/// Real-time VPN connection statistics from OpenVPN management interface
struct VPNStatistics {
    let connectionState: ConnectionState
    let connectedSince: Date?
    let vpnIP: String?
    let publicIP: String?
    let connectedCountry: String?  // e.g., "Japan"
    let connectedCountryShort: String?  // e.g., "JP"
    let connectedServerName: String?  // e.g., "vpngate.example.jp"
    let bytesReceived: Int64
    let bytesSent: Int64
    let currentDownloadSpeed: Double // bytes per second
    let currentUploadSpeed: Double // bytes per second
    let ping: Int? // milliseconds
    let protocolType: String?
    let port: Int?
    let cipher: String?
    
    enum ConnectionState: Equatable {
        case disconnected
        case connecting
        case connected
        case reconnecting
        case error(String)
        
        var displayName: String {
            switch self {
            case .disconnected: return "Disconnected"
            case .connecting: return "Connecting..."
            case .connected: return "Connected"
            case .reconnecting: return "Reconnecting..."
            case .error(let msg): return "Error: \(msg)"
            }
        }
        
        var icon: String {
            switch self {
            case .disconnected: return "circle"
            case .connecting: return "circle.dotted"
            case .connected: return "circle.fill"
            case .reconnecting: return "arrow.clockwise.circle"
            case .error: return "exclamationmark.triangle.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .disconnected: return .gray
            case .connecting: return .orange
            case .connected: return .green
            case .reconnecting: return .blue
            case .error: return .red
            }
        }
    }
    
    static let empty = VPNStatistics(
        connectionState: .disconnected,
        connectedSince: nil,
        vpnIP: nil,
        publicIP: nil,
        connectedCountry: nil,
        connectedCountryShort: nil,
        connectedServerName: nil,
        bytesReceived: 0,
        bytesSent: 0,
        currentDownloadSpeed: 0,
        currentUploadSpeed: 0,
        ping: nil,
        protocolType: nil,
        port: nil,
        cipher: nil
    )
    
    var connectionDuration: TimeInterval {
        guard let since = connectedSince else { return 0 }
        return Date().timeIntervalSince(since)
    }
    
    var formattedDuration: String {
        let duration = connectionDuration
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
    
    var formattedBytesReceived: String {
        return ByteCountFormatter.string(fromByteCount: bytesReceived, countStyle: .binary)
    }
    
    var formattedBytesSent: String {
        return ByteCountFormatter.string(fromByteCount: bytesSent, countStyle: .binary)
    }
    
    var formattedDownloadSpeed: String {
        return String(format: "%.1f Mbps", currentDownloadSpeed * 8 / 1_000_000)
    }
    
    var formattedUploadSpeed: String {
        return String(format: "%.1f Mbps", currentUploadSpeed * 8 / 1_000_000)
    }
}

// MARK: - Copying Extension

extension VPNStatistics {
    /// Create a copy with selective field updates
    /// Uses double-optional pattern: nil = keep existing, .some(nil) = set to nil
    func copying(
        connectionState: ConnectionState? = nil,
        connectedSince: Date?? = nil,
        vpnIP: String?? = nil,
        publicIP: String?? = nil,
        connectedCountry: String?? = nil,
        connectedCountryShort: String?? = nil,
        connectedServerName: String?? = nil,
        bytesReceived: Int64? = nil,
        bytesSent: Int64? = nil,
        currentDownloadSpeed: Double? = nil,
        currentUploadSpeed: Double? = nil,
        ping: Int?? = nil,
        protocolType: String?? = nil,
        port: Int?? = nil,
        cipher: String?? = nil
    ) -> VPNStatistics {
        VPNStatistics(
            connectionState: connectionState ?? self.connectionState,
            connectedSince: connectedSince ?? self.connectedSince,
            vpnIP: vpnIP ?? self.vpnIP,
            publicIP: publicIP ?? self.publicIP,
            connectedCountry: connectedCountry ?? self.connectedCountry,
            connectedCountryShort: connectedCountryShort ?? self.connectedCountryShort,
            connectedServerName: connectedServerName ?? self.connectedServerName,
            bytesReceived: bytesReceived ?? self.bytesReceived,
            bytesSent: bytesSent ?? self.bytesSent,
            currentDownloadSpeed: currentDownloadSpeed ?? self.currentDownloadSpeed,
            currentUploadSpeed: currentUploadSpeed ?? self.currentUploadSpeed,
            ping: ping ?? self.ping,
            protocolType: protocolType ?? self.protocolType,
            port: port ?? self.port,
            cipher: cipher ?? self.cipher
        )
    }
}
