import Foundation

// MARK: - Protocol

/// Service for managing network protection features (Kill Switch, IPv6)
protocol NetworkProtectionServiceProtocol {
  /// Enable the Kill Switch firewall rules
  func enableKillSwitch() async throws

  /// Disable the Kill Switch firewall rules
  func disableKillSwitch() async throws

  /// Check if Kill Switch is currently active
  func isKillSwitchActive() async -> Bool

  /// Disable IPv6 on all network interfaces
  func disableIPv6() async throws

  /// Restore IPv6 on all network interfaces
  func restoreIPv6() async throws
}

// MARK: - Implementation

/// Manages PF firewall rules for Kill Switch and IPv6 protection
final class NetworkProtectionService: NetworkProtectionServiceProtocol {

  // MARK: - Dependencies

  private let scriptRunner: ScriptRunnerProtocol
  private let fileManager: FileManager

  // MARK: - Paths

  private let configDirectory: String
  private let rulesFilePath: String

  // MARK: - Init

  init(scriptRunner: ScriptRunnerProtocol, fileManager: FileManager = .default) {
    self.scriptRunner = scriptRunner
    self.fileManager = fileManager

    let homeDir = fileManager.homeDirectoryForCurrentUser
    self.configDirectory = homeDir.appendingPathComponent(Constants.Paths.configDirectory).path
    self.rulesFilePath = "\(configDirectory)/\(Constants.Paths.killSwitchRulesFile)"
  }

  // MARK: - Kill Switch

  func enableKillSwitch() async throws {
    Log.info("Enabling Kill Switch...")

    // 1. Generate rules file
    try generateKillSwitchRules()

    // 2. Apply rules via pfctl (requires sudo)
    let command = ShellCommands.enableKillSwitch(rulesPath: rulesFilePath)
    _ = try await scriptRunner.run(command, privileged: true)

    Log.success("Kill Switch enabled")
  }

  func disableKillSwitch() async throws {
    Log.info("Disabling Kill Switch...")

    // Flush all rules in our anchor
    _ = try await scriptRunner.run(ShellCommands.disableKillSwitch, privileged: true)

    // Clean up rules file
    try? fileManager.removeItem(atPath: rulesFilePath)

    Log.success("Kill Switch disabled")
  }

  func isKillSwitchActive() async -> Bool {
    // Check if our anchor has any rules
    let command = "pfctl -a com.gateaway -sr 2>/dev/null | wc -l"
    guard let output = try? await scriptRunner.run(command, privileged: false) else {
      return false
    }

    let count = Int(output.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
    return count > 0
  }

  // MARK: - IPv6 Protection

  func disableIPv6() async throws {
    Log.info("Disabling IPv6...")
    _ = try await scriptRunner.run(ShellCommands.disableIPv6, privileged: true)
    Log.success("IPv6 disabled")
  }

  func restoreIPv6() async throws {
    Log.info("Restoring IPv6...")
    _ = try await scriptRunner.run(ShellCommands.enableIPv6, privileged: true)
    Log.success("IPv6 restored")
  }

  // MARK: - Private

  private func generateKillSwitchRules() throws {
    // Ensure config directory exists
    try? fileManager.createDirectory(atPath: configDirectory, withIntermediateDirectories: true)

    let rules = Constants.FirewallRules.killSwitchRules()
    try rules.write(toFile: rulesFilePath, atomically: true, encoding: .utf8)
    Log.debug("Generated Kill Switch rules at: \(rulesFilePath)")
  }
}
