import SwiftUI

// MARK: - Security Tab: Features Section

/// Security features section with toggles for auto-reconnect, kill switch, and IPv6 protection
struct SecurityTabFeaturesSection: View {
  @AppStorage(Constants.StorageKeys.autoReconnectOnDrop) private var autoReconnect: Bool = true
  @AppStorage(Constants.StorageKeys.killSwitchEnabled) private var killSwitchEnabled: Bool = false
  @AppStorage("prefs.ipv6ProtectionEnabled") private var ipv6Protection: Bool = false

  var body: some View {
    SettingsSection(
      title: "Protection",
      icon: "shield.fill",
      iconColor: .purple
    ) {
      VStack(alignment: .leading, spacing: 16) {
        // Kill Switch
        SecurityToggleRow(
          title: "Kill Switch",
          description: "Block internet if VPN disconnects unexpectedly",
          isOn: $killSwitchEnabled,
          warningIcon: true,
          warningText: "Blocks ALL traffic when VPN drops"
        )

        Divider()

        // IPv6 Leak Protection
        SecurityToggleRow(
          title: "IPv6 Leak Protection",
          description: "Disable IPv6 to prevent identity leaks",
          isOn: $ipv6Protection
        )

        Divider()

        // Auto-reconnect
        SecurityToggleRow(
          title: "Auto-Reconnect",
          description: "Automatically reconnect if VPN connection drops",
          isOn: $autoReconnect
        )
      }
    }
  }
}
