# Model Assertion Review: UC24 Reference Alignment And First-Boot Fixes

## Goal

Align `model-assertion/n5pro-model.json` with the Canonical UC24 dangerous reference model
and the Ubuntu Core 24 console-conf documentation to resolve reported flashing and first-boot issues.

## Related Plans

- `.github/plans/2026-04-27-secured-grade-secure-boot-plan.md` — grade matrix, secured build gates, and storage-safety precedent.
- `.github/plans/2026-04-27-production-zfs-provisioning-plan.md` — first-boot UX, snap model integration decisions.

## Reference Sources

- https://github.com/canonical/models/blob/master/ubuntu-core-24-amd64-dangerous.json
- https://documentation.ubuntu.com/core/how-to-guides/image-creation/add-console-conf/

## Analysis: Current Model vs. Reference

| Field | Canonical UC24 dangerous reference | Current n5pro-model.json | Assessment |
|-------|-----------------------------------|--------------------------|------------|
| `grade` | `dangerous` | `__GRADE__` (injected) | OK |
| `storage-safety` | absent (defaults to `prefer-unencrypted`) | `"prefer-encrypted"` | **Problem** — see below |
| `system-user-authority` | absent | `["__DEVELOPER_ID__"]` | Acceptable, keep with docs note |
| `console-conf` snap | absent (added only when needed) | present (`24/stable`) | Keep; consistent with add-console-conf docs |
| `lxd` snap | absent | present (`latest/stable`) | **Problem** — see below |
| Core 4 snaps (pc, pc-kernel, core24, snapd) | present | present with same IDs | OK |

### Problem 1 — `storage-safety: prefer-encrypted` on dangerous-grade builds

The canonical dangerous reference omits `storage-safety` entirely, defaulting to
`prefer-unencrypted`. Our model hardcodes `prefer-encrypted`, which:

- Attempts TPM2-backed FDE enrollment on first boot even in dangerous/development builds.
- Fails silently or stalls on hardware where TPM2 is absent, disabled in firmware, or not
  enrolled with secure boot keys.
- Is inconsistent with `grade: dangerous`, which is intended for development use without
  hardware signing requirements.

Fix: introduce a `__STORAGE_SAFETY__` template variable and set it grade-conditionally in CI:
- `dangerous` → `prefer-unencrypted`
- `signed` → `prefer-encrypted`
- `secured` → `encrypted`

### Problem 2 — `lxd` in required model snaps

The model assertion does not have an "optional" concept; every listed snap is required.
Having `lxd` in the model means snapd **must** pull it from the Snap Store during first boot,
which:

- Requires working network connectivity before setup can complete.
- Significantly increases first-boot time.
- Causes first-boot to stall or fail in air-gapped or DHCP-delayed environments.

Fix: remove `lxd` from the model snaps. Operators who want lxd can side-load it via
`snaps/lxd.snap` or install it post-boot with `snap install lxd`. The build workflow already
supports `--snap` injection for local `.snap` files.

### console-conf: confirmed correct

The UC24 add-console-conf documentation explicitly describes adding `console-conf` as a
separate snap in the model assertion with `type: app` and `default-channel: 24/stable`.
Our current model already follows this pattern correctly. No change needed here.

## Scope

In scope:
- Make `storage-safety` grade-conditional in the model template and workflow.
- Remove `lxd` from required model snaps.
- Update workflow `Sign model assertion` step to inject `STORAGE_SAFETY`.
- Update docs to reflect the lxd side-load path and the storage-safety behavior.

Out of scope:
- Redesigning the console-conf flow or skipping it.
- Full secure boot / FDE validation (tracked in secured-grade plan).
- ZFS provisioning UX (tracked in production-zfs plan).

## Proposed Changes

1. Replace `"storage-safety": "prefer-encrypted"` in `model-assertion/n5pro-model.json`
   with `"storage-safety": "__STORAGE_SAFETY__"`.

2. In the `Sign model assertion` workflow step, add a `STORAGE_SAFETY` derivation block
   before the `sed` substitutions:
   - `dangerous` → `prefer-unencrypted`
   - `signed`    → `prefer-encrypted`
   - `secured`   → `encrypted`
   Then inject: `sed -i "s|__STORAGE_SAFETY__|$STORAGE_SAFETY|g" n5pro-model.json`

3. Remove the `lxd` entry from `model-assertion/n5pro-model.json` snaps list.

4. Update `snaps/README.md` to note that lxd should be side-loaded or installed post-boot
   rather than required in the model.

5. Update `gadget/README.md` or a companion doc to note the storage-safety behavior per grade.

## Files To Touch

- `model-assertion/n5pro-model.json`
- `.github/workflows/build-n5pro-image.yml`
- `snaps/README.md`

## Validation

- `pnpm exec biome check .` passes (biome.json covers root JSON/config files).
- Workflow diff review: confirm `sed` substitutions cover all four `__PLACEHOLDER__` tokens.
- Smoke test: trigger `workflow_dispatch` with `grade: dangerous` and verify signed model
  assertion contains `storage-safety: prefer-unencrypted` and no `lxd` snap entry.
- Smoke test: trigger with `grade: signed` and verify `storage-safety: prefer-encrypted`.

## Risks And Questions

- Risk: existing devices flashed with `prefer-encrypted` may have started FDE enrollment.
  Re-flashing is required; in-place migration is not supported by Ubuntu Core.
- Risk: operators relying on lxd being auto-installed at first boot will need to install it
  manually or side-load the snap. Document this prominently.
- Question: should `lxd` be added back as a model snap only for `signed`/`secured` builds
  where network reliability is assumed? Current recommendation: no — keep it as a side-load
  in all grades and document the pattern.
