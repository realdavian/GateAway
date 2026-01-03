//
//  TouchIDSetupView.swift
//  GateAway
//
//  Helps users enable Touch ID for sudo operations
//

import AppKit
import SwiftUI

struct TouchIDSetupView: View {
  @Environment(\.presentationMode) private var presentationMode
  @State private var isTouchIDEnabled: Bool = false
  @State private var isChecking: Bool = true
  @State private var setupLog: String = ""
  @State private var isSettingUp: Bool = false

  var body: some View {
    VStack(spacing: 20) {
      // Header
      HStack {
        Image(systemName: isTouchIDEnabled ? "touchid" : "exclamationmark.shield")
          .font(.system(size: 48))
          .foregroundColor(isTouchIDEnabled ? .green : .orange)

        VStack(alignment: .leading, spacing: 4) {
          Text("Touch ID for VPN Connection")
            .font(.system(.title2, design: .default).weight(.bold))

          Text(isTouchIDEnabled ? "Enabled ✅" : "Not Enabled")
            .font(.subheadline)
            .foregroundColor(isTouchIDEnabled ? .green : .secondary)
        }
      }
      .padding()

      Divider()

      // Content
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          if !isTouchIDEnabled {
            // Why enable Touch ID
            GroupBox {
              VStack(alignment: .leading, spacing: 12) {
                HStack {
                  Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)
                  Text("Why Enable Touch ID?")
                    .font(.headline)
                }

                Text(
                  "OpenVPN requires administrator privileges to configure network routing. Instead of typing your password every time, you can use Touch ID for a faster, more secure experience."
                )
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
              }
              .padding(8)
            }

            // Manual setup instructions
            GroupBox {
              VStack(alignment: .leading, spacing: 12) {
                HStack {
                  Image(systemName: "terminal")
                    .foregroundColor(.green)
                  Text("Setup Instructions")
                    .font(.headline)
                }

                VStack(alignment: .leading, spacing: 8) {
                  Text("1. Open Terminal app")
                  Text("2. Run this command:")
                    .padding(.top, 4)

                  HStack {
                    Text("sudo nano /etc/pam.d/sudo")
                      .font(.system(.caption, design: .monospaced))
                      .padding(8)
                      .background(Color.black.opacity(0.05))
                      .cornerRadius(4)

                    Button(action: copyCommand) {
                      Image(systemName: "doc.on.doc")
                        .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                    .help("Copy to clipboard")
                  }

                  Text("3. Add this line at the TOP of the file:")
                    .padding(.top, 4)

                  HStack {
                    Text("auth       sufficient     pam_tid.so")
                      .font(.system(.caption, design: .monospaced))
                      .padding(8)
                      .background(Color.black.opacity(0.05))
                      .cornerRadius(4)

                    Button(action: copyPAMLine) {
                      Image(systemName: "doc.on.doc")
                        .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                    .help("Copy to clipboard")
                  }

                  Text("4. Save (Ctrl+O, Enter) and exit (Ctrl+X)")
                  Text("5. Test with: sudo ls /var/root")
                    .padding(.top, 4)
                }
                .font(.caption)
                .foregroundColor(.secondary)
              }
              .padding(8)
            }

            // Quick setup button
            GroupBox {
              VStack(spacing: 12) {
                HStack {
                  Image(systemName: "bolt.fill")
                    .foregroundColor(.yellow)
                  Text("Quick Setup")
                    .font(.headline)
                }

                Text("Let GateAway configure Touch ID for you automatically.")
                  .font(.caption)
                  .foregroundColor(.secondary)
                  .fixedSize(horizontal: false, vertical: true)

                Button(action: quickSetup) {
                  HStack {
                    if isSettingUp {
                      ProgressView()
                        .scaleEffect(0.8)
                    }
                    Text(isSettingUp ? "Setting up..." : "Enable Touch ID Now")
                  }
                  .frame(maxWidth: .infinity)
                  .padding(.vertical, 8)
                  .background(Color.accentColor)
                  .foregroundColor(.white)
                  .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(isSettingUp)

                if !setupLog.isEmpty {
                  Text(setupLog)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(setupLog.contains("✅") ? .green : .red)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.black.opacity(0.05))
                    .cornerRadius(4)
                }
              }
              .padding(8)
            }

          } else {
            // Already enabled
            GroupBox {
              VStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                  .font(.system(size: 48))
                  .foregroundColor(.green)

                Text("Touch ID is Enabled!")
                  .font(.headline)

                Text(
                  "You can now use Touch ID when connecting to VPN servers instead of typing your password."
                )
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
              }
              .padding()
              .frame(maxWidth: .infinity)
            }
          }
        }
        .padding()
      }

      Divider()

      // Footer
      HStack {
        Button("Check Again") {
          checkTouchIDStatus()
        }
        .disabled(isChecking)

        Spacer()

        Button("Close") {
          presentationMode.wrappedValue.dismiss()
        }
      }
      .padding()
    }
    .frame(width: 500, height: 550)
    .onAppear {
      checkTouchIDStatus()
    }
  }

  private func checkTouchIDStatus() {
    isChecking = true

    DispatchQueue.global(qos: .userInitiated).async {
      // Check if pam_tid.so is configured in /etc/pam.d/sudo
      let pamPath = "/etc/pam.d/sudo"

      if let content = try? String(contentsOfFile: pamPath, encoding: .utf8) {
        let isEnabled = content.contains("pam_tid.so")

        DispatchQueue.main.async {
          self.isTouchIDEnabled = isEnabled
          self.isChecking = false
        }
      } else {
        DispatchQueue.main.async {
          self.isTouchIDEnabled = false
          self.isChecking = false
        }
      }
    }
  }

  private func copyCommand() {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString("sudo nano /etc/pam.d/sudo", forType: .string)
  }

  private func copyPAMLine() {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString("auth       sufficient     pam_tid.so", forType: .string)
  }

  private func quickSetup() {
    isSettingUp = true
    setupLog = "Starting setup...\n"

    DispatchQueue.global(qos: .userInitiated).async {
      // Use AppleScript to modify /etc/pam.d/sudo with admin privileges
      let script = """
        do shell script "grep -q 'pam_tid.so' /etc/pam.d/sudo || sed -i '' '1i\\\\
        auth       sufficient     pam_tid.so
        ' /etc/pam.d/sudo" with administrator privileges
        """

      var error: NSDictionary?
      guard let scriptObject = NSAppleScript(source: script) else {
        DispatchQueue.main.async {
          self.setupLog = "❌ Failed to create setup script"
          self.isSettingUp = false
        }
        return
      }

      let _ = scriptObject.executeAndReturnError(&error)

      DispatchQueue.main.async {
        if let error = error {
          let errorMsg = error["NSAppleScriptErrorBriefMessage"] as? String ?? "Unknown error"
          self.setupLog = "❌ Setup failed: \(errorMsg)"
        } else {
          self.setupLog = "✅ Touch ID enabled successfully!"

          // Recheck status
          DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.checkTouchIDStatus()
          }
        }

        self.isSettingUp = false
      }
    }
  }
}

// Window controller for Touch ID setup
class TouchIDSetupWindowController: NSWindowController {
  convenience init() {
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 500, height: 550),
      styleMask: [.titled, .closable],
      backing: .buffered,
      defer: false
    )
    window.title = "Touch ID Setup"
    window.center()
    window.contentView = NSHostingView(rootView: TouchIDSetupView())

    self.init(window: window)
  }
}
