# Milestone 3 Testing Checklist

## Prerequisites

- [ ] OpenVPN installed: `brew install openvpn`
- [ ] Tunnelblick installed: `brew install --cask tunnelblick`
- [ ] Touch ID configured: Settings → Authentication → Setup Touch ID
- [ ] Automation permission granted (will be prompted on first use)

---

## Test 1: OpenVPN Backend Connection

### Steps

1. **Open Settings**
   - [ ] Click menu bar icon → Settings (⚙️)
   - [ ] Verify "VPN Backend" section shows OpenVPN and Tunnelblick

2. **Select OpenVPN Backend**
   - [ ] Select "OpenVPN" from dropdown
   - [ ] Verify green checkmark message appears
   - [ ] Verify no restart required

3. **Connect to VPN**
   - [ ] Click menu bar icon
   - [ ] Select "Best by Country" → Choose Japan
   - [ ] Touch ID prompt should appear (or password)
   - [ ] Wait for connection (icon should change to 🔒)
   - [ ] Verify menu shows "Connected" and server details

4. **Verify Connection**
   ```bash
   # Check external IP
   curl ifconfig.me  # Should show Japanese IP
   
   # Check routing
   ./test-vpn-routing.sh  # Should show "✅ PASS"
   
   # Check OpenVPN state
   ./test-openvpn-state.sh  # Should show "CONNECTED"
   ```

5. **Expected Results**
   - [ ] IP changed to Japan
   - [ ] Routing table shows VPN tunnel (utun8 or similar)
   - [ ] Console shows: `✅ [VPNConnectionManager] Connected successfully`
   - [ ] Menu bar icon is locked (🔒)
   - [ ] No error messages

6. **Disconnect**
   - [ ] Click menu bar icon → Disconnect
   - [ ] Should disconnect gracefully (no sudo prompt)
   - [ ] Icon changes to unlocked (🔓)
   - [ ] IP returns to original

---

## Test 2: Tunnelblick Backend Connection

### Steps

1. **Switch to Tunnelblick**
   - [ ] Open Settings → VPN Backend
   - [ ] Select "Tunnelblick" from dropdown
   - [ ] Verify green checkmark message
   - [ ] Verify app doesn't restart

2. **Connect to VPN**
   - [ ] Click menu bar icon
   - [ ] Select "Best by Country" → Choose Canada
   - [ ] Automation permission dialog may appear (grant it)
   - [ ] Touch ID/password prompt should appear
   - [ ] Wait for connection (up to 30 seconds)
   - [ ] Verify menu shows "Connected"

3. **Verify Connection**
   ```bash
   # Check external IP
   curl ifconfig.me  # Should show Canadian IP
   
   # Check Tunnelblick configs
   ls ~/Library/Application\ Support/Tunnelblick/Configurations/
   # Should show VPNGate_CA_* folder
   ```

4. **Expected Results**
   - [ ] IP changed to Canada
   - [ ] Tunnelblick shows active connection in its menu
   - [ ] Console shows: `✅ [Tunnelblick] Connected successfully!`
   - [ ] Menu bar icon is locked (🔒)

5. **Disconnect**
   - [ ] Click menu bar icon → Disconnect
   - [ ] Tunnelblick disconnects
   - [ ] Icon changes to unlocked (🔓)

---

## Test 3: Dynamic Backend Switching

### Scenario A: Switch While Disconnected

1. **Start with OpenVPN (disconnected)**
   - [ ] Verify status: Disconnected
   - [ ] Open Settings → Switch to Tunnelblick
   - [ ] Verify backend switches without restart
   - [ ] Connect to a server
   - [ ] Verify Tunnelblick is actually used

2. **Switch Back**
   - [ ] Disconnect
   - [ ] Open Settings → Switch to OpenVPN
   - [ ] Connect to a server
   - [ ] Verify OpenVPN is used

### Scenario B: Switch While Connected

1. **Start with OpenVPN (connected)**
   - [ ] Connect to Japan via OpenVPN
   - [ ] Verify connected (check IP)
   - [ ] Open Settings → Switch to Tunnelblick
   - [ ] Verify app auto-disconnects first
   - [ ] Verify backend switches
   - [ ] Reconnect to Canada via Tunnelblick
   - [ ] Verify connection works

2. **Expected Behavior**
   - [ ] No app restart needed
   - [ ] Clean disconnect before switch
   - [ ] New backend works immediately
   - [ ] UI updates correctly

---

## Test 4: UI Status Updates

### Test Status Icons

- [ ] Disconnected: 🔓 (unlocked)
- [ ] Connecting: ⏳ (or spinning)
- [ ] Connected: 🔒 (locked)
- [ ] Error: ⚠️ (warning)

### Test Menu Items

