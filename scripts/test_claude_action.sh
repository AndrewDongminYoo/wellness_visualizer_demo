#!/usr/bin/env bash
set -euo pipefail

repository_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
action_sha=$(
	python3 - "${repository_root}/.github/workflows/claude.yml" <<'PY'
import re
import sys
from pathlib import Path

workflow = Path(sys.argv[1]).read_text()
refs = re.findall(
    r"^\s*-?\s*uses:\s*anthropics/claude-code-action@(\S+)",
    workflow,
    re.MULTILINE,
)
if len(refs) != 1 or re.fullmatch(r"[0-9a-f]{40}", refs[0]) is None:
    raise SystemExit("Expected exactly one SHA-pinned Claude Code Action")
print(refs[0])
PY
)

scratch_directory=$(mktemp -d "${TMPDIR:-/tmp}/wellness-claude-tests.XXXXXX")
trap 'rm -rf -- "${scratch_directory}"' EXIT

printf 'Testing anthropics/claude-code-action@%s\n' "${action_sha}"
curl --fail --silent --show-error --location \
	"https://codeload.github.com/anthropics/claude-code-action/tar.gz/${action_sha}" \
	--output "${scratch_directory}/action.tar.gz"
mkdir "${scratch_directory}/source"
tar -xzf "${scratch_directory}/action.tar.gz" --strip-components=1 -C "${scratch_directory}/source"

cd "${scratch_directory}/source"
bun install --frozen-lockfile --ignore-scripts
bun test
bun run typecheck
