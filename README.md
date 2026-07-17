# Wellness Visualizer Demo

Demo for the Upwork job (“Flutter Developer – Music Visualizations for Wellness App”).
Two types of audio-responsive visualizers + a combined mode.
Layered over the track’s static theme image.

## Composition

- **Aurora** — FragmentShader (`shaders/aurora.frag`). Three layers of fbm noise curtains, teal→violet palette. Bass → curtain width/height, mid → brightness, treble → ripple detail.
- **Fireflies** — ~90 CustomPainter particles. Slow curl drift, audio mapped only to **glow**, not speed (key to maintaining a wellness mood).
- **Audio Analysis** — Real-time FFT via `flutter_soloud`. Attack ~50 ms / Release ~800 ms. Asymmetric smoothing creates a “rising” effect instead of “flickering.” These tuning values are what set this demo apart, so be sure to fine-tune the `tau` value in `audio_engine.dart` to match your track before recording.

## Setup

```bash
flutter pub get
flutter run   # physical device recommended — simulators misrepresent shader performance
```

Manually add 2 assets (git-ignored):

- `assets/audio/ambient.mp3` — Royalty-free ambient/meditation track (e.g., Pixabay Music). Tracks with some dynamic range show better visual response (avoid purely drone-style tracks).
- `assets/images/theme.jpg` — Vertical image of a night sky or lake (Unsplash).

## Note: flutter_soloud API

The `AudioData` API has undergone breaking changes between major versions.
The code targets ^4.x, where the per-sample getters (`getLinearFft`) were replaced by `getAudioData()` returning a `Float32List` — in linear mode the first 256 floats are FFT bins and the next 256 are wave samples.
If the API drifts again, compare with the visualizer example in the package’s `example/` directory and modify only the `_readBands()` method in `audio_engine.dart`.
The rest of the code simply consumes `Bands` values, so it’s unaffected.

## Recording Guide (for Proposal Attachment)

1. Use a physical device (simulators do not accurately reflect shader performance) with a track that evokes a darkroom atmosphere.
2. 15–30 seconds. Start in **Both** mode → switch to Aurora or Fireflies mode alone midway through to demonstrate compliance with the “multiple styles” requirement.
3. Edit the recording to include both quiet and intense sections so that the audio responsiveness is clearly visible.
4. Record the iPhone screen → Do not edit; leave it as is. The goal is to demonstrate the direction, not to present a finished product.
5. Upload to YouTube (unlisted) or Loom, and include the link in the proposal.

## Performance Notes (Points to use in proposals/interviews)

- Both layers run comfortably at 60 fps even without `RepaintBoundary` (shaders run on the GPU; 90 particles use a single-pass `drawCircle`). To support low-end Android devices, reduce the number of particles and lower the FBM octave (5→3).
- No `setState` frame loop — `Ticker` + `ValueNotifier` are directly connected to `CustomPainter.repaint`. Zero widget rebuilds per frame.
- Expansion directions: ripples (same shader pattern with a radial distance field), constellations (particles + proximity lines), sacred geometry (polar coordinate shaders).
