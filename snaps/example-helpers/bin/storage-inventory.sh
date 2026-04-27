#!/usr/bin/env bash

# Storage Inventory Script for N5 Pro
# Captures storage layout: drives, partitions, labels, pools, datasets, hardware info
# Flags:
#   --remote   run over SSH to N5 host instead of this machine
#   --mermaid  emit mermaid diagram code

set -euo pipefail

MODE="local"
FORMAT="human"
for arg in "$@"; do
    case "$arg" in
        --local) MODE="local" ;;
        --remote) MODE="remote" ;;
        --mermaid) FORMAT="mermaid" ;;
    esac
done

N5_HOST="${N5_HOST:-}"
N5_USER="${N5_USER:-ubuntu}"
N5_SSH_KEY="${N5_SSH_KEY:-}"

init_colors() {
    BOLD='\033[1m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    RED='\033[0;31m'
    DIM='\033[2m'
    RESET='\033[0m'
}

section() {
    echo -e "\n${BOLD}${BLUE}===== $1 =====${RESET}\n"
}

warn() {
    echo -e "${YELLOW}!${RESET} $1"
}

table() {
    if command -v column >/dev/null 2>&1; then
        column -t -s $'\t' | sed 's/^/  /'
    else
        sed 's/^/  /'
    fi
}

is_stale_label() {
    local disk_base="$1"
    local partlabel="$2"
    [[ -z "$partlabel" ]] && return 1
    if [[ "$partlabel" =~ ^(nvme[0-9]+n[0-9]+|sd[a-z]+) ]]; then
        [[ "${BASH_REMATCH[1]}" != "$disk_base" ]] && return 0
    fi
    return 1
}

run_inventory() {
    init_colors

    if [[ $EUID -ne 0 ]]; then
        warn "Some information may be limited without root privileges (run with sudo for full detail)"
    fi

    echo -e "${BOLD}${BLUE}N5 Pro Storage Inventory${RESET} ${DIM}$(date '+%Y-%m-%d %H:%M:%S')${RESET}"

    section "PHYSICAL DRIVES"
    {
        printf "DEVICE\tSIZE\tMODEL\tSERIAL\n"
        lsblk -d -n -o NAME,SIZE,MODEL,SERIAL 2>/dev/null | while read -r name size model serial; do
            printf "/dev/%s\t%s\t%s\t%s\n" "$name" "$size" "${model:-(n/a)}" "${serial:-(n/a)}"
        done
    } | table

    section "PARTITION MAP"
    {
        printf "PARTITION\tSIZE\tFSTYPE\tPARTLABEL\tLABEL\tUUID8\tSTATUS\n"
        local NAME="" SIZE="" PKNAME="" TYPE="" FSTYPE="" PARTLABEL="" LABEL="" UUID=""
        while IFS= read -r line; do
            NAME=""; SIZE=""; PKNAME=""; TYPE=""; FSTYPE=""; PARTLABEL=""; LABEL=""; UUID=""
            eval "$line" 2>/dev/null || continue
            [[ "$TYPE" != "part" ]] && continue
            local status="OK"
            is_stale_label "$PKNAME" "$PARTLABEL" && status="STALE"
            printf "/dev/%s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
                "$NAME" "$SIZE" "${FSTYPE:--}" "${PARTLABEL:--}" "${LABEL:--}" "${UUID:0:8}" "$status"
        done < <(lsblk -P -o NAME,SIZE,PKNAME,TYPE,FSTYPE,PARTLABEL,LABEL,UUID 2>/dev/null)
    } | table

    section "ZFS POOLS"
    if command -v zpool >/dev/null 2>&1; then
        {
            printf "POOL\tSIZE\tUSED\tFREE\tHEALTH\n"
            zpool list -H -o name,size,alloc,free,health 2>/dev/null | \
                while IFS=$'\t' read -r name size alloc free health; do
                    printf "%s\t%s\t%s\t%s\t%s\n" "$name" "$size" "$alloc" "$free" "$health"
                done
        } | table
        echo
        echo "  zpool status:"
        zpool status 2>/dev/null | sed 's/^/    /'
    else
        echo "  zpool not available"
    fi

    section "ZFS DATASETS"
    if command -v zfs >/dev/null 2>&1; then
        {
            printf "DATASET\tUSED\tAVAIL\tREFER\tMOUNTPOINT\n"
            zfs list -H -o name,used,avail,refer,mountpoint 2>/dev/null | \
                while IFS=$'\t' read -r name used avail refer mountpoint; do
                    printf "%s\t%s\t%s\t%s\t%s\n" "$name" "$used" "$avail" "$refer" "$mountpoint"
                done
        } | table
    else
        echo "  zfs not available"
    fi

    section "ZFS POOL OPTIONS"
    if command -v zpool >/dev/null 2>&1; then
        {
            printf "POOL\tPROPERTY\tVALUE\tSOURCE\n"
            while IFS=$'\t' read -r pool; do
                zpool get -H -o name,property,value,source all "$pool" 2>/dev/null || true
            done < <(zpool list -H -o name 2>/dev/null)
        } | table
    else
        echo "  zpool not available"
    fi

    section "ZFS ROOT DATASET OPTIONS"
    if command -v zfs >/dev/null 2>&1; then
        {
            printf "DATASET\tPROPERTY\tVALUE\tSOURCE\n"
            while IFS=$'\t' read -r pool; do
                zfs get -H -o name,property,value,source all "$pool" 2>/dev/null || true
            done < <(zpool list -H -o name 2>/dev/null)
        } | table
    else
        echo "  zfs not available"
    fi

    section "MOUNT POINTS"
    {
        printf "FILESYSTEM\tSIZE\tUSED\tAVAIL\tUSEPCT\tMOUNTED_ON\n"
        df -h | grep '^/dev/' | while read -r fs size used avail pct mount; do
            printf "%s\t%s\t%s\t%s\t%s\t%s\n" "$fs" "$size" "$used" "$avail" "$pct" "$mount"
        done
    } | table

    section "NVME CACHE LABELS"
    if lsblk -n -o PARTLABEL 2>/dev/null | grep -qE 'nvme.*-cache-p[0-9]+|nvme-cache'; then
        {
            printf "PARTITION\tSIZE\tPARTLABEL\tTYPE\n"
            lsblk -r -n -o NAME,SIZE,PARTLABEL,TYPE 2>/dev/null | grep -E 'nvme.*-cache-p[0-9]+|nvme-cache' | \
                while read -r name size partlabel type; do
                    printf "/dev/%s\t%s\t%s\t%s\n" "$name" "$size" "$partlabel" "$type"
                done
        } | table
        blkid 2>/dev/null | grep -E 'nvme.*-cache-p[0-9]+|nvme-cache' | sed 's/^/  /' || true
    else
        echo "  No nvme cache partition labels found"
    fi

    section "NVME AI HOT LABELS"
    if lsblk -n -o PARTLABEL 2>/dev/null | grep -qE 'nvme.*-ai-hot|nvme-ai-hot'; then
        {
            printf "PARTITION\tSIZE\tPARTLABEL\tTYPE\n"
            lsblk -r -n -o NAME,SIZE,PARTLABEL,TYPE 2>/dev/null | grep -E 'nvme.*-ai-hot|nvme-ai-hot' | \
                while read -r name size partlabel type; do
                    printf "/dev/%s\t%s\t%s\t%s\n" "$name" "$size" "$partlabel" "$type"
                done
        } | table
        local dup_count
        dup_count=$(lsblk -n -o PARTLABEL 2>/dev/null | grep -cE 'nvme.*-ai-hot|nvme-ai-hot' || true)
        if [[ "$dup_count" -gt 1 ]]; then
            warn "$dup_count ai-hot labels detected; stale labels likely present"
            warn "Run: make apply-local ARGS='-replace=\"module.storage_nvme_cache[0].null_resource.nvme_cache\"'"
        fi
    else
        echo "  No nvme ai-hot partition labels found"
    fi

    section "ARC CONFIG"
    if [[ -f /proc/spl/kstat/zfs/arcstats ]]; then
        {
            printf "SETTING\tVALUE\n"
            awk '
                $1=="c"     {printf "arc_target\t%.1f GiB\n", $3/1073741824}
                $1=="c_min" {printf "arc_min\t%.1f GiB\n", $3/1073741824}
                $1=="c_max" {printf "arc_max\t%.1f GiB\n", $3/1073741824}
            ' /proc/spl/kstat/zfs/arcstats
        } | table
        if [[ -f /etc/modprobe.d/zfs.conf ]]; then
            echo
            grep -E 'zfs_arc' /etc/modprobe.d/zfs.conf | sed 's/^/  /' || echo "  using defaults"
        fi
    else
        echo "  ARC stats unavailable"
    fi

    section "SYSTEMD ZFS SERVICES"
    if command -v systemctl >/dev/null 2>&1; then
        {
            printf "SERVICE\tSTATUS\n"
            for service in zfs-import-nas zfs-import-cache zfs-mount zfs-zed; do
                status=$(systemctl is-active "$service" 2>/dev/null || true)
                [[ -z "$status" ]] && status="not-found"
                printf "%s\t%s\n" "$service" "$status"
            done
        } | table
    else
        echo "  systemctl not available"
    fi

    section "SUMMARY"
    {
        printf "METRIC\tVALUE\n"
        printf "block_devices\t%s\n" "$(lsblk -d -n | wc -l)"
        printf "zfs_pools\t%s\n" "$(zpool list -H 2>/dev/null | wc -l || echo 0)"
        printf "zfs_datasets\t%s\n" "$(zfs list -H 2>/dev/null | wc -l || echo 0)"
        stale_count=$(lsblk -P -o PKNAME,PARTLABEL 2>/dev/null | \
            while IFS= read -r line; do
                PKNAME=""; PARTLABEL=""; eval "$line" 2>/dev/null || true
                is_stale_label "$PKNAME" "$PARTLABEL" && echo 1
            done | wc -l)
        printf "stale_partlabels\t%s\n" "$stale_count"
    } | table

    echo
    echo -e "${BOLD}${GREEN}Storage inventory complete${RESET}"
}

generate_mermaid() {
    declare -A disk_size disk_model
    declare -A part_parent part_size part_fstype part_partlabel part_label
    declare -a disks parts

    local NAME="" SIZE="" TYPE="" PKNAME="" MODEL="" SERIAL="" FSTYPE="" PARTLABEL="" LABEL="" UUID=""
    while IFS= read -r line; do
        NAME=""; SIZE=""; TYPE=""; PKNAME=""; MODEL=""; SERIAL=""; FSTYPE=""; PARTLABEL=""; LABEL=""; UUID=""
        eval "$line" 2>/dev/null || continue
        if [[ "$TYPE" == "disk" ]]; then
            disks+=("$NAME")
            disk_size["$NAME"]="$SIZE"
            disk_model["$NAME"]="${MODEL:-unknown}"
        elif [[ "$TYPE" == "part" ]]; then
            parts+=("$NAME")
            part_parent["$NAME"]="$PKNAME"
            part_size["$NAME"]="$SIZE"
            part_fstype["$NAME"]="$FSTYPE"
            part_partlabel["$NAME"]="$PARTLABEL"
            part_label["$NAME"]="$LABEL"
        fi
    done < <(lsblk -P -o NAME,SIZE,TYPE,PKNAME,MODEL,SERIAL,FSTYPE,PARTLABEL,LABEL,UUID 2>/dev/null)

    declare -A pool_health
    declare -a pools
    while IFS=$'\t' read -r name size alloc free health; do
        pools+=("$name")
        pool_health["$name"]="$health"
    done < <(zpool list -H -o name,size,alloc,free,health 2>/dev/null || true)

    declare -A vdev_state vdev_pool cache_state cache_pool
    declare -a vdevs caches
    local current_pool=""
    local in_cache=0
    local trimmed="" dev="" st=""
    while IFS= read -r raw; do
        trimmed="$(echo "$raw" | sed -E 's/^[[:space:]]+//')"
        if [[ "$trimmed" =~ ^pool:[[:space:]]+(.+) ]]; then
            current_pool="${BASH_REMATCH[1]}"
            in_cache=0
        elif [[ "$trimmed" == "cache" ]]; then
            in_cache=1
        elif [[ "$trimmed" =~ ^([^[:space:]]+)[[:space:]]+(ONLINE|DEGRADED|FAULTED|UNAVAIL|REMOVED) ]]; then
            dev="${BASH_REMATCH[1]}"
            st="${BASH_REMATCH[2]}"
            [[ "$dev" == "NAME" || "$dev" == "$current_pool" || "$dev" == "state:" ]] && continue
            if [[ $in_cache -eq 1 ]]; then
                caches+=("$dev")
                cache_state["$dev"]="$st"
                cache_pool["$dev"]="$current_pool"
            else
                vdevs+=("$dev")
                vdev_state["$dev"]="$st"
                vdev_pool["$dev"]="$current_pool"
            fi
        fi
    done < <(zpool status 2>/dev/null || true)

    declare -A mount_dev mount_use
    while read -r fs size used avail pct mount; do
        dev="${fs#/dev/}"
        mount_dev["$dev"]="$mount"
        mount_use["$dev"]="$pct"
    done < <(df -h 2>/dev/null | grep '^/dev/')

    mid() {
        echo "$1" | tr -c '[:alnum:]_' '_' | sed 's/^[0-9]/_/'
    }

    echo "graph TD"
    echo "    subgraph Physical[\"Physical Drives\"]"
    for disk in "${disks[@]}"; do
        did="disk_$(mid "$disk")"
        echo "        subgraph ${did}[\"${disk} ${disk_model[$disk]} ${disk_size[$disk]}\"]"
        echo "            direction TB"
        for part in "${parts[@]}"; do
            [[ "${part_parent[$part]}" != "$disk" ]] && continue
            pid="part_$(mid "$part")"
            label="${part} ${part_size[$part]}"
            [[ -n "${part_partlabel[$part]}" ]] && label+=$'\n'"${part_partlabel[$part]}"
            [[ -n "${part_fstype[$part]}" ]] && label+=$'\n'"${part_fstype[$part]}"
            if is_stale_label "$disk" "${part_partlabel[$part]}"; then
                label="${label} STALE"
            fi
            echo "            ${pid}[\"\`${label}\`\"]"
        done
        echo "        end"
    done
    echo "    end"
    echo

    if [[ "${#pools[@]}" -gt 0 ]]; then
        echo "    subgraph ZFS[\"ZFS Topology\"]"
        for pool in "${pools[@]}"; do
            pid="pool_$(mid "$pool")"
            echo "        ${pid}[\"\`pool ${pool} ${pool_health[$pool]}\`\"]"
        done
        for dev in "${vdevs[@]}"; do
            vid="vdev_$(mid "$dev")"
            echo "        ${vid}[\"\`vdev ${dev} ${vdev_state[$dev]}\`\"]"
            echo "        pool_$(mid "${vdev_pool[$dev]}") --> ${vid}"
        done
        for dev in "${caches[@]}"; do
            cid="cache_$(mid "$dev")"
            echo "        ${cid}[\"\`cache ${dev} ${cache_state[$dev]}\`\"]"
            echo "        pool_$(mid "${cache_pool[$dev]}") -.-> ${cid}"
        done
        echo "    end"
        echo
    fi

    if [[ "${#mount_dev[@]}" -gt 0 ]]; then
        echo "    subgraph Mounts[\"Active Mounts\"]"
        for dev in "${!mount_dev[@]}"; do
            midv="mnt_$(mid "$dev")"
            echo "        ${midv}[\"\`${mount_dev[$dev]} ${mount_use[$dev]}\`\"]"
            echo "        part_$(mid "$dev") --> ${midv}"
        done
        echo "    end"
    fi

    echo
    for part in "${parts[@]}"; do
        pid="part_$(mid "$part")"
        if is_stale_label "${part_parent[$part]}" "${part_partlabel[$part]}"; then
            echo "    style ${pid} fill:#e63946,stroke:#c1121f,color:#ffffff"
        elif [[ "${part_fstype[$part]}" == "zfs_member" ]]; then
            echo "    style ${pid} fill:#2d6a4f,stroke:#40916c,color:#ffffff"
        elif [[ "${part_partlabel[$part]}" =~ -ai-hot$ || "${part_label[$part]}" == "ai-hot-tier" ]]; then
            echo "    style ${pid} fill:#4895ef,stroke:#3a7bd5,color:#ffffff"
        fi
    done
}

run_local() {
    if [[ "$FORMAT" == "mermaid" ]]; then
        echo '```mermaid'
        generate_mermaid
        echo '```'
    else
        run_inventory
    fi
}

run_remote() {
    if [[ -z "${N5_HOST}" ]]; then
        echo "Error: N5_HOST environment variable is not set" >&2
        echo "Usage: N5_HOST=<ip> N5_USER=<user> [N5_SSH_KEY=<path>] example-helpers.storage-inventory --remote [--mermaid]" >&2
        exit 1
    fi

    if [[ -n "${N5_SSH_KEY}" && ! -f "${N5_SSH_KEY}" ]]; then
        echo "Error: SSH key not found: ${N5_SSH_KEY}" >&2
        exit 1
    fi

    fn="run_inventory"
    [[ "$FORMAT" == "mermaid" ]] && fn="generate_mermaid"

    if [[ "$FORMAT" == "mermaid" ]]; then
        echo "Generating mermaid diagram from ${N5_USER}@${N5_HOST}"
        echo '```mermaid'
    else
        echo "Running storage inventory on ${N5_USER}@${N5_HOST}"
        echo
    fi

    ssh_opts=(
        -o BatchMode=yes
        -o ConnectTimeout=10
        -o StrictHostKeyChecking=accept-new
    )

    if [[ -n "${N5_SSH_KEY}" ]]; then
        ssh_opts+=( -i "${N5_SSH_KEY}" )
    fi

    ssh "${ssh_opts[@]}" \
            "${N5_USER}@${N5_HOST}" \
            "$(declare -f init_colors section warn table is_stale_label run_inventory generate_mermaid); ${fn}"

    if [[ "$FORMAT" == "mermaid" ]]; then
        echo '```'
    fi
}

if [[ "${MODE}" == "local" ]]; then
    run_local
else
    run_remote
fi

