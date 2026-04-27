# Example Helper Snap

This is a template for creating custom helper snap packages to embed shell scripts and utilities in the Ubuntu Core 24 image for the N5 Pro.

## Structure

```text
example-helpers/
├── snap/
│   └── snapcraft.yaml          # Snap package definition
├── bin/
│   ├── setup-storage.sh        # Example script: storage setup
│   ├── configure-network.sh    # Example script: network config
│   ├── networking-state.sh     # Network diagnostics (local and remote)
│   └── storage-inventory.sh    # Storage inventory tool (local and remote)
├── hooks/
│   ├── install                 # Run during snap install
│   └── configure               # Run during snap configure
└── README.md                   # This file
```

## Building This Snap

### Automated Build (GitHub Actions)

The snap is automatically built by GitHub Actions whenever changes are pushed to `snaps/example-helpers/**`:

1. The `build-snaps` job in `.github/workflows/build-n5pro-image.yml` builds the snap
2. The snap is included automatically in the Ubuntu Core image build
3. The image is released with all built snaps included

No manual steps needed—push changes and the CI/CD pipeline handles the rest.

### Manual Build (Local)

To test the snap locally before pushing:

```bash
# Install snapcraft (if not already installed)
sudo snap install snapcraft --classic

# Navigate to the snap directory
cd snaps/example-helpers

# Build the snap without LXD
snapcraft pack --destructive-mode --verbose

# Output: example-helpers_1.0_amd64.snap
```

`--destructive-mode` is used here because this snap is built from a simple local dump layout and does not need an LXD build environment. GitHub Actions uses the same mode to avoid runner-side LXD group setup.

To include the snap in a local image build:

```bash
# Move the built snap to the snaps/ directory
mv example-helpers_1.0_amd64.snap ../

# Build the image (from repo root)
cd ../..
ubuntu-image snap model-assertion/n5pro-model.json --validation=enforce \
  --output-dir build --snap snaps/example-helpers_1.0_amd64.snap
```

Or test the snap directly on a system with snapd:

```bash
# Install the snap in devmode for testing
sudo snap install --dangerous --devmode example-helpers_1.0_amd64.snap

# Test a command
example-helpers.networking-state

# Uninstall when done
sudo snap remove example-helpers
```

## Using Helper Scripts

Once the snap is installed (automatically via image build), scripts are accessible:

```bash
# SSH into running system
ssh user@n5-ip

# Run a helper script
example-helpers.setup-storage
example-helpers.configure-network
example-helpers.networking-state
example-helpers.storage-inventory
```

Or call them directly:

```bash
/snap/example-helpers/current/bin/setup-storage.sh
/snap/example-helpers/current/bin/networking-state.sh --remote
```

## Built-In Helper Scripts

### networking-state.sh

Captures current network state, interfaces, IP configuration, and routing information.

**Local mode (default)** - Run on the N5 Pro itself:

```bash
example-helpers.networking-state
```

**Remote mode** - Diagnose network on the N5 Pro from another machine:

```bash
N5_HOST=192.168.1.100 N5_USER=ubuntu example-helpers.networking-state --remote

# With SSH key (if using key-based auth)
N5_HOST=192.168.1.100 N5_USER=ubuntu N5_SSH_KEY=~/.ssh/id_ed25519 example-helpers.networking-state --remote
```

Output includes:

- NetworkManager status
- Active connections
- IP addresses and routing
- DNS configuration
- Link status for all interfaces

### storage-inventory.sh

Captures comprehensive storage layout: block devices, NVMe/SATA drives, ZFS pools and datasets, mount points, and hardware details.

**Local mode (default)** - Run on the N5 Pro:

```bash
example-helpers.storage-inventory

# Mermaid diagram output
example-helpers.storage-inventory --mermaid
```

**Remote mode** - Inventory storage on the N5 Pro from another machine:

```bash
N5_HOST=192.168.1.100 N5_USER=ubuntu example-helpers.storage-inventory --remote

# With SSH key
N5_HOST=192.168.1.100 N5_USER=ubuntu N5_SSH_KEY=~/.ssh/id_ed25519 example-helpers.storage-inventory --remote

# Mermaid diagram over SSH
N5_HOST=192.168.1.100 N5_USER=ubuntu example-helpers.storage-inventory --remote --mermaid
```

Output includes:

- Block device listing (NVMe and SATA)
- ZFS pool and dataset status
- Partition labels and UUIDs
- Mount points and usage
- L2ARC cache configuration
- ZFS ARC memory settings
- Hardware identification and serial numbers

Both scripts use colored output for readability and work seamlessly whether run locally on the N5 Pro or remotely over SSH.

## Customizing This Template

1. **Rename the snap**: Update `name:` in `snapcraft.yaml`
2. **Add your scripts**: Place shell scripts in `bin/`
3. **Add apps**: For each script, add an `apps` entry in `snapcraft.yaml`
4. **Add hooks**: Include `install` or `configure` hooks if needed
5. **Adjust confinement**: Change `confinement: strict` if your script needs more permissions

## Example: Custom NAS Initialization Snap

```bash
# 1. Create directory structure
mkdir -p nas-setup/snap nas-setup/bin nas-setup/hooks
cd nas-setup

# 2. Create snapcraft.yaml
cat > snap/snapcraft.yaml << 'EOF'
name: nas-setup
version: '1.0'
base: core24
confinement: strict

parts:
  nas-scripts:
    plugin: dump
    source: .
    organize:
      bin/* : bin/
      hooks/* : hooks/

apps:
  format-pool:
    command: bin/format-pool.sh
  mount-nfs:
    command: bin/mount-nfs.sh
EOF

# 3. Add scripts
cat > bin/format-pool.sh << 'EOF'
#!/bin/bash
set -e
POOL_NAME=${1:-tank}
DEVICES=${@:2}

if [ -z "$DEVICES" ]; then
  echo "Usage: nas-setup.format-pool <pool-name> <device1> [device2] ..."
  exit 1
fi

echo "Creating ZFS pool: $POOL_NAME"
sudo zpool create "$POOL_NAME" $DEVICES
echo "Pool created successfully"
EOF
chmod +x bin/format-pool.sh

# 4. Build
snapcraft pack --verbose
```

## Snap Permissions (Confinement Levels)

- **`strict`** - Restricted access, limited to snap-specific directories
- **`classic`** - Full system access (only for trusted snaps, not recommended)
- **`devmode`** - Debugging mode, same access as `classic`

For scripts that need system access (ZFS, LVM, disk partitioning), consider using:

- systemd service integration
- dbus interface
- Or building a custom gadget snap with pre-boot hooks instead

## Pre/Post-Boot Hooks

For scripts that must run during image build or first boot (not post-login), use gadget snaps instead. See [../gadget/README.md](../gadget/README.md) for hook examples.

## Testing Locally

Before building the image, test your snap locally:

```bash
# On a system with snapd
snap install --dangerous --devmode example-helpers_1.0_amd64.snap

# Test the apps
example-helpers.setup-storage

# Inspect snap contents
snap list
snap info example-helpers
snap logs example-helpers -f
```

## References

- [Snapcraft Documentation](https://snapcraft.io/docs)
- [Snap Confinement](https://snapcraft.io/docs/snap-confinement)
- [Ubuntu Core Snaps](https://ubuntu.com/core/docs)
