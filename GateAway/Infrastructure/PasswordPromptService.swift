import AppKit

// MARK: - Protocol

protocol PasswordPromptServiceProtocol {
  @MainActor
  func promptForPassword() async -> String?

  @MainActor
  func showIncorrectPasswordAlert() async -> Bool
}

// MARK: - Password Prompt Service

/// Native macOS password prompt using NSAlert with SecureTextField
/// Used by ScriptRunner when no password is cached or stored in Keychain
final class PasswordPromptService: PasswordPromptServiceProtocol {

  static let shared = PasswordPromptService()

  private init() {}

  /// Shows a native macOS password dialog
  /// - Returns: The entered password, or nil if cancelled
  @MainActor
  func promptForPassword() async -> String? {
    let alert = NSAlert()
    alert.messageText = "Administrator Password Required".localized
    alert.informativeText = "GateAway needs your password to connect to VPN.".localized
    alert.alertStyle = .informational
    alert.addButton(withTitle: "Connect".localized)
    alert.addButton(withTitle: "Cancel".localized)

    // Create password field
    let passwordField = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
    passwordField.placeholderString = "Enter your password".localized
    alert.accessoryView = passwordField

    // Make password field first responder
    alert.window.initialFirstResponder = passwordField

    let response = alert.runModal()

    if response == .alertFirstButtonReturn {
      let password = passwordField.stringValue
      return password.isEmpty ? nil : password
    }

    return nil
  }

  /// Shows an "Incorrect Password" alert with Try Again option
  /// - Returns: true if user wants to try again, false to cancel
  @MainActor
  func showIncorrectPasswordAlert() async -> Bool {
    let alert = NSAlert()
    alert.messageText = "Incorrect Password".localized
    alert.informativeText = "The password you entered is incorrect. Please try again.".localized
    alert.alertStyle = .warning
    alert.addButton(withTitle: "Try Again".localized)
    alert.addButton(withTitle: "Cancel".localized)

    return alert.runModal() == .alertFirstButtonReturn
  }
}
