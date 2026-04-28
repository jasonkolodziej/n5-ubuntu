# Custom Snaps

Drop any `.snap` files here to have them automatically included in the image build.

Source directories with `snap/snapcraft.yaml` are also built automatically by CI and then included in the image.

## Common additions for N5 Pro NAS setup

- `docker.snap` - Docker for container workloads
- `lxd.snap` - LXD for system containers (side-load here; not a required model snap)
- `zfs-tools/` - Local ZFS userspace helper snap source (built by CI)
- Your custom application snaps

> **Note on lxd**: lxd is intentionally NOT listed as a required snap in the model assertion.
> Required model snaps must be pulled from the Snap Store at first boot, which stalls setup if
> network is unavailable or slow. Drop `lxd_<version>_amd64.snap` here to include it as a
> pre-seeded side-load, or install it post-boot with `snap install lxd --channel latest/stable`.

## Included ZFS Helper Source

This repository includes `snaps/zfs-tools/`, which packages:

- `zfs-tools.zpool`
- `zfs-tools.zfs`
- `zfs-tools.status`
- `zfs-tools.init-pool`
- `zfs-tools.auto-init`

Use the helper README for build and runtime setup details: `snaps/zfs-tools/README.md`.

Note: Local snaps must be referenced in the model assertion if you want them as required.
For optional side-loading, just drop them here and the build script will pick them up.
