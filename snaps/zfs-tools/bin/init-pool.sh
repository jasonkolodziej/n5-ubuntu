#!/bin/bash

set -eu

PATH="$SNAP/usr/sbin:$SNAP/usr/bin:$PATH"

POOL_NAME="${1:-tank}"
shift || true

if [ "$#" -lt 1 ]; then
  echo "Usage: zfs-tools.init-pool <pool-name> <device1> [device2 ...]" >&2
  exit 1
fi

if [ ! -e /dev/zfs ]; then
  echo "zfs-tools: /dev/zfs is missing. Ensure the kernel has ZFS module support." >&2
  exit 1
fi

if "$SNAP/usr/sbin/zpool" list "$POOL_NAME" >/dev/null 2>&1; then
  echo "zfs-tools: pool '$POOL_NAME' already exists; skipping create"
  exit 0
fi

echo "zfs-tools: creating pool '$POOL_NAME' on: $*"
"$SNAP/usr/sbin/zpool" create \
  -f \
  -o ashift=12 \
  -O compression=zstd \
  -O atime=off \
  "$POOL_NAME" "$@"

echo "zfs-tools: creating default datasets"
"$SNAP/usr/sbin/zfs" create -o mountpoint=/$POOL_NAME "$POOL_NAME/data" || true
"$SNAP/usr/sbin/zpool" status "$POOL_NAME"
