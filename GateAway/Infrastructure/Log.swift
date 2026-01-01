import Foundation
import os

/// Centralized logging with per-feature categories and environment-aware levels
enum Log {
    
    // MARK: - Log Levels
    
    enum Level: Int, Comparable {
        case debug = 0
        case info = 1
        case warning = 2
        case error = 3
        
        static func < (lhs: Level, rhs: Level) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }
    
    /// Current log level based on build configuration
    #if DEBUG
    static var level: Level = .debug
    #else
    static var level: Level = .warning
    #endif
    
    private static let subsystem = Bundle.identifier
    
    // MARK: - Public Methods
    
    static func debug(
        _ message: String,
        category: LogCategory? = nil,
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) {
        guard level <= .debug else { return }
        log(message, level: .debug, category: category, file: file, function: function, line: line)
    }
    
    static func info(
        _ message: String,
        category: LogCategory? = nil,
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) {
        guard level <= .info else { return }
        log(message, level: .info, category: category, file: file, function: function, line: line)
    }
    
    static func warning(
        _ message: String,
        category: LogCategory? = nil,
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) {
        guard level <= .warning else { return }
        log(message, level: .warning, category: category, file: file, function: function, line: line)
    }
    
    static func error(
        _ message: String,
        category: LogCategory? = nil,
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) {
        guard level <= .error else { return }
        log(message, level: .error, category: category, file: file, function: function, line: line)
    }
    
    /// Success logs - shown at info level with prefix
    static func success(
        _ message: String,
        category: LogCategory? = nil,
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) {
        guard level <= .info else { return }
        let resolvedCategory = category?.rawValue ?? fileName(file)
        let logger = Logger(subsystem: subsystem, category: resolvedCategory)
        let file = fileName(file)
        logger.info("[\(file, privacy: .public):\(line, privacy: .public)] \(function, privacy: .public) — \(message, privacy: .public)")
    }
    
    // MARK: - Private
    
    private static func log(
        _ message: String,
        level: Level,
        category: LogCategory?,
        file: String,
        function: String,
        line: Int
    ) {
        let resolvedCategory = category?.rawValue ?? fileName(file)
        let logger = Logger(subsystem: subsystem, category: resolvedCategory)
        let file = fileName(file)
        
        switch level {
        case .debug:
            logger.debug("[\(file, privacy: .public):\(line, privacy: .public)] \(function, privacy: .public) — \(message, privacy: .public)")
        case .info:
            logger.info("[\(file, privacy: .public):\(line, privacy: .public)] \(function, privacy: .public) — \(message, privacy: .public)")
        case .warning:
            logger.warning("[\(file, privacy: .public):\(line, privacy: .public)] \(function, privacy: .public) — \(message, privacy: .public)")
        case .error:
            logger.error("[\(file, privacy: .public):\(line, privacy: .public)] \(function, privacy: .public) — \(message, privacy: .public)")
        }
    }
    
    private static func fileName(_ file: String) -> String {
        (file as NSString)
            .lastPathComponent
            .replacingOccurrences(of: ".swift", with: "")
    }
}

// MARK: - Log Categories

/// Optional explicit categories for grouping logs in Console.app
enum LogCategory: String {
    case network = "Network"
    case auth = "Auth"
    case vpn = "VPN"
    case ui = "UI"
    case lifecycle = "Lifecycle"
}
