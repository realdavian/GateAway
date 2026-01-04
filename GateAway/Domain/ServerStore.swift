import Combine
import Foundation

@MainActor
final class ServerStore: ObservableObject {

  // MARK: - Published State

  @Published private(set) var servers: [VPNServer] = []
  @Published private(set) var isLoading: Bool = false
  @Published private(set) var lastError: Error?
  @Published private(set) var lastRefresh: Date?

  // MARK: - Dependencies

  private let api: VPNGateAPIProtocol
  private let cache: ServerCacheManagerProtocol

  // MARK: - Init

  init(api: VPNGateAPIProtocol, cache: ServerCacheManagerProtocol) {
    self.api = api
    self.cache = cache

    if let cachedServers = cache.getCachedServers() {
      self.servers = cachedServers
      self.lastRefresh = cache.getCacheAge().map { Date().addingTimeInterval(-$0) }
      Log.debug("Initialized with \(cachedServers.count) cached servers")
    }
  }

  // MARK: - Public Methods

  func fetchServers() async throws -> [VPNServer] {
    isLoading = true
    lastError = nil

    do {
      let fetchedServers = try await api.fetchServers()
      self.servers = fetchedServers
      self.cache.cacheServers(fetchedServers)
      self.lastRefresh = Date()
      self.isLoading = false
      Log.success("Fetched \(fetchedServers.count) servers from API")
      return fetchedServers
    } catch {
      self.isLoading = false
      self.lastError = error
      Log.error("Fetch failed: \(error.localizedDescription)")
      throw error
    }
  }

  func loadServers(forceRefresh: Bool = false) {
    if !forceRefresh, let cachedServers = cache.getCachedServers() {
      servers = cachedServers
      Log.debug("Loaded \(cachedServers.count) servers from cache")
      return
    }

    Task {
      _ = try? await fetchServers()
    }
  }

  /// Pre-fetch servers in background for instant availability
  func warmupCache() {
    if cache.isCacheValid {
      Log.debug("Warmup: cache already valid")
      return
    }

    Log.debug("Warmup: fetching servers...")
    Task {
      do {
        let fetchedServers = try await api.fetchServers()
        await MainActor.run {
          self.servers = fetchedServers
          self.cache.cacheServers(fetchedServers)
          Log.debug("Warmup: cached \(fetchedServers.count) servers")
        }
      } catch {
        Log.warning("Warmup failed: \(error.localizedDescription)")
      }
    }
  }
}
