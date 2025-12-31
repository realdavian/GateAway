import Foundation
import Network

// MARK: - Protocol (ISP: Interface segregation - only selection methods)

protocol ServerSelectionServiceProtocol {
    func selectBestServerAsync(from servers: [VPNServer]) async -> VPNServer?
    func filterServers(_ servers: [VPNServer], byCountry country: String) -> [VPNServer]
    func topServers(from servers: [VPNServer], country: String, limit: Int) -> [VPNServer]
    func availableCountries(from servers: [VPNServer]) -> [String]
}

// MARK: - Implementation (SRP: Single responsibility - server selection logic)

final class ServerSelectionService: ServerSelectionServiceProtocol {
    
    // MARK: - Async Selection (real-time parallel testing)
    
    /// Select best server by testing top candidates in parallel
    /// Returns fastest responding server, falls back to score-based if no responses
    func selectBestServerAsync(from servers: [VPNServer]) async -> VPNServer? {
        guard !servers.isEmpty else { return nil }
        
        // For small lists, skip network testing and use score-based selection
        guard servers.count >= 5 else {
            print("🏓 [ServerSelection] Small list (\(servers.count)), using score-based selection")
            return servers.sorted { compareServers($0, $1) }.first
        }
        
        // Get top 10 candidates by score/ping
        let candidates = Array(servers.sorted { compareServers($0, $1) }.prefix(10))
        
        print("🏓 [ServerSelection] Testing \(candidates.count) servers in parallel...")
        
        // Test in parallel, fallback to score-based if all fail
        if let fastest = await testServersInParallel(candidates) {
            print("✅ [ServerSelection] Fastest server: \(fastest.countryLong) (\(fastest.ip))")
            return fastest
        }
        
        print("⚠️ [ServerSelection] No ping responses, falling back to score-based selection")
        return servers.sorted { compareServers($0, $1) }.first
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
                    let responseTime = await self.probeServer(server)
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
    
    // MARK: - Private: TCP Probe (non-blocking)
    
    /// Probe server reachability using TCP connection
    /// More relevant than ICMP ping (tests actual port connectivity) and non-blocking
    private func probeServer(_ server: VPNServer) async -> TimeInterval? {
        let start = Date()
        let host = NWEndpoint.Host(server.ip)
        // Try common OpenVPN ports: 443 first (often used), then 1194 (default)
        let port = NWEndpoint.Port(rawValue: 443) ?? .https
        
        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true
        
        let connection = NWConnection(host: host, port: port, using: parameters)
        
        return await withCheckedContinuation { continuation in
            var hasResumed = false
            
            connection.stateUpdateHandler = { [weak connection] state in
                guard !hasResumed else { return }
                
                switch state {
                case .ready:
                    hasResumed = true
                    let elapsed = Date().timeIntervalSince(start)
                    continuation.resume(returning: elapsed)
                    connection?.cancel()
                    
                case .failed, .cancelled:
                    hasResumed = true
                    continuation.resume(returning: nil)
                    connection?.cancel()
                    
                default:
                    break
                }
            }
            
            connection.start(queue: .global(qos: .userInitiated))
            
            // Timeout after 1.5s (faster than ping's 2s)
            Task {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                if !hasResumed {
                    hasResumed = true
                    continuation.resume(returning: nil)
                    connection.cancel()
                }
            }
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

