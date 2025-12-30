import SwiftUI

// MARK: - Overview Tab: About Section

/// About section with VPN backend information
struct OverviewTabAboutSection: View {
    var body: some View {
        SettingsSection(
            title: "About",
            icon: "info.circle",
            iconColor: .purple
        ) {
            VStack(alignment: .leading, spacing: 8) {
                InfoRow(label: "Backend", value: "OpenVPN CLI")
                InfoRow(label: "Protocol", value: "OpenVPN (UDP)")
                InfoRow(label: "Encryption", value: "AES-128-CBC")
                InfoRow(label: "DNS", value: "8.8.8.8, 8.8.4.4")
            }
        }
    }
}
