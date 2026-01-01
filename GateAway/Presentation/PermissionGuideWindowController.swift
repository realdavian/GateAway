import AppKit
import SwiftUI

// MARK: - Permission Guide Window Controller

final class PermissionGuideWindowController: NSWindowController {
    init() {
        let rootView = PermissionGuideContentView()
        let hosting = NSHostingController(rootView: rootView)
        
        let window = NSWindow(contentViewController: hosting)
        window.title = "Setup Required"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 520, height: 400))
        window.isReleasedWhenClosed = false
        window.level = .floating // Keep on top
        
        // Add glass/vibrancy effect (native macOS look)
        if #available(macOS 10.14, *) {
            window.titlebarAppearsTransparent = true
            window.backgroundColor = .clear
            
            // Add vibrancy to the content view
            let visualEffect = NSVisualEffectView()
            visualEffect.blendingMode = .behindWindow
            visualEffect.state = .active
            visualEffect.material = .hudWindow // Modern glass effect
            
            let contentView = NSView()
            contentView.addSubview(visualEffect)
            visualEffect.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                visualEffect.topAnchor.constraint(equalTo: contentView.topAnchor),
                visualEffect.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                visualEffect.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                visualEffect.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
            ])
            
            hosting.view.translatesAutoresizingMaskIntoConstraints = false
            visualEffect.addSubview(hosting.view)
            NSLayoutConstraint.activate([
                hosting.view.topAnchor.constraint(equalTo: visualEffect.topAnchor),
                hosting.view.leadingAnchor.constraint(equalTo: visualEffect.leadingAnchor),
                hosting.view.trailingAnchor.constraint(equalTo: visualEffect.trailingAnchor),
                hosting.view.bottomAnchor.constraint(equalTo: visualEffect.bottomAnchor)
            ])
            
            window.contentView = contentView
        } else {
            // Fallback for older macOS
            window.contentViewController = hosting
        }
        
        super.init(window: window)
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }
    
    func show(completion: @escaping (Bool) -> Void) {
        guard let hosting = window?.contentViewController as? NSHostingController<PermissionGuideContentView> else { return }
        
        // Update the view with completion handler
        hosting.rootView = PermissionGuideContentView { proceed in
            self.window?.close()
            completion(proceed)
        }
        
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

struct PermissionGuideContentView: View {
    var onComplete: ((Bool) -> Void)?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with icon
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.blue)
                }
                
                Text("Permission Setup")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("GateAway needs permission to control Tunnelblick")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 30)
            .padding(.bottom, 20)
            
            Divider()
            
            // Instructions
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    InstructionStepView(
                        number: 1,
                        title: "macOS will show a permission dialog",
                        description: "When you click 'Continue', macOS will ask for permission to control Tunnelblick.",
                        icon: "shield.checkered"
                    )
                    
                    InstructionStepView(
                        number: 2,
                        title: "Click 'OK' on the system dialog",
                        description: "This allows GateAway to automatically connect and disconnect VPN servers.",
                        icon: "hand.point.up.left.fill"
                    )
                    
                    InstructionStepView(
                        number: 3,
                        title: "You're done!",
                        description: "This permission only needs to be granted once. You can manage it later in System Settings.",
                        icon: "checkmark.circle.fill"
                    )
                    
                    Divider()
                        .padding(.vertical, 8)
                    
                    // Settings link
                    HStack(spacing: 8) {
                        Image(systemName: "gearshape.2")
                            .foregroundColor(.secondary)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("You can manage permissions at any time:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Button(action: openSystemSettings) {
                                Text("System Settings → Privacy & Security → Automation")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
                .padding()
            }
            
            Divider()
            
            // Action buttons
            HStack(spacing: 12) {
                Button("Cancel") {
                    onComplete?(false)
                }
                .keyboardShortcut(.escape)
                
                Spacer()
                
                Button("Continue") {
                    onComplete?(true)
                }
                .keyboardShortcut(.return)
            }
            .padding()
        }
    }
    
    private func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
            NSWorkspace.shared.open(url)
        }
    }
}

struct InstructionStepView: View {
    let number: Int
    let title: String
    let description: String
    let icon: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.15))
                    .frame(width: 36, height: 36)
                
                Text("\(number)")
                    .font(.system(.body, design: .rounded).weight(.bold))
                    .foregroundColor(.accentColor)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .foregroundColor(.accentColor)
                    
                    Text(title)
                        .font(.headline)
                }
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
    }
}

