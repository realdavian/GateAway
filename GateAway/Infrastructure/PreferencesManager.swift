import Foundation

// MARK: - Preferences Model

struct UserPreferences {
  var autoReconnectOnDrop: Bool
  var reconnectScope: ReconnectScope
  var topKPerCountry: Int
  var vpnProvider: VPNProvider

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
    vpnProvider: .openVPN
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

    return UserPreferences(
      autoReconnectOnDrop: autoReconnect,
      reconnectScope: scope,
      topKPerCountry: max(1, min(20, topK)),
      vpnProvider: provider
    )
  }

  func savePreferences(_ preferences: UserPreferences) {
    defaults.set(preferences.autoReconnectOnDrop, forKey: Keys.autoReconnectOnDrop)
    defaults.set(preferences.reconnectScope.rawValue, forKey: Keys.reconnectScope)
    defaults.set(preferences.topKPerCountry, forKey: Keys.topKPerCountry)
    defaults.set(preferences.vpnProvider.rawValue, forKey: Keys.vpnProvider)
  }
}
