# .github/

CI, PR metadata, and tool-facing repository automation.
Inherit `AGENTS.md` first.

## Where to look

- CI workflow: `.github/workflows/main.yaml`
- PR template: `.github/PULL_REQUEST_TEMPLATE.md`
- Copilot adapter: `.github/copilot-instructions.md`
- Dependency updates: `.github/dependabot.yaml`

## CI expectations

- PR titles to `main` must be semantic.
- Formatting checks `lib` and `test`.
- Analysis runs on `lib` and `test`.
- Tests run with coverage and upload filtered coverage to Codecov.
- `cspell` runs across the repository.
