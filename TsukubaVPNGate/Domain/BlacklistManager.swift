import Foundation

// MARK: - Blacklist Manager Protocol

protocol BlacklistManagerProtocol {
    func isBlacklisted(_ server: VPNServer) -> Bool
    func addToBlacklist(_ server: VPNServer, reason: String, expiry: BlacklistExpiry)
    func removeFromBlacklist(serverId: String)
    func getAllBlacklisted() -> [BlacklistedServer]
    func cleanupExpired()
}

// MARK: - Blacklist Manager Implementation

final class BlacklistManager: BlacklistManagerProtocol {
    
    private let userDefaults: UserDefaults
    private let blacklistKey = "vpn.blacklist"
    
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        
        // Auto-cleanup expired entries on init
        cleanupExpired()
    }
    
    func isBlacklisted(_ server: VPNServer) -> Bool {
        let blacklist = getAllBlacklisted()
        
        // Check if server is blacklisted and not expired
        return blacklist.contains { blacklisted in
            blacklisted.id == server.ip && !blacklisted.isExpired
        }
    }
    
    func addToBlacklist(_ server: VPNServer, reason: String, expiry: BlacklistExpiry) {
        var blacklist = getAllBlacklisted()
        
        // Remove if already exists
        blacklist.removeAll { $0.id == server.ip }
        
        // Add new entry
        let expiryDate = expiry.expiryDate(from: Date())
        let blacklisted = BlacklistedServer(
            id: server.ip,
            hostname: server.hostName,
            country: server.countryLong,
            reason: reason.isEmpty ? "No reason provided" : reason,
            blacklistedAt: Date(),
            expiresAt: expiryDate
        )
        
        blacklist.append(blacklisted)
        
        // Save
        saveBlacklist(blacklist)
        
        print("🚫 [Blacklist] Added \(server.ip) (\(server.countryLong)) - Expires: \(blacklisted.expiryDescription)")
    }
    
    func removeFromBlacklist(serverId: String) {
        var blacklist = getAllBlacklisted()
        blacklist.removeAll { $0.id == serverId }
        saveBlacklist(blacklist)
        
        print("✅ [Blacklist] Removed \(serverId)")
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
            print("🧹 [Blacklist] Cleaned up \(blacklist.count - active.count) expired entries")
        }
    }
    
    // MARK: - Private
    
    private func saveBlacklist(_ blacklist: [BlacklistedServer]) {
        if let data = try? JSONEncoder().encode(blacklist) {
            userDefaults.set(data, forKey: blacklistKey)
        }
    }
}

