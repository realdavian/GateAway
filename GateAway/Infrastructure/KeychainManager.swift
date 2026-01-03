import Foundation
import LocalAuthentication
import Security

// MARK: - Protocol

/// Secure storage for passwords in macOS Keychain with Touch ID support
protocol KeychainManagerProtocol {
  /// Saves admin password to Keychain
  /// - Parameter password: The password to store
  func savePassword(_ password: String) throws

  /// Retrieves admin password, triggering Touch ID authentication
  /// - Returns: The stored password
  /// - Throws: `KeychainError.authenticationCancelled` if user cancels
  func getPassword() async throws -> String

  /// Deletes stored admin password
  func deletePassword() throws

  /// Checks if admin password is stored
  func isPasswordStored() -> Bool

  /// Saves arbitrary data to Keychain for a specific account
  func save(password: Data, account: String) throws

  /// Retrieves data from Keychain for a specific account
  func get(account: String) throws -> Data

  /// Deletes data for a specific account
  func delete(account: String) throws
}

// MARK: - Implementation

final class KeychainManager: KeychainManagerProtocol {

  private let service = Bundle.identifier
  private let account = "admin-password"

  // MARK: - Errors

  enum KeychainError: LocalizedError {
    case saveFailed(OSStatus)
    case retrievalFailed(OSStatus)
    case authenticationCancelled
    case authenticationFailed
    case biometricsNotAvailable
    case passwordNotFound

    var errorDescription: String? {
      switch self {
      case .saveFailed(let status):
        return "Failed to save password: \(status)"
      case .retrievalFailed(let status):
        return "Failed to retrieve password: \(status)"
      case .authenticationCancelled:
        return "Touch ID authentication was cancelled"
      case .authenticationFailed:
        return "Authentication failed"
      case .biometricsNotAvailable:
        return "Touch ID is not available on this device"
      case .passwordNotFound:
        return "No password stored in Keychain"
      }
    }
  }

  init() {}

  // MARK: - Admin Password

  func savePassword(_ password: String) throws {
    guard !password.isEmpty else {
      throw KeychainError.saveFailed(errSecParam)
    }

    try? deletePassword()

    let passwordData = password.data(using: .utf8)!
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
      kSecValueData as String: passwordData,
      kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
    ]

    let status = SecItemAdd(query as CFDictionary, nil)

    guard status == errSecSuccess else {
      Log.error("Failed to save password: \(status)")
      throw KeychainError.saveFailed(status)
    }

    Log.success("Password saved successfully")
  }

  /// Retrieve admin password (triggers Touch ID prompt with password fallback)
  func getPassword() async throws -> String {
    let context = LAContext()
    context.localizedReason = "Authenticate to connect to VPN"
    context.localizedFallbackTitle = "Use Password"

    var authError: NSError?
    guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &authError) else {
      Log.warning(
        "Device authentication not available: \(authError?.localizedDescription ?? "unknown")")
      throw KeychainError.biometricsNotAvailable
    }

    let authenticated: Bool = try await withCheckedThrowingContinuation { continuation in
      context.evaluatePolicy(
        .deviceOwnerAuthentication,
        localizedReason: "Authenticate to connect to VPN"
      ) { success, error in
        if let error = error as? LAError {
          if error.code == .userCancel || error.code == .appCancel {
            Log.warning("User cancelled authentication")
            continuation.resume(throwing: KeychainError.authenticationCancelled)
            return
          }
        }

        if success {
          continuation.resume(returning: true)
        } else {
          Log.error("Authentication failed")
          continuation.resume(throwing: KeychainError.biometricsNotAvailable)
        }
      }
    }

    guard authenticated else {
      throw KeychainError.authenticationFailed
    }

    Log.success("Authentication succeeded")

    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
      kSecReturnData as String: true,
    ]

    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)

    switch status {
    case errSecSuccess:
      guard let passwordData = item as? Data,
        let password = String(data: passwordData, encoding: .utf8)
      else {
        throw KeychainError.retrievalFailed(errSecDecode)
      }
      Log.success("Password retrieved from Keychain")
      return password

    case errSecItemNotFound:
      Log.warning("Password not found")
      throw KeychainError.passwordNotFound

    default:
      Log.error("Failed to retrieve password: \(status)")
      throw KeychainError.retrievalFailed(status)
    }
  }

  func deletePassword() throws {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
    ]

    let status = SecItemDelete(query as CFDictionary)

    guard status == errSecSuccess || status == errSecItemNotFound else {
      Log.error("Failed to delete password: \(status)")
      throw KeychainError.retrievalFailed(status)
    }

    Log.success("Password deleted")
  }

  func isPasswordStored() -> Bool {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
      kSecReturnData as String: false,
    ]

    let status = SecItemCopyMatching(query as CFDictionary, nil)
    return status == errSecSuccess
  }

  static func isBiometricsAvailable() -> Bool {
    let context = LAContext()
    var error: NSError?
    return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
  }

  static func biometricType() -> String {
    let context = LAContext()
    var error: NSError?

    guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
      return "Biometrics"
    }

    switch context.biometryType {
    case .touchID:
      return "Touch ID"
    case .faceID:
      return "Face ID"
    case .opticID:
      return "Optic ID"
    case .none:
      return "Biometrics"
    @unknown default:
      return "Biometrics"
    }
  }

  // MARK: - VPN Credentials

  func save(password: Data, account: String) throws {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
      kSecValueData as String: password,
    ]

    let status = SecItemAdd(query as CFDictionary, nil)

    if status == errSecDuplicateItem {
      let updateQuery: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: service,
        kSecAttrAccount as String: account,
      ]

      let attributes: [String: Any] = [
        kSecValueData as String: password
      ]

      let updateStatus = SecItemUpdate(updateQuery as CFDictionary, attributes as CFDictionary)
      guard updateStatus == errSecSuccess else {
        throw KeychainError.saveFailed(updateStatus)
      }
    } else if status != errSecSuccess {
      throw KeychainError.saveFailed(status)
    }
  }

  func get(account: String) throws -> Data {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
      kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne,
    ]

    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)

    guard status != errSecItemNotFound else {
      throw KeychainError.passwordNotFound
    }
    guard status == errSecSuccess else {
      throw KeychainError.retrievalFailed(status)
    }
    guard let data = item as? Data else {
      throw KeychainError.retrievalFailed(errSecDecode)
    }

    return data
  }

  func delete(account: String) throws {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
    ]

    let status = SecItemDelete(query as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else {
      throw KeychainError.retrievalFailed(status)
    }
  }
}
