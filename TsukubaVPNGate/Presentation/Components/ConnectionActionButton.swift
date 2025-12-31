import SwiftUI

// MARK: - Connection Action Button

/// Reusable connection action button that displays appropriate action based on VPN state
/// Used in OverviewTab, MonitoringTab, and potentially other views
struct ConnectionActionButton: View {
    let connectionState: ConnectionState
    let isDisconnecting: Bool
    let onCancelConnection: () -> Void
    let onDisconnect: () -> Void
    
    var body: some View {
        switch connectionState {
        case .connecting, .reconnecting:
            Button(action: onCancelConnection) {
                HStack {
                    Image(systemName: "stop.circle.fill")
                    Text(connectionState == .reconnecting ? "Stop Reconnecting" : "Stop Connecting")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.red)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            
        case .connected:
            Button(action: onDisconnect) {
                HStack {
                    Image(systemName: "xmark.circle.fill")
                    Text(isDisconnecting ? "Disconnecting..." : "Disconnect")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.red)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .disabled(isDisconnecting)
            
        default:
            EmptyView()
        }
    }
}
