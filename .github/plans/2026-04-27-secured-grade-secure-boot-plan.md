# Secured Grade And Secure Boot Enablement Plan

## Goal

Deliver a production-capable Ubuntu Core image flow that can ship `secured` grade builds with secure boot and encryption expectations, while preserving existing `dangerous` development workflows.

## Related Plans

- .github/plans/README.md - shared planning conventions and naming.
- .github/plans/2026-04-27-production-zfs-provisioning-plan.md - existing production ZFS path and rollout sequencing.

## Investigation Summary (Current State)

- The model assertion template supports grade injection via `"grade": "__GRADE__"`.
- Workflow dispatch now includes all documented Ubuntu Core grades (`dangerous`, `signed`, `secured`).
- Release tagging now marks non-`signed` grades as prerelease.
- The image build currently includes local snap artifacts from `snaps/*.snap`.
- The `zfs-tools` snap is currently `confinement: devmode` and `grade: devel`, intended for development flows.

Implication:

- `secured` can be selected in CI, but current local/devmode snap inclusion means the pipeline is not yet production-hardened for a strict secured posture.

## Scope

- Define a strict secured-grade build path in workflow and model usage.
- Isolate development-only snap behavior from production secured builds.
- Confirm secure boot/FDE prerequisites for target hardware and image composition.
- Keep dangerous/signed paths functional for development and staged rollout.

Out of scope:

- Full redesign of ZFS provisioning UX.
- Device fleet migration from already-installed images.
- New custom bootloader implementation.

## Proposed Changes

1. Enforce grade-aware build policies in CI

- For `secured`: block inclusion of local devmode/devel snaps unless explicitly production-qualified.
- For `dangerous`: preserve current local snap injection behavior.
- For `signed`: keep strict model alignment and production checks.

1. Split snap eligibility by grade

- Add explicit allowlist/denylist checks in workflow before `ubuntu-image` invocation.
- Fail early if a `secured` build detects non-production snap metadata (e.g., devmode, devel, unasserted local-only flow).

1. Define secure boot readiness gates

- Verify gadget/kernel/model combination is valid for secure boot expectations.
- Add documented preflight checklist in docs for `secured` builds.
- Require passing preflight checks before release publication as non-prerelease.

1. Align model assertion and release semantics

- Keep grade values synced with Ubuntu Core model assertion reference.
- Keep release behavior grade-aware (`signed` release, others prerelease) and evaluate whether `secured` should be promoted to full release once gates pass.

1. ZFS production hardening track

- Decide whether `zfs-tools` remains development-only or gets a production variant.
- If production variant is needed, move away from devmode/devel and validate interfaces/runtime dependencies for strict builds.

## Files To Touch

- .github/workflows/build-n5pro-image.yml
- model-assertion/n5pro-model.json
- snaps/zfs-tools/snap/snapcraft.yaml
- docs/BUILDING.md
- docs/FIRST_BOOT.md
- README.md

## Validation

- Workflow matrix/dispatch validation:
  - Run `dangerous`, `signed`, and `secured` workflow dispatches.
- Policy checks:
  - Confirm `secured` fails when development-only snaps are present.
  - Confirm `dangerous` still accepts local development snaps.
- Image build checks:
  - Verify image generation succeeds for allowed grade/snap combinations.
- Runtime checks on hardware:
  - Validate secure boot enabled path and boot behavior.
  - Validate expected encryption/boot constraints for secured builds.

## Risks And Questions

- Risk: `secured` builds may fail until all included snaps meet production/assertion constraints.
- Risk: current ZFS helper implementation may not be compatible with a strict secured policy.
- Risk: secure boot/FDE assumptions can differ by firmware state and hardware configuration.

Open questions:

1. Should `secured` releases be full releases immediately, or remain prerelease until hardware gate evidence is collected?
2. Should `zfs-tools` have separate dev and production snap variants?
3. What minimum validation evidence is required before enabling default `secured` publication?

## Rollout Sequence

1. Add grade-aware guardrails in workflow.
2. Add docs for secured preflight requirements and expected failures.
3. Decide and implement ZFS snap production strategy.
4. Run secured validation on N5 hardware with secure boot enabled.
5. Promote secured release policy once validation criteria are met.
