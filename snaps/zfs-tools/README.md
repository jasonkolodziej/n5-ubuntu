# zfs-tools Snap

Helper snap for Ubuntu Core 24 on the N5 Pro that packages ZFS userspace commands (`zpool`, `zfs`) and bootstrap scripts for data-pool initialization.

## What This Provides

- `zfs-tools.zpool` command
- `zfs-tools.zfs` command
- `zfs-tools.status` quick state report
- `zfs-tools.init-pool` manual pool creation helper
- `zfs-tools.auto-init` optional daemon for first-boot auto-create

## Important Constraints

- This snap uses `confinement: devmode` and `grade: devel` for local, dangerous image builds.
- It is designed for data-pool setup, not Ubuntu Core root filesystem replacement.
- The running kernel must expose `/dev/zfs` (module support is required).

## Build

```bash
cd snaps/zfs-tools
chmod +x bin/*.sh hooks/*
snapcraft pack --destructive-mode --verbose
```

## Configure Auto Create

Use stable `/dev/disk/by-id/...` paths on the target machine.

Auto-create is gated behind explicit confirmation to avoid accidental destructive actions.

```bash
sudo snap set zfs-tools auto-create=true
sudo snap set zfs-tools confirm-default-layout=true
sudo snap set zfs-tools pool-name=tank
sudo snap set zfs-tools devices=/dev/disk/by-id/ata-DISK1,/dev/disk/by-id/ata-DISK2
sudo snap restart zfs-tools.auto-init
```

## Manual Create

```bash
zfs-tools.init-pool tank /dev/disk/by-id/ata-DISK1 /dev/disk/by-id/ata-DISK2
zfs-tools.status
```

## Example Mirror Pool

```bash
zfs-tools.zpool create -f tank mirror \
  /dev/disk/by-id/ata-DISK1 \
  /dev/disk/by-id/ata-DISK2
```
