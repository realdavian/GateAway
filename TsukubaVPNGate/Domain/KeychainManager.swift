import Foundation
import Security
import LocalAuthentication

/// Manages secure storage of admin password in macOS Keychain with Touch ID protection
final class KeychainManager {
    
    // MARK: - Singleton
    static let shared = KeychainManager()
    
    // MARK: - Constants
    private let service = "com.tsukuba.vpngate"
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
    
    // MARK: - Init
    private init() {}
    
    // MARK: - Public Methods
    
    /// Save admin password to Keychain (will require Touch ID on retrieval)
    func savePassword(_ password: String) throws {
        guard !password.isEmpty else {
            throw KeychainError.saveFailed(errSecParam)
        }
        
        // Delete existing item first (if any)
        try? deletePassword()
        
        // Prepare query - simple storage without SecAccessControl
        // We'll authenticate with Touch ID when retrieving instead
        let passwordData = password.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: passwordData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            print("❌ [Keychain] Failed to save password: \(status)")
            throw KeychainError.saveFailed(status)
        }
        
        print("✅ [Keychain] Password saved successfully")
    }
    
    /// Retrieve admin password from Keychain (triggers Touch ID prompt with password fallback)
    func getPassword() async throws -> String {
        // Authenticate with Touch ID OR password fallback
        let context = LAContext()
        context.localizedReason = "Authenticate to connect to VPN"
        context.localizedFallbackTitle = "Use Password"  // Custom fallback button text
        
        var authError: NSError?
        // Use .deviceOwnerAuthentication (not .deviceOwnerAuthenticationWithBiometrics)
        // This allows BOTH Touch ID AND password fallback
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &authError) else {
            print("⚠️ [Keychain] Device authentication not available: \(authError?.localizedDescription ?? "unknown")")
            throw KeychainError.biometricsNotAvailable
        }
        
        
        // Use async continuation instead of semaphore - no thread blocking!
        let authenticated: Bool = try await withCheckedThrowingContinuation { continuation in
            context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: "Authenticate to connect to VPN"
            ) { success, error in
                if let error = error as? LAError {
                    // Only treat explicit user cancel as error, NOT fallback
                    if error.code == .userCancel || error.code == .appCancel {
                        print("⚠️ [Keychain] User cancelled authentication")
                        continuation.resume(throwing: KeychainError.authenticationCancelled)
                        return
                    }
                    // .userFallback is NOT an error - it means they chose "Enter Password"
                }
                
                if success {
                    continuation.resume(returning: true)
                } else {
                    print("❌ [Keychain] Authentication failed")
                    continuation.resume(throwing: KeychainError.biometricsNotAvailable)
                }
            }
        }
        
        guard authenticated else {
            // Should never reach here due to continuation error handling
            throw KeychainError.authenticationFailed
        }
        
        print("✅ [Keychain] Authentication succeeded")
        
        // Now retrieve the password from Keychain
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        switch status {
        case errSecSuccess:
            guard let passwordData = item as? Data,
                  let password = String(data: passwordData, encoding: .utf8) else {
                throw KeychainError.retrievalFailed(errSecDecode)
            }
            print("✅ [Keychain] Password retrieved from Keychain")
            return password
            
        case errSecItemNotFound:
            print("⚠️ [Keychain] Password not found")
            throw KeychainError.passwordNotFound
            
        default:
            print("❌ [Keychain] Failed to retrieve password: \(status)")
            throw KeychainError.retrievalFailed(status)
        }
    }
    
    /// Delete stored password from Keychain
    func deletePassword() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            print("❌ [Keychain] Failed to delete password: \(status)")
            throw KeychainError.retrievalFailed(status)
        }
        
        print("✅ [Keychain] Password deleted")
    }
    
    /// Check if password is stored in Keychain
    func isPasswordStored() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: false
        ]
        
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    /// Check if Touch ID is available on this device
    static func isBiometricsAvailable() -> Bool {
        let context = LAContext()
        var error: NSError?
        
        let canEvaluate = context.canEvaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            error: &error
        )
        
        return canEvaluate
    }
    
    /// Get biometric type (Touch ID, Face ID, etc.)
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
    
    // MARK: - Legacy Methods (for VPN password storage)
    
    /// Legacy method for generic keychain storage (used by OpenVPN config)
    func save(password: Data, account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.tsukubavpngate.vpn",
            kSecAttrAccount as String: account,
            kSecValueData as String: password
        ]
        
        // Try to add
        let status = SecItemAdd(query as CFDictionary, nil)
        
        // If duplicate, update instead
        if status == errSecDuplicateItem {
            let updateQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: "com.tsukubavpngate.vpn",
                kSecAttrAccount as String: account
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
    
    /// Legacy method for generic keychain retrieval (used by OpenVPN config)
    func get(account: String) throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.tsukubavpngate.vpn",
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
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
    
    /// Legacy method for generic keychain deletion (used by OpenVPN config)
    func delete(account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.tsukubavpngate.vpn",
            kSecAttrAccount as String: account
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.retrievalFailed(status)
        }
    }
}
