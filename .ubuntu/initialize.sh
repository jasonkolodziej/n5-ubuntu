#!/bin/bash

set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
export TZ="${TZ:-UTC}"
export PATH="/snap/bin:$PATH"
# Use null keyring so snapcraft local operations (create-key, keys) work headlessly.
# Only store-touching commands (register-key, whoami) need real credentials.
export PYTHON_KEYRING_BACKEND=keyring.backends.null.Keyring
EMAIL="${EMAIL:-your-email@example.com}"
KEY_NAME="${KEY_NAME:-n5pro-key}"
SNAPCRAFT_AUTH_READY=0

start_snapd() {
  if [ "$(ps -p 1 -o comm= 2>/dev/null || true)" != "systemd" ]; then
    echo "error: PID 1 is not systemd; recreate container from compose with /sbin/init first" >&2
    exit 1
  fi

  systemctl daemon-reload
  systemctl enable --now snapd.socket
  systemctl start snapd.service

  until snap version >/dev/null 2>&1; do
    sleep 1
  done
}

install_required_tools() {
  apt-get update
  apt-get install -y tzdata snapd squashfuse fuse gnupg

  snap list snapcraft >/dev/null 2>&1 || snap install snapcraft --classic
  snap list ubuntu-image >/dev/null 2>&1 || snap install ubuntu-image --classic
}

ensure_snapcraft_cli() {
  local i
  for i in $(seq 1 20); do
    if command -v snapcraft >/dev/null 2>&1; then
      return
    fi
    if [ -x /snap/bin/snapcraft ]; then
      export PATH="/snap/bin:$PATH"
      if command -v snapcraft >/dev/null 2>&1; then
        return
      fi
    fi
    sleep 1
  done

  echo "error: snapcraft CLI not found in PATH (expected /snap/bin/snapcraft)" >&2
  exit 1
}

configure_snapcraft_auth() {
  if [ -n "${SNAPCRAFT_STORE_CREDENTIALS:-}" ]; then
    echo "using SNAPCRAFT_STORE_CREDENTIALS from environment"
    SNAPCRAFT_AUTH_READY=1
    return
  fi

  if [ -f /data/snapcraft-store-credentials.txt ]; then
    export SNAPCRAFT_STORE_CREDENTIALS
    SNAPCRAFT_STORE_CREDENTIALS="$(cat /data/snapcraft-store-credentials.txt)"
    echo "loaded SNAPCRAFT_STORE_CREDENTIALS from /data/snapcraft-store-credentials.txt"
    SNAPCRAFT_AUTH_READY=1
    return
  fi

  echo "warning: no Snap Store credentials configured; store-auth commands may fail" >&2
}

setup_signing_key() {
  if [ "$SNAPCRAFT_AUTH_READY" -eq 1 ]; then
    # Full snapcraft flow: create (talks to store) + register
    if snapcraft keys 2>/dev/null | awk 'NR>1 {print $1}' | grep -qx "$KEY_NAME"; then
      echo "snapcraft key '$KEY_NAME' already exists"
    else
      snapcraft create-key "$KEY_NAME"
    fi
    snapcraft keys
    snapcraft register-key "$KEY_NAME"
  else
    # No store credentials: create a raw GPG key that snap sign can use later
    if gpg --list-secret-keys "$KEY_NAME" >/dev/null 2>&1; then
      echo "GPG key '$KEY_NAME' already exists locally"
    else
      echo "creating local GPG key '$KEY_NAME' (no store credentials; skipping snapcraft create-key)" >&2
      gpg --batch --gen-key <<EOF
%no-protection
Key-Type: RSA
Key-Length: 4096
Name-Real: $KEY_NAME
Name-Email: $EMAIL
Expire-Date: 0
%commit
EOF
    fi
    echo "note: key created locally but not registered with Snap Store" >&2
    echo "      to register later: snapcraft login && snapcraft register-key \"$KEY_NAME\"" >&2
  fi
}

export_secret_key() {
  local out="/data/${KEY_NAME}.asc"

  local key_arg
  if gpg --list-secret-keys "$EMAIL" >/dev/null 2>&1; then
    key_arg="$EMAIL"
  else
    key_arg="$(gpg --list-secret-keys --with-colons | awk -F: '/^fpr:/ {print $10; exit}')"
  fi

  if [ -z "${key_arg:-}" ]; then
    echo "warning: no secret GPG key found to export" >&2
    return
  fi

  gpg --armor --export-secret-keys "$key_arg" > "$out"
  echo "private key exported to $out (host path: .ubuntu/data/${KEY_NAME}.asc)"
}

ln -snf "/usr/share/zoneinfo/$TZ" /etc/localtime
echo "$TZ" > /etc/timezone

install_required_tools
start_snapd
ensure_snapcraft_cli
configure_snapcraft_auth

# snapcraft whoami prints authority/brand IDs used in model assertion workflows.
# The snapcraft whoami output will show your id: — that's your authority-id and brand-id for the model assertion.
if ! snapcraft whoami; then
  echo "warning: snapcraft whoami failed (likely no keyring/store login in this container)" >&2
fi
setup_signing_key
export_secret_key

