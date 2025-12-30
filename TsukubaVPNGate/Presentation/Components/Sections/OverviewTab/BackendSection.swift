import SwiftUI

// MARK: - Overview Tab: Backend Section

/// VPN backend status section showing OpenVPN installation status
struct OverviewTabBackendSection: View {
    @State private var isOpenVPNInstalled: Bool = false
    @State private var openVPNVersion: String = ""
    
    var body: some View {
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
        .onAppear {
            checkOpenVPNStatus()
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
}
