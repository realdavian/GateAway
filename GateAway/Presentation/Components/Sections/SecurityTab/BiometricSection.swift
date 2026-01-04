import SwiftUI

// MARK: - Security Tab: Biometric Section

/// Biometric authentication section for Touch ID setup and management
struct SecurityTabBiometricSection: View {
  @Environment(\.keychainManager) private var keychainManager

  @State private var isPasswordStored: Bool = false
  @Binding var showingTestResult: Bool
  @Binding var testResultMessage: String
  @Binding var refreshTrigger: Bool

  let onEnableTouchID: () -> Void

  var body: some View {
    SettingsSection(
      title: "Biometric Authentication".localized,
      icon: "touchid",
      iconColor: .green
    ) {
      VStack(alignment: .leading, spacing: 16) {
        // Main toggle/status row
        HStack {
          VStack(alignment: .leading, spacing: 4) {
            Text("Touch ID for VPN Connections".localized)
              .font(.subheadline)

            if isPasswordStored {
              Text("Password stored securely in Keychain".localized)
                .font(.caption)
                .foregroundColor(.secondary)
            } else {
              Text("Store admin password for Touch ID authentication".localized)
                .font(.caption)
                .foregroundColor(.secondary)
            }
          }

          Spacer()

          // Status indicator
          if isPasswordStored {
            HStack(spacing: 6) {
              Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
              Text("Enabled".localized)
                .font(.caption)
                .foregroundColor(.green)
            }
          } else {
            HStack(spacing: 6) {
              Image(systemName: "xmark.circle")
                .foregroundColor(.secondary)
              Text("Disabled".localized)
                .font(.caption)
                .foregroundColor(.secondary)
            }
          }
        }

        // Action buttons row
        HStack {
          Spacer()

          if !isPasswordStored {
            Button("Enable Touch ID...".localized) {
              onEnableTouchID()
            }
          } else {
            Button("Test Touch ID...".localized) {
              testTouchID()
            }

            Button("Remove...".localized) {
              removeStoredPassword()
            }
          }
        }
      }
    }
    .onAppear {
      refreshPasswordStatus()
    }
    .onChange(of: refreshTrigger) { _ in
      refreshPasswordStatus()
    }
  }

  private func refreshPasswordStatus() {
    isPasswordStored = keychainManager.isPasswordStored()
  }

  private func testTouchID() {
    Task {
      do {
        let _ = try await keychainManager.getPassword()
        await MainActor.run {
          testResultMessage = "✅ \(KeychainManager.biometricType()) authentication successful!"
          showingTestResult = true
        }
      } catch {
        await MainActor.run {
          testResultMessage = "❌ Failed: \(error.localizedDescription)"
          showingTestResult = true
        }
      }
    }
  }

  private func removeStoredPassword() {
    do {
      try keychainManager.deletePassword()
      isPasswordStored = false
      Log.success("Password removed from Keychain")
    } catch {
      testResultMessage = "❌ Failed to remove password: \(error.localizedDescription)"
      showingTestResult = true
    }
  }
}
