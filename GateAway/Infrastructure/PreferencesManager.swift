import Foundation

// MARK: - Preferences Model

struct UserPreferences {
  var autoReconnectOnDrop: Bool
  var reconnectScope: ReconnectScope
  var topKPerCountry: Int
  var vpnProvider: VPNProvider
  var killSwitchEnabled: Bool
  var ipv6ProtectionEnabled: Bool

  enum ReconnectScope: String {
    case sameCountry
    case any
  }

  enum VPNProvider: String, CaseIterable {
    case openVPN = "OpenVPN"

    var displayName: String { "OpenVPN CLI" }
  }

  static let `default` = UserPreferences(
    autoReconnectOnDrop: true,
    reconnectScope: .sameCountry,
    topKPerCountry: 5,
    vpnProvider: .openVPN,
    killSwitchEnabled: false,
    ipv6ProtectionEnabled: false
  )
}

// MARK: - Protocol

protocol PreferencesManagerProtocol {
  func loadPreferences() -> UserPreferences
  func savePreferences(_ preferences: UserPreferences)
}

// MARK: - Implementation

final class PreferencesManager: PreferencesManagerProtocol {
  private let defaults: UserDefaults

  private enum Keys {
    static let autoReconnectOnDrop = "prefs.autoReconnectOnDrop"
    static let reconnectScope = "prefs.reconnectScope"
    static let topKPerCountry = "prefs.topKPerCountry"
    static let vpnProvider = "prefs.vpnProvider"
    static let killSwitchEnabled = "prefs.killSwitchEnabled"
    static let ipv6ProtectionEnabled = "prefs.ipv6ProtectionEnabled"
  }

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
  }

  func loadPreferences() -> UserPreferences {
    let autoReconnect =
      defaults.object(forKey: Keys.autoReconnectOnDrop) as? Bool
      ?? UserPreferences.default.autoReconnectOnDrop
    let scopeRaw =
      defaults.string(forKey: Keys.reconnectScope)
      ?? UserPreferences.default.reconnectScope.rawValue
    let scope = UserPreferences.ReconnectScope(rawValue: scopeRaw) ?? .sameCountry
    let topK =
      defaults.object(forKey: Keys.topKPerCountry) as? Int ?? UserPreferences.default.topKPerCountry
    let providerRaw =
      defaults.string(forKey: Keys.vpnProvider) ?? UserPreferences.default.vpnProvider.rawValue
    let provider = UserPreferences.VPNProvider(rawValue: providerRaw) ?? .openVPN

    let killSwitch =
      defaults.object(forKey: Keys.killSwitchEnabled) as? Bool
      ?? UserPreferences.default.killSwitchEnabled
    let ipv6Protection =
      defaults.object(forKey: Keys.ipv6ProtectionEnabled) as? Bool
      ?? UserPreferences.default.ipv6ProtectionEnabled

    return UserPreferences(
      autoReconnectOnDrop: autoReconnect,
      reconnectScope: scope,
      topKPerCountry: max(1, min(20, topK)),
      vpnProvider: provider,
      killSwitchEnabled: killSwitch,
      ipv6ProtectionEnabled: ipv6Protection
    )
  }

  func savePreferences(_ preferences: UserPreferences) {
    defaults.set(preferences.autoReconnectOnDrop, forKey: Keys.autoReconnectOnDrop)
    defaults.set(preferences.reconnectScope.rawValue, forKey: Keys.reconnectScope)
    defaults.set(preferences.topKPerCountry, forKey: Keys.topKPerCountry)
    defaults.set(preferences.vpnProvider.rawValue, forKey: Keys.vpnProvider)
    defaults.set(preferences.killSwitchEnabled, forKey: Keys.killSwitchEnabled)
    defaults.set(preferences.ipv6ProtectionEnabled, forKey: Keys.ipv6ProtectionEnabled)
  }
}
