import SwiftUI

// MARK: - Blacklist Row

/// A collapsible row displaying blacklisted server information
/// Collapsed: Shows critical info (flag, hostname, country, date, expiry)
/// Expanded: Shows reason, IP, and delete action
struct BlacklistRow: View {
  let server: BlacklistedServer
  let onRemove: () -> Void
  let onEdit: () -> Void

  @State private var isExpanded: Bool = false

  var body: some View {
    VStack(spacing: 0) {
      // Collapsed row - always visible
      Button(action: { withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() } }) {
        HStack(spacing: 12) {
          // Flag
          Text(flagEmoji(for: server.countryShort))
            .font(.title2)
            .frame(width: 36)

          // Hostname
          Text(server.hostname)
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(server.isExpired ? .secondary : .primary)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)

          // Country
          Text(server.country)
            .font(.system(size: 12))
            .foregroundColor(.secondary)
            .frame(width: 80, alignment: .leading)

          // Blacklisted date
          Text(server.formattedBlacklistDate)
            .font(.system(size: 11))
            .foregroundColor(.secondary)
            .frame(width: 80, alignment: .leading)

          // Expiry with icon
          HStack(spacing: 4) {
            if server.isExpired {
              Image(systemName: "clock.badge.exclamationmark")
                .font(.caption2)
                .foregroundColor(.orange)
            }
            Text(server.expiryDescription)
              .font(.system(size: 11))
              .foregroundColor(server.isExpired ? .orange : .secondary)
          }
          .frame(width: 80, alignment: .leading)

          // Chevron
          Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
            .font(.caption)
            .foregroundColor(.secondary)
            .frame(width: 20)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)

      // Expanded section
      if isExpanded {
        VStack(alignment: .leading, spacing: 12) {
          Divider()
            .padding(.horizontal)

          VStack(alignment: .leading, spacing: 8) {
            // IP Address
            HStack(spacing: 8) {
              Text("IP:".localized)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 50, alignment: .leading)
              Text(server.id)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.primary)
            }

            // Reason
            HStack(alignment: .top, spacing: 8) {
              Text("Reason:".localized)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 50, alignment: .leading)
              Text(server.reason.isEmpty ? "No reason provided" : server.reason)
                .font(.system(size: 12))
                .foregroundColor(server.reason.isEmpty ? .secondary : .primary)
                .fixedSize(horizontal: false, vertical: true)
            }
          }
          .padding(.horizontal, 60)  // Align with hostname

          // Actions
          HStack {
            Spacer()

            Button(action: onRemove) {
              HStack(spacing: 4) {
                Image(systemName: "trash")
                Text("Remove from Blacklist".localized)
              }
              .font(.caption)
              .foregroundColor(.white)
              .padding(.horizontal, 12)
              .padding(.vertical, 6)
              .background(Color.red)
              .cornerRadius(6)
            }
            .buttonStyle(.plain)
          }
          .padding(.horizontal)
          .padding(.bottom, 8)
        }
        .background(Color.gray.opacity(0.03))
      }
    }
    .background(server.isExpired ? Color.orange.opacity(0.05) : Color.clear)
    .opacity(server.isExpired ? 0.8 : 1.0)
  }
}
