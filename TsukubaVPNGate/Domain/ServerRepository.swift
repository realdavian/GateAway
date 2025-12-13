import Foundation

// MARK: - Protocol (DIP: Depend on abstractions)

protocol ServerRepositoryProtocol {
    func fetchServers(completion: @escaping (Result<[VPNServer], Error>) -> Void)
    func getCachedServers() -> [VPNServer]
    func getLastRefreshDate() -> Date?
}

// MARK: - Implementation (SRP: Single responsibility - manage server data)

final class ServerRepository: ServerRepositoryProtocol {
    private let api: VPNGateAPIProtocol
    private var cachedServers: [VPNServer] = []
    private var lastRefresh: Date?
    
    init(api: VPNGateAPIProtocol = VPNGateAPI()) {
        self.api = api
    }
    
    func fetchServers(completion: @escaping (Result<[VPNServer], Error>) -> Void) {
        print("📡 ServerRepository: Starting server fetch...")
        api.fetchServers { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let servers):
                print("✅ ServerRepository: Fetched \(servers.count) servers")
                self.cachedServers = servers
                self.lastRefresh = Date()
                completion(.success(servers))
                
            case .failure(let error):
                print("❌ ServerRepository: Fetch failed: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }
    
    func getCachedServers() -> [VPNServer] {
        return cachedServers
    }
    
    func getLastRefreshDate() -> Date? {
        return lastRefresh
    }
}

