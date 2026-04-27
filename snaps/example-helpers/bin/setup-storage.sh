#!/bin/bash

# Setup storage script for Ubuntu Core 24 on N5 Pro
# This is an example helper script demonstrating how to manage storage.

set -e

echo "=== N5 Pro Storage Setup Helper ==="
echo ""

# Show available block devices
echo "Available storage devices:"
lsblk -nd -o NAME,SIZE,TYPE

echo ""
echo "Current disk usage:"
df -h /

echo ""
echo "To use this script for additional setup, modify it to:"
echo "  - Detect NVMe drives"
echo "  - Format partitions"
echo "  - Mount network storage"
echo "  - Create ZFS/LVM volumes"
echo ""
echo "Then rebuild the snap: snapcraft pack --verbose"
