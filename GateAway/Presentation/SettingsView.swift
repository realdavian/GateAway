import SwiftUI

// MARK: - New Tab-Based Settings View

struct SettingsView: View {
  @AppStorage(Constants.StorageKeys.selectedSettingsTab) private var selectedTab: SettingsTab =
    .overview

  enum SettingsTab: Int {
    case overview = 0
    case servers = 1
    case monitoring = 2
    case security = 3
    case blacklist = 4

    var title: String {
      switch self {
      case .overview: return "Overview"
      case .servers: return "Servers"
      case .monitoring: return "Monitoring"
      case .security: return "Security"
      case .blacklist: return "Blacklist"
      }
    }

    var icon: String {
      switch self {
      case .overview: return "house.fill"
      case .servers: return "server.rack"
      case .monitoring: return "chart.bar.fill"
      case .security: return "lock.shield.fill"
      case .blacklist: return "hand.raised.fill"
      }
    }
  }

  var body: some View {
    VStack(spacing: 0) {
      // Header
      HStack {
        Image(systemName: "gearshape.fill")
          .font(.title2)
          .foregroundColor(.accentColor)
        Text("Settings")
          .font(.system(.title2, design: .default).weight(.semibold))
        Spacer()
      }
      .padding()
      .background(Color.gray.opacity(0.1))

      Divider()

      // Tab bar + content
      HStack(spacing: 0) {
        // Sidebar with tabs
        VStack(spacing: 0) {
          ForEach([SettingsTab.overview, .servers, .monitoring, .security, .blacklist], id: \.self)
          { tab in
            Button(action: {
              selectedTab = tab
            }) {
              HStack(spacing: 12) {
                Image(systemName: tab.icon)
                  .font(.body)
                  .frame(width: 20)
                  .foregroundColor(selectedTab == tab ? .accentColor : .secondary)

                Text(tab.title)
                  .font(.system(size: 13))
                  .foregroundColor(selectedTab == tab ? .primary : .secondary)

                Spacer()
              }
              .padding(.horizontal, 16)
              .padding(.vertical, 10)
              .background(selectedTab == tab ? Color.accentColor.opacity(0.1) : Color.clear)
              .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
          }

          Spacer()
        }
        .frame(width: 180)
        .background(Color.gray.opacity(0.05))

        Divider()

        // Content area
        Group {
          switch selectedTab {
          case .overview:
            OverviewTab()
          case .servers:
            ServersTab()
          case .monitoring:
            MonitoringTab()
          case .security:
            SecurityTab()
          case .blacklist:
            BlacklistTab()
          }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
    }
    .frame(minWidth: 900, minHeight: 650)
  }
}

// MARK: - Preview

struct SettingsView_Previews: PreviewProvider {
  static var previews: some View {
    SettingsView()
  }
}
