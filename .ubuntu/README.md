# start


```zsh

# What changed:

# Compose now builds a local image that includes systemd and snapd.
# Container now starts with /sbin/init as PID 1.
# Added cgroup + tmpfs settings needed for systemd in container.
# Initialization script now hard-fails early if PID 1 is not systemd, instead of failing later in snap.
# Run these commands now:

# Create your env file:
cp .env.example .env
# Edit .env with your values (especially CONTAINER_HOST_SOCKET and EMAIL).
podman compose --env-file .env -f compose.sign-setup.yml up -d --force-recreate
podman compose --env-file .env -f compose.sign-setup.yml exec ubuntu-snap /bin/bash /initialize.sh

```


| Secret Name    | Value                                      |
| -------------- | ------------------------------------------ |
| `SIGNING_KEY`  | Full ASCII-armored private key from step 3 |
| `DEVELOPER_ID` | Your developer ID from `snapcraft whoami` -- see `id:` output will show your id: — that's your `authority-id` and `brand-id` for the model assertion.  |
