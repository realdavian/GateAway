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
    
    private let statisticsSubject = CurrentValueSubject<VPNStatistics, Never>(.empty)
    private var timer: Timer?
    private let managementSocketPath: String
    private let fileManager = FileManager.default
    private var monitoringRefCount = 0 // Track number of observers
    
    var statisticsPublisher: AnyPublisher<VPNStatistics, Never> {
        return statisticsSubject.eraseToAnyPublisher()
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
        
        // Initial refresh
        refreshStats()
        
        // Update every second
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.refreshStats()
        }
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
        // Check if management socket exists
        guard fileManager.fileExists(atPath: managementSocketPath) else {
            // Socket gone means VPN disconnected, send empty stats silently
            DispatchQueue.main.async { [weak self] in
                self?.statisticsSubject.send(.empty)
            }
            return
        }
        
        // Query OpenVPN for current stats
        let state = queryState()
        let status = queryStatus()
        
        // Build statistics object
        var stats = VPNStatistics.empty
        let currentStats = statisticsSubject.value
        
        // Parse state
        if let state = state {
            stats = parseState(state, currentStats: currentStats)
        } else {
            print("⚠️ [VPNMonitor] No state response from OpenVPN")
        }
        
        // Parse status for detailed info
        if let status = status {
            stats = parseStatus(status, currentStats: currentStats)
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
        
        // Always publish on main thread
        DispatchQueue.main.async { [weak self] in
            self?.statisticsSubject.send(stats)
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
        let lines = stateOutput.components(separatedBy: "\n")
        guard let stateLine = lines.first(where: { $0.contains(",CONNECTED,") || $0.contains(",CONNECTING,") }) else {
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
        
        let components = stateLine.components(separatedBy: ",")
        guard components.count >= 5 else { return currentStats }
        
        let timestamp = TimeInterval(components[0]) ?? 0
        let stateStr = components[1]
        let vpnIP = components.count > 3 ? components[3] : nil
        let publicIP = components.count > 4 ? components[4] : nil
        
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
    
    private func parseStatus(_ statusOutput: String, currentStats: VPNStatistics) -> VPNStatistics {
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
            connectionState: currentStats.connectionState,
            connectedSince: currentStats.connectedSince,
            vpnIP: currentStats.vpnIP,
            publicIP: currentStats.publicIP,
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

