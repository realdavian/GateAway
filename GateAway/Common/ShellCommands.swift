import Foundation

// MARK: - Shell Commands

/// Centralized shell command strings used throughout the app
enum ShellCommands {

  // MARK: - Process Management

  /// Check count of running OpenVPN processes
  static let checkProcessCount = "ps aux | grep 'openvpn --config' | grep -v grep | wc -l"

  /// Alternative process check using bracket trick
  static let checkProcessCountAlt = "ps aux | grep '[o]penvpn --config' | wc -l"

  /// Kill all OpenVPN processes (silent failure)
  static let killOpenVPN = "killall openvpn 2>/dev/null || true"

  /// Kill all OpenVPN processes forcefully
  static let killOpenVPNForce = "killall -9 openvpn 2>/dev/null || true"

  // MARK: - OpenVPN

  /// Build OpenVPN start command
  /// - Parameters:
  ///   - binary: Path to openvpn binary
  ///   - configPath: Path to .ovpn config file
  /// - Returns: Shell command string
  static func startVPN(binary: String, configPath: String) -> String {
    "\(binary) --config '\(configPath)'"
  }

  /// Build OpenVPN start command with password
  /// - Parameters:
  ///   - binary: Path to openvpn binary
  ///   - configPath: Path to .ovpn config file
  ///   - password: Admin password for sudo
  /// - Returns: Shell command string
  static func startVPNWithSudo(binary: String, configPath: String, password: String) -> String {
    """
    killall openvpn 2>/dev/null || true
    sleep 1
    echo '\(password)' | sudo -S \(binary) --config '\(configPath)'
    """
  }

  // MARK: - Management Socket

  /// Send command to OpenVPN management socket
  /// - Parameters:
  ///   - command: Management command (e.g., "state", "signal SIGTERM")
  ///   - socketPath: Path to management socket
  /// - Returns: Shell command string
  static func managementCommand(_ command: String, socketPath: String) -> String {
    "echo '\(command)' | nc -w 1 -U \(socketPath) 2>/dev/null"
  }

  /// Query connection state from management socket
  static func queryState(socketPath: String) -> String {
    "echo 'state' | nc -w 1 -U \(socketPath) 2>/dev/null | grep -v '^>' | grep -v '^END' | grep '^[0-9]'"
  }

  // MARK: - Homebrew

  /// Install OpenVPN via Homebrew
  static let brewInstallOpenVPN = "brew install openvpn"

  /// Install Homebrew then OpenVPN
  static let installHomebrewAndOpenVPN = """
    /bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\" && \\
    eval \"$(/opt/homebrew/bin/brew shellenv)\" && \\
    brew install openvpn
    """

  // MARK: - Network Protection (Future)

  /// Enable PF firewall kill switch
  static func enableKillSwitch(rulesPath: String) -> String {
    "pfctl -a com.gateaway -f \(rulesPath)"
  }

  /// Disable PF firewall kill switch
  static let disableKillSwitch = "pfctl -a com.gateaway -F all"

  /// Disable IPv6 on common interfaces
  static let disableIPv6 = "networksetup -setv6off Wi-Fi; networksetup -setv6off Ethernet"

  /// Re-enable IPv6 on common interfaces
  static let enableIPv6 =
    "networksetup -setv6automatic Wi-Fi; networksetup -setv6automatic Ethernet"
}
