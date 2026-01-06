import AppKit
import Combine

// MARK: - Status Bar Controller (Presentation Layer - SRP: Menu bar UI only)

final class StatusBarController: NSObject {
  private var coordinator: AppCoordinatorProtocol
  private let monitoringStore: MonitoringStore
  private let serverStore: ServerStore
  private let vpnMonitor: VPNMonitor

  // Services for View injection
  private let keychainManager: KeychainManagerProtocol
  private let cacheManager: ServerCacheManagerProtocol
  private let telemetry: ConnectionTelemetry

  private let statusItem: NSStatusItem
  private var settingsWindow: SettingsWindowController?
  private var cancellables = Set<AnyCancellable>()

  var hasVisibleStatusItem: Bool {
    guard let button = statusItem.button else { return false }
    return !button.title.isEmpty || button.image != nil
  }

  init(
    coordinator: AppCoordinatorProtocol,
    monitoringStore: MonitoringStore,
    serverStore: ServerStore,
    vpnMonitor: VPNMonitor,
    keychainManager: KeychainManagerProtocol,
    cacheManager: ServerCacheManagerProtocol,
    telemetry: ConnectionTelemetry
  ) {
    self.coordinator = coordinator
    self.monitoringStore = monitoringStore
    self.serverStore = serverStore
    self.vpnMonitor = vpnMonitor
    self.keychainManager = keychainManager
    self.cacheManager = cacheManager
    self.telemetry = telemetry
    self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    super.init()

    // Give it a unique autosave name so macOS remembers its position and visibility
    statusItem.autosaveName = "GateAwayStatusItem"
    statusItem.isVisible = true

    configureStatusButton()
    rebuildMenu()

    Log.debug("Subscribing to MonitoringStore")
    monitoringStore.$connectionState
      .receive(on: DispatchQueue.main)
      .sink { [weak self] state in
        Log.debug("Connection state: \(state)")
        self?.updateStatusIcon(storeState: state)
      }
      .store(in: &cancellables)
  }

  // MARK: - Dynamic Updates

  func updateCoordinator(_ newCoordinator: AppCoordinatorProtocol) {
    Log.debug("Updating coordinator (backend switched)")
    self.coordinator = newCoordinator
    rebuildMenu()
  }

  private func configureStatusButton() {
    updateStatusIcon()
  }

  private func updateStatusIcon(storeState: ConnectionState? = nil) {
    guard let button = statusItem.button else { return }

    // Use provided store state, or fall back to store's current state
    let state = storeState ?? monitoringStore.connectionState

    // Choose icon based on connection state
    let (iconName, isTemplate) = iconForStatisticsState(state)

    // Create and configure image
    if let image = NSImage(systemSymbolName: iconName, accessibilityDescription: "GateAway") {
      // Template images automatically adapt to light/dark mode and menu bar styling
      image.isTemplate = isTemplate

      // Configure symbol for menu bar (compact size)
      let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
      let configuredImage = image.withSymbolConfiguration(config)

      button.image = configuredImage
      button.title = ""  // Icon only - cleaner look
      button.imagePosition = .imageOnly
    } else {
      // Fallback for older macOS versions
      button.title = "VPN"
      button.image = nil
    }
  }

  // Map ConnectionState to icon
  private func iconForStatisticsState(_ state: ConnectionState) -> (
    symbolName: String, isTemplate: Bool
  ) {
    switch state {
    case .disconnected:
      return ("lock.open.fill", true)
    case .connecting, .reconnecting, .disconnecting:
      return ("arrow.triangle.2.circlepath", true)
    case .connected:
      return ("shield.lefthalf.filled", true)
    case .error:
      return ("exclamationmark.shield.fill", false)
    }
  }

  // Legacy helper for menu logic (if still needed)
  private func iconForLegacyState(_ state: ConnectionState) -> (
    symbolName: String, isTemplate: Bool
  ) {
    switch state {
    case .disconnected: return ("lock.open.fill", true)
    case .connecting, .reconnecting: return ("arrow.triangle.2.circlepath", true)
    case .connected: return ("shield.lefthalf.filled", true)
    case .disconnecting: return ("arrow.triangle.2.circlepath", true)
    case .error: return ("exclamationmark.shield.fill", false)
    }
  }

