#!/usr/bin/env bash
set -euo pipefail

MODE="local"
if [[ "${1:-}" == "--remote" ]]; then
  MODE="remote"
fi

N5_HOST="${N5_HOST:-}"
N5_USER="${N5_USER:-ubuntu}"
N5_SSH_KEY="${N5_SSH_KEY:-}"

run_step_1() {
  echo
  echo "===== STEP 1: capture current network state ====="
  sudo systemctl status NetworkManager-wait-online.service --no-pager -l || true
  sudo journalctl -b -u NetworkManager-wait-online.service --no-pager || true
  nmcli device status
  nmcli -f NAME,UUID,DEVICE,STATE,AUTOCONNECT connection show
  nmcli -f NAME,DEVICE,STATE connection show --active
  ip -4 addr
  ip -4 route
  resolvectl status || cat /etc/resolv.conf
}

run_step_2() {
  echo
  echo "===== STEP 2: verify both interfaces have link and IP ====="
  ip -br link
  ip -br addr
}

run_local() {
  run_step_1
  run_step_2
}

run_remote() {
  if [[ -z "${N5_HOST}" ]]; then
    echo "Error: N5_HOST environment variable is not set" >&2
    echo "Usage: N5_HOST=<ip> N5_USER=<user> [N5_SSH_KEY=<path>] example-helpers.networking-state --remote" >&2
    exit 1
  fi

  echo "Running networking diagnostics on ${N5_USER}@${N5_HOST}"

  # Use SSH key if provided, otherwise use default SSH authentication
  SSH_OPTS="-o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new"
  if [[ -n "${N5_SSH_KEY}" ]]; then
    SSH_OPTS="${SSH_OPTS} -i ${N5_SSH_KEY}"
  fi

  ssh ${SSH_OPTS} "${N5_USER}@${N5_HOST}" 'bash -s' <<'EOF'
set -euo pipefail

echo
echo "===== STEP 1: capture current network state ====="
sudo systemctl status NetworkManager-wait-online.service --no-pager -l || true
sudo journalctl -b -u NetworkManager-wait-online.service --no-pager || true
nmcli device status
nmcli -f NAME,UUID,DEVICE,STATE,AUTOCONNECT connection show
nmcli -f NAME,DEVICE,STATE connection show --active
ip -4 addr
ip -4 route
resolvectl status || cat /etc/resolv.conf

echo
echo "===== STEP 2: verify both interfaces have link and IP ====="
ip -br link
ip -br addr
EOF
}

if [[ "${MODE}" == "local" ]]; then
  run_local
else
  run_remote
fi