# SoLoud v5 Delivery Plan

## Approved direction

Complete the requested migration and test additions, include all current changes as approved by the operator, and deliver them through the explicit `pr-loop` invocation.
Implementation and observed regression failures already exist; reuse that work.

## Commit sequence

1. Align the SDK, Material UI imports, constructor syntax, and lint configuration.
   Verify the isolated candidate with dependency resolution, Dart formatting, and static analysis.
2. Commit the SoLoud stream migration, matching dependency lockfile, generated plugin registration, audio tests, and affected documentation.
   Verify stream behavior with the audio tests and static analysis.
3. Commit visualizer tests, shared test fixtures, affected documentation, and CI test execution.
   Verify the complete test suite and renderer output.
4. Commit the focused project-local SoLoud visualization guidance.
   Run applicable repository hooks and the advisory Codex diagnostic.

## Review and delivery

Use independent read-only passes for audio lifecycle and rendering/test integration, followed by a root cross-check.
Inspect each candidate index before committing and verify that the intermediate manifest and lockfile agree.
Push a task branch and open a non-draft PR against `main`.
Observe bounded current-head CI and hosted review, address confirmed findings, and finalize the PR body before assigning the operator.
Preserve visible motion evidence and request operator visual approval before the delegated merge.
Keep cleanup and memory recording outside scope because neither was requested.
