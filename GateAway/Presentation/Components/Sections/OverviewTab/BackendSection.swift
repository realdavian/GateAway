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
      title: "VPN Backend".localized,
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
            Text("OpenVPN CLI".localized)
              .font(.system(size: 15, weight: .semibold))

            if isOpenVPNInstalled {
              Text("Installed • Version %@".localized(with: openVPNVersion))
                .font(.caption)
                .foregroundColor(.secondary)
            } else {
              Text("Not Installed".localized)
                .font(.caption)
                .foregroundColor(.orange)
            }
          }

          Spacer()

          if !isOpenVPNInstalled && !showingInstaller {
            Button("Install".localized) {
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

            Text("Requires Homebrew package manager".localized)
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
        title: Text("Install Homebrew?".localized),
        message: Text(
          "OpenVPN requires Homebrew package manager. Would you like to install both Homebrew and OpenVPN?"
            .localized),
        primaryButton: .default(Text("Install Both".localized)) {
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
    Task {
      await checkOpenVPNStatus()
    }
  }

  private func checkHomebrewStatus() {
    isHomebrewInstalled = Constants.Paths.brewBinaryPaths.contains {
      FileManager.default.fileExists(atPath: $0)
    }
  }

  private func checkOpenVPNStatus() async {
    let fileManager = FileManager.default

    for path in Constants.Paths.openVPNBinaryPaths {
      if fileManager.fileExists(atPath: path) {
        isOpenVPNInstalled = true

        let version = await getOpenVPNVersion(at: path)
        if let version = version {
          openVPNVersion = version
        }
        return
      }
    }

    isOpenVPNInstalled = false
  }

  private func getOpenVPNVersion(at path: String) async -> String? {
    await withCheckedContinuation { continuation in
      let task = Process()
      task.launchPath = path
      task.arguments = ["--version"]

      let pipe = Pipe()
      task.standardOutput = pipe

      var hasResumed = false
      let resumeLock = NSLock()

      task.terminationHandler = { _ in
        resumeLock.lock()
        guard !hasResumed else {
          resumeLock.unlock()
          return
        }
        hasResumed = true
        resumeLock.unlock()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        var version: String?
        if let output = String(data: data, encoding: .utf8),
          let firstLine = output.components(separatedBy: "\n").first,
          let versionRange = firstLine.range(of: #"\d+\.\d+\.\d+"#, options: .regularExpression)
        {
          version = String(firstLine[versionRange])
        }
        continuation.resume(returning: version)
      }

      do {
        try task.run()

        // Timeout after 5 seconds
        DispatchQueue.global().asyncAfter(deadline: .now() + 5) {
          resumeLock.lock()
          guard !hasResumed else {
            resumeLock.unlock()
            return
          }
          hasResumed = true
          resumeLock.unlock()

          if task.isRunning {
            task.terminate()
          }
          continuation.resume(returning: nil)
        }
      } catch {
        resumeLock.lock()
        guard !hasResumed else {
          resumeLock.unlock()
          return
        }
        hasResumed = true
        resumeLock.unlock()
        Log.warning("Failed to get OpenVPN version")
        continuation.resume(returning: nil)
      }
    }
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
