import Foundation

/// Abstract layer for VPN backend controllers
protocol VPNControlling {
  /// Establishes a VPN connection to the specified server
  /// - Parameter server: The VPN server to connect to
  func connect(server: VPNServer) async throws

  /// Terminates the current VPN connection
  func disconnect() async throws

  /// Cancels an in-progress connection attempt without throwing
  func cancelConnection()

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
      return "VPN backend not available: \(message)"
    case .connectionFailed(let message):
      return "Connection failed: \(message)"
    case .disconnectionFailed(let message):
      return "Disconnection failed: \(message)"
    case .configurationInvalid(let message):
      return "Invalid configuration: \(message)"
    case .authenticationRequired:
      return "Authentication required. Please configure Touch ID or enter your password."
    case .permissionDenied:
      return "Permission denied. Administrator privileges required."
    case .timeout:
      return "Connection timed out. Please try again."
    }
  }

  var recoverySuggestion: String? {
    switch self {
    case .notAvailable:
      return "Install the required VPN software using Homebrew."
    case .authenticationRequired:
      return "Enable Touch ID in Settings → Authentication."
    case .permissionDenied:
      return "Grant administrator privileges when prompted."
    case .timeout:
      return "Try a different server or check your internet connection."
    default:
      return nil
    }
  }
}
