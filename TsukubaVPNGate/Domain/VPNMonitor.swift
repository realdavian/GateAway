import Foundation
import Combine

// MARK: - VPN Monitor Protocol

protocol VPNMonitorProtocol {
    var statisticsPublisher: AnyPublisher<VPNStatistics, Never> { get }
    func startMonitoring()
    func stopMonitoring()
    func refreshStats()
    func setConnectedServer(country: String?, countryShort: String?, serverName: String?)
}

// MARK: - VPN Monitor Implementation

final class VPNMonitor: VPNMonitorProtocol {
    
    // MARK: - Server Info Management
    
    func setConnectedServer(country: String?, countryShort: String?, serverName: String?) {
        monitoringStore.setConnectedServer(country: country, countryShort: countryShort, serverName: serverName)
    }
    
    // MARK: - Properties
    
    private let monitoringStore: MonitoringStore
    private var monitorTask: Task<Void, Never>?
    private var monitoringRefCount = 0
    
    private let managementSocketPath: String
    private let fileManager = FileManager.default
    
    // Forward to MonitoringStore's publisher
    var statisticsPublisher: AnyPublisher<VPNStatistics, Never> {
        return monitoringStore.$vpnStatistics.eraseToAnyPublisher()
    }
    
    init(monitoringStore: MonitoringStore) {
        self.monitoringStore = monitoringStore
        
        let homeDir = fileManager.homeDirectoryForCurrentUser
        let configDir = homeDir.appendingPathComponent(".tsukuba-vpn")
        self.managementSocketPath = configDir.appendingPathComponent("openvpn.sock").path
        print("📊 [VPNMonitor] Monitoring socket at: \(managementSocketPath)")
    }
    
    // MARK: - Monitoring Lifecycle
    
    func startMonitoring() {
        monitoringRefCount += 1
        print("📊 [VPNMonitor] Starting monitoring (ref count: \(monitoringRefCount))")
        print("📊 [VPNMonitor] Call stack: \(Thread.callStackSymbols.prefix(5))")
        
        // Only start task if not already running
        guard monitorTask == nil else { 
            print("📊 [VPNMonitor] Task already running, skipping")
            return 
        }
        
        print("📊 [VPNMonitor] Creating new monitoring task")
        // Start async monitoring task
        monitorTask = Task { [weak self] in
            guard let self else { return }
            
            var iteration = 0
            while !Task.isCancelled {
                iteration += 1
                if iteration % 10 == 0 {  // Log every 10 iterations
                    print("📊 [VPNMonitor] Still polling... iteration \(iteration)")
                }
                
                await self.refreshStatsAsync()
                
                // Sleep before next poll (macOS 11 compatible)
                do {
                    try await Task.sleep(nanoseconds: 1_000_000_000)  // 1 second
                } catch {
                    print("📊 [VPNMonitor] Task cancelled during sleep")
                    break  // Task cancelled
                }
            }
            
            print("📊 [VPNMonitor] Monitoring task stopped")
        }
    }
    
    func stopMonitoring() {
        monitoringRefCount = max(0, monitoringRefCount - 1)
        print("📊 [VPNMonitor] Stop request (ref count: \(monitoringRefCount))")
        print("📊 [VPNMonitor] Call stack: \(Thread.callStackSymbols.prefix(5))")
        
        // Only stop if no more observers
        guard monitoringRefCount == 0 else { 
            print("📊 [VPNMonitor] Still has \(monitoringRefCount) observer(s), keeping task alive")
            return 
        }
        
        print("📊 [VPNMonitor] Stopping monitoring (no more observers)")
        monitorTask?.cancel()
        monitorTask = nil
    }
    
    // Legacy synchronous method for backward compatibility
    func refreshStats() {
        Task {
            await refreshStatsAsync()
        }
    }
    
    // MARK: - Stats Polling
    
    private func refreshStatsAsync() async {
        // Can read MonitoringStore directly (we're @MainActor)
        let currentStats = monitoringStore.vpnStatistics
        
        // Poll stats on background (automatic with async)
        let newStats = await pollStatistics(previous: currentStats)
        
        // Update store (automatic back to main via @MainActor)
        monitoringStore.updateStatistics(newStats)
    }
    
