import SwiftUI

// MARK: - Security Toggle Row

/// Reusable toggle row for security settings
/// Used in SecurityTab for Auto-Reconnect, DNS Leak Protection, Kill Switch
struct SecurityToggleRow: View {
    let title: String
    let description: String
    @Binding var isOn: Bool
    var warningIcon: Bool = false
    var warningText: String? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline)
                    HStack(spacing: 4) {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        if warningIcon {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                    }
                }
                Spacer()
                Toggle("", isOn: $isOn)
                    .labelsHidden()
                    .toggleStyle(SwitchToggleStyle())
            }
            
            if let warning = warningText, isOn {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(warning)
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                .padding(12)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }
}
