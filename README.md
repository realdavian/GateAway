# TsukubaVPNGate - macOS Menu Bar VPN Client

A native and lightweight macOS menu bar application for connecting to [VPNGate](https://www.vpngate.net/) servers. Simple, fast, and privacy-focused.

<img src="https://img.shields.io/badge/platform-macOS-blue" alt="Platform: macOS"> <img src="https://img.shields.io/badge/macOS-11.0+-green" alt="macOS 11.0+">

## Features

- **🚀 One-Click Connect**: Instantly find and connect to the best available server.
- **📡 WiFi-Style Interface**: Managed entirely from your menu bar, just like your WiFi settings.
- **⚡ Smart Selection**: Automatically tests and selects the fastest servers using parallel latency pings.
- **📊 Real-time Stats**: Track your download/upload speeds and data usage directly in the app.
- **🛡️ Secure & Private**: Uses standard macOS Keychain for credentials and Touch ID for effortless authentication. No tracking. No logs.
- **🔧 Zero Configuration**: Automatically manages and installs necessary VPN binaries on first run.

---

## Requirements

- **macOS 11.0 (Big Sur)** or newer.
- No manual setup required—the app handles all dependencies and permissions automatically.

---

## Getting Started

### 1. Build from Source
Since this is an open-source project, you can build it yourself using Xcode:

1. Clone or download this repository.
2. Open `TsukubaVPNGate.xcodeproj` in Xcode.
3. Press **Cmd + R** to run the application.

### 2. First Launch
- The app will appear in your menu bar (top right) as a small shield or network icon.
- On your first connection attempt, the app may ask for your administrator password once to install the OpenVPN helper.

---

## Usage

### Connecting
- **Best by Country**: Click the menu bar icon, go to "Best by Country," and pick a country. The app will find the fastest server for you.
- **Direct Connect**: Browse the "All Servers" list to pick a specific server based on ping, speed, or uptime.

### Settings
- **Touch ID**: Enable this in Settings to replace password prompts with a simple fingerprint tap.
- **Server Refresh**: The app automatically caches server lists, but you can manually refresh them in the menu.

---

## Privacy

TsukubaVPNGate is built with privacy in mind:
- All connection metrics and history stay strictly on your local machine.
- No external tracking, analytics, or third-party servers are involved in your data flow.
- It is a direct interface between your Mac and the public VPNGate network.

> **Server Logging Disclaimer**: TsukubaVPNGate connects to servers provided by volunteers in the [VPNGate](https://www.vpngate.net) network. While this application does not track your activity, individual server operators (volunteers) may keep their own logs. We have no control over the logging policies of these volunteer servers. Always use the service responsibly and in accordance with local laws.


---

## License

MIT License - see [LICENSE](LICENSE) file  
Made with ❤️ for the macOS community
