import Foundation

// MARK: - VPN Controller Protocol (DIP: Depend on abstraction, not concrete implementation)

/// Protocol defining the contract for VPN backend implementations.
/// Follows SOLID principles:
/// - Single Responsibility: Only handles VPN connection/disconnection
/// - Open/Closed: Open for extension (new backends), closed for modification
/// - Liskov Substitution: All implementations are substitutable
/// - Interface Segregation: Minimal, focused interface
/// - Dependency Inversion: Depend on abstraction, not concretions
///
/// Current implementation:
/// - OpenVPNController (Primary backend, fully automated)
///
/// Future implementations:
/// - WireGuardController
/// - IKEv2Controller
protocol VPNControlling {
    /// Establishes a VPN connection to the specified server
    /// - Parameter server: The VPN server to connect to
    /// - Throws: VPNControllerError on failure
    func connect(server: VPNServer) async throws
    
    /// Terminates the current VPN connection
    /// - Throws: VPNControllerError on failure
    func disconnect() async throws
    
    /// Returns a human-readable name for this VPN backend
    /// Examples: "OpenVPN CLI", "WireGuard", "IKEv2"
    var backendName: String { get }
    
    /// Indicates whether this backend is available/installed on the system
    /// Returns false if required binaries or applications are not found
    var isAvailable: Bool { get }
}

// MARK: - VPN Controller Error

/// Standard error type for VPN operations across all backends
/// Follows consistent error reporting for better UX
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
