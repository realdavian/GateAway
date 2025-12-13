import SwiftUI

// MARK: - Blacklist Tab

struct BlacklistTab: View {
    @State private var blacklist: [BlacklistedServer] = []
    @State private var showingAddDialog: Bool = false
    @State private var autoCleanup: Bool = true
    @State private var showingRemoveConfirm: Bool = false
    @State private var serverToRemove: BlacklistedServer?
    
    private let blacklistManager = BlacklistManager()
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with stats and actions
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(blacklist.count) Blacklisted Servers")
                        .font(.headline)
                    
                    if blacklist.contains(where: { !$0.isExpired }) {
                        Text("\(blacklist.filter { !$0.isExpired }.count) active • \(blacklist.filter { $0.isExpired }.count) expired")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Auto-cleanup toggle
                HStack {
                    Toggle("Auto-cleanup expired", isOn: $autoCleanup)
                        .toggleStyle(SwitchToggleStyle())
                        .font(.caption)
                }
                .onChange(of: autoCleanup) { enabled in
                    if enabled {
                        cleanupExpired()
                    }
                }
                
                Button(action: { showingAddDialog = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                        Text("Add Server")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            .padding()
            
            Divider()
            
            // Blacklist table
            if blacklist.isEmpty {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    
                    Text("No Blacklisted Servers")
                        .font(.headline)
                    
                    Text("Servers you blacklist will appear here")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button(action: { showingAddDialog = true }) {
                        Text("Add Server to Blacklist")
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(blacklist) { server in
                            BlacklistRow(
                                server: server,
                                onRemove: {
                                    serverToRemove = server
                                    showingRemoveConfirm = true
                                },
                                onEdit: {
                                    // TODO: Edit blacklist entry
                                }
                            )
                            
                            Divider()
                        }
                    }
                }
            }
        }
        .onAppear {
            refreshBlacklist()
        }
        .sheet(isPresented: $showingAddDialog) {
            AddToBlacklistView(onAdd: { server, reason, expiry in
                blacklistManager.addToBlacklist(server, reason: reason, expiry: expiry)
                refreshBlacklist()
            })
        }
        .alert(isPresented: $showingRemoveConfirm) {
            Alert(
                title: Text("Remove from Blacklist?"),
                message: serverToRemove.map { Text("Remove \($0.hostname) (\($0.country)) from blacklist?") },
                primaryButton: .destructive(Text("Remove"), action: {
                    if let server = serverToRemove {
                        blacklistManager.removeFromBlacklist(serverId: server.id)
                        refreshBlacklist()
                    }
                }),
                secondaryButton: .cancel()
            )
        }
    }
    
    private func refreshBlacklist() {
        blacklist = blacklistManager.getAllBlacklisted()
            .sorted { $0.blacklistedAt > $1.blacklistedAt }
    }
    
    private func cleanupExpired() {
        blacklistManager.cleanupExpired()
        refreshBlacklist()
    }
}

// MARK: - Blacklist Row

struct BlacklistRow: View {
    let server: BlacklistedServer
    let onRemove: () -> Void
    let onEdit: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Flag
            Text(flagEmoji(for: String(server.country.prefix(2))))
                .font(.title2)
                .frame(width: 40)
            
            // Server info
            VStack(alignment: .leading, spacing: 4) {
                Text(server.hostname)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(server.isExpired ? .secondary : .primary)
                
                Text(server.id)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .frame(width: 160, alignment: .leading)
            
            // Country
            Text(server.country)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .leading)
            
            // Reason
            Text(server.reason)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .frame(width: 120, alignment: .leading)
            
            // Blacklisted date
            Text(server.formattedBlacklistDate)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .frame(width: 140, alignment: .leading)
            
            // Expiry
            HStack(spacing: 4) {
                if server.isExpired {
                    Image(systemName: "clock.badge.exclamationmark")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                Text(server.expiryDescription)
                    .font(.system(size: 11))
                    .foregroundColor(server.isExpired ? .orange : .secondary)
            }
            .frame(width: 120, alignment: .leading)
            
            Spacer()
            
            // Actions
            HStack(spacing: 8) {
                Button(action: onRemove) {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
                .help("Remove from blacklist")
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(server.isExpired ? Color.orange.opacity(0.05) : Color.clear)
        .opacity(server.isExpired ? 0.6 : 1.0)
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
}

// MARK: - Add to Blacklist View

struct AddToBlacklistView: View {
    @Environment(\.presentationMode) var presentationMode
    
    @State private var selectedServerId: String = ""
    @State private var reason: String = ""
    @State private var selectedExpiry: BlacklistExpiry = .duration(86400)
    
    @State private var servers: [VPNServer] = []
    @State private var isLoadingServers: Bool = false
    
    let onAdd: (VPNServer, String, BlacklistExpiry) -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Text("Add to Blacklist")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
            }
            .padding()
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Server selection
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Select Server")
                            .font(.headline)
                        
                        if isLoadingServers {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.7)
                                Text("Loading servers...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } else if servers.isEmpty {
                            Text("No servers available. Refresh the server list from the Servers tab.")
                                .font(.caption)
                                .foregroundColor(.orange)
                        } else {
                            Picker("Server", selection: $selectedServerId) {
                                Text("Select a server...").tag("")
                                ForEach(servers) { server in
                                    Text("\(server.countryLong) - \(server.ip)")
                                        .tag(server.ip)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                    }
                    
                    // Reason
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Reason (Optional)")
                            .font(.headline)
                        
                        TextField("e.g., Too slow, Connection failed", text: $reason)
                            .textFieldStyle(.plain)
                            .padding(10)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                    }
                    
                    // Expiry
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Expires After")
                            .font(.headline)
                        
                        VStack(spacing: 8) {
                            ForEach(BlacklistExpiry.presets, id: \.0) { preset in
                                Button(action: {
                                    selectedExpiry = preset.1
                                }) {
                                    HStack {
                                        Text(preset.0)
                                            .font(.subheadline)
                                        Spacer()
                                        if isSelected(preset.1) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.blue)
                                        }
                                    }
                                    .padding(12)
                                    .background(isSelected(preset.1) ? Color.blue.opacity(0.1) : Color.gray.opacity(0.05))
                                    .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding()
            }
            
            Divider()
            
            // Actions
            HStack {
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.gray.opacity(0.2))
                .foregroundColor(.primary)
                .cornerRadius(8)
                .buttonStyle(.plain)
                
                Spacer()
                
                Button("Add to Blacklist") {
                    if let server = servers.first(where: { $0.ip == selectedServerId }) {
                        onAdd(server, reason, selectedExpiry)
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(selectedServerId.isEmpty ? Color.gray : Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(8)
                .buttonStyle(.plain)
                .disabled(selectedServerId.isEmpty)
            }
            .padding()
        }
        .frame(width: 500, height: 600)
        .onAppear {
            loadServers()
        }
    }
    
    private func loadServers() {
        isLoadingServers = true
        
        VPNGateAPI().fetchServers { result in
            DispatchQueue.main.async {
                isLoadingServers = false
                
                if case .success(let fetchedServers) = result {
                    servers = fetchedServers.sorted { $0.countryLong < $1.countryLong }
                }
            }
        }
    }
    
    private func isSelected(_ expiry: BlacklistExpiry) -> Bool {
        switch (selectedExpiry, expiry) {
        case (.never, .never):
            return true
        case (.duration(let a), .duration(let b)):
            return a == b
        case (.date(let a), .date(let b)):
            return a == b
        default:
            return false
        }
    }
}

