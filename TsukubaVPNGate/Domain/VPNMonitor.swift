import Foundation
import Combine

// MARK: - VPN Monitor Protocol

protocol VPNMonitorProtocol {
    var statisticsPublisher: AnyPublisher<VPNStatistics, Never> { get }
    func startMonitoring()
    func stopMonitoring()
    func refreshStats()
}

// MARK: - VPN Monitor Implementation

final class VPNMonitor: VPNMonitorProtocol {
    
    // MARK: - Shared Instance
    static let shared = VPNMonitor()
    
    // MARK: - Monitoring Lifecycle
    
    private let monitorQueue = DispatchQueue(label: "com.tsukubavpngate.monitor", qos: .userInitiated)
    private var timer: Timer?
    
    private let managementSocketPath: String
    private let fileManager = FileManager.default
    private var monitoringRefCount = 0 // Track number of observers
    
    // Forward to MonitoringStore's publisher
    var statisticsPublisher: AnyPublisher<VPNStatistics, Never> {
        return MonitoringStore.shared.$vpnStatistics.eraseToAnyPublisher()
    }
    
    private init() {
        let homeDir = fileManager.homeDirectoryForCurrentUser
        let configDir = homeDir.appendingPathComponent(".tsukuba-vpn")
        self.managementSocketPath = configDir.appendingPathComponent("openvpn.sock").path
        print("📊 [VPNMonitor] Monitoring socket at: \(managementSocketPath)")
    }
    
    func startMonitoring() {
        monitoringRefCount += 1
        print("📊 [VPNMonitor] Starting monitoring (ref count: \(monitoringRefCount))")
        
        // Only start timer if not already running
        guard timer == nil else { return }
        
        // Use Timer on main queue (required for @MainActor access)
        // I/O work will be dispatched to background within refreshStats()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.refreshStats()
        }
        