    // This automatically runs on background
    private func pollStatistics(previous: VPNStatistics) async -> VPNStatistics {
        // Check if management socket exists (file I/O on background thread)
        guard fileManager.fileExists(atPath: managementSocketPath) else {
            return .empty
        }
        
        // Query OpenVPN for current stats (network I/O on background thread)
        let state = await queryState()
        let status = await queryStatus()
        
        // Build statistics object
        var stats = VPNStatistics.empty
        
        // Parse state
        if let state = state {
            stats = parseState(state, currentStats: previous)
        }
        
        // Parse status for detailed info
        if let status = status {
            stats = parseStatus(status, currentStats: previous, parsedState: stats)
        } else {
            // Keep previous byte counts if status query fails
            stats = VPNStatistics(
                connectionState: stats.connectionState,
                connectedSince: stats.connectedSince,
                vpnIP: stats.vpnIP,
                publicIP: stats.publicIP,
                connectedCountry: previous.connectedCountry,
                connectedCountryShort: previous.connectedCountryShort,
                connectedServerName: previous.connectedServerName,
                bytesReceived: previous.bytesReceived,
                bytesSent: previous.bytesSent,
                currentDownloadSpeed: previous.currentDownloadSpeed,
                currentUploadSpeed: previous.currentUploadSpeed,
                ping: stats.ping,
                protocolType: stats.protocolType,
                port: stats.port,
                cipher: stats.cipher
            )
        }
        
        // Preserve server info from previous stats
        if stats.connectedServerName == nil, let serverName = previous.connectedServerName {
            stats = VPNStatistics(
                connectionState: stats.connectionState,
                connectedSince: stats.connectedSince,
                vpnIP: stats.vpnIP,
                publicIP: stats.publicIP,
                connectedCountry: previous.connectedCountry,
                connectedCountryShort: previous.connectedCountryShort,
                connectedServerName: serverName,
                bytesReceived: stats.bytesReceived,
                bytesSent: stats.bytesSent,
                currentDownloadSpeed: stats.currentDownloadSpeed,
                currentUploadSpeed: stats.currentUploadSpeed,
                ping: stats.ping,
                protocolType: stats.protocolType,
                port: stats.port,
                cipher: stats.cipher
            )
        }
        
        return stats
    }
    
    // MARK: - Management Interface Queries (now async)
    
    private func queryState() async -> String? {
        return await sendCommand("state")
    }
    
    private func queryStatus() async -> String? {
        return await sendCommand("status")
    }
    
    private func sendCommand(_ command: String) async -> String? {
        // This is I/O, so it automatically runs on background with `await`
        return await withCheckedContinuation { continuation in
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
                    if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                       !output.isEmpty {
                        continuation.resume(returning: output)
                        return
                    }
                }
            } catch {
                print("⚠️ [VPNMonitor] Command '\(command)' failed: \(error)")
            }
            
            continuation.resume(returning: nil)
        }
    }
    
    // MARK: - Response Parsers

    
    private func parseState(_ stateOutput: String, currentStats: VPNStatistics) -> VPNStatistics {
        // State format: "1234567890,CONNECTED,SUCCESS,10.8.0.6,92.202.199.250"
        // Filter out metadata lines (starting with >) and empty lines
        let lines = stateOutput.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix(">") && !$0.hasPrefix("END") }
        
        guard let stateLine = lines.first(where: { $0.range(of: "^[0-9]+,", options: .regularExpression) != nil }) else {
            return VPNStatistics(
                connectionState: .disconnected,
                connectedSince: nil,
                vpnIP: nil,
                publicIP: nil,
                connectedCountry: nil,
                connectedCountryShort: nil,
                connectedServerName: nil,
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
        let stateStr = components[1].trimmingCharacters(in: .whitespacesAndNewlines)
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
            connectedCountry: currentStats.connectedCountry,
            connectedCountryShort: currentStats.connectedCountryShort,
            connectedServerName: currentStats.connectedServerName,
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
        var bytesReceived: Int64 = 0
        var bytesSent: Int64 = 0
        
        let lines = statusOutput.components(separatedBy: "\n")
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if trimmed.contains("TCP/UDP read bytes") {
                if let commaIndex = trimmed.firstIndex(of: ",") {
                    let numberPart = trimmed[trimmed.index(after: commaIndex)...].trimmingCharacters(in: .whitespacesAndNewlines)
                    if let bytes = Int64(numberPart) {
                        bytesReceived = bytes
                    }
                }
            }
            
            if trimmed.contains("TCP/UDP write bytes") {
                if let commaIndex = trimmed.firstIndex(of: ",") {
                    let numberPart = trimmed[trimmed.index(after: commaIndex)...].trimmingCharacters(in: .whitespacesAndNewlines)
                    if let bytes = Int64(numberPart) {
                        bytesSent = bytes
                    }
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
            connectedCountry: parsedState.connectedCountry,
            connectedCountryShort: parsedState.connectedCountryShort,
            connectedServerName:parsedState.connectedServerName,
            bytesReceived: bytesReceived,
            bytesSent: bytesSent,
            currentDownloadSpeed: downloadSpeed,
            currentUploadSpeed: uploadSpeed,
            ping: currentStats.ping,
            protocolType: "UDP",
            port: 1194,
            cipher: "AES-128-CBC"
        )
    }
}
