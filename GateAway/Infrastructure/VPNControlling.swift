import Foundation

/// Abstract layer for VPN backend controllers
protocol VPNControlling {
  /// Establishes a VPN connection to the specified server
  /// - Parameter server: The VPN server to connect to
  func connect(server: VPNServer) async throws

  /// Terminates the current VPN connection
  func disconnect() async throws

  /// Cancels an in-progress connection attempt without throwing
  func cancelConnection() async

  /// Human-readable name for this backend (e.g., "OpenVPN CLI")
  var backendName: String { get }

  /// Whether the required binaries are installed on the system
  var isAvailable: Bool { get }
}

// MARK: - Errors

enum VPNControllerError: LocalizedError {
  case notAvailable(String)
  case connectionFailed(String)
  case disconnectionFailed(String)
  case configurationInvalid(String)
  case authenticationRequired
  case permissionDenied
  case timeout

  var errorDescription: String? {
    switch self {
    case .notAvailable(let message):
      return "VPN backend not available: %@".localized(with: message)
    case .connectionFailed(let message):
      return "Connection failed: %@".localized(with: message)
    case .disconnectionFailed(let message):
      return "Disconnection failed: %@".localized(with: message)
    case .configurationInvalid(let message):
      return "Invalid configuration: %@".localized(with: message)
    case .authenticationRequired:
      return "Authentication required. Please configure Touch ID or enter your password.".localized
    case .permissionDenied:
      return "Permission denied. Administrator privileges required.".localized
    case .timeout:
      return "Connection timed out. Please try again.".localized
    }
  }

  var recoverySuggestion: String? {
    switch self {
    case .notAvailable:
      return "Install the required VPN software using Homebrew.".localized
    case .authenticationRequired:
      return "Enable Touch ID in Settings → Authentication.".localized
    case .permissionDenied:
      return "Grant administrator privileges when prompted.".localized
    case .timeout:
      return "Try a different server or check your internet connection.".localized
    default:
      return nil
    }
  }
}
