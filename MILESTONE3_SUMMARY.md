# Milestone 3: Tunnelblick Fix & Dynamic Backend Switching ✅

## Completion Status: DONE 🎉

---

## Changes Made

### 1. Fixed Tunnelblick Backend ✅

**Problem**: Tunnelblick was using drag-and-drop import which required user interaction

**Solution**: 
- Create `.tblk` bundle directly in Tunnelblick's config directory
- Add inline auth credentials (`<auth-user-pass>vpn\nvpn</auth-user-pass>`)
- Use AppleScript to connect and wait for CONNECTED state (up to 30 seconds)

**Key Improvements**:
```swift
// Before: Complex drag-and-drop with NSWorkspace
NSWorkspace.shared.open([ovpnURL], withApplicationAt: tunnelblickURL)
Thread.sleep(5.0) // Hope it imported...

// After: Direct .tblk creation
let tblkURL = configsDir.appendingPathComponent("\(configName).tblk")
try fileManager.createDirectory(at: tblkURL)
// ... create bundle structure
// Tell Tunnelblick to reload
```

**Connection Flow**:
```applescript
tell application "Tunnelblick"
    connect "VPNGate_JP_123456"
    
    -- Wait for connection (up to 30 seconds)
    repeat 30 times
        delay 1
        set configState to state of configuration "VPNGate_JP_123456"
        if configState is "CONNECTED" then
            return "CONNECTED"
        end if
    end repeat
    
    return "TIMEOUT"
end tell
```

---

### 2. Dynamic Backend Switching ✅

**Problem**: Changing VPN provider required app restart

**Solution**: Implemented hot-swapping via NotificationCenter

**Architecture**:
```
SettingsView
  ↓ (user changes picker)
  ↓ NotificationCenter.post("SwitchVPNBackend")
  ↓
AppDelegate.handleBackendSwitchNotification()
  ↓
  1. Disconnect current VPN
  2. Create new VPN controller (OpenVPN or Tunnelblick)
  3. Create new VPNConnectionManager
  4. Create new AppCoordinator
  5. Update StatusBarController with new coordinator
  ↓
StatusBarController.updateCoordinator()
  ↓ rebuildMenu()
  ↓
✅ New backend active!
```

**Key Files Modified**:

#### AppDelegate.swift
```swift
// Store references for dynamic switching
private var connectionManager: VPNConnectionManager?
private var preferencesManager: PreferencesManagerProtocol?
private var currentBackend: UserPreferences.VPNProvider?

// Listen for backend switch notifications
NotificationCenter.default.addObserver(
    self,
    selector: #selector(handleBackendSwitchNotification(_:)),
    name: NSNotification.Name("SwitchVPNBackend"),
    object: nil
)

// Switch backend without restart
@objc private func handleBackendSwitchNotification(_ notification: Notification) {
    guard let provider = notification.userInfo?["provider"] as? UserPreferences.VPNProvider else {
        return
    }
    
    switchVPNBackend(to: provider)
}

func switchVPNBackend(to newBackend: UserPreferences.VPNProvider) {
    // 1. Disconnect current VPN
    connectionManager?.disconnect { [weak self] _ in
        DispatchQueue.main.async {
            // 2. Recreate all dependencies with new backend
            self?.setupVPNBackend()
        }
    }
}
```

#### StatusBarController.swift
```swift
// Change coordinator from 'let' to 'var'
private var coordinator: AppCoordinatorProtocol

// Add update method
func updateCoordinator(_ newCoordinator: AppCoordinatorProtocol) {
    print("🔄 [StatusBarController] Updating coordinator (backend switched)")
    self.coordinator = newCoordinator
    rebuildMenu()
}
```

#### SettingsView.swift
```swift
// Trigger backend switch on picker change
.onChange(of: vpnProviderRaw) { newValue in
    switchVPNBackend(to: newValue)
}

private func switchVPNBackend(to newProviderRaw: String) {
    // Post notification to AppDelegate
    NotificationCenter.default.post(
        name: NSNotification.Name("SwitchVPNBackend"),
        object: nil,
        userInfo: ["provider": newProvider]
    )
    
    // Show success message
    showRestartAlert = true
}
```

---

## Testing

### Tunnelblick Connection Test

1. **Install Tunnelblick** (if not installed):
```bash
brew install --cask tunnelblick
```

2. **Switch to Tunnelblick backend**:
- Open Settings
- Select "Tunnelblick" from VPN Backend dropdown
- See "Backend switched successfully!" message

