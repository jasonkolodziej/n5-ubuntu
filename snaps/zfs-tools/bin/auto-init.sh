#!/bin/bash

set -eu

PATH="$SNAP/usr/sbin:$SNAP/usr/bin:$PATH"
DONE_FILE="$SNAP_COMMON/auto-init.done"

ENABLE="$(snapctl get auto-create || true)"
CONFIRM="$(snapctl get confirm-default-layout || true)"
POOL_NAME="$(snapctl get pool-name || true)"
DEVICES_RAW="$(snapctl get devices || true)"

if [ "$ENABLE" != "true" ]; then
  echo "zfs-tools: auto-create disabled"
  exit 0
fi

if [ "$CONFIRM" != "true" ]; then
  echo "zfs-tools: explicit confirmation required; set 'confirm-default-layout=true'"
  exit 0
fi

if [ -f "$DONE_FILE" ]; then
  echo "zfs-tools: auto-init already completed"
  exit 0
fi

if [ -z "$POOL_NAME" ]; then
  POOL_NAME="tank"
fi

if [ -z "$DEVICES_RAW" ]; then
  echo "zfs-tools: devices config is empty; set with 'snap set zfs-tools devices=...,...'"
  exit 0
fi

if [ ! -e /dev/zfs ]; then
  echo "zfs-tools: /dev/zfs is missing. Waiting for kernel/module support."
  exit 0
fi

if "$SNAP/usr/sbin/zpool" list "$POOL_NAME" >/dev/null 2>&1; then
  echo "zfs-tools: pool '$POOL_NAME' already exists"
  mkdir -p "$(dirname "$DONE_FILE")"
  date -Iseconds > "$DONE_FILE"
  exit 0
fi

IFS=',' read -r -a DEVICES <<< "$DEVICES_RAW"
for d in "${DEVICES[@]}"; do
  if [ ! -e "$d" ]; then
    echo "zfs-tools: missing device '$d', skipping auto-init"
    exit 0
  fi
done

echo "zfs-tools: auto-creating pool '$POOL_NAME' on: ${DEVICES[*]}"
"$SNAP/usr/sbin/zpool" create \
  -f \
  -o ashift=12 \
  -O compression=zstd \
  -O atime=off \
  "$POOL_NAME" "${DEVICES[@]}"

"$SNAP/usr/sbin/zfs" create -o mountpoint=/$POOL_NAME "$POOL_NAME/data" || true
mkdir -p "$(dirname "$DONE_FILE")"
date -Iseconds > "$DONE_FILE"

echo "zfs-tools: auto-init complete"
