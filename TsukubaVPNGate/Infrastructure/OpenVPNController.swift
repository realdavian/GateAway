//
//  OpenVPNController.swift
//  TsukubaVPNGate
//
//  Handles VPN connections via OpenVPN CLI (headless, no GUI prompts)
//

import Foundation

final class OpenVPNController: VPNControlling {
    
    // MARK: - VPNControlling Protocol
    
    var backendName: String {
        return "OpenVPN CLI"
    }
    
    var isAvailable: Bool {
        return fileManager.fileExists(atPath: openVPNBinary)
    }
    
    // MARK: - Private Properties
    
    private let fileManager = FileManager.default
    private var currentConfigPath: String?
    private var currentProcess: Process?
    private var managementSocket: FileHandle?
    private let vpnMonitor: VPNMonitorProtocol
    
    // OpenVPN paths
    private let openVPNBinary: String
    private let configDirectory: String
    private let pidFilePath: String
    private let logFilePath: String
    private let managementSocketPath: String
    
    // MARK: - Error Types
    
    enum OpenVPNError: LocalizedError {
        case notInstalled
        case configurationCreationFailed
        case connectionFailed(String)
        case disconnectionFailed(String)
        case permissionDenied
        
        var errorDescription: String? {
            switch self {
            case .notInstalled:
                return "OpenVPN is not installed. Please install it via Settings."
            case .configurationCreationFailed:
                return "Failed to create OpenVPN configuration file."
            case .connectionFailed(let message):
                return "VPN connection failed: \(message)"
            case .disconnectionFailed(let message):
                return "VPN disconnection failed: \(message)"
            case .permissionDenied:
                return "Permission denied. OpenVPN requires administrator privileges."
            }
        }
    }
    
    init(vpnMonitor: VPNMonitorProtocol = VPNMonitor.shared) {
        self.vpnMonitor = vpnMonitor
        
        // Check both Homebrew paths for OpenVPN
        if fileManager.fileExists(atPath: "/opt/homebrew/sbin/openvpn") {
            openVPNBinary = "/opt/homebrew/sbin/openvpn"
        } else if fileManager.fileExists(atPath: "/usr/local/sbin/openvpn") {
            openVPNBinary = "/usr/local/sbin/openvpn"
        } else {
            openVPNBinary = "/opt/homebrew/sbin/openvpn" // Default path
        }
        
        // Setup directories
        let homeDir = fileManager.homeDirectoryForCurrentUser
        configDirectory = homeDir.appendingPathComponent(".tsukuba-vpn").path
        pidFilePath = "\(configDirectory)/openvpn.pid"
        logFilePath = "\(configDirectory)/openvpn.log"
        managementSocketPath = "\(configDirectory)/openvpn.sock"
        
        // Create config directory if needed
        try? fileManager.createDirectory(atPath: configDirectory, withIntermediateDirectories: true)
        
        // Clean up stale socket
        try? fileManager.removeItem(atPath: managementSocketPath)
    }
    
    // MARK: - VPNControlling Protocol
    
