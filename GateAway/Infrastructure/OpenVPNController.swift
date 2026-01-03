import Foundation

final class OpenVPNController: VPNControlling {

  // MARK: - Protocol

  var backendName: String { "OpenVPN CLI" }

  var isAvailable: Bool { fileManager.fileExists(atPath: openVPNBinary) }

  // MARK: - Properties

  private let fileManager = FileManager.default
  private var currentConfigPath: String?
  private var currentProcess: Process?
  private var managementSocket: FileHandle?
  private let vpnMonitor: VPNMonitorProtocol
  private let keychainManager: KeychainManagerProtocol

  private let openVPNBinary: String
  private let configDirectory: String
  private let pidFilePath: String
  private let logFilePath: String
  private let managementSocketPath: String

  // MARK: - Errors

  enum OpenVPNError: LocalizedError {
    case notInstalled
    case configurationCreationFailed
    case connectionFailed(String)
    case disconnectionFailed(String)
    case permissionDenied

    var errorDescription: String? {
      switch self {
      case .notInstalled:
        return "OpenVPN is not installed. Please install it via Settings."
      case .configurationCreationFailed:
        return "Failed to create OpenVPN configuration file."
      case .connectionFailed(let message):
        return "VPN connection failed: \(message)"
      case .disconnectionFailed(let message):
        return "VPN disconnection failed: \(message)"
      case .permissionDenied:
        return "Permission denied. OpenVPN requires administrator privileges."
      }
    }
  }

  // MARK: - Init

  init(vpnMonitor: VPNMonitorProtocol, keychainManager: KeychainManagerProtocol) {
    self.vpnMonitor = vpnMonitor
    self.keychainManager = keychainManager

    // Check Homebrew paths for OpenVPN using centralized constants
    openVPNBinary =
      Constants.Paths.openVPNBinaryPaths.first {
        FileManager.default.fileExists(atPath: $0)
      } ?? Constants.Paths.openVPNBinaryPaths[0]

    // Setup directories using centralized constants
    let homeDir = fileManager.homeDirectoryForCurrentUser
    configDirectory = homeDir.appendingPathComponent(Constants.Paths.configDirectory).path
    pidFilePath = "\(configDirectory)/\(Constants.Paths.pidFile)"
    logFilePath = "\(configDirectory)/\(Constants.Paths.logFile)"
    managementSocketPath = "\(configDirectory)/\(Constants.Paths.managementSocket)"

    // Create config directory if needed
    try? fileManager.createDirectory(atPath: configDirectory, withIntermediateDirectories: true)

    // Clean up stale socket
    try? fileManager.removeItem(atPath: managementSocketPath)
  }

  // MARK: - Connection

  func connectWithRetry(server: VPNServer, policy: RetryPolicy = .default) async throws {
    try await policy.execute {
      try await self.connect(server: server)
    }
  }

  func connect(server: VPNServer) async throws {
    Log.info("Connecting to \(server.countryLong) (\(server.hostName))")

    // 0. Kill any existing openvpn process (ensures only 1 connection)
    if getOpenVPNProcessCount() > 0 {
      Log.warning("Killing existing process before new connection")
      _ = sendManagementCommand("signal SIGTERM")
      try await Task.sleep(nanoseconds: 500_000_000)
    }

    // 1. Pre-flight Permission Check
    try PermissionService.shared.checkOpenVPNPermission()

    // 2. Check if OpenVPN is installed
    guard isInstalled() else {
      throw OpenVPNError.notInstalled
    }

    // 3. Create configuration file
    let configPath = try createConfiguration(for: server)
    currentConfigPath = configPath

    // 4. Start OpenVPN process
    try await startOpenVPN(configPath: configPath)

    Log.debug("Process running, waiting for CONNECTED state...")
    try await waitForConnection(server: server)

    Log.success("Connection established successfully")
  }

  private func waitForConnection(server: VPNServer) async throws {
    let maxAttempts = Constants.Timeouts.connectionAttempts

    for attempt in 1...maxAttempts {
      if isActuallyConnected() {
        Log.success("Connection established after \(attempt) seconds")
        return
      }

      // Check failure (process crashed)
      if !isOpenVPNRunning() {
        Log.error("Process terminated during connection")
        let errorMessage = extractErrorFromLog() ?? "Connection failed - check log"
        throw OpenVPNError.connectionFailed(errorMessage)
      }

      try await Task.sleep(nanoseconds: 1_000_000_000)
    }

    throw OpenVPNError.connectionFailed(
      "Connection timeout after \(maxAttempts) seconds - check server")
  }

