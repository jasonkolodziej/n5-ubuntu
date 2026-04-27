#!/bin/bash

# Network configuration script for Ubuntu Core 24 on N5 Pro
# This is an example helper script demonstrating network diagnostics.

set -e

echo "=== N5 Pro Network Configuration Helper ==="
echo ""

# Show network interfaces
echo "Network interfaces:"
ip link show

echo ""
echo "IP addresses:"
ip addr show

echo ""
echo "Routing table:"
ip route show

echo ""
echo "DNS configuration:"
if [ -f /etc/resolv.conf ]; then
  cat /etc/resolv.conf
else
  echo "(systemd-resolved in use)"
  systemd-resolve --status
fi

echo ""
echo "To use this script for additional setup, modify it to:"
echo "  - Configure static IP"
echo "  - Set up WiFi connections"
echo "  - Configure DNS"
echo "  - Enable firewall rules"
echo ""
echo "Then rebuild the snap: snapcraft pack --verbose"