  func rebuildMenu() {
    // Update icon to reflect current state
    updateStatusIcon()

    let menu = NSMenu()

    // Status header (Wi‑Fi menu style)
    let summary = coordinator.getStatusSummary()
    let statusItem = NSMenuItem(title: summary.title, action: nil, keyEquivalent: "")
    statusItem.isEnabled = false
    menu.addItem(statusItem)

    if let subtitle = summary.subtitle {
      let sub = NSMenuItem(title: subtitle, action: nil, keyEquivalent: "")
      sub.isEnabled = false
      menu.addItem(sub)
    }

    menu.addItem(.separator())

    // Primary actions
    let refreshItem = NSMenuItem(
      title: "Refresh Server List".localized, action: #selector(onRefresh), keyEquivalent: "r")
    refreshItem.target = self
    menu.addItem(refreshItem)

    // Dynamic connection button (changes based on state)
    let state = coordinator.getCurrentConnectionState()
    let connectionItem: NSMenuItem

    switch state {
    case .disconnected, .error:
      connectionItem = NSMenuItem(
        title: "Connect (Best)".localized, action: #selector(onConnectBest), keyEquivalent: "")
    case .connecting, .reconnecting:
      connectionItem = NSMenuItem(
        title: "⏹ Stop Connecting".localized, action: #selector(onCancelConnection),
        keyEquivalent: "")
    case .connected:
      connectionItem = NSMenuItem(
        title: "Disconnect".localized, action: #selector(onDisconnect), keyEquivalent: "")
    case .disconnecting:
      connectionItem = NSMenuItem(
        title: "Disconnecting...".localized, action: nil, keyEquivalent: "")
      connectionItem.isEnabled = false
    }

    connectionItem.target = self
    menu.addItem(connectionItem)

    menu.addItem(.separator())

    // Country submenu
    buildCountrySubmenu(menu: menu)

    menu.addItem(.separator())

    let settingsItem = NSMenuItem(
      title: "Settings…".localized, action: #selector(onSettings), keyEquivalent: ",")
    settingsItem.target = self
    menu.addItem(settingsItem)

    let quitItem = NSMenuItem(
      title: "Quit".localized, action: #selector(onQuit), keyEquivalent: "q")
    quitItem.target = self
    menu.addItem(quitItem)

    self.statusItem.menu = menu
  }

  private func buildCountrySubmenu(menu: NSMenu) {
    let byCountry = NSMenuItem(title: "Best by Country".localized, action: nil, keyEquivalent: "")
    let byCountryMenu = NSMenu()

    let countries = coordinator.getAvailableCountries()
    Log.debug("Building country submenu: \(countries.count) countries")

    for country in countries {
      let countryItem = NSMenuItem(title: country, action: nil, keyEquivalent: "")
      let serversMenu = NSMenu()

      let topServers = coordinator.getTopServers(forCountry: country)
      if topServers.isEmpty {
        let empty = NSMenuItem(title: "No servers".localized, action: nil, keyEquivalent: "")
        empty.isEnabled = false
        serversMenu.addItem(empty)
      } else {
        for server in topServers {
          let title = formatServerMenuItem(server)
          let item = NSMenuItem(
            title: title, action: #selector(onConnectSpecific(_:)), keyEquivalent: "")
          item.target = self
          item.representedObject = server.id

          // Mark connected server (simplified - no associated value)
          if case .connected = coordinator.getCurrentConnectionState() {
            // Can't check server ID without associated value - just mark any as connected
            // TODO: Consider getting serverInfo from MonitoringStore for exact match
          }

          serversMenu.addItem(item)
        }
      }

      countryItem.submenu = serversMenu
      byCountryMenu.addItem(countryItem)
    }

    byCountry.submenu = byCountryMenu
    menu.addItem(byCountry)
  }

  private func formatServerMenuItem(_ server: VPNServer) -> String {
    let pingPart = server.pingMS.map { "\($0) ms" } ?? "—"
    let speedPart = server.speedMbps.map { "\($0) Mbps" } ?? "—"
    return "\(server.hostName) • \(pingPart) • \(speedPart)"
  }

  // MARK: - Actions

  @objc private func onRefresh() {
    // Show loading state
    updateStatusIcon()

    Task {
      do {
        try await coordinator.refreshServerList()
        await MainActor.run {
          self.rebuildMenu()
        }
      } catch {
        await MainActor.run { [weak self] in
          self?.showError(title: "Refresh Failed".localized, message: error.localizedDescription)
          self?.rebuildMenu()
        }
      }
    }
  }

  @objc private func onConnectBest() {
    // Show connecting state immediately
    updateStatusIcon()

    Task {
      do {
        try await coordinator.connectToBestServer()
        await MainActor.run {
          self.rebuildMenu()
        }
      } catch {
        await MainActor.run { [weak self] in
          self?.showError(title: "Connection Failed".localized, message: error.localizedDescription)
          self?.rebuildMenu()
        }
      }
    }
  }

  @objc private func onConnectSpecific(_ sender: NSMenuItem) {
    guard let id = sender.representedObject as? String,
      let server = coordinator.getServerByID(id)
    else { return }

    // Show connecting state immediately
    updateStatusIcon()

    Task {
      do {
        try await coordinator.connectToServer(server)
        await MainActor.run {
          self.rebuildMenu()
        }
      } catch {
        await MainActor.run { [weak self] in
          self?.showError(title: "Connection Failed".localized, message: error.localizedDescription)
          self?.rebuildMenu()
        }
      }
    }
  }

  @objc private func onDisconnect() {
    // Show disconnecting state immediately
    updateStatusIcon()

    Task {
      do {
        try await coordinator.disconnect()
        await MainActor.run {
          self.rebuildMenu()
        }
      } catch {
        await MainActor.run { [weak self] in
          self?.showError(
            title: "Disconnection Failed".localized, message: error.localizedDescription)
          self?.rebuildMenu()
        }
      }
    }
  }

  @objc private func onCancelConnection() {
    Task {
      await coordinator.cancelConnection()
      await MainActor.run {
        self.rebuildMenu()
      }
    }
  }

  @objc private func onSettings() {
    if settingsWindow == nil {
      settingsWindow = SettingsWindowController(
        coordinator: coordinator,
        monitoringStore: monitoringStore,
        serverStore: serverStore,
        keychainManager: keychainManager,
        cacheManager: cacheManager,
        telemetry: telemetry
      )
    }
    settingsWindow?.show()
    NSApp.activate(ignoringOtherApps: true)
  }

  @objc private func onQuit() {
    NSApp.terminate(nil)
  }

  // MARK: - Error Handling (Presentation layer responsibility)

  private func showError(title: String, message: String) {
    let alert = NSAlert()
    alert.messageText = title
    alert.informativeText = message
    alert.alertStyle = .warning
    alert.addButton(withTitle: "OK".localized)
    alert.runModal()
  }
}
