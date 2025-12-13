import Foundation
import Combine

/// Centralized server list management with caching and pre-loading
@MainActor
final class ServerStore: ObservableObject {
    
    // MARK: - Singleton
    static let shared = ServerStore()
    
    // MARK: - Published State
    @Published private(set) var servers: [VPNServer] = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var lastError: Error?
    
    // MARK: - Dependencies
    private let api: VPNGateAPIProtocol
    private let cache: ServerCacheManager
    
    // MARK: - Init
    init(api: VPNGateAPIProtocol = VPNGateAPI(), cache: ServerCacheManager = .shared) {
        self.api = api
        self.cache = cache
        
        // Load from cache immediately on init
        if let cachedServers = cache.getCachedServers() {
            self.servers = cachedServers
            print("📦 [ServerStore] Initialized with \(cachedServers.count) cached servers")
        }
    }
    
    // MARK: - Public Methods
    
    /// Load servers from cache or API
    /// - Parameter forceRefresh: If true, bypasses cache and fetches from API
    func loadServers(forceRefresh: Bool = false) {
        // Try cache first if not forcing refresh
        if !forceRefresh, let cachedServers = cache.getCachedServers() {
            servers = cachedServers
            print("📦 [ServerStore] Loaded \(cachedServers.count) servers from cache")
            return
        }
        
        // Fetch from API
        fetchFromAPI()
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
        api.fetchServers { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                
                switch result {
                case .success(let fetchedServers):
                    self.servers = fetchedServers
                    self.cache.cacheServers(fetchedServers)
                    print("📦 [ServerStore] Warmup: cached \(fetchedServers.count) servers")
                    
                case .failure(let error):
                    print("⚠️ [ServerStore] Warmup failed: \(error.localizedDescription)")
                    // Don't set lastError during warmup - it's background
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func fetchFromAPI() {
        isLoading = true
        lastError = nil
        
        api.fetchServers { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                self.isLoading = false
                
                switch result {
                case .success(let fetchedServers):
                    self.servers = fetchedServers
                    self.cache.cacheServers(fetchedServers)
                    print("✅ [ServerStore] Fetched \(fetchedServers.count) servers from API")
                    
                case .failure(let error):
                    self.lastError = error
                    print("❌ [ServerStore] Fetch failed: \(error.localizedDescription)")
                }
            }
        }
    }
}
