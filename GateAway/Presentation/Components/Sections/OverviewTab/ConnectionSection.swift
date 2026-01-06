import SwiftUI

// MARK: - Overview Tab: Connection Section

/// Real-time VPN connection status section with stats and action buttons
struct OverviewTabConnectionSection: View {
  @EnvironmentObject var coordinatorWrapper: CoordinatorWrapper
  @EnvironmentObject var monitoringStore: MonitoringStore
  @EnvironmentObject var telemetry: ConnectionTelemetry

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

  var body: some View {
    SettingsSection(
      title: "Connection Status".localized,
      icon: "network",
      iconColor: .blue
    ) {
      VStack(spacing: 16) {
        // Status Card
        VStack(spacing: 12) {
          HStack {
            Image(systemName: connectionState.icon)
              .font(.title2)
              .foregroundColor(colorForState(connectionState))

            VStack(alignment: .leading, spacing: 4) {
              Text(connectionState.displayName)
                .font(.headline)

              if case .connected = connectionState {
                let countryShort = serverInfo.countryShort ?? ""

                if let country = serverInfo.country {
                  Text("\(flagEmoji(for: countryShort)) \(country)")
                    .font(.subheadline)
                }
              } else if case .connecting = connectionState {
                Text("Establishing tunnel...".localized)
                  .font(.caption)
                  .foregroundColor(.secondary)
              } else if case .reconnecting = connectionState {
                Text("Reconnecting...".localized)
                  .font(.caption)
                  .foregroundColor(.secondary)
              }
            }

            Spacer()

            if case .connected = connectionState {
              VStack(alignment: .trailing, spacing: 4) {
                Text(formattedDuration)
                  .font(.system(.body, design: .monospaced))
                  .foregroundColor(.green)
                Text("Connected".localized)
                  .font(.caption2)
                  .foregroundColor(.secondary)
              }
            }
          }
          .padding()
          .background(Color.gray.opacity(0.1))
          .cornerRadius(12)

          // Connection Statistics
          if let telemetryStats = telemetry.getOverallStats() {
            ConnectionStatisticsView(telemetry: telemetryStats)
          }

          // Dynamic connection button
          ConnectionActionButton(
            connectionState: connectionState,
            isDisconnecting: isDisconnecting,
            onCancelConnection: handleCancelConnection,
            onDisconnect: handleDisconnect
          )

          // Quick stats when connected
          if case .connected = connectionState {
            QuickStatsView(stats: stats)
          }
        }
      }
    }
  }

  private var formattedDuration: String {
    guard let since = stats.connectedSince else { return "--:--:--" }
    let elapsed = Date().timeIntervalSince(since)
    let hours = Int(elapsed) / 3600
    let minutes = (Int(elapsed) % 3600) / 60
    let seconds = Int(elapsed) % 60
    return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
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

// MARK: - Connection Statistics View

private struct ConnectionStatisticsView: View {
  let telemetry: (totalAttempts: Int, successCount: Int, avgConnectionTime: TimeInterval)

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Connection Statistics".localized)
        .font(.headline)

      HStack {
        VStack(alignment: .leading, spacing: 4) {
          Text("Success Rate".localized)
            .font(.caption)
            .foregroundColor(.secondary)
          Text("\(Int(Double(telemetry.successCount) / Double(telemetry.totalAttempts) * 100))%")
            .font(.title2)
            .fontWeight(.bold)
            .foregroundColor(.green)
        }

        Spacer()

        VStack(alignment: .trailing, spacing: 4) {
          Text("Avg Connection Time".localized)
            .font(.caption)
            .foregroundColor(.secondary)
          Text(ConnectionTelemetry.formatTime(telemetry.avgConnectionTime))
            .font(.title2)
            .fontWeight(.bold)
            .foregroundColor(.blue)
        }
      }

      HStack {
        Text("Total Attempts: %d".localized(with: telemetry.totalAttempts))
          .font(.caption)
          .foregroundColor(.secondary)
        Spacer()
        Text("%d successful".localized(with: telemetry.successCount))
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
  let stats: VPNStats

  var body: some View {
    HStack(spacing: 16) {
      StatItem(
        icon: "arrow.down.circle.fill",
        label: "Download".localized,
        value: stats.formattedBytesReceived
      )

      Divider()
        .frame(height: 40)

      StatItem(
        icon: "arrow.up.circle.fill",
        label: "Upload".localized,
        value: stats.formattedBytesSent
      )

      Divider()
        .frame(height: 40)

      StatItem(
        icon: "speedometer",
        label: "Speed".localized,
        value: stats.formattedDownloadSpeed
      )
    }
    .padding()
    .background(Color.blue.opacity(0.05))
    .cornerRadius(12)
  }
}
