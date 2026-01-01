import Foundation
import SwiftUI
import Combine

// MARK: - Connection Attempt Model

struct ConnectionAttempt: Codable {
    let serverID: String
    let timestamp: Date
    let success: Bool
    let connectionTime: TimeInterval?
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

// MARK: - Protocol

protocol TelemetryProtocol {
    func recordAttempt(serverID: String, success: Bool, connectionTime: TimeInterval?, retryCount: Int, failureReason: String?)
    func getOverallStats() -> (totalAttempts: Int, successCount: Int, avgConnectionTime: TimeInterval)?
}

// MARK: - Implementation

@MainActor
class ConnectionTelemetry: ObservableObject, TelemetryProtocol {
    
    @Published private(set) var stats: [String: ServerStats] = [:]
    
    private let maxHistoryDays = 30
    private var attempts: [ConnectionAttempt] = []
    private let storageKey = "vpn.connectionAttempts"
    
    init() {
        load()
    }
    
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
        
        Log.debug("Recorded \(success ? "success" : "failure") for server \(serverID)")
    }
    
    func getOverallStats() -> (totalAttempts: Int, successCount: Int, avgConnectionTime: TimeInterval)? {
        guard !attempts.isEmpty else { return nil }
        
        let total = attempts.count
        let success = attempts.filter { $0.success }.count
        let avgTime = attempts.compactMap { $0.connectionTime }.reduce(0, +) / Double(max(1, success))
        
        return (total, success, avgTime)
    }
    
    // MARK: - Private
    
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
            let successfulTimes = attempts.compactMap { $0.connectionTime }
            let avgTime = successfulTimes.isEmpty ? 0 : successfulTimes.reduce(0, +) / Double(successfulTimes.count)
            
            // Reliability: 70% success rate + 20% speed - 10% retry penalty
            let successScore = successRate * 70
            let speedScore = avgTime > 0 ? max(0, 20 - (avgTime * 2)) : 0
            let avgRetries = Double(attempts.map { $0.retryCount }.reduce(0, +)) / Double(totalCount)
            let retryPenalty = avgRetries * 5
            
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
            Log.debug("Loaded \(attempts.count) historical attempts")
        }
    }
}

// MARK: - Helpers

extension ConnectionTelemetry {
    static func formatTime(_ seconds: TimeInterval) -> String {
        if seconds < 1 {
            return String(format: "%.0fms", seconds * 1000)
        } else {
            return String(format: "%.1fs", seconds)
        }
    }
}