  private func extractErrorFromLog() -> String? {
    guard let logContent = try? String(contentsOfFile: logFilePath, encoding: .utf8) else {
      return nil
    }

    let lastLines = logContent.components(separatedBy: "\n").suffix(5).joined(separator: " | ")
    Log.debug("Log: \(lastLines)")

    if lastLines.contains("AUTH_FAILED") {
      return "Authentication Failed"
    }

    return "Connection failed - check log"
  }

  func cancelConnection() {
    Log.info("Cancelling connection...")

    // Try management socket first
    if fileManager.fileExists(atPath: managementSocketPath) {
      Log.debug("Sending cancel via management socket...")
      if sendManagementCommand("signal SIGTERM") {
        Log.success("Cancel signal sent via socket")
        return
      }
    }

    // If socket doesn't exist, process hasn't fully started
    // The Task cancellation in VPNConnectionManager stops the retry loop
    Log.debug("No socket yet - Task cancellation will stop the connection")
  }

  func disconnect() async throws {
    Log.info("Disconnecting...")

    // Try management socket first
    // Try management interface first (NO SUDO REQUIRED!)
    if fileManager.fileExists(atPath: managementSocketPath) {
      if sendManagementCommand("signal SIGTERM") {
        Log.success("Graceful disconnect sent via management socket")
        try await Task.sleep(nanoseconds: 1_500_000_000)
      } else {
        Log.warning("Management socket failed, will try killall")
      }
    }

    // Check if there are still processes running
    let processCount = getOpenVPNProcessCount()
    if processCount > 0 {
      Log.warning("\(processCount) process(es) still running, using killall...")

      let killScript = """
        do shell script "killall -9 openvpn 2>/dev/null || true" with administrator privileges
        """

      var error: NSDictionary?
      if let scriptObject = NSAppleScript(source: killScript) {
        let _ = scriptObject.executeAndReturnError(&error)
        if let error = error {
          Log.warning("Kill script error: \(error)")
        } else {
          Log.success("All OpenVPN processes killed")
          try await Task.sleep(nanoseconds: 500_000_000)
        }
      }
    }

    // Stop monitoring before cleanup
    Log.debug("Stopping VPN monitoring...")
    vpnMonitor.stopMonitoring()

    currentProcess = nil
    try? fileManager.removeItem(atPath: pidFilePath)
    try? fileManager.removeItem(atPath: managementSocketPath)

    if let files = try? fileManager.contentsOfDirectory(atPath: configDirectory) {
      for file in files where file.hasSuffix(".ovpn") {
        try? fileManager.removeItem(atPath: "\(configDirectory)/\(file)")
      }
    }

    currentConfigPath = nil
    Log.success("Disconnected successfully")
  }

