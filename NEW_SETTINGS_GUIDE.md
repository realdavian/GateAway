# New Settings Interface - User Guide

## 🎉 Welcome to the Redesigned Settings!

Your TsukubaVPNGate settings have been completely redesigned with a modern, tab-based interface.

---

## 📑 Tab Overview

### 1. 🏠 **Overview** (Home)
Your dashboard for quick information:
- **Backend Status**: See if OpenVPN is installed
- **Quick Install**: One-click installation if needed
- **Live Connection Status**: Real-time VPN state
- **Quick Stats**: Download, upload, and speed at a glance
- **Technical Info**: Protocol, encryption, DNS settings

**When to use**: Quick check of VPN status and backend health

---

### 2. 🖥️ **Servers** (Browse & Connect)
Explore ALL available VPN servers:
- **Search Bar**: Find servers by country, IP, or hostname
- **Sort Options**: 
  - By Country (alphabetical)
  - By Score (best first)
  - By Ping (fastest first)
  - By Speed (fastest first)
- **Server Details**: Flag, country, IP, ping, speed, score
- **Actions**:
  - **Connect**: Manually connect to any server
  - **Blacklist**: Add server to blacklist

**When to use**: When you want to manually choose a specific server

**Pro Tips**:
- Search for "Japan" to see all Japanese servers
- Sort by Ping to find the fastest connection
- Blacklist slow or unreliable servers

---

### 3. 📊 **Monitoring** (Real-time Stats)
Watch your VPN connection in real-time:

**Connection Status**:
- Current state (Connected/Disconnected/Connecting)
- Connection duration (live timer)
- VPN IP address
- Public IP address

**Network Statistics** (updates every second):
- Downloaded data (total)
- Uploaded data (total)
- Current download speed (Mbps)
- Current upload speed (Mbps)
- Ping (when available)

**Technical Details**:
- Protocol (UDP)
- Port (1194)
- Cipher (AES-128-CBC)
- TLS status
- Connection timestamp

**When to use**: Monitor your active VPN connection performance

**Pro Tips**:
- Watch speeds to verify VPN performance
- Check VPN IP to confirm you're connected
- Monitor data usage for metered connections

---

### 4. 🔒 **Security** (Credentials & Settings)
Manage your VPN security:

**VPN Credentials**:
- Username: `vpn` (default for VPNGate)
- Password: `vpn` (default for VPNGate)
- Show/hide password toggle

**Biometric Authentication**:
- Touch ID Setup: Use fingerprint instead of password
- One-time setup for admin access

**Security Features**:
- **Auto-Reconnect**: Automatically reconnect if VPN drops
- **DNS Leak Protection**: Route all DNS through VPN
- **Kill Switch**: Block internet if VPN disconnects (⚠️ use with caution)

**Advanced Security**:
- IPv6 Leak Protection (always enabled)
- Protocol information
- Encryption details

**When to use**: Configure security settings and Touch ID

**Pro Tips**:
- Enable Touch ID for faster connections
- Enable DNS Leak Protection for privacy
- Use Kill Switch only if you need maximum security

---

### 5. 🚫 **Blacklist** (Server Management)
Manage servers you don't want to connect to:

**Blacklist Table**:
- Server details (flag, IP, country, hostname)
- Reason for blacklisting
- Blacklist date
- Expiry date/status
- Remove button

**Add to Blacklist**:
1. Click "Add Server" button
2. Select server from dropdown
3. Enter reason (optional)
4. Choose expiry:
   - 1 Hour
   - 6 Hours
   - 1 Day
   - 1 Week
   - Permanent

**Auto-Cleanup**:
- Toggle to automatically remove expired entries
- Expired entries shown with orange indicator

**When to use**: Blacklist slow, unreliable, or problematic servers

**Pro Tips**:
- Use 1-hour expiry for temporarily slow servers
- Use permanent for consistently bad servers
- Enable auto-cleanup to keep list tidy
- Add reasons to remember why you blacklisted

---

## 🎯 Common Tasks

### Connect to a Specific Server
1. Go to **Servers** tab
2. Search for country (e.g., "Japan")
3. Sort by Ping or Speed
4. Click **Connect** on desired server

### Monitor Your Connection
1. Connect to a VPN server
2. Go to **Monitoring** tab
3. Watch real-time statistics update

### Blacklist a Slow Server
1. Go to **Servers** tab
2. Find the slow server
3. Click blacklist icon (🚫)
4. Choose expiry time
5. Add reason (optional)

