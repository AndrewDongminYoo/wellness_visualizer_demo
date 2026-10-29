# Copilot Instructions — Wellness Visualizer

This file is a Copilot-specific adapter for the demo's existing documentation.

## Start here

- Follow the operator's repository instructions.
- Use `README.md` for demo intent and `CLAUDE.md` for commands and architecture.
- Use an approved task spec or plan under `docs/specs/` and `docs/plans/` when supplied.

## Copilot defaults

- Prefer small, production-credible changes.
- Follow TDD for behavior changes.
- Keep structural refactors separate from behavioral changes.
- Verify repo facts instead of guessing.
- Preserve notifier-driven painter updates and the audio envelope tuning documented in `CLAUDE.md`.

## Response guidance

- Lead with a concise plan.
- Summarize changed files and why they changed.
- Include exact verification commands.

For CI expectations, use `.github/AGENTS.md` and `.github/workflows/main.yaml`.
