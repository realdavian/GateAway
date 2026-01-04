import Foundation

// MARK: - OpenVPN Management Socket States

/// All possible states from OpenVPN management interface
/// See: https://openvpn.net/community-resources/reference-manual-for-openvpn-2-4/
enum OpenVPNState: String, CaseIterable, Equatable {

  // MARK: - Pre-connection

  /// Initial state, starting connection
  case connecting = "CONNECTING"

  /// Resolving server hostname to IP
  case resolve = "RESOLVE"

  /// Establishing TCP connection to server
  case tcpConnect = "TCP_CONNECT"

  // MARK: - Handshake

  /// Waiting for initial server response
  case wait = "WAIT"

  /// Authenticating with server
  case auth = "AUTH"

  // MARK: - Setup

  /// Downloading config options from server
  case getConfig = "GET_CONFIG"

  /// Assigning IP to virtual interface
  case assignIP = "ASSIGN_IP"

  /// Adding routes to system
  case addRoutes = "ADD_ROUTES"

  // MARK: - Active

  /// Initialization complete, tunnel active
  case connected = "CONNECTED"

  // MARK: - Recovery/Shutdown

  /// Restart occurred, attempting to reconnect
  case reconnecting = "RECONNECTING"

  /// Graceful shutdown in progress
  case exiting = "EXITING"

  // MARK: - Fallback

  /// Unknown state (fallback)
  case unknown

  // MARK: - Init

  /// Initialize from raw string, returns `.unknown` if not recognized
  init(rawValue: String) {
    self = Self.allCases.first { $0.rawValue == rawValue } ?? .unknown
  }

  // MARK: - Display

  /// Detailed status text for UI
  var displayText: String {
    switch self {
    case .connecting: return "Connecting..."
    case .resolve: return "Resolving server..."
    case .tcpConnect: return "Connecting to server..."
    case .wait: return "Waiting for response..."
    case .auth: return "Authenticating..."
    case .getConfig: return "Receiving config..."
    case .assignIP: return "Getting IP address..."
    case .addRoutes: return "Setting up routes..."
    case .connected: return "Connected"
    case .reconnecting: return "Reconnecting..."
    case .exiting: return "Disconnecting..."
    case .unknown: return "Unknown"
    }
  }

  // MARK: - Mapping to ConnectionState

  /// Convert to app's ConnectionState enum
  var toConnectionState: ConnectionState {
    switch self {
    case .connecting, .resolve, .tcpConnect, .wait, .auth, .getConfig, .assignIP, .addRoutes:
      return .connecting
    case .connected:
      return .connected
    case .reconnecting:
      return .reconnecting
    case .exiting:
      return .disconnecting
    case .unknown:
      return .disconnected
    }
  }

  // MARK: - Helpers

  /// Is this a connecting/pre-connected state?
  var isConnecting: Bool {
    switch self {
    case .connecting, .resolve, .tcpConnect, .wait, .auth, .getConfig, .assignIP, .addRoutes:
      return true
    default:
      return false
    }
  }

  /// Is the VPN fully connected?
  var isConnected: Bool {
    self == .connected
  }

  /// Is this a transitional state (may change quickly)?
  var isTransitional: Bool {
    switch self {
    case .connected, .reconnecting, .exiting, .unknown:
      return false
    default:
      return true
    }
  }
}
