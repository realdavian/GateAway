import Foundation

// MARK: - Protocol

/// Manages VPN connection lifecycle and state
protocol VPNConnectionManagerProtocol {
  /// Current connection state
  var currentState: ConnectionState { get }

  /// Connects to a VPN server with optional retry logic
  /// - Parameters:
  ///   - server: The VPN server to connect to
  ///   - enableRetry: Whether to retry on transient failures
  func connect(to server: VPNServer, enableRetry: Bool) async throws

  /// Disconnects from the current VPN server
  func disconnect() async throws

  /// Cancels an in-progress connection attempt
  func cancelConnection() async
}

// MARK: - Implementation

/// Manages VPN connection lifecycle and coordinates between controller, monitor, and UI state
final class VPNConnectionManager: VPNConnectionManagerProtocol {
  private let controller: VPNControlling
  private let telemetry: TelemetryProtocol
  private let monitoringStore: MonitoringStore
  private let vpnMonitor: VPNMonitor
  private var connectionTask: Task<Void, Error>?
  private var currentServer: VPNServer?

  var currentState: ConnectionState {
    monitoringStore.connectionState
  }

  /// Callback invoked when connection state changes
  var onStateChange: ((ConnectionState) -> Void)?

  init(
    controller: VPNControlling,
    backend: UserPreferences.VPNProvider = .openVPN,
    telemetry: TelemetryProtocol,
    monitoringStore: MonitoringStore,
    vpnMonitor: VPNMonitor
  ) {
    self.controller = controller
    self.telemetry = telemetry
    self.monitoringStore = monitoringStore
    self.vpnMonitor = vpnMonitor
    Log.info("Initialized with \(backend.displayName) backend")
  }

  func connect(to server: VPNServer, enableRetry: Bool = true) async throws {
    Log.info("Connecting to: \(server.countryLong)")

    connectionTask?.cancel()
    currentServer = server

    let task = Task {
      try await performConnection(to: server, enableRetry: enableRetry)
    }
    connectionTask = task
    try await task.value
  }

  private func performConnection(to server: VPNServer, enableRetry: Bool) async throws {
    let startTime = Date()
    var actualRetryCount = 0

    await MainActor.run {
      monitoringStore.setConnecting(server: server)
      onStateChange?(.connecting)
    }
    vpnMonitor.startMonitoring()

    do {
      try Task.checkCancellation()

      if enableRetry, let openVPNController = controller as? OpenVPNController {
        try await openVPNController.connectWithRetry(server: server)
      } else {
        try await controller.connect(server: server)
      }

      let connectionTime = Date().timeIntervalSince(startTime)
      Log.success("Connected in \(String(format: "%.2f", connectionTime))s")

      await MainActor.run {
        telemetry.recordAttempt(
          serverID: server.id,
          success: true,
          connectionTime: connectionTime,
          retryCount: actualRetryCount,
          failureReason: nil
        )
        monitoringStore.setConnected()
        onStateChange?(.connected)
      }
    } catch is CancellationError {
      Log.info("Connection cancelled by user")
      vpnMonitor.forceStop()
      await MainActor.run {
        monitoringStore.setDisconnected()
        onStateChange?(.disconnected)
      }
      return
    } catch {
      Log.error("Connection failed: \(error.localizedDescription)")
      vpnMonitor.forceStop()

      await MainActor.run {
        telemetry.recordAttempt(
          serverID: server.id,
          success: false,
          connectionTime: nil,
          retryCount: actualRetryCount,
          failureReason: error.localizedDescription
        )
        monitoringStore.setError(error.localizedDescription)
        onStateChange?(.error(error.localizedDescription))
      }
      throw error
    }
  }

  func cancelConnection() async {
    Log.info("Cancelling connection...")

    connectionTask?.cancel()
    connectionTask = nil
    vpnMonitor.forceStop()

    await MainActor.run {
      monitoringStore.setDisconnecting()
      onStateChange?(.disconnecting)
    }

    await controller.cancelConnection()

    await MainActor.run {
      monitoringStore.setDisconnected()
      onStateChange?(.disconnected)
    }

    currentServer = nil
  }

  func disconnect() async throws {
    Log.info("Disconnecting...")

    await MainActor.run {
      monitoringStore.setDisconnecting()
      onStateChange?(.disconnecting)
    }

    vpnMonitor.forceStop()

    do {
      try await controller.disconnect()
      Log.success("Disconnected successfully")

      await MainActor.run {
        monitoringStore.setDisconnected()
        onStateChange?(.disconnected)
      }
    } catch {
      Log.error("Disconnect failed: \(error.localizedDescription)")

      await MainActor.run {
        monitoringStore.setError(error.localizedDescription)
        onStateChange?(.error(error.localizedDescription))
      }
      throw error
    }

    currentServer = nil
  }
}
