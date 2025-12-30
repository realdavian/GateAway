import SwiftUI

// MARK: - Security Tab

struct SecurityTab: View {
    @AppStorage("vpn.username") private var vpnUsername: String = "vpn"
    @AppStorage("vpn.password") private var vpnPassword: String = "vpn"
    @AppStorage("security.autoReconnect") private var autoReconnect: Bool = true
    @AppStorage("security.dnsLeakProtection") private var dnsLeakProtection: Bool = true
    @State private var killSwitchEnabled: Bool = UserDefaults.standard.bool(forKey: "enableKillSwitch")
    
    @State private var showPassword: Bool = false
    @State private var showingPasswordSetup: Bool = false
    @State private var setupPassword: String = ""
    @State private var isPasswordStored: Bool = KeychainManager.shared.isPasswordStored()
    @State private var showingTestResult: Bool = false
    @State private var testResultMessage: String = ""
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                
                // VPN Credentials
                SettingsSection(
                    title: "VPN Credentials",
                    icon: "key.fill",
                    iconColor: .blue
                ) {
                    VStack(alignment: .leading, spacing: 16) {
                        // Info message
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.blue)
                            Text("VPNGate servers use default credentials. These work for all VPNGate servers.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(12)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                        
                        // Username field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Username")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            TextField("Username", text: $vpnUsername)
                                .textFieldStyle(.plain)
                                .padding(10)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                                .disabled(true) // Disabled for VPNGate
                        }
                        
                        // Password field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Password")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            HStack {
                                if showPassword {
                                    TextField("Password", text: $vpnPassword)
                                        .textFieldStyle(.plain)
                                        .disabled(true) // Disabled for VPNGate
                                } else {
                                    SecureField("Password", text: $vpnPassword)
                                        .disabled(true) // Disabled for VPNGate
                                }
                                
                                Button(action: { showPassword.toggle() }) {
                                    Image(systemName: showPassword ? "eye.slash" : "eye")
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(10)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                        }
                        
                        // Note about defaults
                        Text("Note: These are the default VPNGate credentials and cannot be changed.")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }
                
