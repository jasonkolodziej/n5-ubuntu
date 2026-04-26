# Custom Snaps

Drop any `.snap` files here to have them automatically included in the image build.

## Common additions for N5 Pro NAS setup:

- `docker.snap` - Docker for container workloads
- `lxd.snap` - LXD for system containers
- `zfs-utils-ubuntu.snap` - ZFS support (if building custom gadget)
- Your custom application snaps

Note: Local snaps must be referenced in the model assertion if you want them as required. 
For optional side-loading, just drop them here and the build script will pick them up.