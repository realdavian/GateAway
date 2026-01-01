import Foundation

// MARK: - Protocol

/// Manages caching of VPN server list with configurable TTL
protocol ServerCacheManagerProtocol {
    /// Cache TTL in minutes (default: 30)
    var cacheTTLMinutes: Int { get set }
    
    /// Whether the cache exists and is not expired
    var isCacheValid: Bool { get }
    
    /// Returns cached servers if still valid, nil otherwise
    func getCachedServers() -> [VPNServer]?
    
    /// Stores servers in cache with current timestamp
    func cacheServers(_ servers: [VPNServer])
    
    /// Clears the cache
    func clearCache()
    
    /// Returns cache age in seconds, nil if no cache
    func getCacheAge() -> TimeInterval?
}

// MARK: - Implementation

final class ServerCacheManager: ServerCacheManagerProtocol {
    
    private let cacheKey = "vpn.serverCache"
    private let cacheTimestampKey = "vpn.serverCacheTimestamp"
    private let ttlKey = "serverCacheTTL"
    private let userDefaults: UserDefaults
    
    var cacheTTLMinutes: Int {
        get {
            let value = userDefaults.integer(forKey: ttlKey)
            return value > 0 ? value : 30
        }
        set {
            userDefaults.set(newValue, forKey: ttlKey)
        }
    }
    
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }
    
    func getCachedServers() -> [VPNServer]? {
        guard let timestamp = userDefaults.object(forKey: cacheTimestampKey) as? Date else {
            Log.debug("No cache timestamp found")
            return nil
        }
        
        let age = Date().timeIntervalSince(timestamp)
        let ttlSeconds = TimeInterval(cacheTTLMinutes * 60)
        
        guard age < ttlSeconds else {
            Log.debug("Cache expired (age: \(Int(age))s, TTL: \(Int(ttlSeconds))s)")
            return nil
        }
        
        guard let data = userDefaults.data(forKey: cacheKey),
              let servers = try? JSONDecoder().decode([VPNServer].self, from: data) else {
            Log.debug("Failed to decode cached servers")
            return nil
        }
        
        Log.success("Loaded \(servers.count) servers from cache (age: \(Int(age))s)")
        return servers
    }
    
    func cacheServers(_ servers: [VPNServer]) {
        guard let data = try? JSONEncoder().encode(servers) else {
            Log.error("Failed to encode servers")
            return
        }
        
        userDefaults.set(data, forKey: cacheKey)
        userDefaults.set(Date(), forKey: cacheTimestampKey)
        
        Log.success("Cached \(servers.count) servers (TTL: \(cacheTTLMinutes) min)")
    }
    
    func clearCache() {
        userDefaults.removeObject(forKey: cacheKey)
        userDefaults.removeObject(forKey: cacheTimestampKey)
        Log.debug("Cache cleared")
    }
    
    func getCacheAge() -> TimeInterval? {
        guard let timestamp = userDefaults.object(forKey: cacheTimestampKey) as? Date else {
            return nil
        }
        return Date().timeIntervalSince(timestamp)
    }
    
    var isCacheValid: Bool {
        return getCachedServers() != nil
    }
}
