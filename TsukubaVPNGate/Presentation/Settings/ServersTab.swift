import SwiftUI

// MARK: - Servers Tab (Browse All Servers)

struct ServersTab: View {
    @EnvironmentObject var coordinatorWrapper: CoordinatorWrapper
    @EnvironmentObject var monitoringStore: MonitoringStore
    @EnvironmentObject var serverStore: ServerStore
    
    @State private var filteredServers: [VPNServer] = []
    @State private var searchText: String = ""
    @State private var sortBy: SortOption = .score
    @State private var activeAlert: AlertType?
    
    private let blacklistManager = BlacklistManager()
    
    // Computed property to get connected server info
    private var connectedServerIP: String? {
        guard case .connected = monitoringStore.vpnStatistics.connectionState else {
            return nil
        }
        return monitoringStore.vpnStatistics.vpnIP
    }
    
    private var connectedServerName: String? {
        monitoringStore.vpnStatistics.connectedServerName
    }
    
    private var isConnected: Bool {
        if case .connected = monitoringStore.vpnStatistics.connectionState {
            return true
        }
        return false
    }
    
    enum SortOption: String, CaseIterable {
        case country = "Country"
        case score = "Score"
        case ping = "Ping"
        case speed = "Speed"
        
        var icon: String {
            switch self {
            case .country: return "flag.fill"
            case .score: return "star.fill"
            case .ping: return "timer"
            case .speed: return "speedometer"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack(spacing: 12) {
                // Search
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search by country, IP, or hostname", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(8)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                
                // Sort picker
                Picker("Sort by", selection: $sortBy) {
                    ForEach(SortOption.allCases, id: \.self) { option in
                        Label(option.rawValue, systemImage: option.icon)
                            .tag(option)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 140)
                
                // Refresh button (always forces refresh)
                Button(action: { serverStore.loadServers(forceRefresh: true) }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.body)
                }
                .buttonStyle(.plain)
                .disabled(serverStore.isLoading)
                .help("Refresh server list from API")
                
                // Cache indicator
                if let cacheAge = ServerCacheManager.shared.getCacheAge() {
                    let ageMinutes = Int(cacheAge / 60)
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.caption2)
                            .foregroundColor(.green)
                        Text("\(ageMinutes)m ago")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Server count
                Text("\(filteredServers.count) servers")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                // Loading indicator
                if serverStore.isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                        .frame(width: 20, height: 20)
                }
            }
            .padding()
            
            Divider()
            
            // Table header
            if !serverStore.isLoading && !filteredServers.isEmpty {
                HStack(spacing: 12) {
                    Text("")
                        .frame(width: 40)
                    
                    Text("Country")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 140, alignment: .leading)
                    
                    Text("Ping")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 60)
                    
                    Text("Speed")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 80)
                    
                    Text("Score")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 120)
                    
                    Spacer()
                    
