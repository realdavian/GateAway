import SwiftUI

// MARK: - Environment Keys for Dependency Injection

/// Environment key for KeychainManager
private struct KeychainManagerKey: EnvironmentKey {
  static let defaultValue: KeychainManagerProtocol = KeychainManager()
}

/// Environment key for ServerCacheManager
private struct CacheManagerKey: EnvironmentKey {
  static let defaultValue: ServerCacheManagerProtocol = ServerCacheManager()
}

extension EnvironmentValues {
  var keychainManager: KeychainManagerProtocol {
    get { self[KeychainManagerKey.self] }
    set { self[KeychainManagerKey.self] = newValue }
  }

  var cacheManager: ServerCacheManagerProtocol {
    get { self[CacheManagerKey.self] }
    set { self[CacheManagerKey.self] = newValue }
  }
}
