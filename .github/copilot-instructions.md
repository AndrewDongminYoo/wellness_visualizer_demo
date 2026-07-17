# Copilot Instructions — WarmWake

This file is a Copilot-specific adapter over `AGENTS.md`.

## Start here

- Read `AGENTS.md` first.
- Use `PLAN.md` as the default execution queue.
- Use `docs/core/PRODUCT.md` for product intent.

## Copilot defaults

- Prefer small, production-credible changes.
- Follow TDD for behavior changes.
- Keep structural refactors separate from behavioral changes.
- Verify repo facts instead of guessing.
- Keep this file thin; shared workflow and verification policy belong in `AGENTS.md`.

## Response guidance

- Lead with a concise plan.
- Summarize changed files and why they changed.
- Include exact verification commands.

For command details, use `scripts/AGENTS.md`.
