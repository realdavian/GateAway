#!/bin/bash
# Test OpenVPN Management Interface State Query

SOCKET_PATH="$HOME/.tsukuba-vpn/openvpn.sock"

echo "=== OpenVPN Management Interface State Test ==="
echo ""

if [ ! -S "$SOCKET_PATH" ]; then
    echo "❌ Management socket not found at: $SOCKET_PATH"
    echo "   Make sure OpenVPN is running"
    exit 1
fi

echo "✅ Management socket found"
echo ""

echo "Querying OpenVPN state..."
echo ""

# Send 'state' command and capture output
STATE_OUTPUT=$(echo "state" | nc -w 1 -U "$SOCKET_PATH" 2>/dev/null)

if [ $? -ne 0 ]; then
    echo "❌ Failed to query management interface"
    exit 1
fi

echo "Raw output:"
echo "$STATE_OUTPUT"
echo ""

# Parse state (format: timestamp,STATE,description,IP,remote_IP)
# Filter out management protocol lines (starting with '>') and END marker
STATE_LINE=$(echo "$STATE_OUTPUT" | grep -v "^>" | grep -v "^END" | grep "^[0-9]")

if [ -z "$STATE_LINE" ]; then
    echo "⚠️  No state information received"
    exit 1
fi

echo "Parsed state line:"
echo "$STATE_LINE"
echo ""

# Extract components
IFS=',' read -r timestamp state description ip remote_ip <<< "$STATE_LINE"

echo "=== State Details ==="
echo "Timestamp: $timestamp"
echo "State: $state"
echo "Description: $description"
echo "VPN IP: $ip"
echo "Remote IP: $remote_ip"
echo ""

# Interpret state
case "$state" in
    "CONNECTED")
        echo "✅✅✅ Status: CONNECTED ✅✅✅"
        echo "   VPN is fully established and routing traffic"
        ;;
    "CONNECTING")
        echo "⏳ Status: CONNECTING"
        echo "   VPN is establishing connection..."
        ;;
    "RECONNECTING")
        echo "⏳ Status: RECONNECTING"
        echo "   VPN is attempting to reconnect..."
        ;;
    "DISCONNECTED")
        echo "❌ Status: DISCONNECTED"
        echo "   VPN is not connected"
        ;;
    "WAIT")
        echo "⏳ Status: WAITING"
        echo "   OpenVPN is waiting to start connection"
        ;;
    "AUTH")
        echo "🔐 Status: AUTHENTICATING"
        echo "   Verifying credentials..."
        ;;
    "GET_CONFIG")
        echo "⏳ Status: GETTING CONFIG"
        echo "   Receiving configuration from server..."
        ;;
    "ASSIGN_IP")
        echo "⏳ Status: ASSIGNING IP"
        echo "   Server is assigning IP address..."
        ;;
    *)
        echo "❓ Status: $state (unknown)"
        ;;
esac

