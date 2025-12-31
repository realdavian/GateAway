import SwiftUI

// MARK: - Security Tab

struct SecurityTab: View {
    @Environment(\.keychainManager) private var keychainManager
    
    @State private var showingPasswordSetup: Bool = false
    @State private var setupPassword: String = ""
    @State private var showingTestResult: Bool = false
    @State private var testResultMessage: String = ""
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SecurityTabCredentialsSection()
                
                SecurityTabBiometricSection(
                    showingPasswordSetup: $showingPasswordSetup,
                    showingTestResult: $showingTestResult,
                    testResultMessage: $testResultMessage
                )
                
                SecurityTabFeaturesSection()
                
                SecurityTabAdvancedSection()
            }
            .padding()
        }
        .sheet(isPresented: $showingPasswordSetup) {
            PasswordSetupView(
                password: $setupPassword,
                onSave: {
                    savePasswordToKeychain()
                }
            )
        }
        .alert(isPresented: $showingTestResult) {
            Alert(
                title: Text(testResultMessage.contains("✅") ? "Success" : "Failed"),
                message: Text(testResultMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    private func savePasswordToKeychain() {
        do {
            try keychainManager.savePassword(setupPassword)
            setupPassword = "" // Clear for security
            print("✅ Password saved to Keychain")
        } catch {
            testResultMessage = "❌ Failed to save password: \(error.localizedDescription)"
            showingTestResult = true
        }
    }
}
