import Foundation
import Combine

/// Centralized server list management with caching and pre-loading
@MainActor
final class ServerStore: ObservableObject {
    
    // MARK: - Published State
    @Published private(set) var servers: [VPNServer] = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var lastError: Error?
    @Published private(set) var lastRefresh: Date?
    
    // MARK: - Dependencies (injected for testability)
    private let api: VPNGateAPIProtocol
    private let cache: ServerCacheManagerProtocol
    
    // MARK: - Init
    init(api: VPNGateAPIProtocol = VPNGateAPI(), cache: ServerCacheManagerProtocol) {
        self.api = api
        self.cache = cache
        
        // Load from cache immediately on init
        if let cachedServers = cache.getCachedServers() {
            self.servers = cachedServers
            self.lastRefresh = cache.getCacheAge().map { Date().addingTimeInterval(-$0) }
            print("📦 [ServerStore] Initialized with \(cachedServers.count) cached servers")
        }
    }

    
    // MARK: - Public Methods
    
    /// Fetch servers from API (async version for coordinator)
    /// - Returns: Array of fetched servers
    func fetchServers() async throws -> [VPNServer] {
        isLoading = true
        lastError = nil
        
        do {
            let fetchedServers = try await api.fetchServers()
            self.servers = fetchedServers
            self.cache.cacheServers(fetchedServers)
            self.lastRefresh = Date()
            self.isLoading = false
            print("✅ [ServerStore] Fetched \(fetchedServers.count) servers from API")
            return fetchedServers
        } catch {
            self.isLoading = false
            self.lastError = error
            print("❌ [ServerStore] Fetch failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Load servers from cache or API (fire-and-forget version)
    /// - Parameter forceRefresh: If true, bypasses cache and fetches from API
    func loadServers(forceRefresh: Bool = false) {
        // Try cache first if not forcing refresh
        if !forceRefresh, let cachedServers = cache.getCachedServers() {
            servers = cachedServers
            print("📦 [ServerStore] Loaded \(cachedServers.count) servers from cache")
            return
        }
        
        // Fetch from API
        Task {
            _ = try? await fetchServers()
        }
    }
    
    /// Pre-fetch servers in background for instant availability
    /// Call this on app launch to warm up the cache
    func warmupCache() {
        // If cache is valid, we're already good
        if cache.isCacheValid {
            print("📦 [ServerStore] Warmup: cache already valid")
            return
        }
        
        // Fetch in background without showing loading state
        print("📦 [ServerStore] Warmup: fetching servers...")
        Task {
            do {
                let fetchedServers = try await api.fetchServers()
                await MainActor.run {
                    self.servers = fetchedServers
                    self.cache.cacheServers(fetchedServers)
                    print("📦 [ServerStore] Warmup: cached \(fetchedServers.count) servers")
                }
            } catch {
                print("⚠️ [ServerStore] Warmup failed: \(error.localizedDescription)")
                // Don't set lastError during warmup - it's background
            }
        }
    }
}
