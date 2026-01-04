import Foundation

// MARK: - App Constants

/// Centralized constants for the application
enum Constants {

  // MARK: - Timeouts

  enum Timeouts {
    /// API request timeout in seconds
    static let apiRequest: TimeInterval = 20

    /// Maximum seconds to wait for VPN connection
    static let connectionAttempts: Int = 30

    /// Monitoring poll interval in seconds
    static let monitoringPoll: TimeInterval = 1.0

    /// Socket wait timeout in seconds
    static let socketWait: Int = 5
  }

  // MARK: - Limits

  enum Limits {
    /// Default number of top servers to show per country
    static let defaultTopKServers: Int = 5

    /// Maximum retry count for connections
    static let maxRetryCount: Int = 3

    /// Maximum history days for telemetry
    static let telemetryHistoryDays: Int = 30

    /// Default server cache TTL in minutes
    static let defaultCacheTTL: Int = 30
  }

  // MARK: - Paths

  enum Paths {
    /// App config directory name (in user home)
    static let configDirectory = ".gateaway"

    /// OpenVPN binary paths (checked in order)
    static let openVPNBinaryPaths = [
      "/opt/homebrew/sbin/openvpn",
      "/usr/local/sbin/openvpn",
      "/usr/sbin/openvpn",
    ]

    /// Homebrew binary paths
    static let brewBinaryPaths = [
      "/opt/homebrew/bin/brew",
      "/usr/local/bin/brew",
    ]

    /// Config file names
    static let pidFile = "openvpn.pid"
    static let logFile = "openvpn.log"
    static let managementSocket = "openvpn.sock"
    static let authFile = "auth.txt"
    static let killSwitchRulesFile = "killswitch.rules"

    /// Endpoints
    static let vpngate = "https://www.vpngate.net/api/iphone/"
  }

  // MARK: - Firewall Rules

  enum FirewallRules {
    /// PF rules template for Kill Switch - blocks all traffic except VPN
    static func killSwitchRules(timestamp: Date = Date()) -> String {
      """
      # GateAway Kill Switch Rules
      # Generated at: \(timestamp)
      # Purpose: Block all traffic except VPN tunnel

      # Block all traffic by default
      block all

      # Allow loopback (required for system)
      pass on lo0 all

      # Allow VPN tunnel interfaces (utun*)
      pass on utun0 all
      pass on utun1 all
      pass on utun2 all
      pass on utun3 all

      # Allow OpenVPN to establish connection (UDP/TCP)
      pass out proto udp to any port 1194
      pass out proto tcp to any port 443
      pass out proto tcp to any port 1194

      # Allow DNS through VPN only (will be blocked if VPN down)
      pass out on utun0 proto udp to any port 53
      pass out on utun1 proto udp to any port 53

      # Allow DHCP for local network
      pass out proto udp from any port 68 to any port 67
      pass in proto udp from any port 67 to any port 68
      """
    }
  }

  // MARK: - VPN Credentials

  enum VPNCredentials {
    /// Default VPNGate username
    static let defaultUsername = "vpn"

    /// Default VPNGate password
    static let defaultPassword = "vpn"
  }

  // MARK: - UserDefaults Keys

  enum StorageKeys {
    static let serverCacheTTL = "serverCacheTTL"
    static let selectedSettingsTab = "selectedSettingsTab"
    static let autoReconnectOnDrop = "prefs.autoReconnectOnDrop"
    static let killSwitchEnabled = "prefs.killSwitchEnabled"
    static let ipv6LeakProtection = "prefs.ipv6LeakProtection"
    static let securityAutoReconnect = "security.autoReconnect"
    static let securityDNSLeakProtection = "security.dnsLeakProtection"
    static let vpnUsername = "vpn.username"
    static let vpnPassword = "vpn.password"
  }
}