                    Text("Actions")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 80, alignment: .trailing)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.gray.opacity(0.05))
                
                Divider()
            }
            
            // Servers table
            // Main Content
            ZStack {
                if serverStore.isLoading && filteredServers.isEmpty {
                    VStack {
                        ProgressView()
                        Text("Loading servers...")
                            .foregroundColor(.secondary)
                            .padding(.top, 8)
                    }
                } else if filteredServers.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "server.rack")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No servers available")
                            .font(.title3)
                            .foregroundColor(.secondary)
                        if let error = serverStore.lastError {
                            Text(error.localizedDescription)
                                .font(.caption)
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        Button("Retry") {
                            serverStore.loadServers(forceRefresh: true)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 1) {
                            ForEach(filteredServers) { server in
                                // Check if this server is the connected one
                                // Compare hostnames since that's what's stored in MonitoringStore
                                let isServerConnected: Bool = {
                                    let connectionState = monitoringStore.vpnStatistics.connectionState
                                    let connectedName = monitoringStore.vpnStatistics.connectedServerName
                                    
                                    guard case .connected = connectionState,
                                          let connectedServerName = connectedName else {
                                        return false
                                    }
                                    
                                    let matches = server.hostName == connectedServerName
                                    
                                    return matches
                                }()
                                
                                ServerRow(
                                    server: server,
                                    isBlacklisted: blacklistManager.isBlacklisted(server),
                                    isConnected: isServerConnected,
                                    onConnect: {
                                        // Check if already connected to a different server
                                        if self.isConnected && !isServerConnected {
                                            activeAlert = .reconnect(server)
                                        } else {
                                            activeAlert = .connect(server)
                                        }
                                    },
                                    onBlacklist: {
                                        let isBlacklisted = blacklistManager.isBlacklisted(server)
                                        activeAlert = isBlacklisted ? .blacklistRemove(server) : .blacklistAdd(server)
                                    }
                                )
                                
                                Divider()
                            }
                        }
                    }
                }
            }
            .onAppear {
                serverStore.loadServers()
                filterAndSortServers()
            }
            .onChange(of: searchText) { _ in
                filterAndSortServers()
            }
            .onChange(of: sortBy) { _ in
                filterAndSortServers()
            }
            .onChange(of: serverStore.servers) { _ in
                filterAndSortServers()
            }
            .onChange(of: monitoringStore.vpnStatistics.connectedServerName) { newName in
                print("🔄 [ServersTab] Connected server name changed to: \(newName ?? "nil")")
                // Force view refresh by triggering any state change
                // This ensures the ForEach re-evaluates isServerConnected
            }
            .alert(item: $activeAlert) { alertType in
                switch alertType {
                case .connect(let server):
                    return Alert(
                        title: Text("Connect to Server?"),
                        message: Text("Connect to \(server.countryLong) (\(server.ip))?"),
                        primaryButton: .default(Text("Connect"), action: {
                            print("🎯 [ServersTab] Connect button tapped in alert")
                            connectToServer(server)
                        }),
                        secondaryButton: .cancel()
                    )
                    
                case .reconnect(let server):
                    return Alert(
                        title: Text("Switch Server?"),
                        message: Text("You are currently connected to \(connectedServerName ?? "a server"). Disconnect and connect to \(server.countryLong) (\(server.ip))?"),
                        primaryButton: .default(Text("Switch"), action: {
                            print("🎯 [ServersTab] Reconnect confirmed")
                            // Disconnect first, then connect
                            coordinatorWrapper.disconnect { _ in
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    connectToServer(server)
                                }
                            }
                        }),
                        secondaryButton: .cancel()
                    )
                    
                case .error(let message):
                    return Alert(
                        title: Text("Connection Failed"),
                        message: Text(message),
                        dismissButton: .default(Text("OK"))
                    )
                    
                case .blacklistAdd(let server):
                    return Alert(
                        title: Text("Add to Blacklist?"),
                        message: Text("Blacklist \(server.countryLong) (\(server.ip))? It will be hidden from server selection."),
                        primaryButton: .destructive(Text("Blacklist"), action: {
                            blacklistManager.addToBlacklist(server, reason: "Manually blacklisted from Servers tab", expiry: .never)
                            print("✅ Added \(server.countryLong) to blacklist")
                        }),
                        secondaryButton: .cancel()
                    )
                    
                case .blacklistRemove(let server):
                    return Alert(
                        title: Text("Remove from Blacklist?"),
                        message: Text("Remove \(server.countryLong) (\(server.ip)) from blacklist?"),
                        primaryButton: .destructive(Text("Remove"), action: {
                            blacklistManager.removeFromBlacklist(serverId: server.ip)
                            print("✅ Removed \(server.countryLong) from blacklist")
                        }),
                        secondaryButton: .cancel()
                    )
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func filterAndSortServers() {
        var filtered = serverStore.servers
        
        // Apply search filter
        if !searchText.isEmpty {
            filtered = filtered.filter { server in
                server.countryLong.localizedCaseInsensitiveContains(searchText) ||
                server.countryShort.localizedCaseInsensitiveContains(searchText) ||
                server.ip.contains(searchText) ||
                server.hostName.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Apply sort
        switch sortBy {
        case .country:
            filtered.sort { $0.countryLong < $1.countryLong }
        case .score:
            filtered.sort { $0.score > $1.score }
        case .ping:
            filtered.sort { ($0.pingMS ?? Int.max) < ($1.pingMS ?? Int.max) }
        case .speed:
            filtered.sort { ($0.speedBps ?? 0) > ($1.speedBps ?? 0) }
        }
        
        filteredServers = filtered
    }
    
    private func connectToServer(_ server: VPNServer) {
            print("🔗 Connecting to \(server.countryLong) (\(server.ip))")
            
            // Store server info in MonitoringStore BEFORE connecting
            // This ensures UI can track which server we're connecting to
            monitoringStore.setConnectedServer(
                country: server.countryLong,
                countryShort: server.countryShort,
                serverName: server.hostName
            )
            
            // Use existing coordinator logic (DRY principle!)
            coordinatorWrapper.connect(to: server) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        print("✅ Connected to \(server.countryLong)")
                        // UI will update automatically via MonitoringStore
                        
                    case .failure(let error):
                        // Clear the server info if connection failed
                        monitoringStore.setConnectedServer(country: nil, countryShort: nil, serverName: nil)
                        activeAlert = .error(error.localizedDescription)
                    }
                }
            }
        }
    }
    
    // MARK: - Server Row
    
    struct ServerRow: View {
        let server: VPNServer
        let isBlacklisted: Bool
        let isConnected: Bool
        let onConnect: () -> Void
        let onBlacklist: () -> Void
        
        var body: some View {
            HStack(spacing: 12) {
                // Flag emoji or indicator
                Text(flagEmoji(for: server.countryShort))
                    .font(.title2)
                    .frame(width: 40)
                
                // Country
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(server.countryLong)
                            .font(.system(size: 13, weight: isConnected ? .bold : .medium))
                        
                        if isConnected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                    Text(server.ip)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                .frame(width: 140, alignment: .leading)
                
                // Ping
                if let ping = server.pingMS {
                    VStack(spacing: 2) {
                        Text("\(ping)")
                            .font(.system(size: 13, design: .monospaced))
                        Text("ms")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .frame(width: 60)
                } else {
                    Text("-")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .frame(width: 60)
                }
                
                // Speed
                if let speed = server.speedBps {
                    VStack(spacing: 2) {
                        Text(formatSpeed(speed))
                            .font(.system(size: 13, design: .monospaced))
                        Text("Mbps")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .frame(width: 80)
                } else {
                    Text("-")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .frame(width: 80)
                }
                
                // Score
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundColor(.yellow)
                    Text("\(server.score)")
                        .font(.system(size: 12, design: .monospaced))
                }
                .frame(width: 120)
                
                Spacer()
                
                // Status indicator
                if isBlacklisted {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                        .help("Blacklisted")
                }
                
                // Actions
                HStack(spacing: 8) {
                    Button(action: {
                        print("🔘 [ServerRow] Connect button tapped for \(server.countryLong)")
                        onConnect()
                    }) {
                        Text(isConnected ? "Connected" : "Connect")
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(isConnected ? Color.green : Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .disabled(isBlacklisted || isConnected)
                    .opacity((isBlacklisted || isConnected) ? 0.5 : 1.0)
                    
                    Button(action: onBlacklist) {
                        Image(systemName: "hand.raised.slash.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.white)
                            .padding(6)
                            .background(Color.orange)
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .help("Add to Blacklist")
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(isBlacklisted ? Color.red.opacity(0.05) : Color.clear)
        }
        
        private func flagEmoji(for countryCode: String) -> String {
            let base: UInt32 = 127397
            var emoji = ""
            for scalar in countryCode.uppercased().unicodeScalars {
                if let scalarValue = UnicodeScalar(base + scalar.value) {
                    emoji.unicodeScalars.append(scalarValue)
                }
            }
            return emoji.isEmpty ? "🌍" : emoji
        }
        
        private func formatSpeed(_ bps: Int) -> String {
            let mbps = Double(bps) / 1_000_000
            return String(format: "%.1f", mbps)
        }
    }


// MARK: - Alert Type

extension ServersTab {
    enum AlertType: Identifiable {
        case connect(VPNServer)
        case reconnect(VPNServer)
        case error(String)
        case blacklistAdd(VPNServer)
        case blacklistRemove(VPNServer)
        
        var id: String {
            switch self {
            case .connect(let server): return "connect_\(server.id)"
            case .reconnect(let server): return "reconnect_\(server.id)"
            case .error(let msg): return "error_\(msg.hashValue)"
            case .blacklistAdd(let server): return "blacklist_add_\(server.id)"
            case .blacklistRemove(let server): return "blacklist_remove_\(server.id)"
            }
        }
    }
}
