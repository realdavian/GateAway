import AppKit
import Foundation

enum PermissionError: LocalizedError {
  case appleScriptPermissionDenied
  case openVPNBinMissing

  var errorDescription: String? {
    switch self {
    case .appleScriptPermissionDenied:
      return
        "Automation permission denied. Please allow GateAway to control System Events in System Settings > Privacy & Security > Automation."
    case .openVPNBinMissing:
      return "OpenVPN binary not found. Please install OpenVPN (brew install openvpn)."
    }
  }
}

// MARK: - Protocol

protocol PermissionServiceProtocol {
  func checkOpenVPNPermission() throws
  func requestPermission()
}

final class PermissionService: PermissionServiceProtocol {
  static let shared = PermissionService()

  private init() {}

  /// Pre-flight check for OpenVPN binary existence
  func checkOpenVPNPermission() throws {
    let exists = Constants.Paths.openVPNBinaryPaths.contains {
      FileManager.default.fileExists(atPath: $0)
    }

    if !exists {
      throw PermissionError.openVPNBinMissing
    }
  }

  func requestPermission() {
    // No-op - permission is requested when action is performed
  }
}
