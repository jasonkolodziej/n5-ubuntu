#!/usr/bin/env bash
# flash.sh - Write Ubuntu Core image to USB and repair the GPT backup header
#
# Usage: ./scripts/flash.sh <image.img[.xz]> <disk>
#   image  - path to pc.img or pc.img.xz
#   disk   - target disk, e.g. /dev/disk4 (macOS) or /dev/sdb (Linux)
#
# WHY THIS IS NEEDED:
#   ubuntu-image produces a compact image (~3GB). When dd'd to a larger USB
#   drive, the backup GPT header stays at the original end-of-image sector.
#   Linux's partition scanner sees a mismatched backup header and only exposes
#   2 of the 5 Ubuntu Core partitions. snap-bootstrap then cannot detect the
#   recovery system and aborts. Running sgdisk -e on the PHYSICAL DEVICE after
#   flashing moves the backup GPT to the actual end of the USB, making all 5
#   partitions visible.
#
#   NOTE: sgdisk -e must run on the physical device - running it on the image
#   file before dd does NOT work because the USB physical sector count differs
#   from the image file sector count.

set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <image.img[.xz]> <disk>" >&2
  echo "  macOS example: $0 pc.img.xz /dev/disk4" >&2
  echo "  Linux example: $0 pc.img.xz /dev/sdb" >&2
  exit 1
fi

IMAGE="$1"
DISK="$2"

PLATFORM="$(uname -s)"

if [[ ! -f "$IMAGE" ]]; then
  echo "error: image not found: $IMAGE" >&2
  exit 1
fi

if [[ "$PLATFORM" == "Darwin" ]]; then
  RAW_DISK="${DISK/\/dev\/disk//dev/rdisk}"
  if ! command -v sgdisk >/dev/null 2>&1; then
    echo "sgdisk not found. Installing via Homebrew..."
    brew install gptfdisk
  fi
else
  RAW_DISK="$DISK"
  if ! command -v sgdisk >/dev/null 2>&1; then
    echo "sgdisk not found. Install with: sudo apt-get install gdisk" >&2
    exit 1
  fi
fi

echo "Target disk : $DISK  (raw: $RAW_DISK)"
echo "Image       : $IMAGE"
echo ""
echo "WARNING: This will completely erase $DISK"
read -r -p "Continue? [y/N] " confirm
confirm_lc="$(printf '%s' "$confirm" | tr '[:upper:]' '[:lower:]')"
[[ "$confirm_lc" == "y" ]] || { echo "Aborted."; exit 0; }

# Unmount
echo "Unmounting $DISK..."
if [[ "$PLATFORM" == "Darwin" ]]; then
  diskutil unmountDisk "$DISK"
else
  for part in "${DISK}"?*; do
    sudo umount "$part" 2>/dev/null || true
  done
fi

# Write image
echo "Writing image (this will take a few minutes)..."
if [[ "$IMAGE" == *.xz ]]; then
  xz --decompress --stdout "$IMAGE" | sudo dd of="$RAW_DISK" bs=4m
else
  sudo dd if="$IMAGE" of="$RAW_DISK" bs=4m
fi
sync
echo "Write complete."

# Fix backup GPT header on the PHYSICAL DEVICE
# This is the critical step - must run on the actual block device, not on
# the image file, so sgdisk uses the correct physical sector count.
echo "Repairing GPT backup header on physical device $DISK..."
if [[ "$PLATFORM" == "Darwin" ]]; then
  sudo sgdisk -e "$RAW_DISK"
else
  sudo sgdisk -e "$DISK"
fi
sync
echo "GPT repair complete."

# Verify - all 5 Ubuntu Core partitions should now be visible
echo "Partition table (should show 5 partitions):"
if [[ "$PLATFORM" == "Darwin" ]]; then
  diskutil list "$DISK"
else
  sudo sgdisk -p "$DISK"
fi

# Eject
echo "Ejecting $DISK..."
if [[ "$PLATFORM" == "Darwin" ]]; then
  diskutil eject "$DISK"
else
  sudo eject "$DISK" 2>/dev/null || true
fi

echo ""
echo "Done. USB ready to boot the N5 Pro."
echo "Expected partitions: BIOS Boot, ubuntu-seed, ubuntu-boot, ubuntu-save, ubuntu-data"
