import Combine
import Foundation

// MARK: - Protocol

protocol VPNMonitorProtocol {
  func startMonitoring()
  func stopMonitoring()
  var statsPublisher: AnyPublisher<VPNStats, Never> { get }
}

// MARK: - Implementation

final class VPNMonitor: VPNMonitorProtocol {

  private let managementSocketPath: String
  private let fileManager = FileManager.default
  private var monitorTask: Task<Void, Never>?
  private var monitoringRefCount = 0
  private let statsSubject = CurrentValueSubject<VPNStats, Never>(.empty)

  var statsPublisher: AnyPublisher<VPNStats, Never> {
    statsSubject.eraseToAnyPublisher()
  }

  init() {
    let homeDir = fileManager.homeDirectoryForCurrentUser
    let configDir = homeDir.appendingPathComponent(Constants.Paths.configDirectory)
    self.managementSocketPath =
      configDir.appendingPathComponent(Constants.Paths.managementSocket).path
    Log.debug("Monitoring socket at: \(managementSocketPath)")
  }

  // MARK: - Monitoring Lifecycle

  func startMonitoring() {
    monitoringRefCount += 1
    Log.debug("Starting monitoring (ref count: \(monitoringRefCount))")

    guard monitorTask == nil else { return }

    monitorTask = Task { [weak self] in
      guard let self else { return }

      var previousStats = VPNStats.empty

      while !Task.isCancelled {
        let newStats = await self.pollStats(previous: previousStats)
        self.statsSubject.send(newStats)
        previousStats = newStats

        do {
          try await Task.sleep(nanoseconds: 1_000_000_000)
        } catch {
          break
        }
      }

      Log.debug("Monitoring task stopped")
    }
  }

  func stopMonitoring() {
    monitoringRefCount = max(0, monitoringRefCount - 1)

    guard monitoringRefCount == 0 else { return }

    Log.debug("Stopping monitoring (no more observers)")
    monitorTask?.cancel()
    monitorTask = nil
    statsSubject.send(.empty)
  }

  func forceStop() {
    monitoringRefCount = 0
    monitorTask?.cancel()
    monitorTask = nil
    statsSubject.send(.empty)
    Log.debug("Force stopped")
  }

  // MARK: - Stats Polling

  private func pollStats(previous: VPNStats) async -> VPNStats {
    guard fileManager.fileExists(atPath: managementSocketPath) else {
      return previous
    }

    guard let status = await queryStatus() else {
      return previous
    }

    return parseStatus(status, previous: previous)
  }

  private func queryStatus() async -> String? {
    return await sendCommand("status")
  }

  private func sendCommand(_ command: String) async -> String? {
    return await withCheckedContinuation { continuation in
      let task = Process()
      task.launchPath = "/bin/sh"
      task.arguments = [
        "-c", ShellCommands.managementCommand(command, socketPath: managementSocketPath),
      ]

      let pipe = Pipe()
      task.standardOutput = pipe
      task.standardError = Pipe()

      do {
        try task.run()
        task.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)
        continuation.resume(returning: output)
      } catch {
        continuation.resume(returning: nil)
      }
    }
  }

  private func parseStatus(_ status: String, previous: VPNStats) -> VPNStats {
    var bytesReceived: Int64 = 0
    var bytesSent: Int64 = 0
    var vpnIP: String? = previous.vpnIP
    var connectedSince: Date? = previous.connectedSince

    let lines = status.components(separatedBy: "\n")
    for line in lines {
      let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

      if trimmed.contains("TCP/UDP read bytes") {
        if let commaIndex = trimmed.firstIndex(of: ",") {
          let numberPart = trimmed[trimmed.index(after: commaIndex)...].trimmingCharacters(
            in: .whitespacesAndNewlines)
          if let bytes = Int64(numberPart) {
            bytesReceived = bytes
          }
        }
      }

      if trimmed.contains("TCP/UDP write bytes") {
        if let commaIndex = trimmed.firstIndex(of: ",") {
          let numberPart = trimmed[trimmed.index(after: commaIndex)...].trimmingCharacters(
            in: .whitespacesAndNewlines)
          if let bytes = Int64(numberPart) {
            bytesSent = bytes
          }
        }
      }
    }

    let downloadSpeed =
      bytesReceived > previous.bytesReceived ? Double(bytesReceived - previous.bytesReceived) : 0.0
    let uploadSpeed = bytesSent > previous.bytesSent ? Double(bytesSent - previous.bytesSent) : 0.0

    return VPNStats(
      bytesReceived: bytesReceived,
      bytesSent: bytesSent,
      downloadSpeed: downloadSpeed,
      uploadSpeed: uploadSpeed,
      vpnIP: vpnIP,
      connectedSince: connectedSince
    )
  }
}

// MARK: - Management Socket

extension VPNMonitor {
  func sendManagementCommand(_ command: String) -> Bool {
    guard fileManager.fileExists(atPath: managementSocketPath) else {
      return false
    }

    let process = Process()
    process.launchPath = "/bin/sh"
    process.arguments = [
      "-c", ShellCommands.managementCommand(command, socketPath: managementSocketPath),
    ]

    do {
      try process.run()
      process.waitUntilExit()
      return process.terminationStatus == 0
    } catch {
      return false
    }
  }
}