### Setup Touch ID
1. Go to **Security** tab
2. Click "Setup" in Biometric Authentication
3. Follow the prompts
4. Grant admin permission once
5. Future connections use Touch ID!

### Check Backend Status
1. Go to **Overview** tab
2. See OpenVPN installation status
3. Click "Install" if needed

---

## 🔍 Visual Indicators

### Connection States
- 🟢 **Green Circle**: Connected
- 🟠 **Orange Dotted**: Connecting
- 🔵 **Blue Clockwise**: Reconnecting
- ⚪ **Gray Circle**: Disconnected
- 🔴 **Red Triangle**: Error

### Server Status
- ✅ **Green Check**: Available
- 🚫 **Red X**: Blacklisted
- ⭐ **Yellow Star**: Favorite (future feature)

### Blacklist Status
- ⏰ **Orange Clock**: Expired entry
- 🗑️ **Red Trash**: Remove button

---

## ⚙️ Settings Explained

### Auto-Reconnect
**What it does**: Automatically reconnects if VPN drops  
**When to enable**: For uninterrupted VPN usage  
**When to disable**: If you want manual control

### DNS Leak Protection
**What it does**: Routes all DNS queries through VPN  
**When to enable**: Always (for privacy)  
**When to disable**: Never (unless troubleshooting)

### Kill Switch
**What it does**: Blocks all internet if VPN disconnects  
**When to enable**: Maximum security scenarios  
**When to disable**: Normal usage (can be disruptive)

⚠️ **Warning**: Kill switch will block internet when VPN is off!

---

## 🚀 Performance Tips

1. **Sort by Ping**: Find fastest servers in Servers tab
2. **Blacklist Slow Servers**: Remove bad servers from rotation
3. **Monitor Stats**: Check Monitoring tab for performance
4. **Use Touch ID**: Faster connections without typing password
5. **Enable Auto-Reconnect**: Seamless reconnection on drops

---

## 🐛 Troubleshooting

### Monitoring tab shows "Disconnected"
**Solution**: Connect to a VPN server first

### Server list is empty
**Solution**: Click refresh button or check internet connection

### Blacklist not working
**Solution**: Check if auto-cleanup is removing entries too quickly

### Touch ID not working
**Solution**: Re-run setup in Security tab

### Stats not updating
**Solution**: Ensure VPN is connected and monitoring tab is active

---

## 📊 Window Layout

```
┌─────────────────────────────────────────────┐
│ Settings                                    │
├──────────┬──────────────────────────────────┤
│          │                                   │
│ Overview │                                   │
│ Servers  │      Active Tab Content          │
│ Monitoring│                                  │
│ Security │                                   │
│ Blacklist│                                   │
│          │                                   │
└──────────┴──────────────────────────────────┘
```

- **Minimum Size**: 900x650 pixels
- **Resizable**: Yes, up to 1400x1000 pixels
- **Sidebar**: Fixed 180px width
- **Content**: Scrollable if needed

---

## 🎨 Keyboard Shortcuts

- **⌘ + ,**: Open Settings (from menu bar)
- **⌘ + W**: Close Settings window
- **⌘ + Q**: Quit application
- **Tab**: Navigate between fields
- **Enter**: Confirm actions

---

## 💡 Pro Tips

1. **Bookmark Favorite Servers**: Use the Servers tab to find and remember good servers
2. **Monitor Performance**: Keep Monitoring tab open while testing servers
3. **Temporary Blacklist**: Use 1-hour expiry to test if server improves
4. **Touch ID is Worth It**: Set it up once, save time forever
5. **Check Overview First**: Quick health check before connecting

---

## 📝 Quick Reference

| Task | Tab | Action |
|------|-----|--------|
| Check status | Overview | View connection card |
| Find server | Servers | Search + sort |
| Connect manually | Servers | Click Connect |
| Watch performance | Monitoring | View live stats |
| Setup Touch ID | Security | Click Setup |
| Block server | Blacklist | Add with expiry |
| Remove blacklist | Blacklist | Click trash icon |

---

## 🎉 Enjoy Your New Settings!

The redesigned interface makes it easier than ever to:
- ✅ Browse and connect to any server
- ✅ Monitor your VPN performance
- ✅ Manage security settings
- ✅ Blacklist problematic servers
- ✅ Check backend status

**Happy VPN browsing!** 🚀

