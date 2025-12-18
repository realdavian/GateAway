import SwiftUI

// MARK: - New Tab-Based Settings View

struct SettingsView: View {
    @AppStorage("selectedSettingsTab") private var selectedTab: SettingsTab = .overview
    
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
                    ForEach([SettingsTab.overview, .servers, .monitoring, .security, .blacklist], id: \.self) { tab in
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
        // Note: VPN monitoring lifecycle is managed by AppDelegate
        // based on connection state changes, not UI lifecycle
    }
}

// MARK: - Preview

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}

// MARK: - Reusable Settings Section

struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String
    let iconColor: Color
    let content: Content
    
    init(title: String, icon: String, iconColor: Color, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.iconColor = iconColor
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(iconColor)
                    .frame(width: 32, height: 32)
                    .background(iconColor.opacity(0.1))
                    .clipShape(Circle())
                
                Text(title)
                    .font(.headline)
            }
            
            VStack {
                content
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.1), lineWidth: 1)
            )
        }
    }
}

