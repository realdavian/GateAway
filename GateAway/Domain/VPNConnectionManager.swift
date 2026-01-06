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
  private let networkProtection: NetworkProtectionServiceProtocol
  private let preferencesManager: PreferencesManagerProtocol
  private var connectionTask: Task<Void, Error>?
  private var currentServer: VPNServer?
  private var isAutoReconnecting = false

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
    vpnMonitor: VPNMonitor,
    networkProtection: NetworkProtectionServiceProtocol,
    preferencesManager: PreferencesManagerProtocol
  ) {
    self.controller = controller
    self.telemetry = telemetry
    self.monitoringStore = monitoringStore
    self.vpnMonitor = vpnMonitor
    self.networkProtection = networkProtection
    self.preferencesManager = preferencesManager
    Log.info("Initialized with \(backend.displayName) backend")

    setupAutoReconnect()
  }

  // MARK: - Auto-Reconnect

  private func setupAutoReconnect() {
    vpnMonitor.onConnectionDropped = { [weak self] in
      guard let self = self else { return }
      Task {
        await self.handleConnectionDrop()
      }
    }
  }

  private func handleConnectionDrop() async {
    let preferences = preferencesManager.loadPreferences()

    guard preferences.autoReconnectOnDrop,
      let server = currentServer,
      !isAutoReconnecting
    else {
      return
    }

    Log.info("Connection dropped, auto-reconnecting...")
    isAutoReconnecting = true

    await MainActor.run {
      monitoringStore.setReconnecting()
      onStateChange?(.reconnecting)
    }

    do {
      // Kill switch remains active during reconnect
      try await connect(to: server, enableRetry: true)
      isAutoReconnecting = false
    } catch {
      Log.error("Auto-reconnect failed: \(error.localizedDescription)")
      isAutoReconnecting = false
    }
  }

  func connect(to server: VPNServer, enableRetry: Bool = true) async throws {
    Log.info("Connecting to: \(server.countryLong)")

    connectionTask?.cancel()
    currentServer = server

    // Enable network protections before connecting
    let preferences = preferencesManager.loadPreferences()
    try await enableProtections(preferences: preferences)

    let task = Task {
      try await performConnection(to: server, enableRetry: enableRetry)
    }
    connectionTask = task
    try await task.value
  }

  private func enableProtections(preferences: UserPreferences) async throws {
    if preferences.killSwitchEnabled {
      try await networkProtection.enableKillSwitch()
    }
    if preferences.ipv6ProtectionEnabled {
      try await networkProtection.disableIPv6()
    }
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
    } catch ScriptRunnerError.authenticationCancelled {
      Log.info("Authentication cancelled by user")
      vpnMonitor.forceStop()
      await MainActor.run {
        monitoringStore.setDisconnected()
        onStateChange?(.disconnected)
      }
      return
    } catch KeychainManager.KeychainError.authenticationCancelled {
      Log.info("Biometric authentication cancelled by user")
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

      // Disable network protections on user-initiated disconnect
      try? await networkProtection.disableKillSwitch()
      try? await networkProtection.restoreIPv6()

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
