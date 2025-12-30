import SwiftUI

// MARK: - Overview Tab: Connection Section

/// Real-time VPN connection status section with stats and action buttons
struct OverviewTabConnectionSection: View {
    @EnvironmentObject var coordinatorWrapper: CoordinatorWrapper
    @EnvironmentObject var monitoringStore: MonitoringStore
    
    @State private var isDisconnecting: Bool = false
    
    private var vpnStatistics: VPNStatistics {
        monitoringStore.vpnStatistics
    }
    
    var body: some View {
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
                            .foregroundColor(vpnStatistics.connectionState.color)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(vpnStatistics.connectionState.displayName)
                                .font(.headline)
                            
                            if case .connected = vpnStatistics.connectionState {
                                let countryShort = vpnStatistics.connectedCountryShort ?? ""
                                    
                                if let country = vpnStatistics.connectedCountry {
                                    Text("\(flagEmoji(for: countryShort)) \(country)")
                                        .font(.subheadline)
                                }
                            } else if case .connecting = vpnStatistics.connectionState {
                                Text("Establishing tunnel...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else if case .reconnecting = vpnStatistics.connectionState {
                                Text("Reconnecting...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        if case .connected = vpnStatistics.connectionState {
                            VStack(alignment: .trailing, spacing: 4) {
                                Text(vpnStatistics.formattedDuration)
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundColor(.green)
                                Text("Connected")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                    
                    // Connection Statistics
                    if let telemetry = ConnectionTelemetry.shared.getOverallStats() {
                        ConnectionStatisticsView(telemetry: telemetry)
                    }
                    
                    // Dynamic connection button
                    ConnectionActionButton(
                        connectionState: vpnStatistics.connectionState,
                        isDisconnecting: isDisconnecting,
                        onCancelConnection: handleCancelConnection,
                        onDisconnect: handleDisconnect
                    )
                    
                    // Quick stats when connected
                    if case .connected = vpnStatistics.connectionState {
                        QuickStatsView(vpnStatistics: vpnStatistics)
                    }
                }
            }
        }
    }
    
    private func handleDisconnect() {
        isDisconnecting = true
        
        coordinatorWrapper.disconnect { result in
            DispatchQueue.main.async {
                isDisconnecting = false
                
                switch result {
                case .success:
                    print("✅ Disconnected successfully")
                case .failure(let error):
                    print("❌ Disconnect failed: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func handleCancelConnection() {
        Task {
            await coordinatorWrapper.cancelConnection()
        }
    }
}

// MARK: - Connection Statistics View

private struct ConnectionStatisticsView: View {
    let telemetry: (totalAttempts: Int, successCount: Int, avgConnectionTime: TimeInterval)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Connection Statistics")
                .font(.headline)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Success Rate")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(Int(Double(telemetry.successCount) / Double(telemetry.totalAttempts) * 100))%")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Avg Connection Time")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(ConnectionTelemetry.formatTime(telemetry.avgConnectionTime))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }
            }
            
            HStack {
                Text("Total Attempts: \(telemetry.totalAttempts)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(telemetry.successCount) successful")
                    .font(.caption)
                    .foregroundColor(.green)
            }
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(12)
    }
}

// MARK: - Quick Stats View

private struct QuickStatsView: View {
    let vpnStatistics: VPNStatistics
    
    var body: some View {
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
