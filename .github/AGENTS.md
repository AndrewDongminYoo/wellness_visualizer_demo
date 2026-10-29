# .github/

CI, PR metadata, and tool-facing repository automation.
Follow the operator's repository instructions and use `CLAUDE.md` for project commands and architecture.

## Where to look

- CI workflow: `.github/workflows/main.yaml`
- PR template: `.github/PULL_REQUEST_TEMPLATE.md`
- Copilot adapter: `.github/copilot-instructions.md`
- Dependency updates: `.github/dependabot.yaml`

## CI expectations

- PR titles to `main` must be semantic.
- Formatting checks `lib` and `test`.
- Analysis runs on `lib` and `test`.
- The randomized Flutter test suite runs in the build job.
- `cspell` runs across the repository.
