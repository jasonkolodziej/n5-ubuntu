#!/usr/bin/env bash

# Storage Inventory Script for N5 Pro
# Captures current storage layout: drives, partitions, pools, datasets, and hardware info

set -euo pipefail

MODE="local"
if [[ "${1:-}" == "--remote" ]]; then
  MODE="remote"
fi

N5_HOST="${N5_HOST:-}"
N5_USER="${N5_USER:-ubuntu}"
N5_SSH_KEY="${N5_SSH_KEY:-}"

# Colors for output
BOLD='\033[1m'
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RESET='\033[0m'

print_section() {
    echo -e "\n${BOLD}${BLUE}=== $1 ===${RESET}\n"
}

print_subsection() {
    echo -e "${BOLD}${GREEN}$1${RESET}"
}

run_inventory() {
    # Check if running as root (some commands may need elevated privileges)
    if [[ $EUID -ne 0 ]]; then
        echo -e "${YELLOW}⚠️  Some information may be limited without root privileges${RESET}"
        echo "    Run with 'sudo' for complete hardware details"
    fi

    print_section "BLOCK DEVICES OVERVIEW"
    lsblk -o NAME,SIZE,TYPE,MODEL,SERIAL,LABEL || lsblk

    print_section "NVMe DRIVES (nvme0 - nvme2)"
    for nvme in /dev/nvme0n1 /dev/nvme1n1 /dev/nvme2n1; do
        if [[ -b "$nvme" ]]; then
            print_subsection "$(basename $nvme)"
            
            # Get capacity
            capacity=$(lsblk -b -n -d -o SIZE "$nvme" | awk '{print $1/1024/1024/1024 " GB"}')
            echo "Capacity: $capacity"
            
            # Try to get model info via nvme-cli if available
            if command -v nvme &> /dev/null; then
                echo "Model: $(sudo nvme id-ctrl -H "$nvme" 2>/dev/null | grep '^Model Number' | cut -d: -f2- | xargs || echo 'N/A')"
                echo "Serial: $(sudo nvme id-ctrl -H "$nvme" 2>/dev/null | grep '^Serial Number' | cut -d: -f2- | xargs || echo 'N/A')"
            else
                # Fallback via lsblk
                model=$(lsblk -n -d -o MODEL "$nvme" || echo "N/A")
                serial=$(lsblk -n -d -o SERIAL "$nvme" || echo "N/A")
                echo "Model: $model"
                echo "Serial: $serial"
            fi
            
            # Show partitions and labels
            echo "Partitions:"
            blkid "$nvme"* 2>/dev/null || echo "  (no partitions found)"
            echo ""
        fi
    done

    print_section "SATA DRIVES (sda - sde)"
    for sata in /dev/sd{a,b,c,d,e}; do
        if [[ -b "$sata" ]]; then
            print_subsection "$(basename $sata)"
            
            # Get capacity
            capacity=$(lsblk -b -n -d -o SIZE "$sata" 2>/dev/null | awk '{print $1/1024/1024/1024 " GB"}')
            model=$(lsblk -n -d -o MODEL "$sata" 2>/dev/null || echo "N/A")
            serial=$(lsblk -n -d -o SERIAL "$sata" 2>/dev/null || echo "N/A")
            
            echo "Capacity: $capacity"
            echo "Manufacturer/Model: $model"
            echo "Serial Number: $serial"
            
            # Try to get additional info via smartctl if available
            if command -v smartctl &> /dev/null; then
                sudo smartctl -i "$sata" 2>/dev/null | grep -E "Device Model|Serial Number|Capacity" || true
            fi
            
            # Show partition labels
            echo "Partitions:"
            blkid "$sata"* 2>/dev/null || echo "  (no partitions found)"
            echo ""
        fi
    done

    print_section "ZFS POOL STATUS"
    if command -v zpool &> /dev/null; then
        zpool list -H
        echo ""
        zpool status
    else
        echo "⚠️  ZFS tools not available"
    fi

    print_section "ZFS DATASETS"
    if command -v zfs &> /dev/null; then
        zfs list -H || echo "No datasets found"
    else
        echo "⚠️  ZFS tools not available"
    fi

    print_section "PARTITION LABELS AND UUIDs"
    blkid

    print_section "MOUNT POINTS AND USAGE"
    df -h | grep -E "^/dev/|Filesystem"

    print_section "L2ARC CACHE CONFIGURATION"
    if command -v zpool &> /dev/null; then
        echo "Cache devices (from 'zpool status'):"
        zpool status | grep -A 10 "cache" || echo "No L2ARC cache configured"
    else
        echo "⚠️  ZFS tools not available"
    fi

    print_section "ZFS ARC MEMORY CONFIGURATION"
    if [[ -f /proc/spl/kstat/zfs/arcstats ]]; then
        echo "Current ARC Stats:"
        grep -E "^c |^c_max |^c_min " /proc/spl/kstat/zfs/arcstats | head -3
        
        if [[ -f /etc/modprobe.d/zfs.conf ]]; then
            echo -e "\nZFS Module Configuration:"
            cat /etc/modprobe.d/zfs.conf | grep -E "zfs_arc" || echo "  (using defaults)"
        fi
    else
        echo "ZFS ARC statistics not available (ZFS not loaded?)"
    fi

    print_section "NVME CACHE POOL (if configured)"
    if lsblk -n -o PARTLABEL | grep -q "nvme-cache"; then
        echo "nvme-cache partition(s) found:"
        blkid | grep nvme-cache
        
        # Check if mounted
        if grep -q "nvme-cache" /proc/mounts; then
            echo "Mount point(s):"
            mount | grep nvme-cache
        fi
    else
        echo "No nvme-cache partition labels found"
    fi

    print_section "AI HOT TIER (if configured)"
    if [[ -d /var/nas/ai-hot-tier ]]; then
        echo "Mount point exists: /var/nas/ai-hot-tier"
        df -h /var/nas/ai-hot-tier || echo "  (directory not currently mounted)"
    else
        echo "AI hot tier directory not found"
    fi

    print_section "SYSTEMD ZFS SERVICES STATUS"
    if command -v systemctl &> /dev/null; then
        for service in zfs-import-nas zfs-import-cache zfs-mount; do
            echo "Service: $service"
            systemctl is-active "$service" 2>/dev/null || echo "  (not found or inactive)"
        done
    else
        echo "⚠️  systemctl not available"
    fi

    print_section "STORAGE SUMMARY"
    echo "Total block devices:"
    lsblk -n -d | wc -l

    if command -v zpool &> /dev/null; then
        echo "ZFS pools:"
        zpool list -H | wc -l
    fi

    echo -e "\n${BOLD}✓ Storage inventory complete${RESET}\n"
}

run_local() {
    run_inventory
}

run_remote() {
    if [[ -z "${N5_HOST}" ]]; then
        echo "Error: N5_HOST environment variable is not set" >&2
        echo "Usage: N5_HOST=<ip> N5_USER=<user> [N5_SSH_KEY=<path>] example-helpers.storage-inventory --remote" >&2
        exit 1
    fi

    echo "Running storage inventory on ${N5_USER}@${N5_HOST}"
    echo ""

    # Use SSH key if provided, otherwise use default SSH authentication
    SSH_OPTS="-o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new"
    if [[ -n "${N5_SSH_KEY}" ]]; then
        SSH_OPTS="${SSH_OPTS} -i ${N5_SSH_KEY}"
    fi

    ssh ${SSH_OPTS} "${N5_USER}@${N5_HOST}" \
        "$(declare -f print_section print_subsection run_inventory); run_inventory"
}

if [[ "${MODE}" == "local" ]]; then
    run_local
else
    run_remote
fi

