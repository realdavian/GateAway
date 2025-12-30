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
    func getCurrentConnectionState() -> VPNConnectionState
    func getPreferences() -> UserPreferences
    func getStatusSummary() -> (title: String, subtitle: String?)
}

// MARK: - Implementation (DIP: Coordinates services via abstractions)

final class AppCoordinator: AppCoordinatorProtocol {
    // Dependencies (all injected via protocols - DIP)
    private let serverRepository: ServerRepositoryProtocol
    private let selectionService: ServerSelectionServiceProtocol
    private let connectionManager: VPNConnectionManagerProtocol
    private let preferencesManager: PreferencesManagerProtocol
    
    init(
        serverRepository: ServerRepositoryProtocol,
        selectionService: ServerSelectionServiceProtocol,
        connectionManager: VPNConnectionManagerProtocol,
        preferencesManager: PreferencesManagerProtocol
    ) {
        self.serverRepository = serverRepository
        self.selectionService = selectionService
        self.connectionManager = connectionManager
        self.preferencesManager = preferencesManager
    }
    
    // MARK: - Server Management
    
    func refreshServerList() async throws {
        _ = try await serverRepository.fetchServers()
    }
    
    func getAvailableCountries() -> [String] {
        let servers = serverRepository.getCachedServers()
        return selectionService.availableCountries(from: servers)
    }
    
    func getTopServers(forCountry country: String) -> [VPNServer] {
        let servers = serverRepository.getCachedServers()
        let preferences = preferencesManager.loadPreferences()
        return selectionService.topServers(from: servers, country: country, limit: preferences.topKPerCountry)
    }
    
    func getServerByID(_ id: String) -> VPNServer? {
        return serverRepository.getCachedServers().first { $0.id == id }
    }
    
    // MARK: - Connection Management
    
    func connectToBestServer() async throws {
        let servers = serverRepository.getCachedServers()
        
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
    
    func getCurrentConnectionState() -> VPNConnectionState {
        return connectionManager.currentState
    }
    
    // MARK: - Preferences
    
    func getPreferences() -> UserPreferences {
        return preferencesManager.loadPreferences()
    }
    
    // MARK: - UI Helpers (for presentation layer)
    
    func getStatusSummary() -> (title: String, subtitle: String?) {
        let state = connectionManager.currentState
        let servers = serverRepository.getCachedServers()
        let lastRefresh = serverRepository.getLastRefreshDate()
        
        let title: String
        switch state {
        case .disconnected:
            title = "Disconnected"
        case .connecting(let server):
            title = "Connecting to \(server.countryLong)..."
        case .connected(let server):
            title = "Connected — \(server.countryLong)"
        case .disconnecting:
            title = "Disconnecting..."
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

