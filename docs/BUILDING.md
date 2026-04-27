# Building Ubuntu Core 24 For N5 Pro

This document covers how to build the custom Ubuntu Core 24 image for the Minisforum N5 Pro.

## Prerequisites

Before building locally, ensure you have:

- **Linux host** (Ubuntu 24.04 or compatible)
- **snapd** installed and running
- **snapcraft** snap (`snap install snapcraft --classic`)
- **ubuntu-image** snap (`snap install ubuntu-image --classic`)
- **GPG** and signing key material (see [Setting Up Signing Keys](#setting-up-signing-keys))

On macOS or Windows, use GitHub Actions (see [Building via GitHub Actions](#building-via-github-actions)).

## Setting Up Signing Keys

The image build requires GPG signing keys. Generate or restore them using the `.ubuntu/` bootstrap workflow:

```bash
cd .ubuntu

# 1) Copy the example environment file
cp .env.example .env

# 2) Edit .env with your values
# Required:
#   - EMAIL: your email for the signing key
#   - KEY_NAME: identifier for this key (e.g., "n5pro-key")
#   - DEVELOPER_ID: your Snap Store developer ID (from `snapcraft whoami`)
# Optional:
#   - SNAPCRAFT_STORE_CREDENTIALS: base64-encoded store login token

# 3) Start the signing container
podman compose --env-file .env -f compose.sign-setup.yml up -d --force-recreate

# 4) Run the bootstrap script
podman compose --env-file .env -f compose.sign-setup.yml exec ubuntu-snap /bin/bash /initialize.sh

# 5) Export the generated secrets
ls -lh data/
cat data/github-secrets.env

# 6) Stop the container
podman compose --env-file .env -f compose.sign-setup.yml down
```

The bootstrap process generates:

- `.ubuntu/data/<KEY_NAME>.asc` - private key material
- `.ubuntu/data/snap-gnupg.tar.b64` - base64-encoded GPG home directory
- `.ubuntu/data/github-secrets.env` - secret identifiers for GitHub Actions

**Important:** These files are sensitive. Never commit them to git. Store them securely outside the repository.

## Building Locally

Once signing keys are set up:

```bash
# 1) Ensure snapd is running
sudo systemctl start snapd

# 2) Set environment variables for signing
export SNAP_GNUPG_HOME="$HOME/.snap/gnupg"
export GNUPGHOME="$SNAP_GNUPG_HOME"

# 3) Import signing key into GPG
# (Follow prompts if your key requires a passphrase)
gpg --homedir "$SNAP_GNUPG_HOME" --import .ubuntu/data/<KEY_NAME>.asc

# 4) Verify the key is imported
snap keys

# 5) Navigate to model-assertion directory
cd model-assertion

# 6) Inject your DEVELOPER_ID and sign the model
sed -i "s|__DEVELOPER_ID__|YOUR_DEVELOPER_ID|g" n5pro-model.json
sed -i "s|__TIMESTAMP__|$(date -Iseconds --utc)|g" n5pro-model.json
sed -i "s|__GRADE__|dangerous|g" n5pro-model.json

# Sign with your key (use KEY_NAME from .env)
cat n5pro-model.json | snap sign -k <KEY_NAME> > n5pro.model

# 7) Build the image
mkdir -p ../build
ubuntu-image snap n5pro.model --validation=enforce --output-dir ../build

# Add any custom snaps (optional)
for snap in ../snaps/*.snap; do
  if [ -f "$snap" ]; then
    ubuntu-image snap n5pro.model --validation=enforce --output-dir ../build --snap "$snap"
  fi
done

# 8) Compress for distribution (optional)
cd ../build
xz -T0 -v *.img
ls -lh
```

The build produces:

- `ubuntu-core-24-n5pro.img` - raw disk image
- `ubuntu-core-24-n5pro.img.xz` - compressed image (if xz was run)

## Building via GitHub Actions

If you lack a Linux host or prefer CI/CD:

1. **Set up GitHub secrets** in your repository:

   - `DEVELOPER_ID` - your Snap Store developer ID
   - `SIGNING_KEY_NAME` - key identifier (e.g., "n5pro-key")
   - `SIGNING_KEY` - contents of `.ubuntu/data/<KEY_NAME>.asc`
   - `SNAP_GNUPG_TAR_B64` - contents of `.ubuntu/data/snap-gnupg.tar.b64`
   - `GPG_PASSPHRASE` - passphrase for your key (if it has one)
   - `SNAPCRAFT_STORE_CREDENTIALS` - (optional) Snap Store credentials

2. **Trigger the workflow:**
   - Push to `main` with changes to `model-assertion/`, `gadget/`, `snaps/`, or `.github/workflows/`
   - Or manually dispatch via GitHub UI: go to Actions → Build N5 Pro Ubuntu Core 24 Image → Run workflow

3. **Download the image:**
   - After the build completes, artifacts are uploaded to Actions
   - For releases, the image is published as a GitHub Release asset

## Image Grades

The build supports two grades:

- **dangerous**: Unsigned image, faster to build locally, suitable for development.
- **signed**: Fully signed for production use. Requires valid signing keys and will fail if keys are missing.

To specify the grade in local builds, edit the `sed` command above:

```bash
sed -i "s|__GRADE__|dangerous|g" n5pro-model.json  # or "signed"
```

## Customizing The Image

### Adding Custom Snaps

Place `.snap` files in the `snaps/` directory. They will be automatically included in the build:

```bash
cp my-app.snap snaps/
# Rebuild to include
ubuntu-image snap model-assertion/n5pro.model --validation=enforce --output-dir build --snap snaps/my-app.snap
```

### Creating Helper Snaps With Shell Scripts

Ubuntu Core's read-only root filesystem requires that shell scripts and utilities be packaged as snaps. Use the example template in `snaps/example-helpers/` as a starting point:

**Quick start:**

```bash
cd snaps/example-helpers
# Customize the scripts in bin/
# Edit snap/snapcraft.yaml to add your apps
# Build the snap
snapcraft pack --verbose

# Move to snaps/ for automatic inclusion
mv example-helpers_1.0_amd64.snap ../

# Rebuild the image
cd ../..
ubuntu-image snap model-assertion/n5pro-model.json --validation=enforce --output-dir build
```

**Creating your own snap from scratch:**

```bash
# 1. Create snap structure
mkdir -p my-helpers/snap my-helpers/bin my-helpers/hooks
cd my-helpers

# 2. Create snapcraft.yaml
cat > snap/snapcraft.yaml << 'EOF'
name: my-helpers
version: '1.0'
base: core24
confinement: strict

parts:
  scripts:
    plugin: dump
    source: .
    organize:
      bin/* : bin/

apps:
  my-script:
    command: bin/my-script.sh
    plugs: [system-observe]
EOF

# 3. Add scripts to bin/
chmod +x bin/*.sh

# 4. Build
snapcraft pack --verbose

# 5. Place in snaps/
mv my-helpers_1.0_amd64.snap ../
```

**On the running system, helpers are accessed as:**

```bash
# Via snap command alias
my-helpers.my-script [arguments]

# Via direct path
/snap/my-helpers/current/bin/my-script.sh [arguments]

# With SSH access
ssh user@n5-ip my-helpers.my-script
```

See [snaps/example-helpers/README.md](../snaps/example-helpers/README.md) for complete templates, hook examples, and confinement guidance.

### Enabling ZFS Data-Pool Tooling In The Image

This repo includes a local `snaps/zfs-tools/` source snap that packages `zpool` and `zfs` userspace commands for Ubuntu Core data-pool setup.

Build it locally:

```bash
cd snaps/zfs-tools
chmod +x bin/*.sh hooks/*
snapcraft pack --destructive-mode --verbose
mv zfs-tools_*.snap ../
```

Then build the image as usual. Any `.snap` files in `snaps/` are included automatically.

On first boot, configure optional auto-create with stable disk IDs:

```bash
sudo snap set zfs-tools auto-create=true
sudo snap set zfs-tools confirm-default-layout=true
sudo snap set zfs-tools pool-name=tank
sudo snap set zfs-tools devices=/dev/disk/by-id/ata-DISK1,/dev/disk/by-id/ata-DISK2
sudo snap restart zfs-tools.auto-init
zfs-tools.status
```

Important:

- `zfs-tools` is currently packaged as a local devmode snap for dangerous image flows.
- The kernel must provide ZFS module support (`/dev/zfs` present) for pool commands to work.

### Custom Gadget

For custom boot configuration, kernel parameters, or GRUB changes:

1. Clone the PC gadget: `git clone https://github.com/canonical/pc-gadget.git --branch=24 --depth=1`
2. Edit `gadget.yaml` and `snapcraft.yaml`
3. Build: `snapcraft pack --verbose`
4. Place the resulting `.snap` in `snaps/`
5. Update `model-assertion/n5pro-model.json` to reference your custom gadget

See [gadget/README.md](../gadget/README.md) for details.

## Troubleshooting

### "snap sign: error: no keys found"

You need to import the signing key first:

```bash
gpg --homedir "$SNAP_GNUPG_HOME" --import .ubuntu/data/<KEY_NAME>.asc
snap keys  # verify it appears
```

### "ubuntu-image: error: validation failed"

Ensure:

- The model assertion is correctly signed
- The base, kernel, and gadget snaps match the channel specified in the model
- The GRADE in the model matches your signing setup

### "error: set either SIGNING_KEY or SNAP_GNUPG_TAR_B64 secret"

In GitHub Actions, check that all required secrets are set in your repository settings.

### Image too large for USB

If your image exceeds your USB drive capacity:

- Use a larger USB drive
- Compress the image: `xz -T0 *.img`
- Decompress before flashing: `unxz *.img.xz`

## Next Steps

Once you have a built image, proceed to [FLASHING.md](./FLASHING.md) to write it to USB and install it on the N5 Pro.
