import Foundation

// MARK: - ScriptRunner Errors

enum ScriptRunnerError: LocalizedError {
  case commandFailed(String)
  case authenticationRequired
  case authenticationFailed
  case authenticationCancelled
  case invalidPassword

  var errorDescription: String? {
    switch self {
    case .commandFailed(let message):
      return "Command failed: %@".localized(with: message)
    case .authenticationRequired:
      return "Authentication required for privileged operation".localized
    case .authenticationFailed:
      return "Authentication failed".localized
    case .authenticationCancelled:
      return "Authentication cancelled".localized
    case .invalidPassword:
      return "Invalid password format".localized
    }
  }
}

// MARK: - ScriptRunner Protocol

protocol ScriptRunnerProtocol {
  /// Execute a shell command, optionally with sudo privileges
  /// - Parameters:
  ///   - command: The shell command to execute
  ///   - privileged: If true, run with sudo using cached or freshly authenticated password
  /// - Returns: Command output as string
  func run(_ command: String, privileged: Bool) async throws -> String

  /// Ensures credentials are available (via cache, biometric, or password prompt)
  /// Call this before connection to handle cancellation early
  /// - Throws: `ScriptRunnerError.authenticationCancelled` if user cancels
  func ensureAuthenticated() async throws

  /// Clear cached credentials (call on app quit)
  func clearCredentials()

  /// Check if credentials are currently cached
  var hasCredentials: Bool { get }
}

// MARK: - ScriptRunner Implementation

/// Centralized script execution service with password caching.
/// Password is cached in memory after first Touch ID authentication
/// and persists until app quit for seamless VPN operations.
final class ScriptRunner: ScriptRunnerProtocol {

  // MARK: - Dependencies

  private let keychainManager: KeychainManagerProtocol
  private let passwordPromptService: PasswordPromptServiceProtocol

  // MARK: - Cached Credentials

  /// Password stored as Data for explicit zeroing capability
  private var cachedPassword: Data?

  /// Thread safety for credential access
  private let credentialLock = NSLock()

  var hasCredentials: Bool {
    credentialLock.lock()
    defer { credentialLock.unlock() }
    return cachedPassword != nil
  }

  // MARK: - Init

  init(
    keychainManager: KeychainManagerProtocol, passwordPromptService: PasswordPromptServiceProtocol
  ) {
    self.keychainManager = keychainManager
    self.passwordPromptService = passwordPromptService
  }

  // MARK: - Public API

  func run(_ command: String, privileged: Bool) async throws -> String {
    if privileged {
      return try await runPrivileged(command)
    }
    return try await runDirect(command)
  }

  func clearCredentials() {
    credentialLock.lock()
    defer { credentialLock.unlock() }

    // Zero out password data before releasing
    if var data = cachedPassword {
      data.resetBytes(in: 0..<data.count)
    }
    cachedPassword = nil
    Log.debug("ScriptRunner: Credentials cleared")
  }

  func ensureAuthenticated() async throws {
    // Already have cached password (already validated)
    if hasCredentials {
      Log.debug("ScriptRunner: Credentials already cached and validated")
      return
    }

    // Try biometric/Keychain
    if keychainManager.isPasswordStored() {
      Log.debug("ScriptRunner: Pre-authenticating via Touch ID/Keychain...")
      do {
        let password = try await keychainManager.getPassword()
        // Keychain passwords are already validated when stored
        cachePassword(password)
        Log.success("ScriptRunner: Pre-authentication successful (Keychain)")
        return
      } catch KeychainManager.KeychainError.authenticationCancelled {
        Log.info("ScriptRunner: Biometric pre-auth cancelled")
        throw ScriptRunnerError.authenticationCancelled
      } catch {
        Log.warning("ScriptRunner: Keychain pre-auth failed - \(error.localizedDescription)")
        // Fall through to password prompt
      }
    }

    // Fallback: Password prompt with validation and retry
    while true {
      Log.debug("ScriptRunner: Pre-authenticating via password prompt...")
      guard let password = await passwordPromptService.promptForPassword() else {
        Log.info("ScriptRunner: Password prompt cancelled")
        throw ScriptRunnerError.authenticationCancelled
      }

      // Validate password with sudo -S -v before caching
      Log.debug("ScriptRunner: Validating password...")
      let isValid = await validatePassword(password)

      if isValid {
        cachePassword(password)
        Log.success("ScriptRunner: Pre-authentication successful (password validated)")
        return
      }

      // Show incorrect password alert with retry option
      Log.warning("ScriptRunner: Password validation failed - incorrect password")
      let shouldRetry = await passwordPromptService.showIncorrectPasswordAlert()

      if !shouldRetry {
        Log.info("ScriptRunner: User cancelled after incorrect password")
        throw ScriptRunnerError.authenticationCancelled
      }
      // Loop continues to prompt again
    }
  }

  /// Validates password by testing with sudo -S -v
  private func validatePassword(_ password: String) async -> Bool {
    await withCheckedContinuation { continuation in
      let task = Process()
      task.executableURL = URL(fileURLWithPath: "/bin/bash")
      task.arguments = ["-c", "echo '\(password)' | sudo -S -v 2>/dev/null"]

      let pipe = Pipe()
      task.standardOutput = pipe
      task.standardError = pipe

      task.terminationHandler = { process in
        continuation.resume(returning: process.terminationStatus == 0)
      }

      do {
        try task.run()
      } catch {
        Log.error("ScriptRunner: Failed to validate password: \(error)")
        continuation.resume(returning: false)
      }
    }
  }

  // MARK: - Private: Direct Execution (Non-Privileged)

