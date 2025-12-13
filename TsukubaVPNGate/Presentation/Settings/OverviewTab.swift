import SwiftUI

// MARK: - Overview Tab (Home Page)

struct OverviewTab: View {
    @State private var isOpenVPNInstalled: Bool = false
    @State private var openVPNVersion: String = ""
    @State private var vpnStatistics: VPNStatistics = .empty
    
    private let vpnMonitor = VPNMonitor.shared
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                
                // VPN Backend Status
                SettingsSection(
                    title: "VPN Backend",
                    icon: "terminal.fill",
                    iconColor: .green
                ) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(isOpenVPNInstalled ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
                                    .frame(width: 40, height: 40)
                                
                                Image(systemName: isOpenVPNInstalled ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                    .font(.title3)
                                    .foregroundColor(isOpenVPNInstalled ? .green : .orange)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("OpenVPN CLI")
                                    .font(.system(size: 15, weight: .semibold))
                                
                                if isOpenVPNInstalled {
                                    Text("Installed • Version \(openVPNVersion)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                } else {
                                    Text("Not Installed")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                            }
                            
                            Spacer()
                            
                            if !isOpenVPNInstalled {
                                Button("Install") {
                                    // TODO: Trigger installation
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.accentColor)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                
                // Real-time VPN Status
                SettingsSection(
                    title: "Connection Status",
                    icon: "network",
                    iconColor: .blue
                ) {
                    VStack(spacing: 16) {
                        // Status Card
                        VStack(spacing: 12) {
                            HStack {
                                Image(systemName: vpnStatistics.connectionState.icon)
                                    .font(.title2)
                                    .foregroundColor(colorForState(vpnStatistics.connectionState))
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(vpnStatistics.connectionState.displayName)
                                        .font(.headline)
                                    
                                    if case .connected = vpnStatistics.connectionState,
                                       let publicIP = vpnStatistics.publicIP {
                                        Text("Public IP: \(publicIP)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Spacer()
                                
                                if case .connected = vpnStatistics.connectionState {
                                    VStack(alignment: .trailing, spacing: 4) {
                                        Text(vpnStatistics.formattedDuration)
                                            .font(.system(.body, design: .monospaced))
                                            .foregroundColor(.secondary)
                                        Text("Connected")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(12)
                            
                            // Quick stats
                            if case .connected = vpnStatistics.connectionState {
                                HStack(spacing: 16) {
                                    StatItem(
                                        icon: "arrow.down.circle.fill",
                                        label: "Download",
                                        value: vpnStatistics.formattedBytesReceived
                                    )
                                    
                                    Divider()
                                        .frame(height: 40)
                                    
                                    StatItem(
                                        icon: "arrow.up.circle.fill",
                                        label: "Upload",
                                        value: vpnStatistics.formattedBytesSent
                                    )
                                    
                                    Divider()
                                        .frame(height: 40)
                                    
                                    StatItem(
                                        icon: "speedometer",
                                        label: "Speed",
                                        value: vpnStatistics.formattedDownloadSpeed
                                    )
                                }
                                .padding()
                                .background(Color.blue.opacity(0.05))
                                .cornerRadius(12)
                            }
                        }
                    }
                }
                
                // Quick Info
                SettingsSection(
                    title: "About",
                    icon: "info.circle",
                    iconColor: .purple
                ) {
                    VStack(alignment: .leading, spacing: 8) {
                        InfoRow(label: "Backend", value: "OpenVPN CLI")
                        InfoRow(label: "Protocol", value: "OpenVPN (UDP)")
                        InfoRow(label: "Encryption", value: "AES-128-CBC")
                        InfoRow(label: "DNS", value: "8.8.8.8, 8.8.4.4")
                    }
                }
            }
            .padding()
        }
        .onAppear {
            checkOpenVPNStatus()
            vpnMonitor.startMonitoring()
        }
        .onDisappear {
            vpnMonitor.stopMonitoring()
        }
        .onReceive(vpnMonitor.statisticsPublisher) { stats in
            vpnStatistics = stats
        }
    }
    
    private func checkOpenVPNStatus() {
        let fileManager = FileManager.default
        let openVPNPaths = [
            "/opt/homebrew/sbin/openvpn",
            "/usr/local/sbin/openvpn"
        ]
        
        for path in openVPNPaths {
            if fileManager.fileExists(atPath: path) {
                isOpenVPNInstalled = true
                
                // Get version
                let task = Process()
                task.launchPath = path
                task.arguments = ["--version"]
                
                let pipe = Pipe()
                task.standardOutput = pipe
                
                do {
                    try task.run()
                    task.waitUntilExit()
                    
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    if let output = String(data: data, encoding: .utf8),
                       let firstLine = output.components(separatedBy: "\n").first,
                       let versionRange = firstLine.range(of: #"\d+\.\d+\.\d+"#, options: .regularExpression) {
                        openVPNVersion = String(firstLine[versionRange])
                    }
                } catch {
                    print("Failed to get OpenVPN version")
                }
                
                return
            }
        }
        
        isOpenVPNInstalled = false
    }
    
    
    private func colorForState(_ state: VPNStatistics.ConnectionState) -> Color {
        switch state {
        case .disconnected: return .gray
        case .connecting: return .orange
        case .connected: return .green
        case .reconnecting: return .blue
        case .error: return .red
        }
    }
}

// MARK: - Helper Views

struct StatItem: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
            
            Text(value)
                .font(.system(.body, design: .monospaced))
                .fontWeight(.semibold)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .foregroundColor(.primary)
        }
    }
}

