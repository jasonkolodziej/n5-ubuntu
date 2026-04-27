# n5-ubuntu

Build assets and supporting docs for a custom Ubuntu Core 24 image targeting the Minisforum N5 Pro.

## Getting Started

For complete instructions on building, flashing, and setting up the system:

- **Build Instructions**: See [docs/BUILDING.md](./docs/BUILDING.md)
- **Flashing to USB**: See [docs/FLASHING.md](./docs/FLASHING.md)
- **First Boot Setup**: See [docs/FIRST_BOOT.md](./docs/FIRST_BOOT.md)
- **Documentation Index**: See [docs/README.md](./docs/README.md)

## Repository Layout

- `docs/` contains user-facing guides for building and flashing.
- `model-assertion/n5pro-model.json` defines the signed model assertion template.
- `.github/workflows/build-n5pro-image.yml` builds and releases the image.
- `.ubuntu/` contains the local signing and GitHub secret bootstrap flow.
- `gadget/` and `snaps/` document optional gadget and local snap customization.

## Copilot Customization

- Repo-wide agent guidance lives in `.github/copilot-instructions.md`.
- Custom agents live in `.github/agents/`:
  - `local.agent.md` for direct local workspace edits and validation.
  - `copilot-cli.agent.md` for terminal-first command work.
  - `cloud.agent.md` for cloud-safe tracked-file changes.
  - `reviewer.agent.md` for workflow, model assertion, and docs review.
- Shared plan files live in `.github/plans/` and are intended to be referenced across sessions.
- The shared planning workflow lives in `.github/skills/repo-planning/` and should be used whenever a repo agent is asked to create or update a plan.
