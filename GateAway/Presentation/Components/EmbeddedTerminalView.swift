import Combine
import SwiftUI

/// Embedded terminal view for running shell commands with live output
struct EmbeddedTerminalView: View {
  let command: String
  let onComplete: (Bool) -> Void

  @State private var output: String = ""
  @State private var isRunning: Bool = false
  @State private var exitCode: Int32?
  @State private var process: Process?

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      // Header
      HStack {
        Image(systemName: "terminal.fill")
          .foregroundColor(.green)
        Text("Terminal")
          .font(.caption.bold())

        Spacer()

        if isRunning {
          ProgressView()
            .scaleEffect(0.6)
            .frame(width: 16, height: 16)
          Text("Running...")
            .font(.caption2)
            .foregroundColor(.secondary)
        } else if let code = exitCode {
          Image(systemName: code == 0 ? "checkmark.circle.fill" : "xmark.circle.fill")
            .foregroundColor(code == 0 ? .green : .red)
          Text(code == 0 ? "Complete" : "Failed")
            .font(.caption2)
            .foregroundColor(code == 0 ? .green : .red)
        }
      }

      // Terminal output
      ScrollViewReader { proxy in
        ScrollView {
          Text(output.isEmpty ? "$ \(command)\n" : output)
            .font(.system(size: 11, design: .monospaced))
            .foregroundColor(.green)
            .frame(maxWidth: .infinity, alignment: .leading)
            .id("bottom")
        }
        .onChange(of: output) { _ in
          withAnimation {
            proxy.scrollTo("bottom", anchor: .bottom)
          }
        }
      }
      .frame(height: 150)
      .padding(8)
      .background(Color.black)
      .cornerRadius(6)

      // Action buttons
      HStack {
        if !isRunning && exitCode == nil {
          Button("Run") {
            runCommand()
          }
        }

        if isRunning {
          Button("Cancel") {
            cancelCommand()
          }
        }

        if exitCode != nil {
          Button("Close") {
            onComplete(exitCode == 0)
          }
        }
      }
    }
    .padding()
    .background(Color.gray.opacity(0.1))
    .cornerRadius(12)
    .onAppear {
      runCommand()
    }
  }

  private func runCommand() {
    isRunning = true
    output = "$ \(command)\n"
    exitCode = nil

    Task.detached {
      let process = Process()
      process.launchPath = "/bin/zsh"
      // Source shell profile to get Homebrew PATH, then run command
      process.arguments = ["-l", "-c", command]

      let pipe = Pipe()
      process.standardOutput = pipe
      process.standardError = pipe

      await MainActor.run {
        self.process = process
      }

      pipe.fileHandleForReading.readabilityHandler = { handle in
        let data = handle.availableData
        if let str = String(data: data, encoding: .utf8), !str.isEmpty {
          Task { @MainActor in
            self.output += str
          }
        }
      }

      // Use async continuation with terminationHandler instead of waitUntilExit
      let code: Int32 = await withCheckedContinuation { continuation in
        process.terminationHandler = { proc in
          continuation.resume(returning: proc.terminationStatus)
        }

        do {
          try process.run()
        } catch {
          continuation.resume(returning: -1)
        }
      }

      await MainActor.run {
        self.exitCode = code
        self.isRunning = false
        if code == 0 {
          self.output += "\n[Process completed successfully]\n"
        } else {
          self.output += "\n[Process exited with code \(code)]\n"
        }
      }
    }
  }

  private func cancelCommand() {
    process?.terminate()
    isRunning = false
    output += "\n[Cancelled by user]\n"
    exitCode = -1
  }
}
