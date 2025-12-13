import SwiftUI

// MARK: - Monitoring Tab (Real-time VPN Statistics)

struct MonitoringTab: View {
    @ObservedObject var viewModel: MonitoringViewModel

    private var vpnStatistics: VPNStatistics {
        viewModel.vpnStatistics
    }

    private var connectedSinceString: String? {
        guard let date = vpnStatistics.connectedSince else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                // Connection Status Card
                VStack(alignment: .leading, spacing: 16) {
                    Label("Connection Status", systemImage: "wifi")
                        .font(.headline)
                        .foregroundColor(.primary)

                    VStack(spacing: 16) {
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(colorForState(vpnStatistics.connectionState).opacity(0.2))
                                    .frame(width: 60, height: 60)

                                Image(systemName: vpnStatistics.connectionState.icon)
                                    .font(.title)
                                    .foregroundColor(colorForState(vpnStatistics.connectionState))
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Text(vpnStatistics.connectionState.displayName)
                                    .font(.title3)
                                    .fontWeight(.semibold)

                                if case .connected = vpnStatistics.connectionState {
                                    Text("Duration: \(vpnStatistics.formattedDuration)")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }

                            Spacer()
                        }
                        .padding()
                        .background(Color.gray.opacity(0.05))
                        .cornerRadius(12)

                        if case .connected = vpnStatistics.connectionState {
                            HStack(spacing: 16) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("VPN IP")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(vpnStatistics.vpnIP ?? "N/A")
                                        .font(.system(.body, design: .monospaced))
                                        .fontWeight(.medium)
                                }

                                Divider().frame(height: 40)

                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Public IP")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(vpnStatistics.publicIP ?? "N/A")
                                        .font(.system(.body, design: .monospaced))
                                        .fontWeight(.medium)
                                }
                            }
                            .padding()
                            .background(Color.blue.opacity(0.05))
                            .cornerRadius(12)
                        }
                    }
                }
                .padding()
                .background(Color.white.opacity(0.05))
                .cornerRadius(16)

                // Network Statistics
                if case .connected = vpnStatistics.connectionState {
                    VStack(alignment: .leading, spacing: 16) {
                        Label("Network Statistics", systemImage: "chart.bar.fill")
                            .font(.headline)

                        VStack(spacing: 12) {
                            StatisticRow(
                                icon: "arrow.down.circle.fill",
                                iconColor: .green,
                                label: "Downloaded",
                                value: vpnStatistics.formattedBytesReceived
                            )

                            StatisticRow(
                                icon: "arrow.up.circle.fill",
                                iconColor: .blue,
                                label: "Uploaded",
                                value: vpnStatistics.formattedBytesSent
                            )

                            Divider()

                            StatisticRow(
                                icon: "arrow.down",
                                iconColor: .green,
                                label: "Download Speed",
                                value: vpnStatistics.formattedDownloadSpeed
                            )

                            StatisticRow(
                                icon: "arrow.up",
                                iconColor: .blue,
                                label: "Upload Speed",
                                value: vpnStatistics.formattedUploadSpeed
                            )

                            if let ping = vpnStatistics.ping {
                                Divider()
                                StatisticRow(
                                    icon: "timer",
                                    iconColor: .orange,
                                    label: "Ping",
                                    value: "\(ping) ms"
                                )
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.05))
                        .cornerRadius(12)
                    }
                    .padding()
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(16)

                    // Technical Details
                    VStack(alignment: .leading, spacing: 16) {
                        Label("Technical Details", systemImage: "gearshape.2.fill")
                            .font(.headline)

                        VStack(spacing: 12) {
                            DetailRow(label: "Protocol", value: vpnStatistics.protocolType ?? "UDP")
                            DetailRow(label: "Port", value: vpnStatistics.port.map(String.init) ?? "1194")
                            DetailRow(label: "Cipher", value: vpnStatistics.cipher ?? "AES-128-CBC")

                            if let str = connectedSinceString {
                                DetailRow(label: "Connected Since", value: str)
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.05))
                        .cornerRadius(12)
                    }
                    .padding()
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(16)
                }

                if case .disconnected = vpnStatistics.connectionState {
                    VStack(spacing: 16) {
                        Image(systemName: "wifi.slash")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)

                        Text("Not Connected")
                            .font(.headline)

                        Text("Connect to a VPN server to see real-time statistics")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(40)
                }
            }
            .padding()
        }
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

struct StatisticRow: View {
    let icon: String
    let iconColor: Color
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(iconColor)
                .frame(width: 30)
            
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.system(.body, design: .monospaced))
                .fontWeight(.medium)
        }
    }
}

struct DetailRow: View {
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
                .fontWeight(.medium)
        }
    }
}

