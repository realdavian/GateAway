import SwiftUI

// MARK: - Shared Helper Functions

/// Convert country code to flag emoji
/// - Parameter countryCode: Two-letter country code (e.g., "JP", "US")
/// - Returns: Flag emoji or globe if invalid
func flagEmoji(for countryCode: String) -> String {
    let base: UInt32 = 127397
    var emoji = ""
    for scalar in countryCode.uppercased().unicodeScalars {
        if let scalarValue = UnicodeScalar(base + scalar.value) {
            emoji.unicodeScalars.append(scalarValue)
        }
    }
    return emoji.isEmpty ? "🌍" : emoji
}

/// Format speed from bits per second to human-readable Mbps
/// - Parameter bps: Speed in bits per second
/// - Returns: Formatted string with one decimal place
func formatSpeed(_ bps: Int) -> String {
    let mbps = Double(bps) / 1_000_000
    return String(format: "%.1f", mbps)
}

// MARK: - Environment Keys for DI

/// Environment key for KeychainManager
private struct KeychainManagerKey: EnvironmentKey {
    static let defaultValue: KeychainManagerProtocol = KeychainManager()
}

/// Environment key for ServerCacheManager  
private struct CacheManagerKey: EnvironmentKey {
    static let defaultValue: ServerCacheManagerProtocol = ServerCacheManager()
}

extension EnvironmentValues {
    var keychainManager: KeychainManagerProtocol {
        get { self[KeychainManagerKey.self] }
        set { self[KeychainManagerKey.self] = newValue }
    }
    
    var cacheManager: ServerCacheManagerProtocol {
        get { self[CacheManagerKey.self] }
        set { self[CacheManagerKey.self] = newValue }
    }
}
