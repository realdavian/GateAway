import SwiftUI

// MARK: - Servers Tab (Browse All Servers)

struct ServersTab: View {
  @EnvironmentObject var coordinatorWrapper: CoordinatorWrapper
  @EnvironmentObject var monitoringStore: MonitoringStore
  @EnvironmentObject var serverStore: ServerStore
  @Environment(\.cacheManager) private var cacheManager

  @State private var filteredServers: [VPNServer] = []
  @State private var searchText: String = ""
  @State private var sortBy: SortOption = .score
  @State private var activeAlert: AlertType?
  @State private var serverToBlacklist: VPNServer?
  @State private var blacklistRefreshId: UUID = UUID()

  private let blacklistManager = BlacklistManager()

  // Computed property to get connected server info
  private var connectedServerIP: String? {
    guard case .connected = monitoringStore.connectionState else {
      return nil
    }
    return monitoringStore.stats.vpnIP
  }

  private var connectedServerName: String? {
    monitoringStore.serverInfo.serverName
  }

  private var isConnected: Bool {
    if case .connected = monitoringStore.connectionState {
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
          TextField("Search by country, IP, or hostname".localized, text: $searchText)
            .textFieldStyle(.plain)
        }
        .padding(8)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)

        // Sort picker
        Picker("Sort by".localized, selection: $sortBy) {
          ForEach(SortOption.allCases, id: \.self) { option in
            Label(option.rawValue, systemImage: option.icon)
              .tag(option)
          }
        }
        .pickerStyle(.menu)
        .frame(width: 140)

        // Refresh button
        Button(action: { serverStore.loadServers(forceRefresh: true) }) {
          Image(systemName: "arrow.clockwise")
            .font(.body)
        }
        .buttonStyle(.plain)
        .disabled(serverStore.isLoading)
        .help("Refresh server list from API")

        // Cache indicator
        if let cacheAge = cacheManager.getCacheAge() {
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

          Text("Country".localized)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.secondary)
            .frame(width: 140, alignment: .leading)

          Text("Ping".localized)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.secondary)
            .frame(width: 60)

          Text("Speed".localized)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.secondary)
            .frame(width: 80)

          Text("Score".localized)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.secondary)
            .frame(width: 120)

          Spacer()

          Text("Actions".localized)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.secondary)
            .frame(width: 80, alignment: .trailing)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.05))

        Divider()
      }

      // Main Content
      ZStack {
        if serverStore.isLoading && filteredServers.isEmpty {
          VStack {
            ProgressView()
            Text("Loading servers...".localized)
              .foregroundColor(.secondary)
              .padding(.top, 8)
          }
        } else if filteredServers.isEmpty {
          VStack(spacing: 16) {
            Image(systemName: "server.rack")
              .font(.system(size: 48))
              .foregroundColor(.secondary)
            Text("No servers available".localized)
              .font(.title3)
              .foregroundColor(.secondary)
            if let error = serverStore.lastError {
              Text(error.localizedDescription)
                .font(.caption)
                .foregroundColor(.red)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            }
            Button("Retry".localized) {
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
                let isServerConnected: Bool = {
                  let connectionState = monitoringStore.connectionState
                  let connectedName = monitoringStore.serverInfo.serverName

                  guard case .connected = connectionState,
                    let connectedServerName = connectedName
                  else {
                    return false
                  }

                  return server.hostName == connectedServerName
                }()

                ServerRow(
                  server: server,
                  isBlacklisted: blacklistManager.isBlacklisted(server),
                  isConnected: isServerConnected,
                  connectionState: monitoringStore.connectionState,
                  connectedServerName: monitoringStore.serverInfo.serverName,
                  onConnect: {
                    if self.isConnected && !isServerConnected {
                      activeAlert = .reconnect(server)
                    } else {
                      activeAlert = .connect(server)
                    }
                  },
                  onDisconnect: {
                    handleDisconnect()
                  },
                  onCancelConnection: {
                    handleCancelConnection()
                  },
                  onBlacklist: {
                    let isBlacklisted = blacklistManager.isBlacklisted(server)
                    if isBlacklisted {
                      activeAlert = .blacklistRemove(server)
                    } else {
                      serverToBlacklist = server
                    }
                  }
                )

                Divider()
              }
            }
            .id(blacklistRefreshId)  // Force refresh when blacklist changes
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
      .onChange(of: monitoringStore.serverInfo.serverName) { newName in
        Log.debug("Connected server name changed to: \(newName ?? "nil")")
      }
      .sheet(item: $serverToBlacklist) { server in
        AddToBlacklistView(preselectedServer: server) { server, reason, expiry in
          blacklistManager.addToBlacklist(server, reason: reason, expiry: expiry)
          // Trigger refresh to update blacklist state in UI
          blacklistRefreshId = UUID()
        }
      }
      .alert(item: $activeAlert) { alertType in
        switch alertType {
        case .connect(let server):
          return Alert(
            title: Text("Connect to Server?".localized),
            message: Text("Connect to %@ (%@)?".localized(with: server.countryLong, server.ip)),
            primaryButton: .default(
              Text("Connect".localized),
              action: {
                connectToServer(server)
              }),
            secondaryButton: .cancel()
          )

        case .reconnect(let server):
          return Alert(
            title: Text("Switch Server?".localized),
            message: Text(
              "You are currently connected. Switch to %@ (%@)?".localized(
                with: server.countryLong, server.ip)
            ),
            primaryButton: .default(
              Text("Switch".localized),
              action: {
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
            title: Text("Connection Failed".localized),
            message: Text(message),
            dismissButton: .default(Text("OK".localized))
          )

        case .blacklistRemove(let server):
          return Alert(
            title: Text("Remove from Blacklist?".localized),
            message: Text(
              "Remove %@ (%@) from blacklist?".localized(with: server.countryLong, server.ip)),
            primaryButton: .destructive(
              Text("Remove".localized),
              action: {
                blacklistManager.removeFromBlacklist(serverId: server.ip)
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

    if !searchText.isEmpty {
      filtered = filtered.filter { server in
        server.countryLong.localizedCaseInsensitiveContains(searchText)
          || server.countryShort.localizedCaseInsensitiveContains(searchText)
          || server.ip.contains(searchText)
          || server.hostName.localizedCaseInsensitiveContains(searchText)
      }
    }

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
    // Server info is set by VPNConnectionManager via MonitoringStore.setConnecting()
    coordinatorWrapper.connect(to: server) { result in
      switch result {
      case .success:
        Log.success("Connected to \(server.countryLong)")
      case .failure(let error):
        self.activeAlert = .error(error.localizedDescription)
      }
    }
  }

  private func handleCancelConnection() {
    Task {
      await coordinatorWrapper.cancelConnection()
    }
  }

  private func handleDisconnect() {
    coordinatorWrapper.disconnect { result in
      if case .failure(let error) = result {
        self.activeAlert = .error(error.localizedDescription)
      }
    }
  }
}

// MARK: - Alert Type

extension ServersTab {
  enum AlertType: Identifiable {
    case connect(VPNServer)
    case reconnect(VPNServer)
    case error(String)
    case blacklistRemove(VPNServer)

    var id: String {
      switch self {
      case .connect(let server): return "connect_\(server.id)"
      case .reconnect(let server): return "reconnect_\(server.id)"
      case .error(let msg): return "error_\(msg.hashValue)"
      case .blacklistRemove(let server): return "blacklist_remove_\(server.id)"
      }
    }
  }
}
