import SwiftUI

/// Connection state owned by VPNConnectionManager
/// This is the single source of truth for connection status
enum ConnectionState: Equatable {
  case disconnected
  case connecting
  case connected
  case disconnecting
  case reconnecting
  case error(String)

  // MARK: - ID String (for logging)

  var idString: String {
    switch self {
    case .disconnected: return "disconnected"
    case .connecting: return "connecting"
    case .connected: return "connected"
    case .disconnecting: return "disconnecting"
    case .reconnecting: return "reconnecting"
    case .error(let message): return "error_\(message)"
    }
  }

  // MARK: - Display Properties

  var displayName: String {
    switch self {
    case .disconnected: return "Disconnected"
    case .connecting: return "Connecting..."
    case .connected: return "Connected"
    case .disconnecting: return "Disconnecting..."
    case .reconnecting: return "Reconnecting..."
    case .error(let message): return "Error: \(message)"
    }
  }

  var icon: String {
    switch self {
    case .disconnected: return "wifi.slash"
    case .connecting: return "arrow.triangle.2.circlepath"
    case .connected: return "wifi"
    case .disconnecting: return "arrow.triangle.2.circlepath"
    case .reconnecting: return "arrow.triangle.2.circlepath"
    case .error: return "exclamationmark.triangle"
    }
  }

  var isConnecting: Bool {
    switch self {
    case .connecting, .reconnecting: return true
    default: return false
    }
  }

  var isConnected: Bool {
    if case .connected = self { return true }
    return false
  }

  var isDisconnected: Bool {
    if case .disconnected = self { return true }
    return false
  }
}

// MARK: - Color Helper

func colorForState(_ state: ConnectionState) -> Color {
  switch state {
  case .disconnected:
    return .secondary
  case .connecting, .reconnecting, .disconnecting:
    return .orange
  case .connected:
    return .green
  case .error:
    return .red
  }
}
