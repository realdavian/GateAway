import SwiftUI

// MARK: - Security Tab: Features Section

/// Security features section with toggles for auto-reconnect, DNS leak protection, kill switch
struct SecurityTabFeaturesSection: View {
  @AppStorage(Constants.StorageKeys.autoReconnectOnDrop) private var autoReconnect: Bool = true
  @AppStorage(Constants.StorageKeys.killSwitchEnabled) private var killSwitchEnabled: Bool = false
  @State private var dnsLeakEnabled: Bool = true  // Always enabled by OpenVPN

  var body: some View {
    SettingsSection(
      title: "Security Features",
      icon: "shield.fill",
      iconColor: .purple
    ) {
      VStack(alignment: .leading, spacing: 16) {
        // Auto-reconnect
        SecurityToggleRow(
          title: "Auto-Reconnect",
          description: "Automatically reconnect if VPN connection drops",
          isOn: $autoReconnect
        )

        Divider()

        // DNS Leak Protection (informational - always enabled by OpenVPN)
        HStack {
          VStack(alignment: .leading, spacing: 4) {
            Text("DNS Leak Protection")
              .font(.subheadline)
            Text("Enabled by OpenVPN configuration")
              .font(.caption)
              .foregroundColor(.secondary)
          }

          Spacer()

          Text("Enabled")
            .font(.caption)
            .foregroundColor(.green)
          Image(systemName: "checkmark.circle.fill")
            .foregroundColor(.green)
        }

        Divider()

        // Kill Switch
        SecurityToggleRow(
          title: "Kill Switch",
          description: "Block internet if VPN disconnects unexpectedly",
          isOn: $killSwitchEnabled,
          warningIcon: true,
          warningText: "Blocks ALL traffic when VPN drops. Traffic unblocked on normal disconnect."
        )
      }
    }
  }
}
