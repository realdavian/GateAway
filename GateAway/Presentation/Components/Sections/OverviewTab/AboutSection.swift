import SwiftUI

// MARK: - About Section

/// About section with VPN backend information
struct AboutSection: View {
  var body: some View {
    SettingsSection(
      title: "About".localized,
      icon: "info.circle",
      iconColor: .purple
    ) {
      VStack(alignment: .leading, spacing: 8) {
        InfoRow(label: "Backend".localized, value: "OpenVPN CLI")
        InfoRow(label: "Protocol".localized, value: "OpenVPN (UDP)")
        InfoRow(label: "Encryption".localized, value: "AES-128-CBC")

        // DNS with leak protection note
        VStack(alignment: .leading, spacing: 4) {
          InfoRow(label: "DNS".localized, value: "8.8.8.8, 8.8.4.4")
          HStack(spacing: 4) {
            Image(systemName: "checkmark.shield.fill")
              .foregroundColor(.green)
              .font(.caption2)
            Text("DNS leak protection enabled via OpenVPN".localized)
              .font(.caption2)
              .foregroundColor(.secondary)
          }
          .padding(.leading, 2)
        }
      }
    }
  }
}
