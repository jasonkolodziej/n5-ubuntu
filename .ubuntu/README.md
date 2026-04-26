# start

```zsh
cp .env.example .env
# Edit .env with your values.
# Required for one-time GitHub secret bootstrap:
# - EMAIL
# - KEY_NAME
# - SNAPCRAFT_STORE_CREDENTIALS (or create /data/snapcraft-store-credentials.txt)
podman compose --env-file .env -f compose.sign-setup.yml up -d --force-recreate
podman compose --env-file .env -f compose.sign-setup.yml exec ubuntu-snap /bin/bash /initialize.sh
podman compose --env-file .env -f compose.sign-setup.yml down

# Generated files are written to .ubuntu/data:
ls -lh data/

# Quick view of copy/paste values for GitHub secrets:
cat data/github-secrets.env
```

## Day 1 (Local Bootstrap For GitHub Secrets)

```zsh
# 1) Start the signing container
cd .ubuntu
podman compose --env-file .env -f compose.sign-setup.yml up -d --force-recreate

# 2) Open an interactive shell
podman compose --env-file .env -f compose.sign-setup.yml exec ubuntu-snap /bin/bash

# 3) Inside container: install/start snap tooling first
/bin/bash /initialize.sh prepare
export PATH="/snap/bin:$PATH"

# 4) Still inside container: interactive Snapcraft login + export credentials
snapcraft login
snapcraft export-login /data/snapcraft-store-credentials.txt

# 5) Still inside container: run full bootstrap to create key + exports
/bin/bash /initialize.sh
exit

# 6) Back on host: verify generated files
ls -lh data/
cat data/github-secrets.env

# 7) Optional: stop container after bootstrap
podman compose --env-file .env -f compose.sign-setup.yml down
```

Use these outputs for GitHub secrets:

- `DEVELOPER_ID`: value in `data/github-secrets.env`
- `SIGNING_KEY_NAME`: value in `data/github-secrets.env`
- `SIGNING_KEY`: contents of `data/<KEY_NAME>.asc`
- `SNAP_GNUPG_TAR_B64`: contents of `data/snap-gnupg.tar.b64`
- `SNAPCRAFT_STORE_CREDENTIALS` (optional if you use it in CI): contents of `data/snapcraft-store-credentials.txt`

Notes:

- During `/bin/bash /initialize.sh`, `snap create-key` may prompt for a passphrase.
- If a passphrase-protected key is used, GPG may prompt again while exporting `SIGNING_KEY`.

## Day 2+ (Rerun / Rotate Key)

Rerun with same key (refresh exports only):

```zsh
cd .ubuntu
podman compose --env-file .env -f compose.sign-setup.yml up -d --force-recreate
podman compose --env-file .env -f compose.sign-setup.yml exec ubuntu-snap /bin/bash /initialize.sh
podman compose --env-file .env -f compose.sign-setup.yml down

# Check refreshed outputs
ls -lh data/
cat data/github-secrets.env
```

Rotate to a new key name:

```zsh
cd .ubuntu

# 1) Change KEY_NAME in .env (example)
sed -i '' 's/^KEY_NAME=.*/KEY_NAME=n5-key-2026q2/' .env

# 2) Run bootstrap again
podman compose --env-file .env -f compose.sign-setup.yml up -d --force-recreate
podman compose --env-file .env -f compose.sign-setup.yml exec ubuntu-snap /bin/bash /initialize.sh
podman compose --env-file .env -f compose.sign-setup.yml down

# 3) Verify new files and update GitHub secrets from them
ls -lh data/
cat data/github-secrets.env
```

After key rotation, update GitHub secrets with the new values/files:

- `SIGNING_KEY_NAME` from `data/github-secrets.env`
- `SIGNING_KEY` from `data/<new KEY_NAME>.asc`
- `SNAP_GNUPG_TAR_B64` from `data/snap-gnupg.tar.b64`

|Secret Name|Value|
|-----------|-----|
|`SIGNING_KEY`|Contents of `.ubuntu/data/<KEY_NAME>.asc`|
|`SNAP_GNUPG_TAR_B64`|Contents of `.ubuntu/data/snap-gnupg.tar.b64`|
|`SIGNING_KEY_NAME`|Value in `.ubuntu/data/github-secrets.env`|
|`DEVELOPER_ID`|Your developer ID from `snapcraft whoami` -- see `id:` output will show your id: — that's your `authority-id` and `brand-id` for the model assertion.|

### setting gh

```bash

cd /Users/jasonkolodziej/Code/n5

# Load DEVELOPER_ID and SIGNING_KEY_NAME from generated env file
set -a
source .ubuntu/data/github-secrets.env
set +a

# Set required secrets
gh secret set DEVELOPER_ID --body "$DEVELOPER_ID"
gh secret set SIGNING_KEY_NAME --body "$SIGNING_KEY_NAME"
gh secret set SIGNING_KEY < ".ubuntu/data/${SIGNING_KEY_NAME}.asc"
gh secret set SNAP_GNUPG_TAR_B64 < ".ubuntu/data/snap-gnupg.tar.b64"

# Optional (if file exists)
if [[ -f ".ubuntu/data/snapcraft-store-credentials.txt" ]]; then
  gh secret set SNAPCRAFT_STORE_CREDENTIALS < ".ubuntu/data/snapcraft-store-credentials.txt"
fi

```