  private func getOpenVPNProcessCount() -> Int {
    let task = Process()
    task.launchPath = "/bin/sh"
    task.arguments = ["-c", ShellCommands.checkProcessCount]

    let pipe = Pipe()
    task.standardOutput = pipe

    do {
      try task.run()
      task.waitUntilExit()

      let data = pipe.fileHandleForReading.readDataToEndOfFile()
      if let output = String(data: data, encoding: .utf8) {
        return Int(output.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
      }
    } catch {
      Log.warning("Failed to get process count: \(error)")
    }

    return 0
  }

  // MARK: - Helpers

  func isInstalled() -> Bool {
    return fileManager.fileExists(atPath: openVPNBinary)
  }

  func getConnectionStatus() -> (isConnected: Bool, vpnIP: String?) {
    guard let stateOutput = queryConnectionState() else {
      return (false, nil)
    }

    let components = stateOutput.components(separatedBy: ",")
    if components.count >= 2 {
      let state = components[1]
      let isConnected = state == "CONNECTED"
      let vpnIP = components.count >= 4 ? components[3] : nil
      return (isConnected, vpnIP)
    }

    return (false, nil)
  }

  // MARK: - Configuration

  private func createConfiguration(for server: VPNServer) throws -> String {
    guard let configData = Data(base64Encoded: server.openVPNConfigBase64),
      let configString = String(data: configData, encoding: .utf8)
    else {
      throw OpenVPNError.configurationCreationFailed
    }

    let authFilePath = "\(configDirectory)/auth.txt"
    let passwordData = try? keychainManager.get(account: "vpn")
    let password = passwordData.flatMap { String(data: $0, encoding: .utf8) } ?? "vpn"

    let authContent = "vpn\n\(password)\n"
    try authContent.write(toFile: authFilePath, atomically: true, encoding: .utf8)
    try? fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: authFilePath)

    var cleanLines = configString.components(separatedBy: "\n").filter { line in
      let trimmed = line.trimmingCharacters(in: .whitespaces)
      return !trimmed.hasPrefix("#auth-user-pass") && !trimmed.hasPrefix("auth-user-pass")
        && !trimmed.hasPrefix("management ")
    }

    // Add our configuration block
    cleanLines.append("")
    cleanLines.append("# GateAway Configuration")
    cleanLines.append("auth-user-pass \(authFilePath)")
    cleanLines.append("auth-nocache")
    cleanLines.append("auth-retry nointeract")

    // Standard ciphers
    cleanLines.append("data-ciphers AES-128-CBC:AES-256-GCM:AES-128-GCM:CHACHA20-POLY1305")
    cleanLines.append("data-ciphers-fallback AES-128-CBC")
    cleanLines.append("cipher AES-128-CBC")

    // Networking
    cleanLines.append("redirect-gateway def1")
    cleanLines.append("dhcp-option DNS 8.8.8.8")
    cleanLines.append("dhcp-option DNS 8.8.4.4")

    // Permissions & Management
    cleanLines.append("script-security 2")
    cleanLines.append("management \(managementSocketPath) unix")
    cleanLines.append("daemon")
    cleanLines.append("log \(logFilePath)")
    cleanLines.append("writepid \(pidFilePath)")
    cleanLines.append("persist-tun")
    cleanLines.append("persist-key")
    cleanLines.append("verb 3")
    cleanLines.append("")

    let finalConfig = cleanLines.joined(separator: "\n")

    let configName = "vpngate_\(server.countryShort)_\(Int(Date().timeIntervalSince1970)).ovpn"
      .replacingOccurrences(of: " ", with: "_")
    let configPath = "\(configDirectory)/\(configName)"

    try finalConfig.write(toFile: configPath, atomically: true, encoding: .utf8)
    Log.debug("Created config: \(configPath)")

    return configPath
  }

  // MARK: - OpenVPN Process

  private func startOpenVPN(configPath: String) async throws {
    if keychainManager.isPasswordStored() {
      Log.debug("Password found in Keychain, using Touch ID...")

      do {
        let password = try await keychainManager.getPassword()
        Log.success("Retrieved password via Touch ID")
        try await startOpenVPNWithPassword(password, configPath: configPath)
      } catch KeychainManager.KeychainError.authenticationCancelled {
        Log.warning("User cancelled Touch ID")
        throw OpenVPNError.connectionFailed("Touch ID authentication cancelled")
      } catch {
        Log.warning("Keychain retrieval failed: \(error). Falling back to system prompt.")
        try await startOpenVPNWithAppleScript(configPath: configPath)
      }
    } else {
      Log.debug("No password in Keychain, using system auth prompt...")
      try await startOpenVPNWithAppleScript(configPath: configPath)
    }
  }

  private func startOpenVPNWithPassword(_ password: String, configPath: String) async throws {
    let command = ShellCommands.startVPNWithSudo(
      binary: openVPNBinary,
      configPath: configPath,
      password: password
    )

    let task = Process()
    task.launchPath = "/bin/sh"
    task.arguments = ["-c", command]
    task.standardOutput = Pipe()
    task.standardError = Pipe()

    do {
      try task.run()
      Log.success("Process started with Keychain password")
      try await Task.sleep(nanoseconds: 2_000_000_000)
      try await verifyOpenVPNStarted()
    } catch {
      Log.error("Failed to start with password: \(error)")
      throw OpenVPNError.connectionFailed("Failed to start OpenVPN: \(error.localizedDescription)")
    }
  }

  private func startOpenVPNWithAppleScript(configPath: String) async throws {
    let script = """
      do shell script "killall openvpn 2>/dev/null || true; sleep 1; \(openVPNBinary) --config '\(configPath)'" with administrator privileges
      """

    Log.debug("Requesting admin privileges...")

    guard let scriptObject = NSAppleScript(source: script) else {
      throw OpenVPNError.connectionFailed("Failed to create admin prompt script")
    }

    var executionError: NSDictionary?
    let _ = scriptObject.executeAndReturnError(&executionError)

    if let error = executionError {
      let errorCode = error["NSAppleScriptErrorNumber"] as? Int ?? 0
      let errorMessage = error["NSAppleScriptErrorBriefMessage"] as? String ?? "Unknown error"
      Log.error("Admin script error (code: \(errorCode)): \(errorMessage)")

      if errorCode == -128 {
        throw OpenVPNError.connectionFailed("User cancelled authentication")
      } else {
        throw OpenVPNError.connectionFailed("Script execution failed: \(errorMessage)")
      }
    }

    Log.success("AppleScript completed - process should be starting")
    try await Task.sleep(nanoseconds: 2_000_000_000)
    try await verifyOpenVPNStarted()
  }

