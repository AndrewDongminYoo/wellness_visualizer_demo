# SoLoud v5 Visualization Migration

## Problem and scope

The engine polls the removed flutter_soloud 4.x `AudioData` API while the dependency is upgraded to 5.2.2.
Migrate to `audioVisualizationEvents`, preserve the existing `Bands` interface and attack/release tuning, and add repeatable audio and visualizer tests.
The operator also approved including the existing Dart SDK, Material UI imports, constructor syntax, lint configuration, and generated plugin registration updates in this PR.

## Acceptance criteria

- A 512-sample FFT window produces 256 bins for the existing band ranges.
- Stream packets update raw targets while frame updates apply smoothing.
- Stopping playback cancels the subscription and allows bands to decay toward silence.
- Tests exercise band mapping, malformed packets, playback lifecycle, actual shader output, particle drawing, and repaint notification delivery.
- CI executes the test suite and analyzes both application and test code.
- Project-local SoLoud guidance retains only the visualization skill used during migration.
- Formatting, static analysis, tests, and applicable repository hooks pass.

## Constraints and limits

Keep the existing visualizer algorithms, shader uniforms, colors, and motion rules.
Do not add runtime abstractions or test dependencies beyond the Flutter SDK test package.
Flutter renderer tests do not establish native decoding, physical audio output, or device GPU performance.
The audio migration and Material UI dependency transition require operator review of motion evidence before merge.
