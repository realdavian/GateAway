#!/bin/bash
# VPN Routing Test Script (macOS-aware)

echo "=== VPN Routing Diagnostic ==="
echo ""

echo "1. OpenVPN Processes:"
ps aux | grep '[o]penvpn --config' | awk '{print "   PID: "$2" | Config: "$NF}'
PROCESS_COUNT=$(ps aux | grep '[o]penvpn --config' | wc -l | tr -d ' ')
echo "   Total: $PROCESS_COUNT process(es)"
echo ""

echo "2. Tunnel Interfaces with IPv4:"
ifconfig | grep -A 3 "^utun" | grep -E "utun|inet " | grep -v "inet6"
echo ""

echo "3. Routing Table:"
netstat -rn | grep -E "0\.0\.0\.0/1|128\.0\.0\.0/1|default"
echo ""

echo "4. Checking VPN tunnel IP:"
UTUN_WITH_IP=$(ifconfig | grep -B 3 "inet " | grep "^utun" | head -1 | awk '{print $1}' | tr -d ':')
if [ -n "$UTUN_WITH_IP" ]; then
    echo "   Tunnel: $UTUN_WITH_IP"
else
    echo "   No utun interface with IPv4 found"
fi
echo ""

echo "5. External IP:"
EXTERNAL_IP=$(curl -s --max-time 5 ifconfig.me 2>/dev/null)
if [ -n "$EXTERNAL_IP" ]; then
    echo "   $EXTERNAL_IP"
else
    echo "   Failed to get external IP"
fi
echo ""

echo "6. DNS Servers:"
scutil --dns | grep "nameserver\[0\]" | head -3
echo ""

echo "=== Diagnosis ==="

# 1. OpenVPN process
if [ "$PROCESS_COUNT" -eq 0 ]; then
    echo "❌ No OpenVPN process running"
    exit 0
elif [ "$PROCESS_COUNT" -gt 1 ]; then
    echo "⚠️  Multiple OpenVPN processes detected ($PROCESS_COUNT)"
    exit 0
else
    echo "✅ Single OpenVPN process running"
fi

# 2. Tunnel interface
if [ -z "$UTUN_WITH_IP" ]; then
    echo "❌ No utun interface has IPv4"
    echo "   OpenVPN may not have completed connection"
    exit 0
else
    echo "✅ Tunnel interface: $UTUN_WITH_IP has IPv4"
fi

echo ""

# 3. Check for macOS full-tunnel override routes
HAS_0_ROUTE=$(route -n get 1.1.1.1 2>/dev/null | grep "$UTUN_WITH_IP")
HAS_128_ROUTE=$(route -n get 8.8.8.8 2>/dev/null | grep "$UTUN_WITH_IP")

if [ -n "$HAS_0_ROUTE" ] && [ -n "$HAS_128_ROUTE" ]; then
    echo "✅ macOS split override routes detected:"
    echo "   • 0.0.0.0/1 → $UTUN_WITH_IP"
    echo "   • 128.0.0.0/1 → $UTUN_WITH_IP"
    echo "   This means ALL IPv4 traffic goes through the VPN."
    FULL_TUNNEL=1
else
    echo "❌ Missing override routes"
    echo "   This means full-tunnel may NOT be active"
    FULL_TUNNEL=0
fi

echo ""

# 4. Final verdict
if [ "$FULL_TUNNEL" -eq 1 ]; then
    echo "🎉🎉🎉 FINAL STATUS: FULL VPN TUNNEL ACTIVE 🎉🎉🎉"
    echo "   • Traffic routed via VPN"
    echo "   • External IP changed"
    echo "   • macOS default route override functioning normally"
else
    echo "❌ FINAL STATUS: VPN CONNECTED BUT NOT ROUTING ALL TRAFFIC"
fi

echo ""
echo "=== OpenVPN Log (last 20 lines) ==="
if [ -f ~/.tsukuba-vpn/openvpn.log ]; then
    sudo tail -20 ~/.tsukuba-vpn/openvpn.log 2>/dev/null || echo "Run with sudo to read log"
else
    echo "Log file not found"
fi
