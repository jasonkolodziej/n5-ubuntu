# Documentation

This directory contains user-facing documentation for building, flashing, and setting up Ubuntu Core 24 on the Minisforum N5 Pro.

## Quick Start

1. **Build the image**: See [BUILDING.md](./BUILDING.md)
   - Set up signing keys using the `.ubuntu/` bootstrap process
   - Build locally or use GitHub Actions

2. **Flash to USB**: See [FLASHING.md](./FLASHING.md)
   - Write the image to a USB drive
   - Boot the N5 Pro from USB

3. **First Boot Setup**: See [FIRST_BOOT.md](./FIRST_BOOT.md)
   - Complete console-conf configuration
   - Create user account and configure networking
   - Install applications and finalize system setup

## Documentation Structure

**[BUILDING.md](./BUILDING.md)** - Prerequisites, local builds, GitHub Actions, customization, troubleshooting

**[FLASHING.md](./FLASHING.md)** - Preparing USB drives, writing images, boot process, initial console access

**[FIRST_BOOT.md](./FIRST_BOOT.md)** - Console-conf walkthrough, user setup, networking, snap installation, post-boot configuration

**[README.md](./README.md)** - This file—overview and navigation

## Key Concepts

### Image Build

- Requires GPG signing keys set up via `.ubuntu/` bootstrap
- Produces `ubuntu-core-24-n5pro.img` (compressed as `.img.xz` for distribution)
- Can be built locally (Linux) or via GitHub Actions

### Flashing

- Write image to USB with `dd` or Rufus (Windows)
- Boot N5 Pro from USB
- Access system via console or SSH

### First Boot

- Console-conf interactive setup wizard
- Create system user account
- Configure networking (wired or wireless)
- Install snaps and applications
- Optionally install to NVMe for permanent use

### Customization

- Add snaps to `snaps/` for inclusion in the image
- Customize the gadget for boot parameters, GRUB settings, or hardware-specific tweaks
- Modify `model-assertion/n5pro-model.json` for different base images or snap channels

## Repo Layout

For a complete overview of the repository, see the main [README.md](../README.md).

Key files for building and flashing:

- `.github/workflows/build-n5pro-image.yml` - CI/CD workflow
- `.ubuntu/` - Local signing and bootstrap tooling
- `model-assertion/n5pro-model.json` - Image definition
- `gadget/README.md` - Optional gadget customization
- `snaps/README.md` - Optional snap payloads

## Support

For issues or questions:

1. Check the **Troubleshooting** sections in [BUILDING.md](./BUILDING.md), [FLASHING.md](./FLASHING.md), and [FIRST_BOOT.md](./FIRST_BOOT.md)
2. Review [.github/copilot-instructions.md](../.github/copilot-instructions.md) for repo conventions
3. Check [../.ubuntu/README.md](../.ubuntu/README.md) for signing and bootstrap details
4. Consult [Ubuntu Core Documentation](https://ubuntu.com/core/docs) and [Snap Documentation](https://snapcraft.io/docs)
