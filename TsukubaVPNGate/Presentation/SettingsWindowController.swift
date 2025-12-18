import AppKit
import SwiftUI

// MARK: - Settings Window Controller (Presentation Layer - SRP: Window management)

final class SettingsWindowController: NSWindowController {
    init(coordinator: AppCoordinatorProtocol,
         monitoringStore: MonitoringStore,
         serverStore: ServerStore) {
        let coordinatorWrapper = CoordinatorWrapper(coordinator)
        let rootView = SettingsView()
            .environmentObject(coordinatorWrapper)
            .environmentObject(monitoringStore)
            .environmentObject(serverStore)
        let hosting = NSHostingController(rootView: rootView)
        
        let window = NSWindow(contentViewController: hosting)
        window.title = "TsukubaVPNGate Settings"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: 900, height: 650))
        window.minSize = NSSize(width: 900, height: 650)
        window.maxSize = NSSize(width: 1400, height: 1000)
        window.isReleasedWhenClosed = false
        window.titlebarAppearsTransparent = false
        
        super.init(window: window)
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }
    
    func show() {
        window?.center()
        window?.makeKeyAndOrderFront(nil)
    }
}

