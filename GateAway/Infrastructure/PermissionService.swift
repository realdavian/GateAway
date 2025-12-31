import Foundation
import AppKit

enum PermissionError: LocalizedError {
    case appleScriptPermissionDenied
    case openVPNBinMissing
    
    var errorDescription: String? {
        switch self {
        case .appleScriptPermissionDenied:
            return "Automation permission denied. Please allow TsukubaVPNGate to control Tunnelblick/System Events in System Settings > Privacy & Security > Automation."
        case .openVPNBinMissing:
            return "OpenVPN binary not found. Please install OpenVPN (brew install openvpn)."
        }
    }
}

final class PermissionService {
    static let shared = PermissionService()
    
    private init() {}
    
    /// Checks if the application has permission to execute AppleScript/Process.
    /// This is a heuristic check. Real permission is determined by the OS prompting the user.
    func checkOpenVPNPermission() throws {
        // Simple check: Can we run a harmless command via Process?
        // Note: Running `sudo` specifically triggers the prompt if not authorized,
        // but we don't want to trigger sudo prompt unnecessarily here.
        // The main issue identified was "hanging" when permission dialog is behind or blocked.
        
        // This method can be expanded to check specific Automation permissions if using AppleScript.
        // For now, we rely on the fact that if we can't run basic Process operations, we are likely blocked.
        
        // NOTE: macOS does not provide a public API to proactively check Automation permissions 
        // without triggering the request.
        
        // However, we can check if OpenVPN binary exists, which is a common failure.
        let paths = ["/usr/local/sbin/openvpn", "/opt/homebrew/sbin/openvpn", "/usr/sbin/openvpn"]
        let exists = paths.contains { FileManager.default.fileExists(atPath: $0) }
        
        if !exists {
            throw PermissionError.openVPNBinMissing
        }
    }
    
    /// Attempts to trigger the permission dialog proactively if possible (e.g. via a dummy script).
    func requestPermission() {
        // No-op for now, as triggering requires action.
    }
}
