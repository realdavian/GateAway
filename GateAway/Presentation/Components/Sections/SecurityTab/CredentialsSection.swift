import SwiftUI

// MARK: - Security Tab: Credentials Section

/// VPN credentials section displaying username/password fields
/// Note: VPNGate uses fixed default credentials
struct SecurityTabCredentialsSection: View {
  @AppStorage(Constants.StorageKeys.vpnUsername) private var vpnUsername: String = Constants
    .VPNCredentials.defaultUsername
  @AppStorage(Constants.StorageKeys.vpnPassword) private var vpnPassword: String = Constants
    .VPNCredentials.defaultPassword
  @State private var showPassword: Bool = false

  var body: some View {
    SettingsSection(
      title: "VPN Credentials".localized,
      icon: "key.fill",
      iconColor: .blue
    ) {
      VStack(alignment: .leading, spacing: 16) {
        // Info message
        HStack(spacing: 8) {
          Image(systemName: "info.circle.fill")
            .foregroundColor(.blue)
          Text(
            "VPNGate servers use default credentials. These work for all VPNGate servers.".localized
          )
          .font(.caption)
          .foregroundColor(.secondary)
        }
        .padding(12)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(8)

        // Username field
        VStack(alignment: .leading, spacing: 8) {
          Text("Username".localized)
            .font(.caption)
            .foregroundColor(.secondary)

          TextField("Username".localized, text: $vpnUsername)
            .textFieldStyle(.plain)
            .padding(10)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            .disabled(true)
        }

        // Password field
        VStack(alignment: .leading, spacing: 8) {
          Text("Password".localized)
            .font(.caption)
            .foregroundColor(.secondary)

          HStack {
            if showPassword {
              TextField("Password".localized, text: $vpnPassword)
                .textFieldStyle(.plain)
                .disabled(true)
            } else {
              SecureField("Password".localized, text: $vpnPassword)
                .disabled(true)
            }

            Button(action: { showPassword.toggle() }) {
              Image(systemName: showPassword ? "eye.slash" : "eye")
                .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
          }
          .padding(10)
          .background(Color.gray.opacity(0.1))
          .cornerRadius(8)
        }

        // Note about defaults
        Text("Note: These are the default VPNGate credentials and cannot be changed.".localized)
          .font(.caption2)
          .foregroundColor(.orange)
      }
    }
  }
}
