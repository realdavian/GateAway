import Foundation

// MARK: - Protocol (DIP: Depend on abstractions)

protocol ServerRepositoryProtocol {
    func fetchServers(completion: @escaping (Result<[VPNServer], Error>) -> Void)
    func fetchServers() async throws -> [VPNServer]
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
    
    // MARK: - Async/Await API (Modern)
    
    func fetchServers() async throws -> [VPNServer] {
        print("📡 ServerRepository: Starting server fetch (async)...")
        let servers = try await api.fetchServers()
        print("✅ ServerRepository: Fetched \(servers.count) servers")
        self.cachedServers = servers
        self.lastRefresh = Date()
        return servers
    }
    
    // MARK: - Legacy Completion API (for backward compatibility)
    
    func fetchServers(completion: @escaping (Result<[VPNServer], Error>) -> Void) {
        Task {
            do {
                let servers = try await fetchServers()
                completion(.success(servers))
            } catch {
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

