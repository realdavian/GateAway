import Foundation
import AppKit
import os

enum TsukubaError: LocalizedError {
    case network(String)
    case vpn(String)
    case system(String)
    case permission(String)
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .network(let msg): return "Network Error: \(msg)"
        case .vpn(let msg): return "VPN Error: \(msg)"
        case .system(let msg): return "System Error: \(msg)"
        case .permission(let msg): return "Permission Error: \(msg)"
        case .unknown(let error): return error.localizedDescription
        }
    }
}

final class ErrorService {
    static let shared = ErrorService()
    
    private let logger = Logger(subsystem: "com.tsukubavpngate", category: "Error")
    
    private init() {}
    
    func log(_ error: Error, severity: OSLogType = .error, file: String = #file, function: String = #function, line: Int = #line) {
        let fileName = (file as NSString).lastPathComponent
        logger.log(level: severity, "[\(fileName):\(line)] \(function) - \(error.localizedDescription)")
    }
    
    @MainActor
    func present(_ error: Error) {
        // Log it first
        log(error)
        
        let alert = NSAlert()
        alert.messageText = "An Error Occurred"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        
        // Handle special cases (like permissions)
        if let tsukubaError = error as? TsukubaError, case .permission(let msg) = tsukubaError {
             alert.messageText = "Permission Required"
             alert.informativeText = msg
             alert.addButton(withTitle: "Open Settings")
        }
        
        if let window = NSApp.keyWindow {
            alert.beginSheetModal(for: window)
        } else {
            alert.runModal()
        }
    }
}
