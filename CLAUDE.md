# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

A Flutter demo for an Upwork proposal ([job link](https://www.upwork.com/jobs/~022077819614281231545): "Flutter Developer – Music Visualizations for Wellness App").
It is a proof-of-direction, not a product: audio-reactive visualizers layered over a static theme image, recorded on a physical device and attached to the proposal.
Keep changes small and demo-focused — no architecture beyond what the recording needs.

## Commands

```bash
flutter pub get
flutter run                # use a physical device — simulators misrepresent shader performance
flutter analyze
dart format --line-length 120 .
dart run import_sorter:main
```

Common task scripts (run/test/format/reinstall) are defined in `merry.yaml` (referenced from `pubspec.yaml`'s `scripts:` key).
There is no test suite.
Two assets must be added manually before running (git-ignored, see README): `assets/audio/ambient.mp3` and `assets/images/theme.jpg`.

## Architecture

The entire app is four files driven by one render loop with **zero widget rebuilds per frame**:

- `lib/main.dart` — single screen. A `Ticker` advances a `ValueNotifier<double> _time` and calls `AudioEngine.instance.update(dt)` once per frame. Mode switching (Aurora / Fireflies / Both) is the only `setState`.
- `lib/audio/audio_engine.dart` — singleton wrapping `flutter_soloud` playback + FFT. Publishes smoothed band energies through `ValueNotifier<Bands>` (bass / mid / treble / energy, all 0..1).
- `lib/visualizers/aurora_visualizer.dart` — full-screen `FragmentShader` (`shaders/aurora.frag`) drawn with `BlendMode.plus`.
- `lib/visualizers/fireflies_visualizer.dart` — ~90 particles via `CustomPainter`, single-pass `drawCircle`.

Both painters pass `super(repaint: Listenable.merge([time, bands]))` and return `false` from `shouldRepaint` — repainting is driven entirely by the notifiers, never by widget rebuilds.
Preserve this pattern in any new visualizer.

### The wellness tuning (the point of the demo)

`AudioEngine.update` applies asymmetric attack/release smoothing: `tau = 0.05s` rising, `0.80s` falling.
Visuals swell instead of strobing.
Audio maps to **glow/brightness, never to particle speed**.
These constants are the demo's differentiator — tune them per track, don't "simplify" them away.

### Shader uniform contract

`aurora.frag` uniforms are set positionally in `_AuroraPainter.paint`: 0=width, 1=height, 2=time, 3=bass, 4=mid, 5=treble.
Changing the shader's uniform order requires updating the painter in lockstep.

### flutter_soloud API drift

The `AudioData` API has breaking changes across major versions; the code targets ^4.x, where per-sample getters (`getLinearFft`) were replaced by `getAudioData()` returning a `Float32List` (linear mode: first 256 floats = FFT bins, next 256 = wave samples).
If the API drifts again, fix only `AudioEngine._readBands` (compare with the package's `example/` visualizer) — everything else consumes `Bands` and is unaffected.

## Known Config Quirks

- `.github/copilot-instructions.md` and `.github/AGENTS.md` are leftovers from a different template project ("WarmWake") and reference files that don't exist here (`PLAN.md`, `docs/`, root `AGENTS.md`, `test/`). Ignore them.
- `analysis_options.yaml` includes the repo-local `flutter_lints.yaml` (a checked-in copy of the full SDK lint list with per-rule overrides) — the `flutter_lints` package include is not used.
- `l10n.yaml` points to a removed `lib/l10n/`; stale from the pre-cleanup template.

## Extension Directions (from README)

Ripples (radial distance field, same shader pattern), constellations (particles + proximity lines), sacred geometry (polar coordinate shaders).
For low-end Android: reduce particle count and drop FBM octaves 5→3.
