import SwiftUI

// MARK: - Password Setup View

/// Modal view for setting up Touch ID with admin password
/// Used in SecurityTab for biometric authentication setup
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
