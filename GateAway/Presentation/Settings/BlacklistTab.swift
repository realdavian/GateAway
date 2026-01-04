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
            Text(
              "\(blacklist.filter { !$0.isExpired }.count) active • \(blacklist.filter { $0.isExpired }.count) expired"
            )
            .font(.caption)
            .foregroundColor(.secondary)
          }
        }

        Spacer()

        // Auto-cleanup toggle
        HStack {
          Toggle("Auto-cleanup expired".localized, isOn: $autoCleanup)
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
            Text("Add Server".localized)
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

          Text("No Blacklisted Servers".localized)
            .font(.headline)

          Text("Servers you blacklist will appear here".localized)
            .font(.caption)
            .foregroundColor(.secondary)
        }
        Spacer()
      } else {
        // Table header
        HStack(spacing: 12) {
          Text("")
            .frame(width: 36)

          Text("Hostname".localized)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)

          Text("Country".localized)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.secondary)
            .frame(width: 80, alignment: .leading)

          Text("Added".localized)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.secondary)
            .frame(width: 80, alignment: .leading)

          Text("Expires".localized)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.secondary)
            .frame(width: 80, alignment: .leading)

          Text("")
            .frame(width: 20)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.05))

        Divider()

        ScrollView {
          LazyVStack(spacing: 0) {
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
        title: Text("Remove from Blacklist?".localized),
        message: serverToRemove.map {
          Text("Remove %@ (%@) from blacklist?".localized(with: $0.hostname, $0.country))
        },
        primaryButton: .destructive(
          Text("Remove".localized),
          action: {
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
