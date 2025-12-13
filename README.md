# TsukubaVPNGate - macOS Menu Bar VPN Client

A native macOS menu bar application for connecting to [VPNGate](https://www.vpngate.net/) servers with ease.

<img src="https://img.shields.io/badge/platform-macOS-blue" alt="Platform: macOS"> <img src="https://img.shields.io/badge/Swift-5.9-orange" alt="Swift 5.9"> <img src="https://img.shields.io/badge/macOS-11.0+-green" alt="macOS 11.0+">

## Features

✅ **Dual Backend Support**
- OpenVPN CLI (headless, recommended)
- Tunnelblick (GUI-based alternative)
- Switch between backends without restarting

✅ **Smart Server Selection**
- Browse by country
- Sort by ping/speed/uptime
- Auto-select best server per country
- Real-time server list from VPNGate API

✅ **Menu Bar Integration**
- Native macOS menu bar app
- WiFi-style interface
- Connection status indicator
- Quick connect/disconnect

✅ **Modern macOS Features**
- Touch ID for sudo prompts
- Dark/Light mode support
- Native notifications
- Secure credential storage

✅ **Minimal & Clean**
- No bloatware
- Open source
- Privacy-focused
- No tracking or analytics

---

## Requirements

- macOS 11.0 (Big Sur) or later
- **OpenVPN** (for OpenVPN backend) - installed via Homebrew
- **Tunnelblick** (for Tunnelblick backend) - optional

---

## Installation

### 1. Clone Repository

```bash
git clone https://github.com/yourusername/TsukubaVPNGate.git
cd TsukubaVPNGate
```

### 2. Install Dependencies

**OpenVPN CLI** (recommended):
```bash
brew install openvpn
```

**Tunnelblick** (optional):
```bash
brew install --cask tunnelblick
```

### 3. Build & Run

Open `TsukubaVPNGate.xcodeproj` in Xcode and build (⌘ + B), or:

```bash
xcodebuild -project TsukubaVPNGate.xcodeproj -scheme TsukubaVPNGate -configuration Release
```

---

## Usage

### First Launch

1. The app appears in your menu bar (🔓 icon)
2. Open Settings to:
   - Select VPN backend (OpenVPN or Tunnelblick)
   - Configure auto-reconnect
   - Set country preferences
   - Enable Touch ID for sudo

### Connecting to VPN

**Option 1: Best by Country**
1. Click menu bar icon
2. Select "Best by Country" → Choose a country
3. App automatically selects the fastest server
4. Wait for connection (status icon changes to 🔒)

**Option 2: Quick Best**
1. Click "Connect to Best Overall"
2. Connects to the globally fastest server

### Switching Backends

1. Open Settings (⚙️)
2. Select VPN Backend: OpenVPN or Tunnelblick
3. Backend switches instantly (no restart needed)
4. Reconnect to apply

### Disconnecting

- Click menu bar icon → "Disconnect"
- Or click the status icon directly

---

## Touch ID Setup

Enable Touch ID for `sudo` commands (no more password typing!):

1. Open Settings → Authentication
2. Click "Setup Touch ID"
3. Follow the prompts
4. Grant admin permission once
5. Future VPN connections use Touch ID! ✨

---

## Architecture

```
Presentation Layer
  ├── StatusBarController (Menu bar UI)
  ├── SettingsView (Preferences UI)
  └── AppDelegate (Lifecycle)

Domain Layer
  ├── VPNConnectionManager (Connection logic)
  ├── AppCoordinator (Service orchestration)
  ├── ServerSelectionService (Best server algorithm)
  └── VPNGateAPI (Server list fetching)

Infrastructure Layer
  ├── OpenVPNController (OpenVPN CLI backend)
  ├── TunnelblickVPNController (Tunnelblick backend)
  ├── ServerRepository (Local caching)
  └── PreferencesManager (UserDefaults wrapper)
```

**Design Principles**: SOLID, Clean Architecture, Dependency Injection

---

## Configuration

### OpenVPN Backend

**Auto-configured with**:
- Authentication: `vpn/vpn` (VPNGate default)
- Routing: Full tunnel (`redirect-gateway def1`)
- DNS: Google DNS (8.8.8.8, 8.8.4.4)
- Cipher: AES-128-CBC (fallback: AES-256-GCM)
- Management: Unix socket for programmatic control

### Tunnelblick Backend

**Auto-configured with**:
- Creates `.tblk` bundles automatically
- Inline auth credentials
- AppleScript-based control
- Automatic config cleanup

---

## Troubleshooting

### VPN Not Connecting

**OpenVPN**:
```bash
# Check if OpenVPN is running
ps aux | grep openvpn

# Check logs
tail -f ~/Library/Application\ Support/TsukubaVPNGate/openvpn.log

# Test routing
./test-vpn-routing.sh
```

**Tunnelblick**:
- Check System Settings → Privacy & Security → Automation
- Grant permission to control Tunnelblick
- Restart Tunnelblick if needed

### IP Not Changing

```bash
# Check current IP
curl ifconfig.me

# Check routing
route -n get 8.8.8.8 | grep interface

# Should show: interface: utun8 (or similar VPN interface)
```

### Touch ID Not Working

```bash
# Check if Touch ID is enabled for sudo
grep -q 'pam_tid.so' /etc/pam.d/sudo && echo "✅ Enabled" || echo "❌ Disabled"

# Re-enable via Settings → Authentication → Setup Touch ID
```

---

## Testing Scripts

### Test VPN Connection Status
```bash
./test-openvpn-state.sh
```

### Test VPN Routing
```bash
./test-vpn-routing.sh
```

---

## Development

### Project Structure

```
TsukubaVPNGate/
├── Presentation/          # UI Layer
│   ├── AppDelegate.swift
│   ├── StatusBarController.swift
│   ├── SettingsView.swift
│   └── TouchIDSetupView.swift
├── Domain/                # Business Logic
│   ├── VPNConnectionManager.swift
│   ├── AppCoordinator.swift
│   ├── ServerSelectionService.swift
│   └── VPNGateAPI.swift
├── Infrastructure/        # External Integrations
│   ├── OpenVPNController.swift
│   ├── TunnelblickVPNController.swift
│   ├── ServerRepository.swift
│   └── PreferencesManager.swift
└── Models/                # Data Models
    ├── VPNServer.swift
    └── UserPreferences.swift
```

### Build Configurations

**Debug**:
- Dock icon visible (for easier debugging)
- Verbose logging
- Shorter timeouts

**Release**:
- Menu bar only (no Dock icon)
- Minimal logging
- Production timeouts

### Adding a New VPN Backend

1. Implement `VPNControlling` protocol:

```swift
protocol VPNControlling {
    func connect(server: VPNServer, completion: @escaping (Result<Void, Error>) -> Void)
    func disconnect(completion: @escaping (Result<Void, Error>) -> Void)
}
```

2. Add to `UserPreferences.VPNProvider` enum
3. Update `AppDelegate.setupVPNBackend()` switch statement
4. Add UI in `SettingsView`

---

## Milestones

✅ **Milestone 1**: Menu bar UI, server fetching, basic architecture  
✅ **Milestone 2**: OpenVPN CLI integration, proper routing  
✅ **Milestone 3**: Tunnelblick support, dynamic backend switching  
🚧 **Milestone 4**: Auto-reconnect, connection monitoring (in progress)  
📋 **Milestone 5**: App Store release, notarization  

---

## Contributing

Contributions welcome! Please:
1. Follow Swift style guide
2. Maintain SOLID principles
3. Write tests for new features
4. Update documentation

---

## License

MIT License - see [LICENSE](LICENSE) file

---

## Acknowledgments

- [VPNGate](https://www.vpngate.net/) - Free VPN servers
- [OpenVPN](https://openvpn.net/) - Open source VPN protocol
- [Tunnelblick](https://tunnelblick.net/) - macOS OpenVPN client

---

## Support

Issues? Questions? Open an issue on GitHub!

**Logs Location**:
- OpenVPN: `~/Library/Application Support/TsukubaVPNGate/openvpn.log`
- Configs: `~/Library/Application Support/TsukubaVPNGate/configs/`
- Tunnelblick: `~/Library/Application Support/Tunnelblick/Configurations/`

---

Made with ❤️ for the macOS community

