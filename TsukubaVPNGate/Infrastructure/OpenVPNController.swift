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
    
    // MARK: - Dependencies (injected for testability)
    private let keychainManager: KeychainManagerProtocol
    
    init(vpnMonitor: VPNMonitorProtocol, keychainManager: KeychainManagerProtocol) {
        self.vpnMonitor = vpnMonitor
        self.keychainManager = keychainManager
        
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
    
    /// Connect with automatic retry for better reliability
    func connectWithRetry(server: VPNServer, policy: RetryPolicy = .default) async throws {
        try await policy.execute {
            try await self.connect(server: server)
        }
    }
    
    func connect(server: VPNServer) async throws {
        print("🔗 [OpenVPN] Connecting to \(server.countryLong) (\(server.hostName))")
        
        // 0. Kill any existing openvpn process (ensures only 1 connection)
        if getOpenVPNProcessCount() > 0 {
            print("⚠️ [OpenVPN] Killing existing process before new connection")
            _ = sendManagementCommand("signal SIGTERM")
            try await Task.sleep(nanoseconds: 500_000_000)  // Wait 0.5s for cleanup
        }
        
        // 1. Pre-flight Permission Check
        try PermissionService.shared.checkOpenVPNPermission()
        
        // 2. Check if OpenVPN is installed
        guard isInstalled() else {
            throw OpenVPNError.notInstalled
        }
        
        // 3. Create configuration file
        let configPath = try createConfiguration(for: server)
        currentConfigPath = configPath
        
        // 4. Start OpenVPN process
        try await startOpenVPN(configPath: configPath)
        
        // 5. Wait for connection to establish
        print("⏳ [OpenVPN] Process running, waiting for CONNECTED state...")
        try await waitForConnection(server: server)
        
        print("✅ [OpenVPN] Connection established successfully")
    }


    
    private func waitForConnection(server: VPNServer) async throws {
        let maxAttempts = 30
        
        for attempt in 1...maxAttempts {
            // Check success (file I/O and socket I/O automatically on background)
            if isActuallyConnected() {
                print("✅ [OpenVPN] Connection established after \(attempt) seconds")
                // Server info is set by VPNConnectionManager via MonitoringStore
                return  // Success!
            }
            
            // Check failure (process crashed)
            if !isOpenVPNRunning() {
                print("❌ [OpenVPN] Process terminated during connection")
                
                // Try to read log (file I/O automatically on background)
                let errorMessage = extractErrorFromLog() ?? "Connection failed - check log"
                throw OpenVPNError.connectionFailed(errorMessage)
            }
            
            // Wait before next attempt (macOS 11 compatible)
            try await Task.sleep(nanoseconds: 1_000_000_000)  // 1 second

        }
        
        // Timeout
        throw OpenVPNError.connectionFailed("Connection timeout after \(maxAttempts) seconds - check server")
    }
    
    private func extractErrorFromLog() -> String? {
        guard let logContent = try? String(contentsOfFile: logFilePath, encoding: .utf8) else {
            return nil
        }
        
        let lastLines = logContent.components(separatedBy: "\n").suffix(5).joined(separator: " | ")
        print("📋 [OpenVPN] Log: \(lastLines)")
        
        if lastLines.contains("AUTH_FAILED") {
            return "Authentication Failed"
        }
        
        return "Connection failed - check log"
    }

    
    /// Cancel an in-progress connection attempt
    /// Uses management socket (no sudo needed). If socket doesn't exist yet,
    /// Task cancellation in VPNConnectionManager handles stopping the retry loop.
    func cancelConnection() {
        print("🛑 [OpenVPN] Cancelling connection...")
        
        // Try management socket first (NO SUDO NEEDED!)
        if fileManager.fileExists(atPath: managementSocketPath) {
            print("📡 [OpenVPN] Sending cancel via management socket...")
            if sendManagementCommand("signal SIGTERM") {
                print("✅ [OpenVPN] Cancel signal sent via socket")
                return
            }
        }
        
        // If socket doesn't exist, process hasn't fully started
        // The Task cancellation in VPNConnectionManager stops the retry loop
        print("ℹ️ [OpenVPN] No socket yet - Task cancellation will stop the connection")
    }
    
    func disconnect() async throws {
        print("🔌 [OpenVPN] Disconnecting...")
        
        // Try management interface first (NO SUDO REQUIRED!)
        if fileManager.fileExists(atPath: managementSocketPath) {
            print("📡 [OpenVPN] Sending disconnect via management interface...")
            
            if sendManagementCommand("signal SIGTERM") {
                print("✅ [OpenVPN] Graceful disconnect sent via management socket")
                try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
            } else {
                print("⚠️ [OpenVPN] Management socket failed, will try killall")
            }
        }
        
        // Check if there are still processes running
        let processCount = getOpenVPNProcessCount()
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
                    try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                }
            }
        }
        
        // Stop monitoring before cleanup
        print("📊 [OpenVPN] Stopping VPN monitoring...")
        vpnMonitor.stopMonitoring()
        
        // Cleanup all config files and sockets
        currentProcess = nil
        try? fileManager.removeItem(atPath: pidFilePath)
        try? fileManager.removeItem(atPath: managementSocketPath)
        
        // Clean up all .ovpn files in the directory
        if let files = try? fileManager.contentsOfDirectory(atPath: configDirectory) {
            for file in files where file.hasSuffix(".ovpn") {
                try? fileManager.removeItem(atPath: "\(configDirectory)/\(file)")
            }
        }
        
        currentConfigPath = nil
        
        print("✅ [OpenVPN] Disconnected successfully")
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
        let passwordData = try? keychainManager.get(account: "vpn")
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
    
    private func startOpenVPN(configPath: String) async throws {
        // Try to get admin password from Keychain (triggers Touch ID if stored)
        if keychainManager.isPasswordStored() {
            print("🔐 [OpenVPN] Password found in Keychain, using Touch ID...")
            
            do {
                // This will trigger Touch ID prompt
                let password = try await keychainManager.getPassword()
                print("✅ [OpenVPN] Retrieved password via Touch ID")
                
                // Use password with osascript for non-interactive sudo
                try await startOpenVPNWithPassword(password, configPath: configPath)
                
            } catch KeychainManager.KeychainError.authenticationCancelled {
                print("⚠️ [OpenVPN] User cancelled Touch ID")
                throw OpenVPNError.connectionFailed("Touch ID authentication cancelled")
                
            } catch {
                print("⚠️ [OpenVPN] Keychain retrieval failed: \(error). Falling back to system prompt.")
                // Fall back to standard AppleScript prompt
                try await startOpenVPNWithAppleScript(configPath: configPath)
            }
        } else {
            print("🔐 [OpenVPN] No password in Keychain, using system auth prompt...")
            // No password stored, use standard AppleScript prompt
            try await startOpenVPNWithAppleScript(configPath: configPath)
        }
    }
    
    private func startOpenVPNWithPassword(_ password: String, configPath: String) async throws {
        // Use password via stdin for non-interactive sudo
        let command = """
        killall openvpn 2>/dev/null || true
        sleep 1
        echo '\(password)' | sudo -S \(openVPNBinary) --config '\(configPath)'
        """
        
        let task = Process()
        task.launchPath = "/bin/sh"
        task.arguments = ["-c", command]
        task.standardOutput = Pipe()
        task.standardError = Pipe()
        
        do {
            try task.run()
            print("✅ [OpenVPN] Process started with Keychain password (no manual auth needed!)")
            
            // Wait a moment for process to initialize
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            
            // Continue with standard process verification
            try await verifyOpenVPNStarted()
            
        } catch {
            print("❌ [OpenVPN] Failed to start with password: \(error)")
            throw OpenVPNError.connectionFailed("Failed to start OpenVPN: \(error.localizedDescription)")
        }
    }
    
    private func startOpenVPNWithAppleScript(configPath: String) async throws {
        // SINGLE sudo call: kill any existing OpenVPN processes AND start new one
        // This prevents double password prompts!
        let script = """
        do shell script "killall openvpn 2>/dev/null || true; sleep 1; \(openVPNBinary) --config '\(configPath)'" with administrator privileges
        """
        
        print("🔐 [OpenVPN] Requesting admin privileges (Touch ID supported)...")
        print("⏳ [OpenVPN] Waiting for user authentication...")
        
        guard let scriptObject = NSAppleScript(source: script) else {
            throw OpenVPNError.connectionFailed("Failed to create admin prompt script")
        }
        
        var executionError: NSDictionary?
        let _ = scriptObject.executeAndReturnError(&executionError)
        
        if let error = executionError {
            let errorCode = error["NSAppleScriptErrorNumber"] as? Int ?? 0
            let errorMessage = error["NSAppleScriptErrorBriefMessage"] as? String ?? "Unknown error"
            print("❌ [OpenVPN] Admin script error (code: \(errorCode)): \(errorMessage)")
            
            if errorCode == -128 {
                // User cancelled
                throw OpenVPNError.connectionFailed("User cancelled authentication")
            } else {
                throw OpenVPNError.connectionFailed("Script execution failed: \(errorMessage)")
            }
        }
        
        print("✅ [OpenVPN] AppleScript completed - process should be starting")
        
        // Wait a moment for process to initialize
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        // Continue with standard verification
        try await verifyOpenVPNStarted()
    }
    
    private func verifyOpenVPNStarted() async throws {
        // Check if process actually started
        if isOpenVPNRunning() {
            print("✅ [OpenVPN] Process confirmed running")
            
            // Wait for management socket
            var socketWait = 0
            while socketWait < 5 && !fileManager.fileExists(atPath: managementSocketPath) {
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                socketWait += 1
            }
            
            if fileManager.fileExists(atPath: managementSocketPath) {
                print("✅ [OpenVPN] Management socket ready")
                connectToManagementInterface()
                
                // Start monitoring after successful connection
                print("📊 [OpenVPN] Starting VPN monitoring...")
                vpnMonitor.startMonitoring()
                
                // Success!
            } else {
                print("⚠️ [OpenVPN] Management socket not created")
                throw OpenVPNError.connectionFailed("Management socket not available")
            }
        } else {
            print("❌ [OpenVPN] Process failed to start")
            // Try to get error from log
            if let logContent = try? String(contentsOfFile: logFilePath, encoding: .utf8) {
                let lastLines = logContent.components(separatedBy: "\n").suffix(3).joined(separator: " | ")
                print("📋 [OpenVPN] Log: \(lastLines)")
            }
            throw OpenVPNError.connectionFailed("Process failed to start")
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