        // Initial refresh
        refreshStats()
    }
    
    func stopMonitoring() {
        monitoringRefCount = max(0, monitoringRefCount - 1)
        print("📊 [VPNMonitor] Stop request (ref count: \(monitoringRefCount))")
        
        // Only stop timer if no more observers
        guard monitoringRefCount == 0 else { return }
        
        print("📊 [VPNMonitor] Stopping monitoring (no more observers)")
        timer?.invalidate()
        timer = nil
        // Don't reset stats - keep last known state
    }
    
    func refreshStats() {
        // RUNNING ON MAIN THREAD (called from Timer)
        print("📊 [VPNMonitor] refreshStats() called on thread: \(Thread.current)")
        
        // Synchronously access @MainActor store
        let currentStats = MonitoringStore.shared.vpnStatistics
        print("📊 [VPNMonitor] Current stats: \(currentStats.connectionState)")
        
        // Dispatch I/O work to background queue
        monitorQueue.async { [weak self] in
            print("📊 [VPNMonitor] Processing stats on background queue")
            self?.processStatsOnBackground(currentStats: currentStats)
        }
    }
    
    private func processStatsOnBackground(currentStats: VPNStatistics) {
        // RUNNING ON BACKGROUND QUEUE - monitorQueue
        
        // Check if management socket exists (file I/O on background thread)
        guard fileManager.fileExists(atPath: managementSocketPath) else {
            // Socket gone means VPN disconnected, send empty stats loudly
            DispatchQueue.main.async {
                MonitoringStore.shared.updateStatistics(.empty)
            }
            return
        }
        
        // Query OpenVPN for current stats (network I/O on background thread)
        let state = queryState()
        let status = queryStatus()
        
        // Build statistics object
        var stats = VPNStatistics.empty
        
        // Parse state
        if let state = state {
            stats = parseState(state, currentStats: currentStats)
        } else {
            print("⚠️ [VPNMonitor] No state response from OpenVPN")
        }
        
        // Parse status for detailed info
        if let status = status {
            stats = parseStatus(status, currentStats: currentStats, parsedState: stats)
        } else {
            // Keep previous byte counts if status query fails
            stats = VPNStatistics(
                connectionState: stats.connectionState,
                connectedSince: stats.connectedSince,
                vpnIP: stats.vpnIP,
                publicIP: stats.publicIP,
                bytesReceived: currentStats.bytesReceived,
                bytesSent: currentStats.bytesSent,
                currentDownloadSpeed: currentStats.currentDownloadSpeed,
                currentUploadSpeed: currentStats.currentUploadSpeed,
                ping: stats.ping,
                protocolType: stats.protocolType,
                port: stats.port,
                cipher: stats.cipher
            )
        }
        
        // Always publish on main thread (MonitoringStore is @MainActor)
        DispatchQueue.main.async {
            MonitoringStore.shared.updateStatistics(stats)
        }
    }
    
    // MARK: - Management Interface Queries
    
    private func queryState() -> String? {
        return sendCommand("state")
    }
    
    private func queryStatus() -> String? {
        return sendCommand("status")
    }
    
    private func queryByteCount() -> String? {
        return sendCommand("bytecount 1") // Subscribe to byte count updates every 1 second
    }
    
    private func sendCommand(_ command: String) -> String? {
        let task = Process()
        task.launchPath = "/bin/sh"
        task.arguments = ["-c", "echo '\(command)' | nc -w 1 -U \(managementSocketPath) 2>/dev/null"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        
        do {
            try task.run()
            task.waitUntilExit()
            
            if task.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
                    if !output.isEmpty {
                        return output
                    }
                }
            }
        } catch {
            print("⚠️ [VPNMonitor] Command '\(command)' failed: \(error)")
        }
        
        return nil
    }
    
    // MARK: - Response Parsers
    
    private func parseState(_ stateOutput: String, currentStats: VPNStatistics) -> VPNStatistics {
        // State format: "1234567890,CONNECTED,SUCCESS,10.8.0.6,92.202.199.250"
        // Filter out metadata lines (starting with >) and empty lines
        let lines = stateOutput.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix(">") && !$0.hasPrefix("END") }
        
        print("📊 [VPNMonitor] parseState filtered lines: \(lines)")
        
        guard let stateLine = lines.first(where: { $0.range(of: "^[0-9]+,", options: .regularExpression) != nil }) else {
            print("⚠️ [VPNMonitor] No valid state line found in: \(stateOutput)")
            return VPNStatistics(
                connectionState: .disconnected,
                connectedSince: nil,
                vpnIP: nil,
                publicIP: nil,
                bytesReceived: currentStats.bytesReceived,
                bytesSent: currentStats.bytesSent,
                currentDownloadSpeed: currentStats.currentDownloadSpeed,
                currentUploadSpeed: currentStats.currentUploadSpeed,
                ping: currentStats.ping,
                protocolType: currentStats.protocolType,
                port: currentStats.port,
                cipher: currentStats.cipher
            )
        }
        
        print("📊 [VPNMonitor] Parsing state line: \(stateLine)")
        
        let components = stateLine.components(separatedBy: ",")
        guard components.count >= 5 else { return currentStats }
        
        let timestamp = TimeInterval(components[0]) ?? 0
        let stateStr = components[1].trimmingCharacters(in: .whitespacesAndNewlines)  // Trim \r and spaces
        let vpnIP = components.count > 3 ? components[3] : nil
        let publicIP = components.count > 4 ? components[4] : nil
        
        print("📊 [VPNMonitor] Parsed state string: '\(stateStr)'")
        
        let connectionState: VPNStatistics.ConnectionState
        if stateStr == "CONNECTED" {
            connectionState = .connected
        } else if stateStr == "CONNECTING" || stateStr == "WAIT" || stateStr == "AUTH" {
            connectionState = .connecting
        } else if stateStr == "RECONNECTING" {
            connectionState = .reconnecting
        } else {
            connectionState = .disconnected
        }
        
        print("📊 [VPNMonitor] Determined connection state: \(connectionState)")
        
        let connectedSince = timestamp > 0 ? Date(timeIntervalSince1970: timestamp) : nil
        
        return VPNStatistics(
            connectionState: connectionState,
            connectedSince: connectedSince,
            vpnIP: vpnIP,
            publicIP: publicIP,
            bytesReceived: currentStats.bytesReceived,
            bytesSent: currentStats.bytesSent,
            currentDownloadSpeed: currentStats.currentDownloadSpeed,
            currentUploadSpeed: currentStats.currentUploadSpeed,
            ping: currentStats.ping,
            protocolType: currentStats.protocolType,
            port: currentStats.port,
            cipher: currentStats.cipher
        )
    }
    
    private func parseStatus(_ statusOutput: String, currentStats: VPNStatistics, parsedState: VPNStatistics) -> VPNStatistics {
        // For CLIENT mode, OpenVPN reports:
        // TCP/UDP read bytes,123456  (bytes received from server)
        // TCP/UDP write bytes,78910  (bytes sent to server)
        
        var bytesReceived: Int64 = 0
        var bytesSent: Int64 = 0
        var foundRead = false
        var foundWrite = false
        
        let lines = statusOutput.components(separatedBy: "\n")
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // More flexible matching - check if line contains the key phrases
            if trimmed.contains("TCP/UDP read bytes") {
                // Extract number after comma
                if let commaIndex = trimmed.firstIndex(of: ",") {
                    let numberPart = trimmed[trimmed.index(after: commaIndex)...].trimmingCharacters(in: .whitespacesAndNewlines)
                    if let bytes = Int64(numberPart) {
                        bytesReceived = bytes
                        foundRead = true
                    }
                }
            }
            
            // Look for TCP/UDP write bytes (sent to VPN server)
            if trimmed.contains("TCP/UDP write bytes") {
                // Extract number after comma
                if let commaIndex = trimmed.firstIndex(of: ",") {
                    let numberPart = trimmed[trimmed.index(after: commaIndex)...].trimmingCharacters(in: .whitespacesAndNewlines)
                    if let bytes = Int64(numberPart) {
                        bytesSent = bytes
                        foundWrite = true
                    }
                }
            }
        }
        
        // Only log debug info on first failure to reduce spam
        if (!foundRead || !foundWrite) && currentStats.connectionState == .connected && currentStats.bytesReceived == 0 {
            print("⚠️ [VPNMonitor] Missing byte counts (read: \(foundRead), write: \(foundWrite))")
            print("📋 [VPNMonitor] Sample lines:")
            for (idx, line) in lines.prefix(15).enumerated() {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    print("  Line \(idx): '\(trimmed)'")
                }
            }
        }
        
        // Calculate speeds (bytes per second) based on delta
        let downloadSpeed = bytesReceived > currentStats.bytesReceived ?
            Double(bytesReceived - currentStats.bytesReceived) : 0.0
        let uploadSpeed = bytesSent > currentStats.bytesSent ?
            Double(bytesSent - currentStats.bytesSent) : 0.0
        
        return VPNStatistics(
            connectionState: parsedState.connectionState,
            connectedSince: parsedState.connectedSince,
            vpnIP: parsedState.vpnIP,
            publicIP: parsedState.publicIP,
            bytesReceived: bytesReceived,
            bytesSent: bytesSent,
            currentDownloadSpeed: downloadSpeed,
            currentUploadSpeed: uploadSpeed,
            ping: currentStats.ping,
            protocolType: "UDP", // Could parse from logs
            port: 1194, // Could parse from config
            cipher: "AES-128-CBC" // Could parse from logs
        )
    }
}

