# Custom Gadget Snap (Optional)

For the Minisforum N5 Pro, the generic `pc` gadget usually works fine since it's standard x86_64 UEFI.

## When to customize

1. **Custom kernel cmdline** (e.g., `zfs_force=1`, `nomodeset`, etc.)
2. **GRUB timeout changes** (set to 0 for headless boot)
3. **Specific bootloader branding**
4. **Hardware-specific tweaks**

## To build custom gadget

```bash
git clone https://github.com/canonical/pc-gadget.git --branch=24 --depth=1
cd pc-gadget
# Edit gadget.yaml, snapcraft.yaml
snapcraft pack --verbose
```

Then:

1. Place the `.snap` in `../snaps/`
2. Update `model-assertion/n5pro-model.json` to use your `gadget` name (remove `id` and `default-channel` for local snaps, set `grade: dangerous`)

## Pre-Boot And Post-Boot Hooks

Custom gadget snaps can include hooks that run during image build or first boot, before or after the system is fully initialized. This is useful for tasks that must run with full system privileges before user login.

### Gadget Hooks Structure

In your custom gadget snap:

```text
pc-gadget/
├── snap/
│   └── snapcraft.yaml
├── meta/
│   └── hooks/
│       ├── prepare-image     # Runs during image build (image-prepare)
│       └── prepare-system    # Runs after kernel boot, before console-conf (first-boot)
└── gadget.yaml
```

### prepare-image Hook

Runs during image assembly, before the image is finalized. Used for pre-build customization.

Example: `meta/hooks/prepare-image`

```bash
#!/bin/bash

# This runs during ubuntu-image build
# Full system access, can modify image contents directly

echo "Preparing image for N5 Pro..."

# Example: Add custom kernel parameters
# (This depends on gadget.yaml structure)

# Example: Pre-create directories on root filesystem
# (Limited; root filesystem is read-only in final image)

# Example: Pre-load snaps or configuration
# (Use snaps/ directory or model assertion instead)

exit 0
```

### prepare-system Hook

Runs after boot but before console-conf interactive setup. Full root access available.

Example: `meta/hooks/prepare-system`

```bash
#!/bin/bash

# This runs during first boot, before console-conf
# Full system access as root
# Output goes to console and system logs

set -e

echo "========================================"
echo "Preparing system for N5 Pro (pre-boot)"
echo "========================================"

# Example 1: Check and report hardware
echo "Detected hardware:"
lsblk -d -o NAME,SIZE
lspci | grep -E "Network|Storage"

# Example 2: Set system parameters
echo "Configuring system parameters..."
sysctl -w vm.swappiness=10

# Example 3: Create required directories
mkdir -p /var/lib/custom-data
chmod 755 /var/lib/custom-data

# Example 4: Load required kernel modules
modprobe zfs || true

# Example 5: Configure network (DHCP)
echo "Ensuring network is configured..."
if ! ip link show eth0 | grep -q UP; then
  ip link set eth0 up
  dhclient eth0 || true
fi

echo "========================================"
echo "System preparation complete"
echo "========================================"

exit 0
```

### Adding Hooks To Your Gadget

1. Clone the PC gadget (as shown above)
2. Create the `meta/hooks/` directory structure
3. Add hook scripts and make them executable:

```bash
mkdir -p meta/hooks
chmod +x meta/hooks/prepare-image meta/hooks/prepare-system
```

1. Update `snap/snapcraft.yaml` to include the hooks directory:

```yaml
parts:
  pc-gadget:
    plugin: dump
    source: .
    organize:
      meta/* : meta/
      gadget.yaml : gadget.yaml
```

1. Build and include in image:

```bash
snapcraft pack --verbose
mv pc_24.x.x_amd64.snap ../snaps/
```

### Example: Pre-Boot ZFS Configuration

```bash
#!/bin/bash
# meta/hooks/prepare-system - Set up ZFS kernel module

set -e

echo "Setting up ZFS..."

# Load ZFS kernel module
modprobe zfs

# Configure ZFS module parameters
echo "Set ZFS module parameters:"
echo 32 > /proc/sys/kernel/shmmax   # Shared memory for ZFS ARC

# Check if ZFS tools are available (if bundled in a snap)
if command -v zpool &> /dev/null; then
  echo "ZFS tools ready"
else
  echo "ZFS tools not in path (install via snap)"
fi

exit 0
```

### Example: Pre-Boot Network Configuration

```bash
#!/bin/bash
# meta/hooks/prepare-system - Ensure network is up

set -e

echo "Configuring network before console-conf..."

# Try wired connection first
if [ -f /sys/class/net/eth0/phy_port_id ]; then
  echo "Bringing up eth0..."
  ip link set eth0 up
  dhclient eth0 || true
  
  # Wait for IP
  for i in {1..10}; do
    if ip addr show eth0 | grep -q "inet "; then
      echo "eth0 online: $(ip addr show eth0 | grep 'inet ')"
      break
    fi
    sleep 1
  done
fi

# Fallback: try other interfaces
for iface in enp* wlan*; do
  if [ -d "/sys/class/net/$iface" ]; then
    echo "Bringing up $iface..."
    ip link set "$iface" up
    dhclient "$iface" || true
  fi
done

exit 0
```

### Debugging Hooks

If a hook fails, boot into the running system and check:

```bash
# View hook output
snap logs -f

# Check system logs
journalctl -xe

# Manually re-run a hook (if using ubuntu-image)
/var/lib/snapd/snaps/pc_*/hooks/prepare-system
```

### Important Notes

- Hooks run with **full root access** but run **very early** in the boot process
- Limited services are available (no networking yet in prepare-image)
- Failures in hooks will prevent image finalization (prepare-image) or first boot (prepare-system)
- Return exit code 0 for success; non-zero aborts the process
- Keep hooks simple; defer complex setup to post-login snaps instead

### For More Complex Setup: Use Snaps Instead

For tasks that don't require pre-boot access, use [helper snaps](../docs/BUILDING.md#creating-helper-snaps-with-shell-scripts) instead. They're easier to test, update, and debug.
