# Production ZFS Provisioning Plan For N5 Pro Ubuntu Core

## Goal

Deliver a production-ready Ubuntu Core image flow where end users can choose either a hardware-based default ZFS layout or a custom ZFS layout during first-boot provisioning.

Decision captured:

- First-boot default provisioning requires explicit end-user confirmation before any destructive pool-create action.

## Related Plans

- .github/plans/README.md - Naming and shared-plan storage conventions.

## Scope

- Define a production path for ZFS support across kernel, gadget, model assertion, image build, and first-boot UX.
- Use N5 Pro hardware profile to provide sensible default ZFS topologies.
- Preserve an explicit custom path so advanced users can choose pool layout, vdev strategy, and mount policy.
- Update docs in the same pass as workflow/model/gadget changes.

Out of scope:

- Migrating existing in-field systems to a new root disk layout.
- Supporting non-N5 hardware topology auto-detection beyond safe fallback behavior.
- Building a full desktop/live-installer ISO workflow (this repo is Ubuntu Core focused).

## Hardware-Derived Design Inputs

From README hardware data:

- Up to five SATA HDD slots (3.5/2.5) -> natural data pool targets.
- Multiple NVMe/U.2 slots -> candidates for boot/system disk, ZFS special vdev, SLOG, or L2ARC.
- ECC-capable memory and NAS use-case -> prioritize data integrity defaults.

Default policy candidates (to validate):

1. Single-disk mode: one-disk pool with no redundancy warning.
2. Two-disk mode: mirror.
3. Three or more data disks: RAIDZ1 default with explicit warning when disk count or capacity profile suggests RAIDZ2.
4. Optional NVMe assignment prompts: leave unused by default, optionally use as cache/log/special vdev.

## Proposed Changes

1. Kernel readiness for ZFS (production)

- Validate whether current pc-kernel channel exposes required ZFS module support on target hardware.
- If missing or unstable, fork/build a custom kernel snap with ZFS support and test import/create on N5 Pro.
- Document supported kernel channel/snap name and constraints.

1. Gadget-driven provisioning defaults

- Introduce or adopt a custom gadget snap path for production provisioning defaults.
- Define gadget defaults that preseed ZFS helper snap configuration keys for default mode:
  - auto-create toggle
  - default pool name
  - selected data-disk IDs strategy
  - optional NVMe role disabled by default
- Ensure defaults are safe and idempotent.

1. First-boot user choice (default vs custom)

- Implement first-boot flow in a helper snap service:
  - If user chooses default, apply hardware-derived layout and create pool.
  - If user chooses custom, skip auto-create and expose guided command path.
- Add a simple interaction mechanism suitable for Ubuntu Core:
  - Console prompt helper command after console-conf
  - SSH-friendly command workflow
- Persist selection and prevent repeated destructive actions after first success.

1. Snap/model integration

- Promote ZFS helper snap from ad-hoc/local behavior to production intent:
  - tighten metadata
  - evaluate confinement path for production posture
- Add required snaps to model assertion when appropriate for enforced production images.
- Keep local dangerous flow available for development/testing.

1. CI workflow updates

- Update image workflow to build required snap sources and fail fast on missing artifacts.
- Add checks that verify expected snaps are present in build outputs.
- Keep documentation aligned with workflow behavior.

1. Documentation and operator guides

- Update docs/BUILDING.md with production build matrix (dangerous vs signed, default vs custom provisioning).
- Update docs/FIRST_BOOT.md with clear decision tree and examples for both modes.
- Update gadget/README.md and snaps/README.md with production role boundaries.
- Update top-level README.md with concise ZFS capability statement and links.

## Files To Touch

- .github/workflows/build-n5pro-image.yml
- model-assertion/n5pro-model.json
- gadget/README.md
- snaps/README.md
- snaps/zfs-tools/snap/snapcraft.yaml
- snaps/zfs-tools/bin/auto-init.sh
- snaps/zfs-tools/bin/init-pool.sh
- snaps/zfs-tools/README.md
- docs/BUILDING.md
- docs/FIRST_BOOT.md
- README.md
- .github/plans/2026-04-27-production-zfs-provisioning-plan.md

## Validation

- Repo consistency review:
  - Verify workflow commands match docs and local bootstrap expectations.
- Snap packaging checks:
  - chmod +x on scripts/hooks before pack.
  - snapcraft pack --destructive-mode for local dump-style snaps.
- Image build checks:
  - Build dangerous image locally (or CI) and confirm helper snap inclusion.
  - Verify first-boot default mode creates expected pool layout using stable disk IDs.
  - Verify custom mode does not auto-create and supports manual commands.
- Runtime checks on N5 hardware:
  - zpool status and zfs list healthy post-provisioning.
  - Reboot idempotency: no repeated pool-creation attempts.

## Risks And Questions

- Kernel support risk: production ZFS depends on kernel module availability and compatibility.
- Confinement risk: production posture may require tighter interfaces or revised snap design.
- UX risk: Ubuntu Core first-boot interaction must stay simple and non-destructive.
- Disk selection risk: wrong default device matching could be destructive without strict by-id rules.

Open questions:

1. Should default layout for 5-bay HDD sets be RAIDZ1 or RAIDZ2 for production baseline?
2. Should NVMe be reserved for system-only by default, or offered as optional special vdev in guided setup?
3. What is the minimum production bar for signed builds before enabling required model snaps?

## Rollout Sequence

1. Land kernel support decision and document it.
2. Land gadget/model default wiring plus helper snap config contract.
3. Land first-boot default/custom UX and safety guards.
4. Land CI/doc updates and run end-to-end test on N5 hardware.
5. Promote to signed build path after validation gate passes.
