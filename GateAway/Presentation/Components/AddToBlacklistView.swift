import SwiftUI

// MARK: - Add to Blacklist View

/// Modal view for adding a server to the blacklist
/// Can be used with a pre-selected server (from ServersTab) or with server picker (from BlacklistTab)
struct AddToBlacklistView: View {
  @Environment(\.presentationMode) var presentationMode
  @EnvironmentObject var serverStore: ServerStore

  // Pre-selected server (when called from ServersTab)
  let preselectedServer: VPNServer?

  @State private var selectedServerId: String = ""
  @State private var reason: String = ""
  @State private var selectedExpiry: BlacklistExpiry = .duration(86400)

  let onAdd: (VPNServer, String, BlacklistExpiry) -> Void

  // Expiry presets for the grid
  private let expiryPresets: [(String, BlacklistExpiry)] = [
    ("1 Hour", .duration(3600)),
    ("2 Hours", .duration(7200)),
    ("8 Hours", .duration(28800)),
    ("1 Day", .duration(86400)),
    ("7 Days", .duration(604800)),
    ("Never", .never),
  ]

  init(
    preselectedServer: VPNServer? = nil,
    onAdd: @escaping (VPNServer, String, BlacklistExpiry) -> Void
  ) {
    self.preselectedServer = preselectedServer
    self.onAdd = onAdd
    // Set initial selection if server is preselected
    if let server = preselectedServer {
      _selectedServerId = State(initialValue: server.ip)
    }
  }

  private var selectedServer: VPNServer? {
    preselectedServer ?? serverStore.servers.first(where: { $0.ip == selectedServerId })
  }

  private var canAdd: Bool {
    selectedServer != nil
  }

  var body: some View {
    VStack(spacing: 0) {
      // Header
      HStack {
        VStack(alignment: .leading, spacing: 4) {
          Text("Add to Blacklist")
            .font(.title2)
            .fontWeight(.bold)

          if let server = preselectedServer {
            HStack(spacing: 6) {
              Text(flagEmoji(for: server.countryShort))
              Text(server.countryLong)
                .foregroundColor(.secondary)
              Text("•")
                .foregroundColor(.secondary)
              Text(server.ip)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
            }
          }
        }
        Spacer()
        Button(action: { presentationMode.wrappedValue.dismiss() }) {
          Image(systemName: "xmark.circle.fill")
            .font(.title2)
            .foregroundColor(.secondary)
        }
        .buttonStyle(.plain)
      }
      .padding()

      Divider()

      // Content
      VStack(alignment: .leading, spacing: 20) {
        // Server selection (only show if no preselected server)
        if preselectedServer == nil {
          VStack(alignment: .leading, spacing: 8) {
            Text("Select Server")
              .font(.headline)

            if serverStore.isLoading {
              HStack {
                ProgressView()
                  .scaleEffect(0.7)
                Text("Loading servers...")
                  .font(.caption)
                  .foregroundColor(.secondary)
              }
            } else if serverStore.servers.isEmpty {
              Text("No servers available. Refresh the server list from the Servers tab.")
                .font(.caption)
                .foregroundColor(.orange)
            } else {
              Picker("Server", selection: $selectedServerId) {
                Text("Select a server...").tag("")
                ForEach(serverStore.servers.sorted { $0.countryLong < $1.countryLong }) { server in
                  Text(
                    "\(flagEmoji(for: server.countryShort)) \(server.countryLong) - \(server.ip)"
                  )
                  .tag(server.ip)
                }
              }
              .pickerStyle(.menu)
            }
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

        // Expiry - Grid layout
        VStack(alignment: .leading, spacing: 12) {
          Text("Expires After")
            .font(.headline)

          LazyVGrid(
            columns: [
              GridItem(.flexible()),
              GridItem(.flexible()),
              GridItem(.flexible()),
            ], spacing: 8
          ) {
            ForEach(expiryPresets, id: \.0) { preset in
              Button(action: {
                selectedExpiry = preset.1
              }) {
                Text(preset.0)
                  .font(.subheadline)
                  .frame(maxWidth: .infinity)
                  .padding(.vertical, 10)
                  .background(isSelected(preset.1) ? Color.accentColor : Color.gray.opacity(0.1))
                  .foregroundColor(isSelected(preset.1) ? .white : .primary)
                  .cornerRadius(8)
              }
              .buttonStyle(.plain)
            }
          }
        }
      }
      .padding()

      Divider()

      // Footer with Add button
      HStack {
        Spacer()

        Button("Add to Blacklist") {
          if let server = selectedServer {
            onAdd(server, reason, selectedExpiry)
            presentationMode.wrappedValue.dismiss()
          }
        }
        .keyboardShortcut(.defaultAction)
        .disabled(!canAdd)
      }
      .padding()
    }
    .frame(width: preselectedServer != nil ? 380 : 480)
    .fixedSize(horizontal: false, vertical: true)
    .onAppear {
      if preselectedServer == nil {
        serverStore.loadServers()
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
