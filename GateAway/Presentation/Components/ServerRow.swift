import SwiftUI

// MARK: - Server Row

/// A row displaying server information in the servers list
/// Supports connect/disconnect/stop actions based on connection state
struct ServerRow: View {
    let server: VPNServer
    let isBlacklisted: Bool
    let isConnected: Bool
    let connectionState: ConnectionState
    let connectedServerName: String?
    let onConnect: () -> Void
    let onDisconnect: () -> Void
    let onCancelConnection: () -> Void
    let onBlacklist: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Flag emoji
            Text(flagEmoji(for: server.countryShort))
                .font(.title2)
                .frame(width: 40)
            
            // Country
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(server.countryLong)
                        .font(.system(size: 13, weight: isConnected ? .bold : .medium))
                    
                    if isConnected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
                Text(server.ip)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .frame(width: 140, alignment: .leading)
            
            // Ping
            if let ping = server.pingMS {
                VStack(spacing: 2) {
                    Text("\(ping)")
                        .font(.system(size: 13, design: .monospaced))
                    Text("ms")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(width: 60)
            } else {
                Text("-")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .frame(width: 60)
            }
            
            // Speed
            if let speed = server.speedBps {
                VStack(spacing: 2) {
                    Text(formatSpeed(speed))
                        .font(.system(size: 13, design: .monospaced))
                    Text("Mbps")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(width: 80)
            } else {
                Text("-")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .frame(width: 80)
            }
            
            // Score
            HStack(spacing: 4) {
                Image(systemName: "star.fill")
                    .font(.caption)
                    .foregroundColor(.yellow)
                Text("\(server.score)")
                    .font(.system(size: 12, design: .monospaced))
            }
            .frame(width: 120)
            
            Spacer()
            
            // Blacklist indicator
            if isBlacklisted {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
                    .help("Blacklisted")
            }
            
            // Actions
            HStack(spacing: 8) {
                // Dynamic connection button
                if isConnected {
                    Button(action: {
                    Log.debug("Disconnect button tapped for \(server.countryLong)")
                    onDisconnect()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark.circle.fill")
                            Text("Disconnect")
                        }
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                } else if (connectionState == .connecting || connectionState == .reconnecting),
                          let connectingServerName = connectedServerName,
                          server.hostName == connectingServerName {
                    // Show Stop button ONLY for the server being connected to
                    Button(action: {
                    Log.debug("Stop button tapped for \(server.countryLong)")
                    onCancelConnection()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "stop.circle.fill")
                            Text("Stop")
                        }
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                } else {
                    // Show Connect for disconnected servers
                    Button(action: {
                    Log.debug("Connect button tapped for \(server.countryLong)")
                    onConnect()
                    }) {
                        Text("Connect")
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .disabled(isBlacklisted)
                    .opacity(isBlacklisted ? 0.5 : 1.0)
                }
                
                Button(action: onBlacklist) {
                    Image(systemName: "hand.raised.slash.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.white)
                        .padding(6)
                        .background(Color.orange)
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .help("Add to Blacklist")
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(isBlacklisted ? Color.red.opacity(0.05) : Color.clear)
    }
}
