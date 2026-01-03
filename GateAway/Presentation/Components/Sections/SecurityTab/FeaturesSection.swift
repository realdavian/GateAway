import SwiftUI

// MARK: - Security Tab: Features Section

/// Security features section with toggles for auto-reconnect, DNS leak protection, kill switch
struct SecurityTabFeaturesSection: View {
  @AppStorage(Constants.StorageKeys.securityAutoReconnect) private var autoReconnect: Bool = true
  @AppStorage(Constants.StorageKeys.securityDNSLeakProtection) private var dnsLeakProtection: Bool =
    true
  @State private var killSwitchEnabled: Bool = UserDefaults.standard.bool(
    forKey: "enableKillSwitch")

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

        // DNS Leak Protection
        SecurityToggleRow(
          title: "DNS Leak Protection",
          description: "Route all DNS queries through VPN tunnel",
          isOn: $dnsLeakProtection
        )

        Divider()

        // Kill Switch
        SecurityToggleRow(
          title: "Kill Switch",
          description: "Block internet if VPN disconnects",
          isOn: $killSwitchEnabled,
          warningIcon: true,
          warningText: "Kill switch will block all internet traffic when VPN is disconnected"
        )
      }
    }
  }
}
