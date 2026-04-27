#!/bin/bash

set -eu

PATH="$SNAP/usr/sbin:$SNAP/usr/bin:$PATH"

echo "=== zfs-tools status ==="

if [ -e /dev/zfs ]; then
  echo "zfs device: present"
else
  echo "zfs device: missing"
fi

echo ""
echo "configured auto-create:"
echo "  auto-create=$(snapctl get auto-create || true)"
echo "  confirm-default-layout=$(snapctl get confirm-default-layout || true)"
echo "  pool-name=$(snapctl get pool-name || true)"
echo "  devices=$(snapctl get devices || true)"

echo ""
echo "pools:"
"$SNAP/usr/sbin/zpool" list || true

echo ""
echo "datasets:"
"$SNAP/usr/sbin/zfs" list || true