3. **Connect to VPN**:
- Choose "Best by Country" → Select a country
- Grant automation permission if prompted
- Wait for connection (up to 30 seconds)
- Verify IP changed: `curl ifconfig.me`

### Backend Switching Test

1. **Start with OpenVPN**:
```bash
# In Settings, select "OpenVPN"
# Connect to a Japanese server
curl ifconfig.me  # Should show Japanese IP
```

2. **Switch to Tunnelblick** (without restart):
```bash
# In Settings, select "Tunnelblick"
# Wait for disconnect → backend switch
# Reconnect to same country
curl ifconfig.me  # Should still work!
```

3. **Switch back to OpenVPN**:
```bash
# In Settings, select "OpenVPN"
# Instant switch, no restart needed ✅
```

---

## Architecture Benefits

### Before Milestone 3
- ❌ Tunnelblick required manual user interaction
- ❌ Backend switch required app restart
- ❌ Tight coupling between AppDelegate and VPN backend

### After Milestone 3
- ✅ Tunnelblick fully automated (like OpenVPN)
- ✅ Backend switch happens instantly (no restart)
- ✅ Loose coupling via NotificationCenter
- ✅ Single source of truth for backend selection (UserDefaults)

---

## Code Quality Improvements

### 1. Consistent VPN Controller Interface

Both backends now implement:
```swift
protocol VPNControlling {
    func connect(server: VPNServer, completion: @escaping (Result<Void, Error>) -> Void)
    func disconnect(completion: @escaping (Result<Void, Error>) -> Void)
}
```

### 2. Simplified Connection Flow

**OpenVPN**:
1. Create config with auth credentials
2. Start process via AppleScript (sudo + Touch ID)
3. Query management socket for CONNECTED state
4. Report success/failure

**Tunnelblick**:
1. Create .tblk bundle with inline auth
2. Connect via AppleScript
3. Poll Tunnelblick's state API for CONNECTED
4. Report success/failure

Both wait for actual connection before reporting success! ✅

### 3. Dynamic Dependency Injection

```swift
// Old: Hardcoded at launch
let vpnController: VPNControlling = OpenVPNController()

// New: Dynamic based on preferences
func setupVPNBackend() {
    let preferences = preferencesManager.loadPreferences()
    let vpnController: VPNControlling
    
    switch preferences.vpnProvider {
    case .tunnelblick:
        vpnController = TunnelblickVPNController()
    case .openVPN:
        vpnController = OpenVPNController()
    }
    
    // Inject into manager
    let connectionManager = VPNConnectionManager(controller: vpnController)
}
```

---

## Known Issues & Future Work

### Current Limitations

1. **Tunnelblick Automation Permission**
   - First-time connection requires granting automation permission
   - User may need to restart Tunnelblick after granting permission
   - Not a bug, just macOS security requirement

2. **Backend Switch During Active Connection**
   - Currently disconnects, then switches
   - Could be improved to remember last server and auto-reconnect

### Potential Improvements

1. **Auto-reconnect after backend switch**
```swift
// Store last connected server
let lastServer = coordinator.getLastConnectedServer()

// After backend switch
if let server = lastServer {
    coordinator.connect(to: server)
}
```

2. **Backend status indicators**
```
Settings UI:
✅ OpenVPN CLI (Active)
⚪ Tunnelblick (Installed)
```

3. **Tunnelblick config cleanup**
```swift
// Remove old VPNGate configs periodically
func cleanupOldConfigs() {
    let configsDir = ...
    let files = try fileManager.contentsOfDirectory(at: configsDir)
    
    for file in files where file.lastPathComponent.hasPrefix("VPNGate_") {
        let age = Date().timeIntervalSince(file.creationDate)
        if age > 7 * 24 * 60 * 60 { // 7 days
            try? fileManager.removeItem(at: file)
        }
    }
}
```

---

## Summary

| Feature | Status | Notes |
|---------|--------|-------|
| Tunnelblick Backend | ✅ Fixed | Direct .tblk creation, inline auth |
| OpenVPN Backend | ✅ Working | Management socket, proper routing |
| Backend Switching | ✅ Dynamic | No restart needed, instant switch |
| Connection Status | ✅ Accurate | Both backends report real state |
| UI Updates | ✅ Real-time | didSet observer pattern |
| Code Quality | ✅ Clean | SOLID principles, good separation |

---

**Next**: Milestone 4 - Code cleanup, remove VPNStatusMonitor, polish UI! 🚀

