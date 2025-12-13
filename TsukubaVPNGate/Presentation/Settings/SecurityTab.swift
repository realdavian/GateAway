import SwiftUI

// MARK: - Security Tab

struct SecurityTab: View {
    @AppStorage("vpn.username") private var vpnUsername: String = "vpn"
    @AppStorage("vpn.password") private var vpnPassword: String = "vpn"
    @AppStorage("security.autoReconnect") private var autoReconnect: Bool = true
    @AppStorage("security.dnsLeakProtection") private var dnsLeakProtection: Bool = true
    @AppStorage("security.killSwitch") private var killSwitch: Bool = false
    
    @State private var showTouchIDSetup: Bool = false
    @State private var showPassword: Bool = false
    
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
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            Image(systemName: "touchid")
                                .font(.title2)
                                .foregroundColor(.green)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Touch ID for Admin Access")
                                    .font(.system(size: 13, weight: .medium))
                                Text("Use Touch ID instead of password when connecting to VPN")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Button(action: { showTouchIDSetup = true }) {
                                Text("Setup")
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.green)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
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
                            Toggle("", isOn: $killSwitch)
                                .labelsHidden()
                                .toggleStyle(SwitchToggleStyle())
                        }
                        
                        if killSwitch {
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
        .sheet(isPresented: $showTouchIDSetup) {
            TouchIDSetupView()
        }
    }
    
    // Cache TTL in minutes
    @AppStorage("serverCacheTTL") private var cacheTTL: Int = 30
}
