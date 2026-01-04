import SwiftUI

// MARK: - Security Tab: Advanced Section

/// Advanced settings section with cache settings
struct SecurityTabAdvancedSection: View {
  @AppStorage(Constants.StorageKeys.serverCacheTTL) private var cacheTTL: Int = Constants.Limits
    .defaultCacheTTL

  var body: some View {
    SettingsSection(
      title: "Cache".localized,
      icon: "archivebox.fill",
      iconColor: .gray
    ) {
      VStack(alignment: .leading, spacing: 8) {
        // Server Cache TTL
        HStack {
          Text("Server List Cache".localized)
            .font(.subheadline)
          Spacer()
          Picker("Cache TTL".localized, selection: $cacheTTL) {
            Text("5 min").tag(5)
            Text("15 min").tag(15)
            Text("30 min").tag(30)
            Text("1 hour").tag(60)
            Text("2 hours").tag(120)
            Text("24 hours").tag(1440)
          }
          .pickerStyle(.menu)
          .frame(width: 120)
        }

        Text("How long to keep the server list cached before refreshing.".localized)
          .font(.caption)
          .foregroundColor(.secondary)

        // Cache status
        CacheStatusView(cacheTTL: cacheTTL)
      }
    }
  }
}

// MARK: - Cache Status View

private struct CacheStatusView: View {
  @Environment(\.cacheManager) private var cacheManager
  let cacheTTL: Int

  var body: some View {
    if let cacheAge = cacheManager.getCacheAge() {
      let ageMinutes = Int(cacheAge / 60)
      let isExpired = cacheAge > TimeInterval(cacheTTL * 60)

      HStack(spacing: 6) {
        Image(systemName: isExpired ? "clock.badge.exclamationmark" : "clock.fill")
          .foregroundColor(isExpired ? .orange : .green)
          .font(.caption)

        if isExpired {
          Text("Cache expired (\(ageMinutes) min ago)")
            .font(.caption)
            .foregroundColor(.orange)
        } else {
          Text("Last updated \(ageMinutes) min ago")
            .font(.caption)
            .foregroundColor(.secondary)
        }

        Spacer()

        Button("Clear Cache".localized) {
          cacheManager.clearCache()
          Log.debug("Cache cleared by user")
        }
        .font(.caption)
      }
      .padding(.vertical, 4)
    } else {
      HStack(spacing: 6) {
        Image(systemName: "tray")
          .foregroundColor(.secondary)
          .font(.caption)
        Text("No cached data".localized)
          .font(.caption)
          .foregroundColor(.secondary)
      }
      .padding(.vertical, 4)
    }
  }
}
