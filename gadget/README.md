# Custom Gadget Snap (Optional)

For the Minisforum N5 Pro, the generic `pc` gadget usually works fine since it's standard x86_64 UEFI.

## When to customize:

1. **Custom kernel cmdline** (e.g., `zfs_force=1`, `nomodeset`, etc.)
2. **GRUB timeout changes** (set to 0 for headless boot)
3. **Specific bootloader branding**
4. **Hardware-specific tweaks**

## To build custom gadget:

```bash
git clone https://github.com/canonical/pc-gadget.git --branch=24 --depth=1
cd pc-gadget
# Edit gadget.yaml, snapcraft.yaml
snapcraft pack --verbose
```

Then:

1. Place the `.snap` in `../snaps/`
2. Update `model-assertion/n5pro-model.json` to use your `gadget` name (remove `id` and `default-channel` for local snaps, set `grade: dangerous`)