  private func runDirect(_ command: String) async throws -> String {
    Log.debug("ScriptRunner: Running non-privileged command")

    return try await withCheckedThrowingContinuation { continuation in
      let process = Process()
      process.launchPath = "/bin/sh"
      process.arguments = ["-c", command]

      let outputPipe = Pipe()
      let errorPipe = Pipe()
      process.standardOutput = outputPipe
      process.standardError = errorPipe

      var hasResumed = false
      let resumeLock = NSLock()

      process.terminationHandler = { proc in
        resumeLock.lock()
        guard !hasResumed else {
          resumeLock.unlock()
          return
        }
        hasResumed = true
        resumeLock.unlock()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outputData, encoding: .utf8) ?? ""

        if proc.terminationStatus == 0 {
          continuation.resume(returning: output.trimmingCharacters(in: .whitespacesAndNewlines))
        } else {
          let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
          let errorOutput = String(data: errorData, encoding: .utf8) ?? "Unknown error"
          continuation.resume(throwing: ScriptRunnerError.commandFailed(errorOutput))
        }
      }

      do {
        try process.run()

        // Timeout after 30 seconds for non-privileged commands
        DispatchQueue.global().asyncAfter(deadline: .now() + 30) {
          resumeLock.lock()
          guard !hasResumed else {
            resumeLock.unlock()
            return
          }
          hasResumed = true
          resumeLock.unlock()

          if process.isRunning {
            process.terminate()
          }
          continuation.resume(throwing: ScriptRunnerError.commandFailed("Command timed out"))
        }
      } catch {
        resumeLock.lock()
        guard !hasResumed else {
          resumeLock.unlock()
          return
        }
        hasResumed = true
        resumeLock.unlock()
        continuation.resume(throwing: ScriptRunnerError.commandFailed(error.localizedDescription))
      }
    }
  }

  // MARK: - Private: Privileged Execution

  private func runPrivileged(_ command: String) async throws -> String {
    // Try cached password first
    if let password = getCachedPassword() {
      Log.debug("ScriptRunner: Using cached credentials")
      return try await runWithSudo(command, password: password)
    }

    // Check if password is stored in Keychain
    if keychainManager.isPasswordStored() {
      Log.debug("ScriptRunner: Authenticating via Touch ID/Keychain...")

      do {
        let password = try await keychainManager.getPassword()
        cachePassword(password)
        Log.debug("ScriptRunner: Credentials cached for session")
        return try await runWithSudo(command, password: password)
      } catch KeychainManager.KeychainError.authenticationCancelled {
        Log.info("ScriptRunner: Biometric cancelled by user")
        throw ScriptRunnerError.authenticationCancelled
      } catch {
        Log.warning("ScriptRunner: Keychain auth failed - \(error.localizedDescription)")
        // Fall through to password prompt for other errors
      }
    }

    // Fallback: Show native password prompt
    Log.debug("ScriptRunner: Showing password prompt...")
    return try await runWithPasswordPrompt(command)
  }

  private func runWithPasswordPrompt(_ command: String) async throws -> String {
    // Show native macOS password dialog
    guard let password = await passwordPromptService.promptForPassword() else {
      Log.warning("ScriptRunner: User cancelled password prompt")
      throw ScriptRunnerError.authenticationCancelled
    }

    // Cache the entered password for the session
    cachePassword(password)
    Log.debug("ScriptRunner: Password entered and cached for session")

    // Execute with the entered password
    return try await runWithSudo(command, password: password)
  }

  private func runWithSudo(_ command: String, password: String) async throws -> String {
    // Use sudo sh -c to run the entire command as root
    // Use double quotes for outer wrapper, escape inner double quotes
    let escapedCommand = command.replacingOccurrences(of: "\"", with: "\\\"")
    let sudoCommand = "echo '\(password)' | sudo -S sh -c \"\(escapedCommand)\""

    return try await withCheckedThrowingContinuation { continuation in
      let process = Process()
      process.launchPath = "/bin/sh"
      process.arguments = ["-c", sudoCommand]

      let outputPipe = Pipe()
      let errorPipe = Pipe()
      process.standardOutput = outputPipe
      process.standardError = errorPipe

      do {
        try process.run()
        Log.debug("ScriptRunner: Process launched, waiting for auth...")

        // Wait briefly for sudo to process the password and start openvpn
        // If auth fails, stderr will have error message
        DispatchQueue.global().asyncAfter(deadline: .now() + 1.5) {
          // Check if there were immediate errors (wrong password, etc)
          let errorData = errorPipe.fileHandleForReading.availableData
          let errorOutput = String(data: errorData, encoding: .utf8) ?? ""

          if errorOutput.contains("incorrect password") || errorOutput.contains("Sorry, try again")
          {
            process.terminate()
            continuation.resume(throwing: ScriptRunnerError.authenticationFailed)
          } else if !process.isRunning && process.terminationStatus != 0 {
            // Process exited with error
            continuation.resume(
              throwing: ScriptRunnerError.commandFailed(
                errorOutput.isEmpty ? "Process failed" : errorOutput))
          } else {
            // Process is running (daemon started) or completed successfully
            Log.success("ScriptRunner: Command started successfully")
            continuation.resume(returning: "")
          }
        }
      } catch {
        continuation.resume(throwing: ScriptRunnerError.commandFailed(error.localizedDescription))
      }
    }
  }

  // MARK: - Private: Credential Management

  private func getCachedPassword() -> String? {
    credentialLock.lock()
    defer { credentialLock.unlock() }

    guard let data = cachedPassword else { return nil }
    return String(data: data, encoding: .utf8)
  }

  private func cachePassword(_ password: String) {
    credentialLock.lock()
    defer { credentialLock.unlock() }

    cachedPassword = password.data(using: .utf8)
  }
}
