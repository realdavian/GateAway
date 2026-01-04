import SwiftUI

// MARK: - Security Tab

struct SecurityTab: View {
  @Environment(\.keychainManager) private var keychainManager

  @State private var showingTestResult: Bool = false
  @State private var testResultMessage: String = ""
  @State private var biometricRefreshTrigger: Bool = false

  private var passwordSetupController: PasswordSetupWindowController?

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        SecurityTabCredentialsSection()

        SecurityTabBiometricSection(
          showingTestResult: $showingTestResult,
          testResultMessage: $testResultMessage,
          refreshTrigger: $biometricRefreshTrigger,
          onEnableTouchID: {
            showPasswordSetupWindow()
          }
        )

        SecurityTabFeaturesSection()

        SecurityTabAdvancedSection()

        AboutSection()
      }
      .padding()
    }
    .alert(isPresented: $showingTestResult) {
      Alert(
        title: Text(testResultMessage.contains("✅") ? "Success" : "Failed"),
        message: Text(testResultMessage),
        dismissButton: .default(Text("OK"))
      )
    }
  }

  private func showPasswordSetupWindow() {
    let controller = PasswordSetupWindowController(
      keychainManager: keychainManager,
      onSave: { _ in
        // Refresh biometric status after save
        biometricRefreshTrigger.toggle()
      }
    )
    controller.showWindow()
  }
}
