# Project Guidelines

## Architecture
This repository builds a custom Ubuntu Core 24 image for the Minisforum N5 Pro.
The tracked source of truth is small and split by responsibility:
- `model-assertion/n5pro-model.json` defines the signed Ubuntu Core model.
- `.github/workflows/build-n5pro-image.yml` signs the model, builds the image, and publishes release artifacts.
- `gadget/README.md` documents optional gadget customization.
- `snaps/README.md` documents optional local `.snap` payloads added to image builds.
- `.ubuntu/` contains local bootstrap and secret-export tooling for generating signing materials and GitHub Actions secrets.

## Build And Validation
Prefer the smallest validation that matches the files you changed.
- For workspace config or JSON-like repo files covered by Biome, use `pnpm exec biome check .` from the repo root.
- Do not assume Biome covers `.github/`, `gadget/`, `model-assertion/`, or `snaps/`; `biome.json` currently excludes those directories.
- For workflow or shell-script changes, validate by reading the surrounding docs and keeping commands consistent between `.github/workflows/` and `.ubuntu/README.md`.
- For Snapcraft packaging in `snaps/`, ensure required metadata is present in `snap/snapcraft.yaml` (at minimum `title`, `contact`, and `license`) and make script/hook files executable before packing.
- On GitHub-hosted runners, prefer `snapcraft pack --destructive-mode` for local dump-style snaps and normalize mode bits in CI (`chmod +x snaps/<name>/bin/*.sh snaps/<name>/hooks/*`) before `snapcraft pack`.

## Conventions
- Keep edits narrow and preserve the existing structure; this repo is mostly configuration, docs, and build orchestration.
- When changing image build behavior, signing flow, model assertion fields, or bootstrap steps, update the relevant docs in the same pass. Usually that means `.ubuntu/README.md`, `gadget/README.md`, or `snaps/README.md`.
- Treat `.ubuntu/.env`, `.ubuntu/data/`, signing keys, exported credentials, and any base64 secret material as sensitive. Never commit them, print them into markdown, or add sample values beyond placeholders already in the repo.
- Prefer changes that work both for the local `.ubuntu` bootstrap flow and for the GitHub Actions workflow instead of introducing environment-specific divergence.
- The default image build path assumes the generic `pc` gadget and optional `.snap` files dropped into `snaps/`.
- For shell snippets and scripts intended to run on macOS, assume the system Bash is 3.2 and avoid Bash 4+ features such as `${var,,}`.

## Copilot Agents And Plans
- Shared repo agents live in `.github/agents/` and are expected to delegate based on task shape: local execution, terminal-first CLI help, cloud-safe repo edits, and review.
- Shared agent-authored plans live in `.github/plans/` and are tracked in git for reuse across sessions and agents.
- When asked to plan, review existing files in `.github/plans/` first, then create or update a plan file that references relevant prior plans by path.