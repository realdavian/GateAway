import SwiftUI

// MARK: - Shared Helper Functions

/// Convert country code to flag emoji
/// - Parameter countryCode: Two-letter country code (e.g., "JP", "US")
/// - Returns: Flag emoji or globe if invalid
func flagEmoji(for countryCode: String) -> String {
    let base: UInt32 = 127397
    var emoji = ""
    for scalar in countryCode.uppercased().unicodeScalars {
        if let scalarValue = UnicodeScalar(base + scalar.value) {
            emoji.unicodeScalars.append(scalarValue)
        }
    }
    return emoji.isEmpty ? "🌍" : emoji
}

/// Get color for VPN connection state
/// - Parameter state: Current connection state
/// - Returns: Appropriate color for the state
func colorForState(_ state: VPNStatistics.ConnectionState) -> Color {
    switch state {
    case .disconnected: return .gray
    case .connecting: return .orange
    case .connected: return .green
    case .reconnecting: return .blue
    case .error: return .red
    }
}

/// Format speed from bits per second to human-readable Mbps
/// - Parameter bps: Speed in bits per second
/// - Returns: Formatted string with one decimal place
func formatSpeed(_ bps: Int) -> String {
    let mbps = Double(bps) / 1_000_000
    return String(format: "%.1f", mbps)
}
