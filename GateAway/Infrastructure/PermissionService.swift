import Foundation
import AppKit

enum PermissionError: LocalizedError {
    case appleScriptPermissionDenied
    case openVPNBinMissing
    
    var errorDescription: String? {
        switch self {
        case .appleScriptPermissionDenied:
            return "Automation permission denied. Please allow GateAway to control System Events in System Settings > Privacy & Security > Automation."
        case .openVPNBinMissing:
            return "OpenVPN binary not found. Please install OpenVPN (brew install openvpn)."
        }
    }
}

final class PermissionService {
    static let shared = PermissionService()
    
    private init() {}
    
    /// Pre-flight check for OpenVPN binary existence
    func checkOpenVPNPermission() throws {
        let paths = ["/usr/local/sbin/openvpn", "/opt/homebrew/sbin/openvpn", "/usr/sbin/openvpn"]
        let exists = paths.contains { FileManager.default.fileExists(atPath: $0) }
        
        if !exists {
            throw PermissionError.openVPNBinMissing
        }
    }
    
    func requestPermission() {
        // No-op - permission is requested when action is performed
    }
}
