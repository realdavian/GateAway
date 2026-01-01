import SwiftUI

// MARK: - Permission Guide View

struct PermissionGuideView: View {
    var onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Image(systemName: "hand.raised.fill")
                    .font(.largeTitle)
                    .foregroundColor(.orange)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Permission Required")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Allow GateAway to control Tunnelblick")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Divider()
            
            // Instructions
            VStack(alignment: .leading, spacing: 16) {
                InstructionStep(
                    number: 1,
                    title: "Open System Settings",
                    description: "Click the button below to open System Settings"
                )
                
                InstructionStep(
                    number: 2,
                    title: "Navigate to Privacy & Security",
                    description: "Find and click 'Automation' in the Privacy & Security section"
                )
                
                InstructionStep(
                    number: 3,
                    title: "Enable GateAway",
                    description: "Find 'GateAway' in the list and check the box next to 'Tunnelblick'"
                )
                
                InstructionStep(
                    number: 4,
                    title: "Try Connecting Again",
                    description: "Close this window and try connecting to a VPN server"
                )
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
            
            Spacer()
            
            // Actions
            HStack(spacing: 12) {
                Button("Cancel") {
                    onDismiss()
                }
                .keyboardShortcut(.escape)
                
                Button("Open System Settings") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
                        NSWorkspace.shared.open(url)
                    }
                    onDismiss()
                }
                .keyboardShortcut(.return)
                .buttonStyle(.bordered)
                .accentColor(.accentColor)
            }
        }
        .padding()
        .frame(width: 500, height: 450)
    }
}

struct InstructionStep: View {
    let number: Int
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Step number badge
            ZStack {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 32, height: 32)
                
                Text("\(number)")
                    .font(.system(.body, design: .rounded).weight(.bold))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

