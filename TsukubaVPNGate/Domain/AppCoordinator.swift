import Foundation

// MARK: - Coordinator Protocol (OCP: Open for extension)

protocol AppCoordinatorProtocol {
    func refreshServerList() async throws
    func connectToBestServer() async throws
    func connectToServer(_ server: VPNServer) async throws
    func disconnect() async throws
    func cancelConnection() async
    
    func getAvailableCountries() -> [String]
    func getTopServers(forCountry country: String) -> [VPNServer]
    func getServerByID(_ id: String) -> VPNServer?
    func getCurrentConnectionState() -> ConnectionState
    func getPreferences() -> UserPreferences
    func getStatusSummary() -> (title: String, subtitle: String?)
}

// MARK: - Implementation (DIP: Coordinates services via abstractions)

final class AppCoordinator: AppCoordinatorProtocol {
    // Dependencies
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
        
        // Use async parallel testing for best server selection
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
    
    // MARK: - UI Helpers (for presentation layer)
    
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

