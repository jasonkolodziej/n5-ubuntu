---
name: repo-planning
description: 'Create or update shared implementation plans for the n5-ubuntu repository. Use when asked to plan, write a plan, save a plan, review prior plans, or reference existing plans before starting work.'
argument-hint: 'Describe the repo task to plan and any existing files or constraints that must be covered.'
---

# Repo Planning

## When To Use
- The user asks for a plan, implementation plan, migration plan, rollout plan, or work breakdown.
- The user asks an agent to save a plan for later reference.
- The user wants a new plan to reuse or cite earlier repo plans.

## Shared Storage
- Store shared plans under `.github/plans/`.
- Keep plans in git so other repo agents and the user can review them later.
- Before creating a new plan, inspect existing files in `.github/plans/` and reuse relevant context.

## Procedure
1. List existing files in `.github/plans/`.
2. Read any overlapping or recent plans before drafting a new one.
3. Create a new plan file with a stable, descriptive name in this format: `YYYY-MM-DD-topic-plan.md`.
4. Add a `Related plans` section near the top that links to any relevant prior plan files.
5. Keep the plan scoped to tracked repo work and mention affected files, validation, risks, and open questions.
6. If the user asks to update an existing plan instead of creating a new one, edit that file and preserve useful history.

## Plan Template
Use this shape unless the task needs something tighter:

```markdown
# <Plan Title>

## Goal
Short statement of what the plan is meant to accomplish.

## Related Plans
- `.github/plans/<existing-plan>.md` - why it matters

## Scope
- In scope items
- Out of scope items

## Proposed Changes
1. First major step.
2. Second major step.
3. Validation or rollout step.

## Files To Touch
- `path/to/file`

## Validation
- Command or review step

## Risks And Questions
- Known risk or dependency
```

## Repo-Specific Rules
- Check `.github/copilot-instructions.md` before finalizing the plan.
- Keep workflow plans aligned with `.ubuntu/README.md` when bootstrap or secret-export behavior is involved.
- Do not include secrets, secret values, or copied contents from `.ubuntu/.env` or `.ubuntu/data/`.
- Prefer file references to concrete repo paths over generic prose.

## Output
- Save the plan in `.github/plans/`.
- In the chat response, mention the created or updated plan path and the prior plans it referenced.