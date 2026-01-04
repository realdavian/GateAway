import AppKit
import SwiftUI

// MARK: - Password Setup Dialog

/// Apple-style password dialog using NSAlert with accessory view
/// Matches the look and feel of macOS authentication prompts
class PasswordSetupWindowController {

  private var keychainManager: KeychainManagerProtocol
  private var onSave: (String) -> Void

  init(keychainManager: KeychainManagerProtocol, onSave: @escaping (String) -> Void) {
    self.keychainManager = keychainManager
    self.onSave = onSave
  }

  func showWindow() {
    let alert = NSAlert()

    // Configure alert style like Apple's auth dialogs
    alert.messageText = "GateAway wants to store your password"
    alert.informativeText = """
      Enter your administrator password to enable Touch ID for VPN connections. \
      Your password will be securely stored in the macOS Keychain.
      """
    alert.alertStyle = .informational

    // App icon (or custom icon)
    if let appIcon = NSImage(named: NSImage.applicationIconName) {
      alert.icon = appIcon
    }

    // Create password field accessory view
    let accessoryView = createAccessoryView()
    alert.accessoryView = accessoryView

    // Buttons (Apple style: action button on right)
    alert.addButton(withTitle: "Enable Touch ID")
    alert.addButton(withTitle: "Cancel")

    // Get password field from accessory view
    guard
      let passwordField = accessoryView.subviews.first(where: { $0 is NSSecureTextField })
        as? NSSecureTextField
    else {
      return
    }

    // Make password field first responder
    alert.window.initialFirstResponder = passwordField

    // Show dialog
    let response = alert.runModal()

    if response == .alertFirstButtonReturn {
      let password = passwordField.stringValue
      if !password.isEmpty {
        validateAndSavePassword(password)
      }
    }
  }

  private func createAccessoryView() -> NSView {
    let containerView = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 80))

    // Label
    let label = NSTextField(labelWithString: "Password:")
    label.font = .systemFont(ofSize: 13)
    label.frame = NSRect(x: 0, y: 50, width: 300, height: 20)

    // Password field with Apple styling
    let passwordField = NSSecureTextField(frame: NSRect(x: 0, y: 20, width: 300, height: 24))
    passwordField.placeholderString = "Enter your administrator password"
    passwordField.font = .systemFont(ofSize: 13)
    passwordField.bezelStyle = .roundedBezel
    passwordField.focusRingType = .default

    // Helper text
    let helperText = NSTextField(labelWithString: "This is the password you use for sudo commands.")
    helperText.font = .systemFont(ofSize: 11)
    helperText.textColor = .secondaryLabelColor
    helperText.frame = NSRect(x: 0, y: 0, width: 300, height: 16)

    containerView.addSubview(label)
    containerView.addSubview(passwordField)
    containerView.addSubview(helperText)

    return containerView
  }

  private func validateAndSavePassword(_ password: String) {
    // Test the password with a simple sudo command
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/bin/bash")
    task.arguments = ["-c", "echo '\(password)' | sudo -S -v 2>/dev/null"]

    let pipe = Pipe()
    task.standardOutput = pipe
    task.standardError = pipe

    do {
      try task.run()
      task.waitUntilExit()

      if task.terminationStatus == 0 {
        // Password is valid, save it
        savePassword(password)
      } else {
        // Password is incorrect
        showInvalidPasswordAlert()
      }
    } catch {
      Log.error("Failed to validate password: \(error)")
      showInvalidPasswordAlert()
    }
  }

  private func showInvalidPasswordAlert() {
    let errorAlert = NSAlert()
    errorAlert.messageText = "Incorrect Password"
    errorAlert.informativeText = "The password you entered is incorrect. Please try again."
    errorAlert.alertStyle = .warning
    errorAlert.addButton(withTitle: "Try Again")
    errorAlert.addButton(withTitle: "Cancel")

    if errorAlert.runModal() == .alertFirstButtonReturn {
      // User wants to try again
      showWindow()
    }
  }

  private func savePassword(_ password: String) {
    do {
      try keychainManager.savePassword(password)
      Log.success("Password validated and saved to Keychain")
      onSave(password)
    } catch {
      // Show error alert
      let errorAlert = NSAlert()
      errorAlert.messageText = "Failed to Save Password"
      errorAlert.informativeText = error.localizedDescription
      errorAlert.alertStyle = .critical
      errorAlert.runModal()
    }
  }
}