    func connect(server: VPNServer, completion: @escaping (Result<Void, Error>) -> Void) {
        print("🔗 [OpenVPN] Connecting to \(server.countryLong) (\(server.hostName))")
        
        // 1. Pre-flight Permission Check
        do {
            try PermissionService.shared.checkOpenVPNPermission()
        } catch {
            print("❌ [OpenVPN] Permission check failed: \(error.localizedDescription)")
            DispatchQueue.main.async {
                completion(.failure(error))
            }
            return
        }
        
        // Check if OpenVPN is installed (redundant with PermissionService but keeps specific error)
        guard isInstalled() else {
            DispatchQueue.main.async {
                completion(.failure(OpenVPNError.notInstalled))
            }
            return
        }
        
        // Create configuration file
        do {
            let configPath = try createConfiguration(for: server)
            currentConfigPath = configPath
            
            // Start OpenVPN process
            startOpenVPN(configPath: configPath) { [weak self] error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ [OpenVPN] Failed to start: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        completion(.failure(error))
                    }
                    return
                }
                
                // Process is now running! Start non-blocking polling
                print("⏳ [OpenVPN] Process running, waiting for CONNECTED state...")
                self.startConnectionPolling(server: server, completion: completion)
            }
            
        } catch {
            print("❌ [OpenVPN] Connection failed: \(error)")
            DispatchQueue.main.async {
                completion(.failure(error))
            }
        }
    }
    
    private func startConnectionPolling(server: VPNServer, completion: @escaping (Result<Void, Error>) -> Void) {
        let pollingQueue = DispatchQueue(label: "com.tsukubavpngate.connection-polling", qos: .userInitiated)
        let maxAttempts = 30
        
        func pollAttempt(attemptNumber: Int) {
            // Run all checks on background queue
            pollingQueue.async { [weak self] in
                guard let self = self else {
                    DispatchQueue.main.async {
                        completion(.failure(OpenVPNError.connectionFailed("Controller deallocated")))
                    }
                    return
                }
                
                // 1. Check Success (file I/O and socket I/O on background thread)
                if self.isActuallyConnected() {
                    print("✅ [OpenVPN] Connection established after \(attemptNumber) seconds")
                    
                    // Update MonitoringStore with connected server info
                    DispatchQueue.main.async {
                        MonitoringStore.shared.setConnectedServer(
                            country: server.countryLong,
                            countryShort: server.countryShort,
                            serverName: server.hostName
                        )
                        completion(.success(()))
                    }
                    return
                }
                
                // 2. Check Failure (Process Crash)
                if !self.isOpenVPNRunning() {
                    print("❌ [OpenVPN] Process terminated during connection")
                    
                    // Try to read log (file I/O on background thread)
                    var logMsg = "Connection failed - check log"
                    if let logContent = try? String(contentsOfFile: self.logFilePath, encoding: .utf8) {
                        let lastLines = logContent.components(separatedBy: "\n").suffix(5).joined(separator: " | ")
                        print("📋 [OpenVPN] Log: \(lastLines)")
                        // Extract meaningful error if possible
                        if lastLines.contains("AUTH_FAILED") {
                            logMsg = "Authentication Failed"
                        }
                    }
                    
                    DispatchQueue.main.async {
                        completion(.failure(OpenVPNError.connectionFailed(logMsg)))
                    }
                    return
                }
                
                // 3. Check Timeout
                if attemptNumber >= maxAttempts {
                    print("⚠️ [OpenVPN] Connection timeout after \(maxAttempts) seconds")
                    DispatchQueue.main.async {
                        completion(.failure(OpenVPNError.connectionFailed("Connection timeout - check server")))
                    }
                    return
                }
                
                // 4. Continue polling (schedule next attempt)
                pollingQueue.asyncAfter(deadline: .now() + 1.0) {
                    pollAttempt(attemptNumber: attemptNumber + 1)
                }
            }
        }
        
        // Start first attempt
        pollAttempt(attemptNumber: 1)
    }
    
    func disconnect(completion: @escaping (Result<Void, Error>) -> Void) {
        print("🔌 [OpenVPN] Disconnecting...")
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Try management interface first (NO SUDO REQUIRED!)
            if self.fileManager.fileExists(atPath: self.managementSocketPath) {
                print("📡 [OpenVPN] Sending disconnect via management interface...")
                
                if self.sendManagementCommand("signal SIGTERM") {
                    print("✅ [OpenVPN] Graceful disconnect sent via management socket")
                    Thread.sleep(forTimeInterval: 1.5) // Wait for graceful shutdown
                } else {
                    print("⚠️ [OpenVPN] Management socket failed, will try killall")
                }
            }
            
            // Check if there are still processes running
            let processCount = self.getOpenVPNProcessCount()
            if processCount > 0 {
                print("⚠️ [OpenVPN] \(processCount) process(es) still running, using killall...")
                
                let killScript = """
                do shell script "killall -9 openvpn 2>/dev/null || true" with administrator privileges
                """
                
                var error: NSDictionary?
                if let scriptObject = NSAppleScript(source: killScript) {
                    let _ = scriptObject.executeAndReturnError(&error)
                    if let error = error {
                        print("⚠️ [OpenVPN] Kill script error: \(error)")
                    } else {
                        print("✅ [OpenVPN] All OpenVPN processes killed")
                        Thread.sleep(forTimeInterval: 0.5)
                    }
                }
            }
            
            // Stop monitoring before cleanup
            print("📊 [OpenVPN] Stopping VPN monitoring...")
            self.vpnMonitor.stopMonitoring()
            
            // Cleanup all config files and sockets
            self.currentProcess = nil
            try? self.fileManager.removeItem(atPath: self.pidFilePath)
            try? self.fileManager.removeItem(atPath: self.managementSocketPath)
            
            // Clean up all .ovpn files in the directory
            if let files = try? self.fileManager.contentsOfDirectory(atPath: self.configDirectory) {
                for file in files where file.hasSuffix(".ovpn") {
                    try? self.fileManager.removeItem(atPath: "\(self.configDirectory)/\(file)")
                }
            }
            
            self.currentConfigPath = nil
            
            print("✅ [OpenVPN] Disconnected successfully")
            
            DispatchQueue.main.async {
                completion(.success(()))
            }
        }
    }
    
    private func getOpenVPNProcessCount() -> Int {
        let task = Process()
        task.launchPath = "/bin/sh"
        task.arguments = ["-c", "ps aux | grep 'openvpn --config' | grep -v grep | wc -l"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                return Int(output.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
            }
        } catch {
            print("⚠️ [OpenVPN] Failed to get process count: \(error)")
        }
        
        return 0
    }

    // MARK: - Helper Methods
    func isInstalled() -> Bool {
        return fileManager.fileExists(atPath: openVPNBinary)
    }
    
    func getConnectionStatus() -> (isConnected: Bool, vpnIP: String?) {
        // Public method to check actual connection status
        guard let stateOutput = queryConnectionState() else {
            return (false, nil)
        }
        
        // Parse state: format is "timestamp,STATE,description,IP,..."
        let components = stateOutput.components(separatedBy: ",")
        if components.count >= 2 {
            let state = components[1]
            let isConnected = state == "CONNECTED"
            let vpnIP = components.count >= 4 ? components[3] : nil
            return (isConnected, vpnIP)
        }
        
        return (false, nil)
    }

    // MARK: - Private Methods
    
    private func createConfiguration(for server: VPNServer) throws -> String {
        // Decode base64 OpenVPN config
        guard let configData = Data(base64Encoded: server.openVPNConfigBase64),
              let configString = String(data: configData, encoding: .utf8) else {
            throw OpenVPNError.configurationCreationFailed
        }
        
        // Securely handle credentials
        let authFilePath = "\(configDirectory)/auth.txt"
        
        // 1. Try to get password from Keychain (account "vpn")
        let passwordData = try? KeychainManager.shared.get(account: "vpn")
        let password = passwordData.flatMap { String(data: $0, encoding: .utf8) } ?? "vpn"
        
        // 2. Write to file with restricted permissions (0600)
        // Note: 'write(toFile...)' uses default permissions. 
        // We should explicitly set permissions after writing.
        let authContent = "vpn\n\(password)\n" // standard VPNGate user is 'vpn'
        try authContent.write(toFile: authFilePath, atomically: true, encoding: .utf8)
        
        try? fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: authFilePath)
        
        // Build clean config
        var cleanLines = configString.components(separatedBy: "\n").filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return !trimmed.hasPrefix("#auth-user-pass") &&
                   !trimmed.hasPrefix("auth-user-pass") &&
                   !trimmed.hasPrefix("management ")
        }
        
        // Add our configuration block
        cleanLines.append("")
        cleanLines.append("# TsukubaVPNGate Configuration")
        cleanLines.append("auth-user-pass \(authFilePath)")
        cleanLines.append("auth-nocache")
        cleanLines.append("auth-retry nointeract")
        
        // Standard ciphers
        cleanLines.append("data-ciphers AES-128-CBC:AES-256-GCM:AES-128-GCM:CHACHA20-POLY1305")
        cleanLines.append("data-ciphers-fallback AES-128-CBC")
        cleanLines.append("cipher AES-128-CBC")
        
        // Networking
        cleanLines.append("redirect-gateway def1")
        cleanLines.append("dhcp-option DNS 8.8.8.8")
        cleanLines.append("dhcp-option DNS 8.8.4.4")
        
        // Permissions & Management
        cleanLines.append("script-security 2")
        cleanLines.append("management \(managementSocketPath) unix")
        cleanLines.append("daemon")
        cleanLines.append("log \(logFilePath)")
        cleanLines.append("writepid \(pidFilePath)")
        cleanLines.append("persist-tun")
        cleanLines.append("persist-key")
        cleanLines.append("verb 3")
        cleanLines.append("")
        
        let finalConfig = cleanLines.joined(separator: "\n")
        
        // Save to file
        let configName = "vpngate_\(server.countryShort)_\(Int(Date().timeIntervalSince1970)).ovpn"
            .replacingOccurrences(of: " ", with: "_")
        let configPath = "\(configDirectory)/\(configName)"
        
        try finalConfig.write(toFile: configPath, atomically: true, encoding: .utf8)
        
        print("✅ [OpenVPN] Created config: \(configPath)")
        
        return configPath
    }
    
    private func startOpenVPN(configPath: String, completion: @escaping (Error?) -> Void) {
        // SINGLE sudo call: kill any existing OpenVPN processes AND start new one
        // This prevents double password prompts!
        let script = """
        do shell script "killall openvpn 2>/dev/null || true; sleep 1; \(openVPNBinary) --config '\(configPath)'" with administrator privileges
        """
        
        print("🔐 [OpenVPN] Requesting admin privileges (Touch ID supported)...")
        print("⏳ [OpenVPN] Waiting for user authentication...")
        
        guard let scriptObject = NSAppleScript(source: script) else {
            completion(OpenVPNError.connectionFailed("Failed to create admin prompt script"))
            return
        }
        
        // Execute in background - use .default QoS to avoid priority inversion with AppleScript
        DispatchQueue.global(qos: .default).async { [weak self] in
            guard let self = self else { 
                completion(OpenVPNError.connectionFailed("Controller deallocated"))
                return 
            }
            
            var executionError: NSDictionary?
            let _ = scriptObject.executeAndReturnError(&executionError)
            
            if let error = executionError {
                let errorCode = error["NSAppleScriptErrorNumber"] as? Int ?? 0
                let errorMessage = error["NSAppleScriptErrorBriefMessage"] as? String ?? "Unknown error"
                print("❌ [OpenVPN] Admin script error (code: \(errorCode)): \(errorMessage)")
                
                if errorCode == -128 {
                    // User cancelled
                    completion(OpenVPNError.connectionFailed("User cancelled authentication"))
                } else {
                    completion(OpenVPNError.connectionFailed("Script execution failed: \(errorMessage)"))
                }
                return
            }
            
            print("✅ [OpenVPN] AppleScript completed - process should be starting")
            
            // Wait a moment for process to initialize
            Thread.sleep(forTimeInterval: 2.0)
            
            // Check if process actually started
            if self.isOpenVPNRunning() {
                print("✅ [OpenVPN] Process confirmed running")
                
                // Wait for management socket
                var socketWait = 0
                while socketWait < 5 && !self.fileManager.fileExists(atPath: self.managementSocketPath) {
                    Thread.sleep(forTimeInterval: 0.5)
                    socketWait += 1
                }
                
                if self.fileManager.fileExists(atPath: self.managementSocketPath) {
                    print("✅ [OpenVPN] Management socket ready")
                    self.connectToManagementInterface()
                    
                    // Start monitoring after successful connection
                    // Note: VPNMonitor uses reference counting, so multiple start/stop calls are safe
                    print("📊 [OpenVPN] Starting VPN monitoring...")
                    self.vpnMonitor.startMonitoring()
                    
                    completion(nil) // Success!
                } else {
                    print("⚠️ [OpenVPN] Management socket not created")
                    completion(OpenVPNError.connectionFailed("Management socket not available"))
                }
            } else {
                print("❌ [OpenVPN] Process failed to start")
                // Try to get error from log
                if let logContent = try? String(contentsOfFile: self.logFilePath, encoding: .utf8) {
                    let lastLines = logContent.components(separatedBy: "\n").suffix(3).joined(separator: " | ")
                    print("📋 [OpenVPN] Log: \(lastLines)")
                }
                completion(OpenVPNError.connectionFailed("Process failed to start"))
            }
        }
    }
    
    // MARK: - Process Management
    
    private func isOpenVPNRunning() -> Bool {
        // Check for actual running processes (more reliable than PID file which may not be written yet)
        let task = Process()
        task.launchPath = "/bin/sh"
        task.arguments = ["-c", "ps aux | grep '[o]penvpn --config' | wc -l"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8),
               let count = Int(output.trimmingCharacters(in: .whitespacesAndNewlines)) {
                let isRunning = count > 0
                if isRunning {
                    print("✅ [OpenVPN] Process check: \(count) process(es) running")
                }
                return isRunning
            }
        } catch {
            print("⚠️ [OpenVPN] Failed to check process: \(error)")
        }
        
        return false
    }
    
    private func connectToManagementInterface() {
        // Connect to OpenVPN management socket for better control
        guard fileManager.fileExists(atPath: managementSocketPath) else {
            print("⚠️ [OpenVPN] Management socket not ready yet")
            return
        }
        
        print("🔌 [OpenVPN] Management interface available at \(managementSocketPath)")
    }
    
    private func queryConnectionState() -> String? {
        // Query OpenVPN's actual connection state via management interface
        guard fileManager.fileExists(atPath: managementSocketPath) else {
            return nil
        }
        
        let task = Process()
        task.launchPath = "/bin/sh"
        // Fixed: Filter out lines starting with '>' and 'END', get the state line
        task.arguments = ["-c", "echo 'state' | nc -w 1 -U \(managementSocketPath) 2>/dev/null | grep -v '^>' | grep -v '^END' | grep '^[0-9]'"]
        
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
                    // Output format: "1234567890,CONNECTED,SUCCESS,10.8.0.6,..."
                    return output
                }
            }
        } catch {
            print("⚠️ [OpenVPN] Failed to query state: \(error)")
        }
        
        return nil
    }
    
    private func isActuallyConnected() -> Bool {
        // Check if OpenVPN has completed connection (not just started)
        guard let stateOutput = queryConnectionState() else {
            return false
        }
        
        // Parse state: format is "timestamp,STATE,description,IP,..."
        let components = stateOutput.components(separatedBy: ",")
        if components.count >= 2 {
            let state = components[1]
            let isConnected = state == "CONNECTED"
            
            if isConnected {
                print("✅ [OpenVPN] State: CONNECTED")
                if components.count >= 4 {
                    let ip = components[3]
                    print("✅ [OpenVPN] VPN IP: \(ip)")
                }
            } else {
                print("⏳ [OpenVPN] State: \(state)")
            }
            
            return isConnected
        }
        
        return false
    }
    
    private func sendManagementCommand(_ command: String) -> Bool {
        // Send command to OpenVPN management socket (NO SUDO NEEDED!)
        guard fileManager.fileExists(atPath: managementSocketPath) else {
            print("⚠️ [OpenVPN] Management socket not found")
            return false
        }
        
        // Use nc (netcat) to send command to Unix socket
        let task = Process()
        task.launchPath = "/usr/bin/nc"
        task.arguments = ["-U", managementSocketPath]
        
        let inputPipe = Pipe()
        task.standardInput = inputPipe
        task.standardOutput = Pipe()
        task.standardError = Pipe()
        
        do {
            try task.run()
            
            // Write command
            let commandData = "\(command)\n".data(using: .utf8)!
            inputPipe.fileHandleForWriting.write(commandData)
            inputPipe.fileHandleForWriting.closeFile()
            
            task.waitUntilExit()
            
            if task.terminationStatus == 0 {
                print("✅ [OpenVPN] Sent '\(command)' via management socket (no sudo needed!)")
                return true
            } else {
                print("⚠️ [OpenVPN] Failed to send command via socket")
                return false
            }
        } catch {
            print("⚠️ [OpenVPN] Socket communication error: \(error)")
            return false
        }
    }
}

