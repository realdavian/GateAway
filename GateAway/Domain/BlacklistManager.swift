import Foundation

// MARK: - Protocol

/// Manages temporary blacklisting of VPN servers
protocol BlacklistManagerProtocol {
    /// Checks if a server is currently blacklisted
    func isBlacklisted(_ server: VPNServer) -> Bool
    
    /// Adds a server to the blacklist with reason and expiry
    func addToBlacklist(_ server: VPNServer, reason: String, expiry: BlacklistExpiry)
    
    /// Removes a server from the blacklist
    func removeFromBlacklist(serverId: String)
    
    /// Returns all blacklisted servers
    func getAllBlacklisted() -> [BlacklistedServer]
    
    /// Removes expired entries from the blacklist
    func cleanupExpired()
}

// MARK: - Implementation

final class BlacklistManager: BlacklistManagerProtocol {
    
    private let userDefaults: UserDefaults
    private let blacklistKey = "vpn.blacklist"
    
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        cleanupExpired()
    }
    
    func isBlacklisted(_ server: VPNServer) -> Bool {
        let blacklist = getAllBlacklisted()
        return blacklist.contains { blacklisted in
            blacklisted.id == server.ip && !blacklisted.isExpired
        }
    }
    
    func addToBlacklist(_ server: VPNServer, reason: String, expiry: BlacklistExpiry) {
        var blacklist = getAllBlacklisted()
        blacklist.removeAll { $0.id == server.ip }
        
        let expiryDate = expiry.expiryDate(from: Date())
        let blacklisted = BlacklistedServer(
            id: server.ip,
            hostname: server.hostName,
            country: server.countryLong,
            countryShort: server.countryShort,
            reason: reason.isEmpty ? "No reason provided" : reason,
            blacklistedAt: Date(),
            expiresAt: expiryDate
        )
        
        blacklist.append(blacklisted)
        saveBlacklist(blacklist)
        
        Log.debug("Blacklisted \(server.ip) (\(server.countryLong)) - Expires: \(blacklisted.expiryDescription)")
    }
    
    func removeFromBlacklist(serverId: String) {
        var blacklist = getAllBlacklisted()
        blacklist.removeAll { $0.id == serverId }
        saveBlacklist(blacklist)
        
        Log.debug("Removed \(serverId) from blacklist")
    }
    
    func getAllBlacklisted() -> [BlacklistedServer] {
        guard let data = userDefaults.data(forKey: blacklistKey),
              let blacklist = try? JSONDecoder().decode([BlacklistedServer].self, from: data) else {
            return []
        }
        
        return blacklist
    }
    
    func cleanupExpired() {
        let blacklist = getAllBlacklisted()
        let active = blacklist.filter { !$0.isExpired }
        
        if active.count < blacklist.count {
            saveBlacklist(active)
            Log.debug("Cleaned up \(blacklist.count - active.count) expired blacklist entries")
        }
    }
    
    // MARK: - Private
    
    private func saveBlacklist(_ blacklist: [BlacklistedServer]) {
        if let data = try? JSONEncoder().encode(blacklist) {
            userDefaults.set(data, forKey: blacklistKey)
        }
    }
}
