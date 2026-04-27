# Flashing Ubuntu Core 24 To N5 Pro Via USB

This document covers how to write the built Ubuntu Core 24 image to a USB drive and install it on the Minisforum N5 Pro.

## Prerequisites

- **Built image**: `ubuntu-core-24-n5pro.img` or `ubuntu-core-24-n5pro.img.xz` (see [BUILDING.md](./BUILDING.md))
- **USB drive**: 8 GB or larger (will be erased)
- **Host machine**: Linux, macOS, or Windows with USB write capability
- **Tools**: `dd`, `lsblk`/`diskutil`, and optionally `xz` for decompression

## Step 1: Prepare The Image

If your image is compressed (`.img.xz`), decompress it first:

```bash
unxz ubuntu-core-24-n5pro.img.xz
```

Verify the image exists and note its size:

```bash
ls -lh ubuntu-core-24-n5pro.img
```

## Step 2: Identify The USB Drive

### Identify on Linux

List all block devices:

```bash
lsblk
```

Look for your USB drive (typically `sdb`, `sdc`, etc.). **Do NOT use** `sda` or the device your system boots from.

Identify the device name:

```bash
# Example output:
# sdb           8:0    1  29.3G  0 disk
# ├─sdb1        8:1    1   600M  0 part /media/user/EFI
# └─sdb2        8:2    1  28.7G  0 part /media/user/DATA
# Your device is: /dev/sdb
```

### Identify on macOS

List all disks:

```bash
diskutil list
```

Look for your USB drive (typically `/dev/disk2`, `/dev/disk3`, etc.). **Do NOT use** `/dev/disk0` or `/dev/disk1`.

Identify the device name:

```bash
# Example output:
# /dev/disk2 (external, physical):
#    #:                       TYPE NAME                    SIZE       IDENTIFIER
#    0:     FDisk_partition_scheme                        *31.0 GB    disk2
# Your device is: /dev/disk2
```

### Identify on Windows

Use Disk Management or `Get-Volume` in PowerShell:

```powershell
Get-Volume | where { $_.DriveLetter -ne "C" }
```

Or use the Windows Disk Management GUI (right-click Start → Disk Management).

Identify the disk number (e.g., `\\.\PhysicalDrive2`).

## Step 3: Unmount The USB Drive

### Unmount on Linux

```bash
# Unmount all partitions on the USB drive
sudo umount /dev/sdb*

# Or with a specific device:
sudo umount /media/user/EFI /media/user/DATA
```

### On macOS

```bash
# Unmount the drive (replace disk2 with your device)
diskutil unmountDisk /dev/disk2
```

### Unmount on Windows

Eject the drive from File Explorer or Disk Management.

## Step 4: Write The Image To USB

### Write on Linux

```bash
# Replace sdb with your device (from lsblk output)
# Replace ubuntu-core-24-n5pro.img with your image filename
sudo dd if=ubuntu-core-24-n5pro.img of=/dev/sdb bs=4M status=progress oflag=sync
```

Wait for `dd` to complete (message: "X bytes copied").

### Write on macOS

```bash
# Replace disk2 with your device (from diskutil list output)
# Use the raw device path (rdisk) for faster writing
sudo dd if=ubuntu-core-24-n5pro.img of=/dev/rdisk2 bs=4M

# Or with progress indicator (requires Homebrew dd: brew install gnu-coreutils)
sudo gdd if=ubuntu-core-24-n5pro.img of=/dev/rdisk2 bs=4M status=progress
```

Eject the drive when complete:

```bash
diskutil eject /dev/disk2
```

### Write on Windows (PowerShell as Administrator)

```powershell
# Install Win32 Disk Imager (GUI) or use this command:
# For Windows, download and use Rufus, Win32 Disk Imager, or:

# Using dd for Windows (requires GNUwin32 or msys2)
dd if=ubuntu-core-24-n5pro.img of=\\.\PhysicalDrive2 bs=4M

# Or use Rufus from https://rufus.ie/
# - Select the image
# - Select your USB device
# - Click "Start"
```

## Step 5: Verify The Write (Optional But Recommended)

### Verify on Linux

```bash
# Compare the first 100 MB of the image to the USB
dd if=/dev/sdb bs=1M count=100 | md5sum
dd if=ubuntu-core-24-n5pro.img bs=1M count=100 | md5sum

# Both should output the same hash
```

### Verify on macOS

```bash
# Compare the image to the USB device
dd if=/dev/rdisk2 bs=1M | md5 > /tmp/usb.md5
md5 -r ubuntu-core-24-n5pro.img > /tmp/img.md5
# Both should match
```

## Step 6: Boot The N5 Pro From USB

1. **Insert the USB drive** into the N5 Pro.
2. **Power on** the N5 Pro.
3. **Enter the boot menu** during startup (typically by pressing **F7**, **F10**, **F12**, or **ESC**—check your BIOS/UEFI settings).
4. **Select the USB drive** from the boot options (e.g., "USB: [Name of your drive]").
5. **Boot from USB**.

Ubuntu Core 24 should start. You'll see:

- Initial boot messages
- Console-conf interactive setup (if this is the first boot)
- A login prompt

## Step 7: Complete Ubuntu Core Setup

On first boot, console-conf will prompt you to:

1. **Select your keyboard layout** (or press Enter for default)
2. **Create a system user** (username, password, SSH key)
3. **Configure networking** (DHCP is default)
4. **Accept the license agreement**

After console-conf completes, the system will reboot. You can then log in with your username.

## Step 8: Install To NVMe (Optional)

To install Ubuntu Core permanently on the N5 Pro's NVMe drive:

1. **After first boot**, log in to the system via SSH or console.
2. **Insert a second USB drive** (or wait for more free space).
3. **Run the installer** (if present, or use `ubuntu-image` on the running system).

Alternatively, if you prefer to keep the live USB:

- Leave the USB inserted for each boot, or
- Consider writing a second image to the NVMe for permanent installation.

**Note:** Ubuntu Core is designed to boot from read-only media. For a persistent installation, you may need to:

- Customize the gadget to support NVMe boot
- Or provision a writable partition on the NVMe separately

See [BUILDING.md](./BUILDING.md) under "Custom Gadget" for advanced installation options.

## Troubleshooting

### "Device not found" or "No such file or directory"

Double-check your device identifier:

- Linux: `lsblk` and verify it's `/dev/sdX` (not a partition like `/dev/sdb1`)
- macOS: `diskutil list` and verify it's `/dev/diskX`
- Windows: Check Device Manager or Disk Management

### "Permission denied" when writing

Use `sudo` (Linux/macOS) or run as Administrator (Windows PowerShell).

### USB drive not appearing in boot menu

- Try a different USB port (preferably USB 3.0 or 2.0, not USB-C)
- Verify the image was written correctly (re-check with `dd if=/dev/sdb | md5sum`)
- Update BIOS/UEFI on the N5 Pro (visit Minisforum support)

### Boot hangs or kernel panic

- Verify the image file is not corrupted: `sha256sum ubuntu-core-24-n5pro.img`
- Try writing to a different USB drive
- Check that BIOS settings support UEFI boot (not legacy/MBR)

### Slow boot from USB

This is normal for USB 2.0 drives. Use a USB 3.0 drive for faster boot.

## Next Steps

After the N5 Pro boots from USB, you can:

- Configure the system (users, networking, snaps)
- Develop and test software
- Prepare for permanent installation on NVMe

For further customization, see [BUILDING.md](./BUILDING.md) and [../gadget/README.md](../gadget/README.md).
