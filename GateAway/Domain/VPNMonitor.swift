import Foundation
import Combine

// MARK: - VPN Monitor Protocol

protocol VPNMonitorProtocol {
    func startMonitoring()
    func stopMonitoring()
    var statsPublisher: AnyPublisher<VPNStats, Never> { get }
}

// MARK: - VPN Monitor Implementation

/// Monitors OpenVPN via management socket and publishes stats.
/// This is a pure publisher - it does NOT own connection state.
/// Stats are published via Combine, subscribed to by MonitoringStore.
final class VPNMonitor: VPNMonitorProtocol {
    
    // MARK: - Properties
    
    private let managementSocketPath: String
    private let fileManager = FileManager.default
    
    private var monitorTask: Task<Void, Never>?
    private var monitoringRefCount = 0
    
    // MARK: - Combine Publisher
    
    private let statsSubject = CurrentValueSubject<VPNStats, Never>(.empty)
    
    /// Publisher for real-time VPN stats
    var statsPublisher: AnyPublisher<VPNStats, Never> {
        statsSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Init
    
    init() {
        let homeDir = fileManager.homeDirectoryForCurrentUser
        let configDir = homeDir.appendingPathComponent(".tsukuba-vpn")
        self.managementSocketPath = configDir.appendingPathComponent("openvpn.sock").path
        print("📊 [VPNMonitor] Monitoring socket at: \(managementSocketPath)")
    }
    
    // MARK: - Monitoring Lifecycle
    
    func startMonitoring() {
        monitoringRefCount += 1
        print("📊 [VPNMonitor] Starting monitoring (ref count: \(monitoringRefCount))")
        
        // Only start task if not already running
        guard monitorTask == nil else {
            print("📊 [VPNMonitor] Task already running, skipping")
            return
        }
        
        print("📊 [VPNMonitor] Creating new monitoring task")
        monitorTask = Task { [weak self] in
            guard let self else { return }
            
            var previousStats = VPNStats.empty
            var iteration = 0
            
            while !Task.isCancelled {
                iteration += 1
                if iteration % 10 == 0 {
                    print("📊 [VPNMonitor] Still polling... iteration \(iteration)")
                }
                
                // Poll stats from OpenVPN socket
                let newStats = await self.pollStats(previous: previousStats)
                
                // Publish to subscribers
                self.statsSubject.send(newStats)
                previousStats = newStats
                
                // Sleep before next poll
                do {
                    try await Task.sleep(nanoseconds: 1_000_000_000)  // 1 second
                } catch {
                    print("📊 [VPNMonitor] Task cancelled during sleep")
                    break
                }
            }
            
            print("📊 [VPNMonitor] Monitoring task stopped")
        }
    }
    
    func stopMonitoring() {
        monitoringRefCount = max(0, monitoringRefCount - 1)
        print("📊 [VPNMonitor] Stop request (ref count: \(monitoringRefCount))")
        
        // Only stop if no more observers
        guard monitoringRefCount == 0 else {
            print("📊 [VPNMonitor] Still has \(monitoringRefCount) observer(s), keeping task alive")
            return
        }
        
        print("📊 [VPNMonitor] Stopping monitoring (no more observers)")
        monitorTask?.cancel()
        monitorTask = nil
        
        // Reset stats
        statsSubject.send(.empty)
    }
    
    /// Force stop monitoring (for cancel/disconnect)
    func forceStop() {
        monitoringRefCount = 0
        monitorTask?.cancel()
        monitorTask = nil
        statsSubject.send(.empty)
        print("📊 [VPNMonitor] Force stopped")
    }
    
    // MARK: - Stats Polling
    
    private func pollStats(previous: VPNStats) async -> VPNStats {
        // Check if management socket exists
        guard fileManager.fileExists(atPath: managementSocketPath) else {
            return previous  // Keep previous stats if no socket
        }
        
        // Query OpenVPN for status
        guard let status = await queryStatus() else {
            return previous
        }
        
        // Parse status for stats
        return parseStatus(status, previous: previous)
    }
    
    private func queryStatus() async -> String? {
        return await sendCommand("status")
    }
    
    private func sendCommand(_ command: String) async -> String? {
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
                
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8)
                continuation.resume(returning: output)
            } catch {
                continuation.resume(returning: nil)
            }
        }
    }
    
    private func parseStatus(_ status: String, previous: VPNStats) -> VPNStats {
        var bytesReceived: Int64 = 0
        var bytesSent: Int64 = 0
        var vpnIP: String? = previous.vpnIP
        var connectedSince: Date? = previous.connectedSince
        
        let lines = status.components(separatedBy: "\n")
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Parse: TCP/UDP read bytes,12345
            if trimmed.contains("TCP/UDP read bytes") {
                if let commaIndex = trimmed.firstIndex(of: ",") {
                    let numberPart = trimmed[trimmed.index(after: commaIndex)...].trimmingCharacters(in: .whitespacesAndNewlines)
                    if let bytes = Int64(numberPart) {
                        bytesReceived = bytes
                    }
                }
            }
            
            // Parse: TCP/UDP write bytes,67890
            if trimmed.contains("TCP/UDP write bytes") {
                if let commaIndex = trimmed.firstIndex(of: ",") {
                    let numberPart = trimmed[trimmed.index(after: commaIndex)...].trimmingCharacters(in: .whitespacesAndNewlines)
                    if let bytes = Int64(numberPart) {
                        bytesSent = bytes
                    }
                }
            }
        }
        
        // Calculate speeds (bytes per second)
        let downloadSpeed = bytesReceived > previous.bytesReceived ?
            Double(bytesReceived - previous.bytesReceived) : 0.0
        let uploadSpeed = bytesSent > previous.bytesSent ?
            Double(bytesSent - previous.bytesSent) : 0.0
        
        return VPNStats(
            bytesReceived: bytesReceived,
            bytesSent: bytesSent,
            downloadSpeed: downloadSpeed,
            uploadSpeed: uploadSpeed,
            vpnIP: vpnIP,
            connectedSince: connectedSince
        )
    }
}

// MARK: - Management Socket Interface

extension VPNMonitor {
    /// Send a signal to OpenVPN via management socket
    func sendManagementCommand(_ command: String) -> Bool {
        guard fileManager.fileExists(atPath: managementSocketPath) else {
            return false
        }
        
        let process = Process()
        process.launchPath = "/bin/sh"
        process.arguments = ["-c", "echo '\(command)' | nc -w 1 -U \(managementSocketPath) 2>/dev/null"]
        
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
}