  private func verifyOpenVPNStarted() async throws {
    if isOpenVPNRunning() {
      Log.success("Process confirmed running")

      var socketWait = 0
      while socketWait < 5 && !fileManager.fileExists(atPath: managementSocketPath) {
        try await Task.sleep(nanoseconds: 500_000_000)
        socketWait += 1
      }

      if fileManager.fileExists(atPath: managementSocketPath) {
        Log.success("Management socket ready")
        connectToManagementInterface()
        vpnMonitor.startMonitoring()
      } else {
        Log.warning("Management socket not created")
        throw OpenVPNError.connectionFailed("Management socket not available")
      }
    } else {
      Log.error("Process failed to start")
      if let logContent = try? String(contentsOfFile: logFilePath, encoding: .utf8) {
        let lastLines = logContent.components(separatedBy: "\n").suffix(3).joined(separator: " | ")
        Log.debug("Log: \(lastLines)")
      }
      throw OpenVPNError.connectionFailed("Process failed to start")
    }
  }

  // MARK: - Process Management

  private func isOpenVPNRunning() -> Bool {
    let task = Process()
    task.launchPath = "/bin/sh"
    task.arguments = ["-c", ShellCommands.checkProcessCountAlt]

    let pipe = Pipe()
    task.standardOutput = pipe

    do {
      try task.run()
      task.waitUntilExit()

      let data = pipe.fileHandleForReading.readDataToEndOfFile()
      if let output = String(data: data, encoding: .utf8),
        let count = Int(output.trimmingCharacters(in: .whitespacesAndNewlines))
      {
        let isRunning = count > 0
        if isRunning {
          Log.debug("Process check: \(count) process(es) running")
        }
        return isRunning
      }
    } catch {
      Log.warning("Failed to check process: \(error)")
    }

    return false
  }

  private func connectToManagementInterface() {
    guard fileManager.fileExists(atPath: managementSocketPath) else {
      Log.warning("Management socket not ready yet")
      return
    }

    Log.debug("Management interface available at \(managementSocketPath)")
  }

  private func queryConnectionState() -> String? {
    guard fileManager.fileExists(atPath: managementSocketPath) else {
      return nil
    }

    let task = Process()
    task.launchPath = "/bin/sh"
    task.arguments = [
      "-c",
      ShellCommands.queryState(socketPath: managementSocketPath),
    ]

    let pipe = Pipe()
    task.standardOutput = pipe
    task.standardError = Pipe()

    do {
      try task.run()
      task.waitUntilExit()

      if task.terminationStatus == 0 {
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(
          in: .whitespacesAndNewlines),
          !output.isEmpty
        {
          // Output format: "1234567890,CONNECTED,SUCCESS,10.8.0.6,..."
          return output
        }
      }
    } catch {
      Log.warning("Failed to query state: \(error)")
    }

    return nil
  }

  private func isActuallyConnected() -> Bool {
    guard let stateOutput = queryConnectionState() else {
      return false
    }

    let components = stateOutput.components(separatedBy: ",")
    if components.count >= 2 {
      let state = components[1]
      let isConnected = state == "CONNECTED"

      if isConnected {
        Log.success("State: CONNECTED")
        if components.count >= 4 {
          let ip = components[3]
          Log.success("VPN IP: \(ip)")
        }
      } else {
        Log.debug("State: \(state)")
      }

      return isConnected
    }

    return false
  }

  private func sendManagementCommand(_ command: String) -> Bool {
    guard fileManager.fileExists(atPath: managementSocketPath) else {
      Log.warning("Management socket not found")
      return false
    }

    let task = Process()
    task.launchPath = "/usr/bin/nc"
    task.arguments = ["-U", managementSocketPath]

    let inputPipe = Pipe()
    task.standardInput = inputPipe
    task.standardOutput = Pipe()
    task.standardError = Pipe()

    do {
      try task.run()

      let commandData = "\(command)\n".data(using: .utf8)!
      inputPipe.fileHandleForWriting.write(commandData)
      inputPipe.fileHandleForWriting.closeFile()

      task.waitUntilExit()

      if task.terminationStatus == 0 {
        Log.success("Sent '\(command)' via management socket")
        return true
      } else {
        Log.warning("Failed to send command via socket")
        return false
      }
    } catch {
      Log.warning("Socket communication error: \(error)")
      return false
    }
  }
}
