# First Boot And Initial Setup

This document covers the complete first-boot setup process for Ubuntu Core 24 on the N5 Pro, including console-conf configuration, post-installation steps, and initial system validation.

## Overview

On the first boot from USB, Ubuntu Core will:

1. Load the kernel and system snaps
2. Start the console-conf interactive setup wizard
3. Prompt you to configure keyboard, user, networking, and accept the license
4. Reboot into the fully initialized system

The entire first-boot setup typically takes 2-5 minutes.

## Step 1: Wait For Console-Conf

After the initial boot messages, you'll see:

```text
Welcome to Ubuntu Core 24

Console-conf will help you get set up.

Press ENTER to continue.
```

Press **Enter** to begin the interactive setup.

## Step 2: Configure Keyboard Layout

Console-conf will ask for your keyboard layout:

```text
Select keyboard layout [en]:
```

- Press **Enter** to accept the default (English/US).
- Or type a locale code (e.g., `fr` for French, `de` for German) and press **Enter**.

Common options:

- `en` - English (default)
- `de` - German
- `fr` - French
- `es` - Spanish
- `it` - Italian
- `ja` - Japanese
- `zh` - Chinese

After selection, you'll be prompted to confirm the layout with a test phrase.

## Step 3: Create Your System User

Console-conf will ask you to create a system user account:

```text
Create a system user account.
Username [ubuntu]: 
```

- Enter your desired username (default is `ubuntu`).
- Press **Enter**.

Then you'll be prompted for a password:

```text
Password (leave blank to use SSH public key only):
```

- **Option A:** Enter a password for login. Press **Enter**.
  - Re-enter the password to confirm.
- **Option B:** Leave blank (press **Enter**) to require SSH public key authentication instead.

### SSH Key Setup (Recommended)

If you chose Option B or want to add an SSH key anyway:

```text
SSH public key from Canonical-SSO:
```

- Enter your Canonical SSO username, or
- Paste an SSH public key directly

If you have a GitHub account, you can retrieve your public key from `https://github.com/<username>.keys`.

**Recommended:** Set up SSH key-based authentication for more secure, password-less login.

## Step 4: Configure Networking

Console-conf will detect your network interfaces:

```text
Available network interfaces:
[1] eth0 (Wired)
[2] wlan0 (Wireless)

Select interface [1]:
```

For wired connection (recommended for initial setup):

- Press **Enter** to accept the default (typically `eth0`).
- DHCP is enabled by default; the system will automatically obtain an IP address.

For wireless:

- Type `2` (or the wireless interface number) and press **Enter**.
- When prompted, enter your WiFi SSID and password.

**Verify connection:**

After configuration, console-conf will show:

```text
Checking connectivity... OK
IP Address: 192.168.x.x
```

If you see "OK", networking is ready.

## Step 5: Accept License Agreement

Console-conf will display the Ubuntu Core license:

```text
Do you accept the terms and conditions? [y/N]:
```

- Type `y` and press **Enter** to accept.

After acceptance, you'll see:

```text
System initialized successfully.
Rebooting...
```

The system will reboot automatically.

## Step 6: Wait For Reboot

The system will restart and show boot messages. This typically takes 30-60 seconds. You'll eventually see a login prompt:

```text
ubuntu-core-24 login:
```

## Step 7: Log In

Once you see the login prompt, log in with your username:

```text
ubuntu-core-24 login: <your-username>
Password: <your-password>
```

Or if you set up SSH key authentication:

```bash
ssh <your-username>@<N5-IP-Address>
```

**Note:** To find your N5 Pro's IP address if using SSH:

- Connect to your router's admin panel
- Look for the device in connected clients list
- Or from the N5 Pro console, type: `ip addr show`

After login, you'll see the shell prompt:

```text
user@ubuntu-core-24:~$
```

## Step 8: Update The System

Once logged in, ensure your system is up to date:

```bash
sudo snap refresh
```

This updates all system snaps to the latest versions. The process may take a few minutes.

Check snap status:

```bash
snap list
```

You should see something like:

```text
Name      Version   Rev   Tracking       Publisher   Notes
core24    24.x.x    xxxx  latest/stable  canonical   base
pc        24.x.x    xxxx  latest/stable  canonical   -
pc-kernel 24.x.x    xxxx  latest/stable  canonical   -
snapd     2.xx.x    xxxx  latest/stable  canonical   snapd
```

## Step 9: Install Applications (Optional)

Ubuntu Core uses snaps for application distribution. Install applications with:

```bash
sudo snap install <snap-name>
```

**Common snaps for the N5 Pro:**

