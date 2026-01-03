import SwiftUI

// MARK: - Overview Tab: Backend Section

/// VPN backend status section showing OpenVPN installation status
struct OverviewTabBackendSection: View {
  @State private var isOpenVPNInstalled: Bool = false
  @State private var isHomebrewInstalled: Bool = false
  @State private var openVPNVersion: String = ""
  @State private var showingInstaller: Bool = false
  @State private var showingHomebrewConfirm: Bool = false
  @State private var installCommand: String = ""

  var body: some View {
    SettingsSection(
      title: "VPN Backend",
      icon: "terminal.fill",
      iconColor: .green
    ) {
      VStack(alignment: .leading, spacing: 12) {
        // OpenVPN status row
        HStack(spacing: 12) {
          ZStack {
            Circle()
              .fill(isOpenVPNInstalled ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
              .frame(width: 40, height: 40)

            Image(
              systemName: isOpenVPNInstalled
                ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
            )
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

          if !isOpenVPNInstalled && !showingInstaller {
            Button("Install") {
              startInstallation()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.accentColor)
            .foregroundColor(.white)
            .cornerRadius(8)
            .buttonStyle(.plain)
          }
        }

        // Homebrew info (if not installed)
        if !isHomebrewInstalled && !isOpenVPNInstalled && !showingInstaller {
          HStack(spacing: 8) {
            Image(systemName: "info.circle.fill")
              .foregroundColor(.blue)

            Text("Requires Homebrew package manager")
              .font(.caption)
              .foregroundColor(.secondary)
          }
          .padding(10)
          .background(Color.blue.opacity(0.1))
          .cornerRadius(8)
        }

        // Embedded terminal for installation
        if showingInstaller {
          EmbeddedTerminalView(
            command: installCommand,
            onComplete: { success in
              showingInstaller = false
              if success {
                checkDependencies()
              }
            }
          )
        }
      }
    }
    .onAppear {
      checkDependencies()
    }
    .alert(isPresented: $showingHomebrewConfirm) {
      Alert(
        title: Text("Install Homebrew?"),
        message: Text(
          "OpenVPN requires Homebrew package manager. Would you like to install both Homebrew and OpenVPN?"
        ),
        primaryButton: .default(Text("Install Both")) {
          installCommand = """
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" && \\
            eval "$(/opt/homebrew/bin/brew shellenv)" && \\
            brew install openvpn
            """
          showingInstaller = true
        },
        secondaryButton: .cancel()
      )
    }
  }

  private func checkDependencies() {
    checkHomebrewStatus()
    checkOpenVPNStatus()
  }

  private func checkHomebrewStatus() {
    isHomebrewInstalled = Constants.Paths.brewBinaryPaths.contains {
      FileManager.default.fileExists(atPath: $0)
    }
  }

  private func checkOpenVPNStatus() {
    let fileManager = FileManager.default

    for path in Constants.Paths.openVPNBinaryPaths {
      if fileManager.fileExists(atPath: path) {
        isOpenVPNInstalled = true

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
            let versionRange = firstLine.range(of: #"\d+\.\d+\.\d+"#, options: .regularExpression)
          {
            openVPNVersion = String(firstLine[versionRange])
          }
        } catch {
          Log.warning("Failed to get OpenVPN version")
        }

        return
      }
    }

    isOpenVPNInstalled = false
  }

  private func startInstallation() {
    if isHomebrewInstalled {
      // Homebrew exists, just install OpenVPN
      installCommand = ShellCommands.brewInstallOpenVPN
      showingInstaller = true
    } else {
      // Ask user if they want to install Homebrew
      showingHomebrewConfirm = true
    }
  }
}
