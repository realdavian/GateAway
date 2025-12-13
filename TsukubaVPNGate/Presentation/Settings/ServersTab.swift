import SwiftUI

// MARK: - Servers Tab (Browse All Servers)

struct ServersTab: View {
    @State private var servers: [VPNServer] = []
    @State private var filteredServers: [VPNServer] = []
    @State private var searchText: String = ""
    @State private var sortBy: SortOption = .score
    @State private var isLoading: Bool = false
    @State private var selectedServer: VPNServer?
    @State private var showingConnectAlert: Bool = false
    
    private let blacklistManager = BlacklistManager()
    
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
                
                // Refresh button
                Button(action: refreshServers) {
                    Image(systemName: "arrow.clockwise")
                        .font(.body)
                }
                .buttonStyle(.plain)
                .disabled(isLoading)
                
                // Server count
                Text("\(filteredServers.count) servers")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            
            Divider()
            
            // Table header
            if !isLoading && !filteredServers.isEmpty {
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
            if isLoading {
                Spacer()
                ProgressView("Loading servers...")
                Spacer()
            } else if filteredServers.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "server.rack")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No servers found")
                        .font(.headline)
                    Text(searchText.isEmpty ? "Refresh to load servers" : "Try a different search term")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(filteredServers) { server in
                            ServerRow(
                                server: server,
                                isBlacklisted: blacklistManager.isBlacklisted(server),
                                onConnect: {
                                    selectedServer = server
                                    showingConnectAlert = true
                                },
                                onBlacklist: {
                                    // TODO: Show blacklist dialog
                                }
                            )
                            
                            Divider()
                        }
                    }
                }
            }
        }
        .onAppear {
            if servers.isEmpty {
                refreshServers()
            }
        }
        .onChange(of: searchText) { _ in
            filterAndSortServers()
        }
        .onChange(of: sortBy) { _ in
            filterAndSortServers()
        }
        .alert(isPresented: $showingConnectAlert) {
            Alert(
                title: Text("Connect to Server?"),
                message: selectedServer.map { Text("Connect to \($0.countryLong) (\($0.ip))?") },
                primaryButton: .default(Text("Connect"), action: {
                    if let server = selectedServer {
                        connectToServer(server)
                    }
                }),
                secondaryButton: .cancel()
            )
        }
    }
    
    private func refreshServers() {
        isLoading = true
        
        // Fetch from API
        VPNGateAPI().fetchServers { result in
            DispatchQueue.main.async {
                isLoading = false
                
                switch result {
                case .success(let fetchedServers):
                    servers = fetchedServers
                    filterAndSortServers()
                    print("✅ Loaded \(fetchedServers.count) servers")
                    
                case .failure(let error):
                    print("❌ Failed to load servers: \(error)")
                }
            }
        }
    }
    
    private func filterAndSortServers() {
        var filtered = servers
        
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
        // TODO: Trigger connection through coordinator
        NotificationCenter.default.post(
            name: NSNotification.Name("ConnectToServer"),
            object: nil,
            userInfo: ["server": server]
        )
    }
}

// MARK: - Server Row

struct ServerRow: View {
    let server: VPNServer
    let isBlacklisted: Bool
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
                Text(server.countryLong)
                    .font(.system(size: 13, weight: .medium))
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
                Button(action: onConnect) {
                    Text("Connect")
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(isBlacklisted ? Color.gray.opacity(0.3) : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .disabled(isBlacklisted)
                
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

