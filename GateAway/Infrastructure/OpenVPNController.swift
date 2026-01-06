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
  private let scriptRunner: ScriptRunnerProtocol
  private let permissionService: PermissionServiceProtocol

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
        return "OpenVPN is not installed. Please install it via Settings.".localized
      case .configurationCreationFailed:
        return "Failed to create OpenVPN configuration file.".localized
      case .connectionFailed(let message):
        return "VPN connection failed: %@".localized(with: message)
      case .disconnectionFailed(let message):
        return "VPN disconnection failed: %@".localized(with: message)
      case .permissionDenied:
        return "Permission denied. OpenVPN requires administrator privileges.".localized
      }
    }
  }

  // MARK: - Init

  init(
    vpnMonitor: VPNMonitorProtocol, keychainManager: KeychainManagerProtocol,
    scriptRunner: ScriptRunnerProtocol, permissionService: PermissionServiceProtocol
  ) {
    self.vpnMonitor = vpnMonitor
    self.keychainManager = keychainManager
    self.scriptRunner = scriptRunner
    self.permissionService = permissionService

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
    if await getOpenVPNProcessCount() > 0 {
      Log.warning("Killing existing process before new connection")
      _ = await sendManagementCommand("signal SIGTERM")
      try await Task.sleep(nanoseconds: 500_000_000)
    }

    // 1. Pre-flight Permission Check
    try permissionService.checkOpenVPNPermission()

    // 2. Check if OpenVPN is installed
    guard isAvailable else {
      throw OpenVPNError.notInstalled
    }

    // 3. Pre-authenticate (handles cancellation before VPN setup)
    try await scriptRunner.ensureAuthenticated()

    // 4. Create configuration file
    let configPath = try createConfiguration(for: server)
    currentConfigPath = configPath

    // 5. Start OpenVPN process
    try await startOpenVPN(configPath: configPath)

    Log.debug("Process running, waiting for CONNECTED state...")
    try await waitForConnection(server: server)

    Log.success("Connection established successfully")
  }

  private func waitForConnection(server: VPNServer) async throws {
    let maxAttempts = Constants.Timeouts.connectionAttempts

    for attempt in 1...maxAttempts {
      if await isActuallyConnected() {
        Log.success("Connection established after \(attempt) seconds")
        return
      }

      // Check failure (process crashed)
      if await !isOpenVPNRunning() {
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

  func cancelConnection() async {
    Log.info("Cancelling connection...")

    // Try management socket first
    if fileManager.fileExists(atPath: managementSocketPath) {
      Log.debug("Sending cancel via management socket...")
      if await sendManagementCommand("signal SIGTERM") {
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
      if await sendManagementCommand("signal SIGTERM") {
        Log.success("Graceful disconnect sent via management socket")
        try await Task.sleep(nanoseconds: 1_500_000_000)
      } else {
        Log.warning("Management socket failed, will try killall")
      }
    }

    // Check if there are still processes running
    let processCount = await getOpenVPNProcessCount()
    if processCount > 0 {
      Log.warning("\(processCount) process(es) still running, using force kill...")

      do {
        _ = try await scriptRunner.run(ShellCommands.killOpenVPNForce, privileged: true)
        Log.success("All OpenVPN processes killed")
        try await Task.sleep(nanoseconds: 500_000_000)
      } catch {
        Log.warning("Force kill failed: \(error.localizedDescription)")
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

  private func getOpenVPNProcessCount() async -> Int {
    await withCheckedContinuation { continuation in
      let task = Process()
      task.launchPath = "/bin/sh"
      task.arguments = ["-c", ShellCommands.checkProcessCount]

      let pipe = Pipe()
      task.standardOutput = pipe

      var hasResumed = false
      let resumeLock = NSLock()

      task.terminationHandler = { _ in
        resumeLock.lock()
        guard !hasResumed else {
          resumeLock.unlock()
          return
        }
        hasResumed = true
        resumeLock.unlock()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let result =
          Int(
            String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
              ?? "") ?? 0
        continuation.resume(returning: result)
      }

      do {
        try task.run()

        // Timeout after 5 seconds
        DispatchQueue.global().asyncAfter(deadline: .now() + 5) {
          resumeLock.lock()
          guard !hasResumed else {
            resumeLock.unlock()
            return
          }
          hasResumed = true
          resumeLock.unlock()

          if task.isRunning {
            task.terminate()
          }
          continuation.resume(returning: 0)
        }
      } catch {
        resumeLock.lock()
        guard !hasResumed else {
          resumeLock.unlock()
          return
        }
        hasResumed = true
        resumeLock.unlock()
        Log.warning("Failed to get process count: \(error)")
        continuation.resume(returning: 0)
      }
    }
  }

  // MARK: - Helpers

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
    // Use ScriptRunner for privileged execution - handles auth caching automatically
    Log.debug("Starting OpenVPN via ScriptRunner...")

    // Build VPN startup command using centralized ShellCommands
    let vpnCommand = ShellCommands.startVPNCommand(binary: openVPNBinary, configPath: configPath)

    do {
      _ = try await scriptRunner.run(vpnCommand, privileged: true)
      Log.success("OpenVPN process started via ScriptRunner")

      // Wait for process to initialize
      try await Task.sleep(nanoseconds: 2_000_000_000)
      try await verifyOpenVPNStarted()
    } catch ScriptRunnerError.authenticationCancelled {
      Log.info("Authentication cancelled by user")
      throw ScriptRunnerError.authenticationCancelled
    } catch ScriptRunnerError.authenticationFailed {
      Log.warning("Authentication failed")
      throw OpenVPNError.connectionFailed("Authentication failed")
    } catch ScriptRunnerError.commandFailed(let msg) {
      Log.error("Command failed: \(msg)")
      throw OpenVPNError.connectionFailed("Failed to start OpenVPN: \(msg)")
    } catch {
      Log.error("Unexpected error: \(error)")
      throw OpenVPNError.connectionFailed("Failed to start OpenVPN: \(error.localizedDescription)")
    }
  }

  // MARK: - Deprecated: Old auth methods removed - now using ScriptRunner

  private func verifyOpenVPNStarted() async throws {
    if await isOpenVPNRunning() {
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

  private func isOpenVPNRunning() async -> Bool {
    await withCheckedContinuation { continuation in
      let task = Process()
      task.launchPath = "/bin/sh"
      task.arguments = ["-c", ShellCommands.checkProcessCountAlt]

      let pipe = Pipe()
      task.standardOutput = pipe

      var hasResumed = false
      let resumeLock = NSLock()

      task.terminationHandler = { _ in
        resumeLock.lock()
        guard !hasResumed else {
          resumeLock.unlock()
          return
        }
        hasResumed = true
        resumeLock.unlock()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        var isRunning = false
        if let output = String(data: data, encoding: .utf8),
          let count = Int(output.trimmingCharacters(in: .whitespacesAndNewlines))
        {
          isRunning = count > 0
          if isRunning {
            Log.debug("Process check: \(count) process(es) running")
          }
        }
        continuation.resume(returning: isRunning)
      }

      do {
        try task.run()

        // Timeout after 5 seconds
        DispatchQueue.global().asyncAfter(deadline: .now() + 5) {
          resumeLock.lock()
          guard !hasResumed else {
            resumeLock.unlock()
            return
          }
          hasResumed = true
          resumeLock.unlock()

          if task.isRunning {
            task.terminate()
          }
          continuation.resume(returning: false)
        }
      } catch {
        resumeLock.lock()
        guard !hasResumed else {
          resumeLock.unlock()
          return
        }
        hasResumed = true
        resumeLock.unlock()
        Log.warning("Failed to check process: \(error)")
        continuation.resume(returning: false)
      }
    }
  }

  private func connectToManagementInterface() {
    guard fileManager.fileExists(atPath: managementSocketPath) else {
      Log.warning("Management socket not ready yet")
      return
    }

    Log.debug("Management interface available at \(managementSocketPath)")
  }

  private func queryConnectionState() async -> String? {
    guard fileManager.fileExists(atPath: managementSocketPath) else {
      return nil
    }

    return await withCheckedContinuation { continuation in
      let task = Process()
      task.launchPath = "/bin/sh"
      task.arguments = [
        "-c",
        ShellCommands.queryState(socketPath: self.managementSocketPath),
      ]

      let pipe = Pipe()
      task.standardOutput = pipe
      task.standardError = Pipe()

      var hasResumed = false
      let resumeLock = NSLock()

      task.terminationHandler = { proc in
        resumeLock.lock()
        guard !hasResumed else {
          resumeLock.unlock()
          return
        }
        hasResumed = true
        resumeLock.unlock()

        var output: String?
        if proc.terminationStatus == 0 {
          let data = pipe.fileHandleForReading.readDataToEndOfFile()
          if let result = String(data: data, encoding: .utf8)?.trimmingCharacters(
            in: .whitespacesAndNewlines),
            !result.isEmpty
          {
            output = result
          }
        }
        continuation.resume(returning: output)
      }

      do {
        try task.run()

        DispatchQueue.global().asyncAfter(deadline: .now() + 5) {
          resumeLock.lock()
          guard !hasResumed else {
            resumeLock.unlock()
            return
          }
          hasResumed = true
          resumeLock.unlock()

          if task.isRunning {
            task.terminate()
          }
          continuation.resume(returning: nil)
        }
      } catch {
        resumeLock.lock()
        guard !hasResumed else {
          resumeLock.unlock()
          return
        }
        hasResumed = true
        resumeLock.unlock()
        Log.warning("Failed to query state: \(error)")
        continuation.resume(returning: nil)
      }
    }
  }

  private func isActuallyConnected() async -> Bool {
    guard let stateOutput = await queryConnectionState() else {
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

  private func sendManagementCommand(_ command: String) async -> Bool {
    guard fileManager.fileExists(atPath: managementSocketPath) else {
      Log.warning("Management socket not found")
      return false
    }

    return await withCheckedContinuation { continuation in
      let task = Process()
      task.launchPath = "/usr/bin/nc"
      task.arguments = ["-U", self.managementSocketPath]

      let inputPipe = Pipe()
      task.standardInput = inputPipe
      task.standardOutput = Pipe()
      task.standardError = Pipe()

      var hasResumed = false
      let resumeLock = NSLock()

      task.terminationHandler = { proc in
        resumeLock.lock()
        guard !hasResumed else {
          resumeLock.unlock()
          return
        }
        hasResumed = true
        resumeLock.unlock()

        let success = proc.terminationStatus == 0
        if success {
          Log.success("Sent '\(command)' via management socket")
        } else {
          Log.warning("Failed to send command via socket")
        }
        continuation.resume(returning: success)
      }

      do {
        try task.run()

        if let commandData = "\(command)\n".data(using: .utf8) {
          inputPipe.fileHandleForWriting.write(commandData)
        }
        inputPipe.fileHandleForWriting.closeFile()

        DispatchQueue.global().asyncAfter(deadline: .now() + 5) {
          resumeLock.lock()
          guard !hasResumed else {
            resumeLock.unlock()
            return
          }
          hasResumed = true
          resumeLock.unlock()

          if task.isRunning {
            task.terminate()
          }
          continuation.resume(returning: false)
        }
      } catch {
        resumeLock.lock()
        guard !hasResumed else {
          resumeLock.unlock()
          return
        }
        hasResumed = true
        resumeLock.unlock()
        Log.warning("Socket communication error: \(error)")
        continuation.resume(returning: false)
      }
    }
  }
}
