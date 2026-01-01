import Foundation

// MARK: - Protocol

/// Central coordinator for app-wide VPN operations
protocol AppCoordinatorProtocol {
    /// Refreshes the server list from the API
    func refreshServerList() async throws
    
    /// Connects to the best available server using parallel ping tests
    func connectToBestServer() async throws
    
    /// Connects to a specific VPN server
    /// - Parameter server: The server to connect to
    func connectToServer(_ server: VPNServer) async throws
    
    /// Disconnects from the current VPN server
    func disconnect() async throws
    
    /// Cancels an in-progress connection attempt
    func cancelConnection() async
    
    /// Returns list of countries with available servers
    func getAvailableCountries() -> [String]
    
    /// Returns top servers for a country, sorted by quality
    /// - Parameter country: The country name to filter by
    func getTopServers(forCountry country: String) -> [VPNServer]
    
    /// Finds a server by its unique ID
    /// - Parameter id: The server ID to search for
    func getServerByID(_ id: String) -> VPNServer?
    
    /// Returns the current connection state
    func getCurrentConnectionState() -> ConnectionState
    
    /// Returns user preferences
    func getPreferences() -> UserPreferences
    
    /// Returns a formatted status summary for UI display
    func getStatusSummary() -> (title: String, subtitle: String?)
}

// MARK: - Implementation

/// Coordinates between services and provides a unified API for the UI layer
final class AppCoordinator: AppCoordinatorProtocol {
    private let serverStore: ServerStore
    private let selectionService: ServerSelectionServiceProtocol
    private let connectionManager: VPNConnectionManagerProtocol
    private let preferencesManager: PreferencesManagerProtocol
    
    init(
        serverStore: ServerStore,
        selectionService: ServerSelectionServiceProtocol,
        connectionManager: VPNConnectionManagerProtocol,
        preferencesManager: PreferencesManagerProtocol
    ) {
        self.serverStore = serverStore
        self.selectionService = selectionService
        self.connectionManager = connectionManager
        self.preferencesManager = preferencesManager
    }
    
    // MARK: - Server Management
    
    @MainActor
    func refreshServerList() async throws {
        _ = try await serverStore.fetchServers()
    }
    
    @MainActor
    func getAvailableCountries() -> [String] {
        let servers = serverStore.servers
        return selectionService.availableCountries(from: servers)
    }
    
    @MainActor
    func getTopServers(forCountry country: String) -> [VPNServer] {
        let servers = serverStore.servers
        let preferences = preferencesManager.loadPreferences()
        return selectionService.topServers(from: servers, country: country, limit: preferences.topKPerCountry)
    }
    
    @MainActor
    func getServerByID(_ id: String) -> VPNServer? {
        return serverStore.servers.first { $0.id == id }
    }
    
    // MARK: - Connection Management
    
    @MainActor
    func connectToBestServer() async throws {
        let servers = serverStore.servers
        
        guard let bestServer = await selectionService.selectBestServerAsync(from: servers) else {
            throw NSError(domain: "AppCoordinator", code: 1, userInfo: [NSLocalizedDescriptionKey: "No servers available"])
        }
        
        try await connectToServer(bestServer)
    }
    
    func connectToServer(_ server: VPNServer) async throws {
        try await connectionManager.connect(to: server, enableRetry: true)
    }
    
    func disconnect() async throws {
        try await connectionManager.disconnect()
    }
    
    func cancelConnection() async {
        await connectionManager.cancelConnection()
    }
    
    func getCurrentConnectionState() -> ConnectionState {
        return connectionManager.currentState
    }
    
    // MARK: - Preferences
    
    func getPreferences() -> UserPreferences {
        return preferencesManager.loadPreferences()
    }
    
    // MARK: - UI Helpers
    
    @MainActor
    func getStatusSummary() -> (title: String, subtitle: String?) {
        let state = connectionManager.currentState
        let servers = serverStore.servers
        let lastRefresh = serverStore.lastRefresh
        
        let title: String
        switch state {
        case .disconnected:
            title = "Disconnected"
        case .connecting:
            title = "Connecting..."
        case .connected:
            title = "Connected"
        case .disconnecting:
            title = "Disconnecting..."
        case .reconnecting:
            title = "Reconnecting..."
        case .error(let message):
            title = "Error: \(message)"
        }
        
        var subtitleParts: [String] = []
        if !servers.isEmpty {
            subtitleParts.append("Servers: \(servers.count)")
        }
        if let lastRefresh {
            let formatter = DateFormatter()
            formatter.dateStyle = .none
            formatter.timeStyle = .short
            subtitleParts.append("Updated: \(formatter.string(from: lastRefresh))")
        }
        
        let subtitle = subtitleParts.isEmpty ? nil : subtitleParts.joined(separator: " • ")
        
        return (title, subtitle)
    }
}
