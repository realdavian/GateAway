import SwiftUI

// MARK: - Monitoring Tab (Real-time VPN Statistics)

struct MonitoringTab: View {
  @EnvironmentObject var coordinatorWrapper: CoordinatorWrapper
  @EnvironmentObject var monitoringStore: MonitoringStore

  @State private var isDisconnecting: Bool = false

  private var connectionState: ConnectionState {
    monitoringStore.connectionState
  }

  private var stats: VPNStats {
    monitoringStore.stats
  }

  private var serverInfo: VPNServerInfo {
    monitoringStore.serverInfo
  }

  private var connectedSinceString: String? {
    guard let date = stats.connectedSince else { return nil }
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
          Label("Connection Status".localized, systemImage: "wifi")
            .font(.headline)
            .foregroundColor(.primary)

          VStack(spacing: 16) {
            // Single row with status, country, IPs
            HStack(spacing: 12) {
              // Status indicator
              ZStack {
                Circle()
                  .fill(colorForState(connectionState).opacity(0.2))
                  .frame(width: 40, height: 40)

                Image(systemName: connectionState.icon)
                  .foregroundColor(colorForState(connectionState))
              }

              VStack(alignment: .leading, spacing: 4) {
                Text(connectionState.displayName)
                  .font(.headline)

                let countryShort = serverInfo.countryShort ?? ""
                if let country = serverInfo.country {
                  Text("\(flagEmoji(for: countryShort)) \(country)")
                    .font(.subheadline)
                }
              }

              Spacer()

              // VPN IP
              if case .connected = connectionState {
                VStack(alignment: .trailing, spacing: 4) {
                  if let vpnIP = stats.vpnIP {
                    HStack(spacing: 4) {
                      Text("VPN:".localized)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                      Text(vpnIP)
                        .font(.caption)
                        .fontWeight(.medium)
                    }
                  }
                }
              }
            }
            .padding()
            .background(Color.gray.opacity(0.05))
            .cornerRadius(12)

            // Dynamic connection button
            ConnectionActionButton(
              connectionState: connectionState,
              isDisconnecting: isDisconnecting,
              onCancelConnection: handleCancelConnection,
              onDisconnect: handleDisconnect
            )
          }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)

        // Network Statistics
        if case .connected = connectionState {
          VStack(alignment: .leading, spacing: 16) {
            Label("Network Statistics".localized, systemImage: "chart.bar.fill")
              .font(.headline)

            VStack(spacing: 12) {
              StatisticRow(
                icon: "arrow.down.circle.fill",
                iconColor: .green,
                label: "Downloaded".localized,
                value: stats.formattedBytesReceived
              )

              StatisticRow(
                icon: "arrow.up.circle.fill",
                iconColor: .blue,
                label: "Uploaded".localized,
                value: stats.formattedBytesSent
              )

              Divider()

              StatisticRow(
                icon: "arrow.down",
                iconColor: .green,
                label: "Download Speed".localized,
                value: stats.formattedDownloadSpeed
              )

              StatisticRow(
                icon: "arrow.up",
                iconColor: .blue,
                label: "Upload Speed".localized,
                value: stats.formattedUploadSpeed
              )
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
            Label("Technical Details".localized, systemImage: "gearshape.2.fill")
              .font(.headline)

            VStack(spacing: 12) {
              DetailRow(label: "Protocol".localized, value: serverInfo.protocolType ?? "OpenVPN")
              DetailRow(label: "Port".localized, value: serverInfo.port.map(String.init) ?? "1194")
              DetailRow(label: "Cipher".localized, value: serverInfo.cipher ?? "AES-128-CBC")

              if let str = connectedSinceString {
                DetailRow(label: "Connected Since".localized, value: str)
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

        if case .disconnected = connectionState {
          VStack(spacing: 16) {
            Image(systemName: "wifi.slash")
              .font(.system(size: 48))
              .foregroundColor(.secondary)

            Text("Not Connected".localized)
              .font(.headline)

            Text("Connect to a VPN server to see real-time statistics".localized)
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

  private func handleDisconnect() {
    isDisconnecting = true

    coordinatorWrapper.disconnect { result in
      DispatchQueue.main.async {
        isDisconnecting = false

        switch result {
        case .success:
          Log.success("Disconnected successfully")
        case .failure(let error):
          Log.error("Disconnect failed: \(error.localizedDescription)")
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
