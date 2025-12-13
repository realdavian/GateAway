import Foundation

/// Manages caching of VPN server list with configurable TTL
final class ServerCacheManager {
    
    // MARK: - Singleton
    static let shared = ServerCacheManager()
    
    // MARK: - UserDefaults Keys
    private let cacheKey = "vpn.serverCache"
    private let cacheTimestampKey = "vpn.serverCacheTimestamp"
    private let ttlKey = "serverCacheTTL"
    
    // MARK: - Properties
    private let userDefaults: UserDefaults
    
    // Cache TTL in minutes (from UserDefaults, default 30)
    var cacheTTLMinutes: Int {
        get {
            let value = userDefaults.integer(forKey: ttlKey)
            return value > 0 ? value : 30 // Default 30 minutes
        }
        set {
            userDefaults.set(newValue, forKey: ttlKey)
        }
    }
    
    // MARK: - Init
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }
    
    // MARK: - Cache Operations
    
    /// Get cached servers if still valid based on TTL
    func getCachedServers() -> [VPNServer]? {
        guard let timestamp = userDefaults.object(forKey: cacheTimestampKey) as? Date else {
            print("📦 [ServerCache] No cache timestamp found")
            return nil
        }
        
        let age = Date().timeIntervalSince(timestamp)
        let ttlSeconds = TimeInterval(cacheTTLMinutes * 60)
        
        guard age < ttlSeconds else {
            print("📦 [ServerCache] Cache expired (age: \(Int(age))s, TTL: \(Int(ttlSeconds))s)")
            return nil
        }
        
        guard let data = userDefaults.data(forKey: cacheKey),
              let servers = try? JSONDecoder().decode([VPNServer].self, from: data) else {
            print("📦 [ServerCache] Failed to decode cached servers")
            return nil
        }
        
        print("✅ [ServerCache] Loaded \(servers.count) servers from cache (age: \(Int(age))s)")
        return servers
    }
    
    /// Cache servers with current timestamp
    func cacheServers(_ servers: [VPNServer]) {
        guard let data = try? JSONEncoder().encode(servers) else {
            print("❌ [ServerCache] Failed to encode servers")
            return
        }
        
        userDefaults.set(data, forKey: cacheKey)
        userDefaults.set(Date(), forKey: cacheTimestampKey)
        
        print("✅ [ServerCache] Cached \(servers.count) servers (TTL: \(cacheTTLMinutes) min)")
    }
    
    /// Clear cache
    func clearCache() {
        userDefaults.removeObject(forKey: cacheKey)
        userDefaults.removeObject(forKey: cacheTimestampKey)
        print("🗑️ [ServerCache] Cache cleared")
    }
    
    /// Get cache age in seconds (nil if no cache)
    func getCacheAge() -> TimeInterval? {
        guard let timestamp = userDefaults.object(forKey: cacheTimestampKey) as? Date else {
            return nil
        }
        return Date().timeIntervalSince(timestamp)
    }
    
    /// Get cache timestamp
    func getCacheTimestamp() -> Date? {
        return userDefaults.object(forKey: cacheTimestampKey) as? Date
    }
    
    /// Check if cache exists and is valid
    var isCacheValid: Bool {
        return getCachedServers() != nil
    }
}
