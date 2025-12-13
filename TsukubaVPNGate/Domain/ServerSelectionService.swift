import Foundation

// MARK: - Protocol (ISP: Interface segregation - only selection methods)

protocol ServerSelectionServiceProtocol {
    func selectBestServer(from servers: [VPNServer]) -> VPNServer?
    func selectBestServer(from servers: [VPNServer], inCountry country: String) -> VPNServer?
    func filterServers(_ servers: [VPNServer], byCountry country: String) -> [VPNServer]
    func topServers(from servers: [VPNServer], country: String, limit: Int) -> [VPNServer]
    func availableCountries(from servers: [VPNServer]) -> [String]
}

// MARK: - Implementation (SRP: Single responsibility - server selection logic)

final class ServerSelectionService: ServerSelectionServiceProtocol {
    
    func selectBestServer(from servers: [VPNServer]) -> VPNServer? {
        return servers
            .sorted { compareServers($0, $1) }
            .first
    }
    
    func selectBestServer(from servers: [VPNServer], inCountry country: String) -> VPNServer? {
        let filtered = filterServers(servers, byCountry: country)
        return selectBestServer(from: filtered)
    }
    
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
    
    // MARK: - Private
    
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

