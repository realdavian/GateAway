import SwiftUI

// MARK: - Security Tab: Advanced Section

/// Advanced settings section with protocol info, encryption, and cache settings
struct SecurityTabAdvancedSection: View {
    @AppStorage("serverCacheTTL") private var cacheTTL: Int = 30
    
    var body: some View {
        SettingsSection(
            title: "Advanced",
            icon: "gearshape.2.fill",
            iconColor: .gray
        ) {
            VStack(alignment: .leading, spacing: 16) {
                // IPv6 leak protection
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("IPv6 Leak Protection")
                            .font(.subheadline)
                        Text("Disable IPv6 to prevent leaks")
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
                
                // Protocol
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("VPN Protocol")
                            .font(.subheadline)
                        Text("OpenVPN UDP (fastest)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                
                Divider()
                
                // Encryption
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Encryption")
                            .font(.subheadline)
                        Text("AES-128-CBC with TLS 1.2+")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                
                Divider()
                
                // Server Cache TTL
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Server List Cache Duration")
                            .font(.subheadline)
                        Spacer()
                        Picker("Cache TTL", selection: $cacheTTL) {
                            Text("5 min").tag(5)
                            Text("15 min").tag(15)
                            Text("30 min").tag(30)
                            Text("1 hour").tag(60)
                            Text("2 hours").tag(120)
                            Text("24 hours").tag(1440)
                        }
                        .pickerStyle(.menu)
                        .frame(width: 180)
                    }
                    
                    Text("How long to keep the server list cached before refreshing from VPN Gate.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    // Cache status
                    CacheStatusView(cacheTTL: cacheTTL)
                }
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
                
                Button("Clear Cache") {
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
                Text("No cached data")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
    }
}