                // Biometric Authentication
                SettingsSection(
                    title: "Biometric Authentication",
                    icon: "touchid",
                    iconColor: .green
                ) {
                    VStack(alignment: .leading, spacing: 16) {
                        // Main toggle/status row
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Touch ID for VPN Connections")
                                    .font(.subheadline)
                                
                                if isPasswordStored {
                                    Text("Password stored securely in Keychain")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                } else {
                                    Text("Store admin password for Touch ID authentication")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            // Status indicator
                            if isPasswordStored {
                                HStack(spacing: 6) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text("Enabled")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                }
                            } else {
                                HStack(spacing: 6) {
                                    Image(systemName: "xmark.circle")
                                        .foregroundColor(.secondary)
                                    Text("Disabled")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        
                        // Action buttons row (right-aligned macOS style)
                        HStack {
                            Spacer()
                            
                            if !isPasswordStored {
                                Button("Enable Touch ID...") {
                                    showingPasswordSetup = true
                                }
                            } else {
                                Button("Test Touch ID...") {
                                    testTouchID()
                                }
                                
                                Button("Remove...") {
                                    removeStoredPassword()
                                }
                            }
                        }
                    }
                }
                
                // Security Features
                SettingsSection(
                    title: "Security Features",
                    icon: "shield.fill",
                    iconColor: .purple
                ) {
                    VStack(alignment: .leading, spacing: 16) {
                        // Auto-reconnect
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Auto-Reconnect")
                                    .font(.subheadline)
                                Text("Automatically reconnect if VPN connection drops")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Toggle("", isOn: $autoReconnect)
                                .labelsHidden()
                                .toggleStyle(SwitchToggleStyle())
                        }
                        
                        Divider()
                        
                        // DNS Leak Protection
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("DNS Leak Protection")
                                    .font(.subheadline)
                                Text("Route all DNS queries through VPN tunnel")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Toggle("", isOn: $dnsLeakProtection)
                                .labelsHidden()
                                .toggleStyle(SwitchToggleStyle())
                        }
                        
                        Divider()
                        
                        // Kill Switch
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Kill Switch")
                                    .font(.subheadline)
                                HStack(spacing: 4) {
                                    Text("Block internet if VPN disconnects")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.caption2)
                                        .foregroundColor(.orange)
                                }
                            }
                            Spacer()
                            Toggle("", isOn: $killSwitchEnabled)
                                .labelsHidden()
                                .toggleStyle(SwitchToggleStyle())
                        }
                        
                        if killSwitchEnabled {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text("Kill switch will block all internet traffic when VPN is disconnected")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                            .padding(12)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                }
                
                // Advanced Settings (includes network settings + cache)
                SettingsSection(
                    title: "Advanced",
                    icon: "gearshape.2.fill",
                    iconColor: .gray
                ) {
                    VStack(alignment: .leading, spacing: 16) {
                        // IPv6 leak protection
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("IPv6 Leak Protection")
                                    .font(.subheadline)
                                Text("Disable IPv6 to prevent leaks")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Text("Enabled")
                                .font(.caption)
                                .foregroundColor(.green)
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                        
                        Divider()
                        
                        // Protocol
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("VPN Protocol")
                                    .font(.subheadline)
                                Text("OpenVPN UDP (fastest)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        
                        Divider()
                        
                        // Encryption
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Encryption")
                                    .font(.subheadline)
                                Text("AES-128-CBC with TLS 1.2+")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        
                        Divider()
                        
                        // Server Cache TTL
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Server List Cache Duration")
                                    .font(.subheadline)
                                Spacer()
                                Picker("Cache TTL", selection: $cacheTTL) {
                                    Text("5 min").tag(5)
                                    Text("15 min").tag(15)
                                    Text("30 min").tag(30)
                                    Text("1 hour").tag(60)
                                    Text("2 hours").tag(120)
                                    Text("24 hours").tag(1440)
                                }
                                .pickerStyle(.menu)
                                .frame(width: 180)
                            }
                            
                            Text("How long to keep the server list cached before refreshing from VPN Gate.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            // Cache status
                            if let cacheAge = ServerCacheManager.shared.getCacheAge() {
                                let ageMinutes = Int(cacheAge / 60)
                                let isExpired = cacheAge > TimeInterval(cacheTTL * 60)
                                
                                HStack(spacing: 6) {
                                    Image(systemName: isExpired ? "clock.badge.exclamationmark" : "clock.fill")
                                        .foregroundColor(isExpired ? .orange : .green)
                                        .font(.caption)
                                    
                                    if isExpired {
                                        Text("Cache expired (\(ageMinutes) min ago)")
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                    } else {
                                        Text("Last updated \(ageMinutes) min ago")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Button("Clear Cache") {
                                        ServerCacheManager.shared.clearCache()
                                        print("🗑️ Cache cleared by user")
                                    }
                                    .font(.caption)
                                }
                                .padding(.vertical, 4)
                            } else {
                                HStack(spacing: 6) {
                                    Image(systemName: "tray")
                                        .foregroundColor(.secondary)
                                        .font(.caption)
                                    Text("No cached data")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
            }
            .padding()
            
        }
        .sheet(isPresented: $showingPasswordSetup) {
            PasswordSetupView(
                password: $setupPassword,
                onSave: {
                    savePasswordToKeychain()
                }
            )
        }
        .alert(isPresented: $showingTestResult) {
            Alert(
                title: Text(testResultMessage.contains("✅") ? "Success" : "Failed"),
                message: Text(testResultMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    // MARK: - Helper Methods
    
    private func savePasswordToKeychain() {
        do {
            try KeychainManager.shared.savePassword(setupPassword)
            isPasswordStored = true
            setupPassword = "" // Clear for security
            print("✅ Password saved to Keychain")
        } catch {
            testResultMessage = "❌ Failed to save password: \(error.localizedDescription)"
            showingTestResult = true
        }
    }
    
    private func testTouchID() {
        Task {
            do {
                let _ = try await KeychainManager.shared.getPassword()
                await MainActor.run {
                    testResultMessage = "✅ \(KeychainManager.biometricType()) authentication successful!"
                    showingTestResult = true
                }
            } catch {
                await MainActor.run {
                    testResultMessage = "❌ Failed: \(error.localizedDescription)"
                    showingTestResult = true
                }
            }
        }
    }
    
    private func removeStoredPassword() {
        do {
            try KeychainManager.shared.deletePassword()
            isPasswordStored = false
            print("✅ Password removed from Keychain")
        } catch {
            testResultMessage = "❌ Failed to remove password: \(error.localizedDescription)"
            showingTestResult = true
        }
    }
    
    // Cache TTL in minutes
    @AppStorage("serverCacheTTL") private var cacheTTL: Int = 30
}

// MARK: - Password Setup View

struct PasswordSetupView: View {
    @Environment(\.presentationMode) var presentationMode
    @Binding var password: String
    let onSave: () -> Void
    
    @State private var showPassword: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Enable Touch ID for VPN")
                    .font(.headline)
                Spacer()
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // Content
            VStack(alignment: .leading, spacing: 20) {
                // Info box
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title2)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Your admin password will be securely stored")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("Future VPN connections will use Touch ID instead of requiring you to type your password.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(12)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
                
                // Password field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Admin Password")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    HStack {
                        if showPassword {
                            TextField("", text: $password)
                                .textFieldStyle(.plain)
                        } else {
                            SecureField("", text: $password)
                                .textFieldStyle(.plain)
                        }
                        
                        Button(action: { showPassword.toggle() }) {
                            Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(8)
                    .background(Color(NSColor.textBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    )
                    .cornerRadius(6)
                    
                    Text("The password you use for 'sudo' commands")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            
            Spacer()
            
            Divider()
            
            // Footer buttons
            HStack(spacing: 12) {
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("Enable Touch ID") {
                    onSave()
                    presentationMode.wrappedValue.dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(password.isEmpty)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 480, height: 320)
    }
}
