import Combine
import Foundation

// MARK: - Protocol

protocol VPNMonitorProtocol {
  func startMonitoring()
  func stopMonitoring()
  var statsPublisher: AnyPublisher<VPNStats, Never> { get }
}

// MARK: - State Query Result

/// Result from querying OpenVPN management socket state
struct StateQueryResult {
  let state: OpenVPNState?
  let vpnIP: String?
  let remoteIP: String?

  static let empty = StateQueryResult(state: nil, vpnIP: nil, remoteIP: nil)
}

// MARK: - Implementation

final class VPNMonitor: VPNMonitorProtocol {

  private let managementSocketPath: String
  private let fileManager = FileManager.default
  private let networkProtectionService: NetworkProtectionServiceProtocol
  private var monitorTask: Task<Void, Never>?
  private var monitoringRefCount = 0
  private let statsSubject = CurrentValueSubject<VPNStats, Never>(.empty)
  private var wasConnected = false

  /// Callback invoked when connection drops unexpectedly
  var onConnectionDropped: (() -> Void)?

  var statsPublisher: AnyPublisher<VPNStats, Never> {
    statsSubject.eraseToAnyPublisher()
  }

  init(networkProtectionService: NetworkProtectionServiceProtocol) {
    self.networkProtectionService = networkProtectionService
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
    wasConnected = false
    Log.debug("Force stopped")
  }

  // MARK: - Stats Polling

  private func pollStats(previous: VPNStats) async -> VPNStats {
    // Check 1: Socket file exists (process alive)
    guard fileManager.fileExists(atPath: managementSocketPath) else {
      if wasConnected {
        wasConnected = false
        Log.warning("VPN connection dropped (socket missing)")
        onConnectionDropped?()
      }
      return previous
    }

    // Query status and state from management socket
    async let statusResult = queryStatus()
    async let stateResultAsync = queryState()

    guard let status = await statusResult else {
      return previous
    }

    let stateResult = await stateResultAsync
    let newStats = parseStatus(
      status,
      openVPNState: stateResult.state,
      stateVpnIP: stateResult.vpnIP,
      remoteIP: stateResult.remoteIP,
      previous: previous
    )

    // Check 2: State explicitly changed to non-connected state
    // Only trigger if we get a definitive state (not nil from failed query)
    let isNowConnected = newStats.isConnected
    if wasConnected,
      let state = stateResult.state,
      !state.isConnected && !state.isConnecting
    {
      // Explicit state change to RECONNECTING, EXITING, or other non-connected state
      Log.warning("VPN connection dropped (state: \(state.rawValue))")
      onConnectionDropped?()
    }

    // Check 3: Tunnel interface exists (only if state says connected)
    if isNowConnected && !networkProtectionService.isTunnelInterfaceActive() {
      Log.warning("VPN connection dropped (tunnel interface missing)")
      wasConnected = false
      onConnectionDropped?()
      return previous
    }

    // Only update wasConnected if we got a valid state
    if stateResult.state != nil {
      wasConnected = isNowConnected
    }
    return newStats
  }

  private func queryStatus() async -> String? {
    return await sendCommand("status")
  }

  private func queryState() async -> StateQueryResult {
    // Query state via management socket - returns format:
    // timestamp,STATE,description,local_ip,remote_ip
    guard let response = await sendCommand("state") else {
      return .empty
    }

    // Parse state from response (e.g., "1234567890,CONNECTED,SUCCESS,10.8.0.6,198.51.100.1")
    let lines = response.components(separatedBy: "\n")
    for line in lines where !line.hasPrefix(">") && !line.hasPrefix("END") && !line.isEmpty {
      let parts = line.components(separatedBy: ",")
      if parts.count >= 2 {
        let stateString = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
        let state = OpenVPNState(rawValue: stateString)
        let vpnIP =
          parts.count >= 4 ? parts[3].trimmingCharacters(in: .whitespacesAndNewlines) : nil
        let remoteIP =
          parts.count >= 5 ? parts[4].trimmingCharacters(in: .whitespacesAndNewlines) : nil

        // Log state transitions
        Log.debug("OpenVPN state: \(state.rawValue)")

        return StateQueryResult(
          state: state,
          vpnIP: vpnIP.flatMap { $0.isEmpty ? nil : $0 },
          remoteIP: remoteIP.flatMap { $0.isEmpty ? nil : $0 }
        )
      }
    }
    return .empty
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

      var hasResumed = false
      let resumeLock = NSLock()

      // Non-blocking: use terminationHandler instead of waitUntilExit
      task.terminationHandler = { _ in
        resumeLock.lock()
        guard !hasResumed else {
          resumeLock.unlock()
          return
        }
        hasResumed = true
        resumeLock.unlock()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)
        continuation.resume(returning: output)
      }

      do {
        try task.run()

        // Timeout after 5 seconds to prevent hangs
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
        continuation.resume(returning: nil)
      }
    }
  }

  private func parseStatus(
    _ status: String,
    openVPNState: OpenVPNState?,
    stateVpnIP: String?,
    remoteIP: String?,
    previous: VPNStats
  ) -> VPNStats {
    var bytesReceived: Int64 = 0
    var bytesSent: Int64 = 0
    var vpnIP: String? = stateVpnIP ?? previous.vpnIP
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
      remoteIP: remoteIP ?? previous.remoteIP,
      connectedSince: connectedSince,
      openVPNState: openVPNState
    )
  }

  /// Enable state notifications from OpenVPN
  func enableStateNotifications() async {
    _ = await sendCommand("state on")
    Log.debug("State notifications enabled")
  }

  /// Disable state notifications
  func disableStateNotifications() async {
    _ = await sendCommand("state off")
    Log.debug("State notifications disabled")
  }
}

// MARK: - Management Socket

extension VPNMonitor {
  func sendManagementCommand(_ command: String) async -> Bool {
    guard fileManager.fileExists(atPath: managementSocketPath) else {
      return false
    }

    return await withCheckedContinuation { continuation in
      let process = Process()
      process.launchPath = "/bin/sh"
      process.arguments = [
        "-c", ShellCommands.managementCommand(command, socketPath: self.managementSocketPath),
      ]

      var hasResumed = false
      let resumeLock = NSLock()

      process.terminationHandler = { proc in
        resumeLock.lock()
        guard !hasResumed else {
          resumeLock.unlock()
          return
        }
        hasResumed = true
        resumeLock.unlock()

        continuation.resume(returning: proc.terminationStatus == 0)
      }

      do {
        try process.run()

        // Timeout after 5 seconds
        DispatchQueue.global().asyncAfter(deadline: .now() + 5) {
          resumeLock.lock()
          guard !hasResumed else {
            resumeLock.unlock()
            return
          }
          hasResumed = true
          resumeLock.unlock()

          if process.isRunning {
            process.terminate()
          }
          continuation.resume(returning: false)
        }
      } catch {
        resumeLock.lock()
        guard !hasResumed else {
          resumeLock.unlock()
          return
        }
        hasResumed = true
        resumeLock.unlock()
        continuation.resume(returning: false)
      }
    }
  }
}