**When Disconnected**:
- [ ] "Connect to Best Overall" enabled
- [ ] "Best by Country" submenu enabled
- [ ] "Disconnect" disabled/grayed
- [ ] Status shows "Disconnected"

**When Connected**:
- [ ] "Connect to Best Overall" disabled/grayed
- [ ] "Best by Country" disabled/grayed
- [ ] "Disconnect" enabled
- [ ] Status shows "Connected to [Country]"
- [ ] Server details visible (IP, speed, ping)

---

## Test 5: Error Handling

### Test No Internet

1. **Disconnect WiFi**
   - [ ] Try connecting to VPN
   - [ ] Verify error message shown
   - [ ] Verify app doesn't crash

### Test Invalid Server

1. **Connect to oldest/slowest server**
   - [ ] Select a low-score server
   - [ ] Try connecting
   - [ ] If fails, verify error is shown
   - [ ] App should remain functional

### Test Permission Denied

1. **Deny Touch ID prompt**
   - [ ] Try connecting
   - [ ] Cancel Touch ID prompt
   - [ ] Verify error message
   - [ ] App should not crash

---

## Test 6: Settings Persistence

1. **Change Settings**
   - [ ] Set Auto-reconnect: ON
   - [ ] Set Top K servers: 5
   - [ ] Set VPN Backend: Tunnelblick
   - [ ] Add preferred countries: Japan, Canada

2. **Restart App**
   - [ ] Quit app (⌘ + Q)
   - [ ] Relaunch
   - [ ] Open Settings
   - [ ] Verify all settings persisted

---

## Test 7: Multi-Connection Protection

1. **Connect to Server A**
   - [ ] Connect to Japan
   - [ ] Verify connected

2. **Try Connecting to Server B**
   - [ ] Without disconnecting, select Canada
   - [ ] Verify app disconnects A first
   - [ ] Then connects to B
   - [ ] Verify no multiple OpenVPN processes

3. **Verify Process Count**
   ```bash
   ps aux | grep -E "openvpn|Tunnelblick" | grep -v grep
   # Should show only 1 VPN process
   ```

---

## Test 8: Performance & Stability

### Memory Leaks

1. **Connect/Disconnect 10 Times**
   - [ ] Rapid connect/disconnect cycles
   - [ ] Monitor Activity Monitor → Memory
   - [ ] Verify memory doesn't grow unbounded

### Long Connection

1. **Stay Connected 30+ Minutes**
   - [ ] Connect to stable server
   - [ ] Leave running
   - [ ] Verify connection stays stable
   - [ ] Verify app remains responsive

### CPU Usage

1. **Monitor CPU When Idle**
   - [ ] With VPN connected
   - [ ] Activity Monitor should show < 5% CPU
   - [ ] No spinning/high CPU usage

---

## Known Issues (Expected Behavior)

### Tunnelblick

- ⚠️ **First-time automation permission**: Required by macOS, one-time setup
- ⚠️ **May need Tunnelblick restart**: After granting automation permission
- ⚠️ **Connection slower than OpenVPN**: Tunnelblick uses GUI, adds overhead

### OpenVPN

- ⚠️ **Sudo required**: Normal for OpenVPN CLI (mitigated by Touch ID)
- ⚠️ **Management socket**: Created in ~/Library, cleaned up on disconnect

---

## Regression Testing

After any code changes, verify:

- [ ] Both backends still connect successfully
- [ ] Backend switching still works
- [ ] Touch ID still works (if configured)
- [ ] Settings persist after restart
- [ ] No console errors or crashes
- [ ] Menu bar icon updates correctly

---

## Test Results Template

```
Date: ________
macOS Version: ________
Xcode Version: ________

Test 1 (OpenVPN): ☐ Pass  ☐ Fail  Notes: __________
Test 2 (Tunnelblick): ☐ Pass  ☐ Fail  Notes: __________
Test 3 (Switching): ☐ Pass  ☐ Fail  Notes: __________
Test 4 (UI): ☐ Pass  ☐ Fail  Notes: __________
Test 5 (Errors): ☐ Pass  ☐ Fail  Notes: __________
Test 6 (Persistence): ☐ Pass  ☐ Fail  Notes: __________
Test 7 (Multi-Connection): ☐ Pass  ☐ Fail  Notes: __________
Test 8 (Performance): ☐ Pass  ☐ Fail  Notes: __________

Overall: ☐ Ready for Release  ☐ Needs Fixes
```

---

## Automated Testing (Future)

```bash
# Planned for Milestone 4
./scripts/run_integration_tests.sh

# Will test:
# - API fetching
# - Server selection logic
# - Configuration generation
# - Process management
```

---

**Ready to test? Run through this checklist and mark off each item!** ✅