```bash
# Development tools
sudo snap install code              # Visual Studio Code
sudo snap install git               # Git version control

# Container and virtualization
sudo snap install docker            # Docker containers
sudo snap install lxd               # LXD containers

# System utilities
sudo snap install htop              # System monitor
sudo snap install tmux              # Terminal multiplexer
sudo snap install curl              # HTTP client
```

**List all available snaps:**

```bash
snap search <keyword>
```

For example:

```bash
snap search docker
snap search database
snap search web-server
```

## Step 10: Configure SSH (Recommended)

If you didn't set up SSH during console-conf:

```bash
# Check SSH status
sudo systemctl status ssh

# Start SSH if not running
sudo systemctl start ssh
sudo systemctl enable ssh

# View your SSH public key (to add to remote systems)
cat ~/.ssh/authorized_keys
```

For improved security, disable password authentication:

```bash
# Edit SSH config
sudo nano /etc/ssh/sshd_config

# Find and uncomment/change these lines:
# PermitRootLogin no
# PasswordAuthentication no
# PubkeyAuthentication yes

# Restart SSH
sudo systemctl restart ssh
```

## Step 11: Configure Hostname (Optional)

To customize the device hostname:

```bash
# View current hostname
hostnamectl

# Set new hostname
sudo hostnamectl set-hostname my-n5-pro

# Verify
hostnamectl
```

The hostname change takes effect after reboot or:

```bash
sudo systemctl restart systemd-hostnamed
```

## Step 12: Set Up Storage (If Using External Drives)

For NVMe or additional storage, check available block devices:

```bash
lsblk
```

**Example output:**

```text
NAME   MAJ:MIN RM   SIZE RO TYPE MOUNTPOINT
sda      8:0    0   477G  0 disk
└─sda1   8:1    0   477G  0 part /
```

Mount external drives:

```bash
# Create mount point
sudo mkdir -p /mnt/data

# Mount the drive (replace sdb1 with your device)
sudo mount /dev/sdb1 /mnt/data

# Check mount
mount | grep /mnt/data
```

To mount permanently on boot, edit `/etc/fstab`:

```bash
sudo nano /etc/fstab

# Add line:
# /dev/sdb1  /mnt/data  ext4  defaults  0  2

sudo systemctl daemon-reload
```

## Step 13: Test System Connectivity

Verify your system is functioning correctly:

```bash
# Check internet connectivity
ping 8.8.8.8

# Check system uptime
uptime

# Check disk space
df -h

# Check memory usage
free -h

# Check running snaps
snap list
```

## Step 14: Take A Snapshot (Optional)

If you've customized the system heavily and want to preserve this state before further changes:

```bash
sudo snap save --set=my-first-boot
```

You can later restore this snapshot:

```bash
sudo snap restore --restore=my-first-boot
```

## Step 15: Plan Next Steps

After first boot, you have these options:

### Option A: Keep Running from USB (Development)

- Leave the USB inserted and boot from it each time.
- Use for development, testing, and temporary deployments.
- **Limitation:** Any changes to `/` or system files are lost on reboot.

### Option B: Install to NVMe (Permanent)

For a permanent installation on the N5 Pro's NVMe drive, see [FLASHING.md - Step 8: Install To NVMe](./FLASHING.md#step-8-install-to-nvme-optional).

## Troubleshooting First Boot

### Console-Conf Hangs

If console-conf appears stuck:

1. Wait 30 seconds (network detection can take time).
2. If still unresponsive, press **Ctrl+C** and reboot:

   ```bash
   sudo reboot
   ```

### Networking Not Working

Verify network interface:

```bash
ip link show
```

If the interface is down:

```bash
sudo ip link set eth0 up
```

For DHCP issues:

```bash
sudo dhclient eth0
sudo ip addr show eth0
```

### SSH Connection Refused

Verify SSH is running:

```bash
sudo systemctl status ssh
```

Start it if needed:

```bash
sudo systemctl start ssh
sudo systemctl enable ssh
```

### Cannot Find System IP

Find your N5 Pro's IP from the console:

```bash
ip addr show

# Or scan your network from another machine
nmap -sn 192.168.x.0/24
```

### Snap Refresh Fails

Check network connectivity:

```bash
snap version
snap refresh --list
```

If refresh still fails, try with verbosity:

```bash
sudo snap refresh -vv
```

## Next Steps

After completing first boot:

- **For development:** Install snaps and tools; see [Step 9](#step-9-install-applications-optional).
- **For production:** Secure your system (see [Step 10](#step-10-configure-ssh-recommended)), then consider installing to NVMe.
- **For customization:** Modify network config, install Docker/LXD, or build applications.

For more information, consult:

- [Ubuntu Core Documentation](https://ubuntu.com/core/docs)
- [Snap Documentation](https://snapcraft.io/docs)
- [N5 Pro Specifications](https://www.minisforum.com)
