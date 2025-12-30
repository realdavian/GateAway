import SwiftUI

// MARK: - Security Tab: Biometric Section

/// Biometric authentication section for Touch ID setup and management
struct SecurityTabBiometricSection: View {
    @State private var isPasswordStored: Bool = KeychainManager.shared.isPasswordStored()
    @Binding var showingPasswordSetup: Bool
    @Binding var showingTestResult: Bool
    @Binding var testResultMessage: String
    
    var body: some View {
        SettingsSection(
            title: "Biometric Authentication",
            icon: "touchid",
            iconColor: .green
        ) {
            VStack(alignment: .leading, spacing: 16) {
                // Main toggle/status row
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Touch ID for VPN Connections")
                            .font(.subheadline)
                        
                        if isPasswordStored {
                            Text("Password stored securely in Keychain")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text("Store admin password for Touch ID authentication")
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
                            Text("Enabled")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    } else {
                        HStack(spacing: 6) {
                            Image(systemName: "xmark.circle")
                                .foregroundColor(.secondary)
                            Text("Disabled")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Action buttons row
                HStack {
                    Spacer()
                    
                    if !isPasswordStored {
                        Button("Enable Touch ID...") {
                            showingPasswordSetup = true
                        }
                    } else {
                        Button("Test Touch ID...") {
                            testTouchID()
                        }
                        
                        Button("Remove...") {
                            removeStoredPassword()
                        }
                    }
                }
            }
        }
    }
    
    private func testTouchID() {
        Task {
            do {
                let _ = try await KeychainManager.shared.getPassword()
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
            try KeychainManager.shared.deletePassword()
            isPasswordStored = false
            print("✅ Password removed from Keychain")
        } catch {
            testResultMessage = "❌ Failed to remove password: \(error.localizedDescription)"
            showingTestResult = true
        }
    }
    
    /// Call this after password is saved to refresh state
    func refreshPasswordStatus() {
        isPasswordStored = KeychainManager.shared.isPasswordStored()
    }
}
