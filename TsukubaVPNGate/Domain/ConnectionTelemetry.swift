import Foundation
import SwiftUI
import Combine

// MARK: - Connection Attempt Model

/// Represents a single connection attempt with its outcome and metrics
struct ConnectionAttempt: Codable {
    let serverID: String
    let timestamp: Date
    let success: Bool
    let connectionTime: TimeInterval?  // nil if failed
    let retryCount: Int
    let failureReason: String?
    
    init(serverID: String, success: Bool, connectionTime: TimeInterval?, retryCount: Int, failureReason: String? = nil) {
        self.serverID = serverID
        self.timestamp = Date()
        self.success = success
        self.connectionTime = connectionTime
        self.retryCount = retryCount
        self.failureReason = failureReason
    }
}

// MARK: - Server Statistics

/// Aggregated statistics for a specific server
struct ServerStats: Codable {
    let totalAttempts: Int
    let successCount: Int
    let failureCount: Int
    let avgConnectionTime: TimeInterval
    let reliabilityScore: Double
    
    var successRate: Double {
        guard totalAttempts > 0 else { return 0 }
        return Double(successCount) / Double(totalAttempts)
    }
    
    var successRatePercent: Int {
        Int(successRate * 100)
    }
}

// MARK: - Connection Telemetry Manager

/// Manages connection telemetry data for reliability tracking and server scoring
/// All data is stored locally - no external analytics
@MainActor
class ConnectionTelemetry: ObservableObject {
    static let shared = ConnectionTelemetry()
    
    @Published private(set) var stats: [String: ServerStats] = [:]
    
    private let maxHistoryDays = 30
    private var attempts: [ConnectionAttempt] = []
    
    private let storageKey = "vpn.connectionAttempts"
    
    private init() {
        load()
    }
    
    // MARK: - Public API
    
    /// Record a connection attempt
    func recordAttempt(
        serverID: String,
        success: Bool,
        connectionTime: TimeInterval?,
        retryCount: Int = 0,
        failureReason: String? = nil
    ) {
        let attempt = ConnectionAttempt(
            serverID: serverID,
            success: success,
            connectionTime: connectionTime,
            retryCount: retryCount,
            failureReason: failureReason
        )
        
        attempts.append(attempt)
        cleanOldData()
        recalculateStats()
        save()
        
        print("📊 [Telemetry] Recorded \(success ? "✅ success" : "❌ failure") for server \(serverID)")
    }
    
    /// Get reliability score (0-100) for a server
    func getReliabilityScore(for serverID: String) -> Double {
        stats[serverID]?.reliabilityScore ?? 50.0  // Default to 50 if no data
    }
    
    /// Get stats for a specific server
    func getStats(for serverID: String) -> ServerStats? {
        stats[serverID]
    }
    
    /// Get overall statistics across all servers
    func getOverallStats() -> (totalAttempts: Int, successCount: Int, avgConnectionTime: TimeInterval)? {
        guard !attempts.isEmpty else { return nil }
        
        let total = attempts.count
        let success = attempts.filter { $0.success }.count
        let avgTime = attempts.compactMap { $0.connectionTime }.reduce(0, +) / Double(max(1, success))
        
        return (total, success, avgTime)
    }
    
    /// Get most reliable servers
    func getMostReliableServers(count: Int = 5) -> [String] {
        stats
            .filter { $0.value.totalAttempts >= 3 }  // Require minimum attempts
            .sorted { $0.value.reliabilityScore > $1.value.reliabilityScore }
            .prefix(count)
            .map { $0.key }
    }
    
    /// Clear all telemetry data
    func clearAll() {
        attempts.removeAll()
        stats.removeAll()
        save()
        print("📊 [Telemetry] Cleared all data")
    }
    
    // MARK: - Private Helpers
    
    private func cleanOldData() {
        let cutoff = Date().addingTimeInterval(-Double(maxHistoryDays) * 24 * 3600)
        attempts.removeAll { $0.timestamp < cutoff }
    }
    
    private func recalculateStats() {
        var newStats: [String: ServerStats] = [:]
        
        let groupedAttempts = Dictionary(grouping: attempts, by: { $0.serverID })
        
        for (serverID, attempts) in groupedAttempts {
            let successCount = attempts.filter { $0.success }.count
            let totalCount = attempts.count
            let failureCount = totalCount - successCount
            
            guard totalCount > 0 else { continue }
            
            let successRate = Double(successCount) / Double(totalCount)
            
            // Calculate average connection time (only for successful attempts)
            let successfulTimes = attempts.compactMap { $0.connectionTime }
            let avgTime = successfulTimes.isEmpty ? 0 : successfulTimes.reduce(0, +) / Double(successfulTimes.count)
            
            // Calculate reliability score (0-100)
            // 70% weight on success rate
            // 20% weight on speed (lower time = higher score)
            // 10% penalty for retries
            let successScore = successRate * 70
            let speedScore = avgTime > 0 ? max(0, 20 - (avgTime * 2)) : 0  // 10s = 0 points, 0s = 20 points
            let avgRetries = Double(attempts.map { $0.retryCount }.reduce(0, +)) / Double(totalCount)
            let retryPenalty = avgRetries * 5  // Each retry costs 5 points
            
            let reliability = min(100, max(0, successScore + speedScore - retryPenalty))
            
            newStats[serverID] = ServerStats(
                totalAttempts: totalCount,
                successCount: successCount,
                failureCount: failureCount,
                avgConnectionTime: avgTime,
                reliabilityScore: reliability
            )
        }
        
        stats = newStats
    }
    
    // MARK: - Persistence
    
    private func save() {
        if let data = try? JSONEncoder().encode(attempts) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
    
    private func load() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([ConnectionAttempt].self, from: data) {
            attempts = decoded
            cleanOldData()
            recalculateStats()
            print("📊 [Telemetry] Loaded \(attempts.count) historical attempts")
        }
    }
}

// MARK: - Helper Extensions

extension ConnectionTelemetry {
    /// Get color for reliability score
    static func colorForScore(_ score: Double) -> Color {
        switch score {
        case 80...100: return .green
        case 60..<80: return .yellow
        case 40..<60: return .orange
        default: return .red
        }
    }
    
    /// Format connection time for display
    static func formatTime(_ seconds: TimeInterval) -> String {
        if seconds < 1 {
            return String(format: "%.0fms", seconds * 1000)
        } else {
            return String(format: "%.1fs", seconds)
        }
    }
}
