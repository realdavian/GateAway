import Foundation

// MARK: - Protocol (ISP: Interface segregation - only selection methods)

protocol ServerSelectionServiceProtocol {
    func selectBestServer(from servers: [VPNServer]) -> VPNServer?
    func selectBestServer(from servers: [VPNServer], inCountry country: String) -> VPNServer?
    func selectBestServerAsync(from servers: [VPNServer]) async -> VPNServer?
    func filterServers(_ servers: [VPNServer], byCountry country: String) -> [VPNServer]
    func topServers(from servers: [VPNServer], country: String, limit: Int) -> [VPNServer]
    func availableCountries(from servers: [VPNServer]) -> [String]
}

// MARK: - Implementation (SRP: Single responsibility - server selection logic)

final class ServerSelectionService: ServerSelectionServiceProtocol {
    
    // MARK: - Sync Selection (uses stored ping values)
    
    func selectBestServer(from servers: [VPNServer]) -> VPNServer? {
        return servers
            .sorted { compareServers($0, $1) }
            .first
    }
    
    func selectBestServer(from servers: [VPNServer], inCountry country: String) -> VPNServer? {
        let filtered = filterServers(servers, byCountry: country)
        return selectBestServer(from: filtered)
    }
    
    // MARK: - Async Selection (real-time parallel ping testing)
    
    /// Select best server by testing top candidates in parallel
    /// Returns fastest responding server, falls back to score-based if no responses
    func selectBestServerAsync(from servers: [VPNServer]) async -> VPNServer? {
        guard servers.count >= 5 else {
            // Small list - use sync method
            return selectBestServer(from: servers)
        }
        
        // Get top 10 candidates by score/ping
        let candidates = Array(servers.sorted { compareServers($0, $1) }.prefix(10))
        
        print("🏓 [ServerSelection] Testing \(candidates.count) servers in parallel...")
        
        // Test in parallel, fallback to sync if all fail
        if let fastest = await testServersInParallel(candidates) {
            print("✅ [ServerSelection] Fastest server: \(fastest.countryLong) (\(fastest.ip))")
            return fastest
        }
        
        print("⚠️ [ServerSelection] No ping responses, falling back to score-based selection")
        return selectBestServer(from: servers)
    }
    
    // MARK: - Filtering & Utilities
    
    func filterServers(_ servers: [VPNServer], byCountry country: String) -> [VPNServer] {
        return servers.filter { $0.countryLong == country }
    }
    
    func topServers(from servers: [VPNServer], country: String, limit: Int) -> [VPNServer] {
        let filtered = filterServers(servers, byCountry: country)
        let sorted = filtered.sorted { compareServers($0, $1) }
        return Array(sorted.prefix(max(1, limit)))
    }
    
    func availableCountries(from servers: [VPNServer]) -> [String] {
        let countries = Set(servers.map { $0.countryLong }.filter { !$0.isEmpty })
        return countries.sorted()
    }
    
    // MARK: - Private: Parallel Testing
    
    private func testServersInParallel(_ candidates: [VPNServer]) async -> VPNServer? {
        await withTaskGroup(of: (VPNServer, TimeInterval?).self) { group in
            for server in candidates {
                group.addTask {
                    let responseTime = await self.pingServer(server)
                    return (server, responseTime)
                }
            }
            
            // Find fastest responding server
            var best: (VPNServer, TimeInterval)?
            for await (server, time) in group {
                guard let time = time else { continue }
                
                if best == nil || time < best!.1 {
                    best = (server, time)
                    print("🏓 [ServerSelection] \(server.ip): \(String(format: "%.0fms", time * 1000))")
                }
            }
            
            return best?.0
        }
    }
    
    private func pingServer(_ server: VPNServer) async -> TimeInterval? {
        let start = Date()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/sbin/ping")
        process.arguments = ["-c", "1", "-t", "2", server.ip]  // 1 ping, 2 second timeout
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        
        do {
            try process.run()
            process.waitUntilExit()
            
            if process.terminationStatus == 0 {
                return Date().timeIntervalSince(start)
            }
            return nil
        } catch {
            return nil
        }
    }
    
    // MARK: - Private: Comparison
    
    private func compareServers(_ a: VPNServer, _ b: VPNServer) -> Bool {
        // Prefer lower ping, then higher score
        let aPing = a.pingMS ?? Int.max
        let bPing = b.pingMS ?? Int.max
        
        if aPing != bPing {
            return aPing < bPing
        }
        
        return a.score > b.score
    }
}

