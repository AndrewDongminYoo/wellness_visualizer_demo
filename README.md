# Wellness Visualizer

<p align="center">
  <img src="public/demo.gif" width="300" alt="Aurora and firefly visualizers glowing in sync with ambient music" />
</p>

<p align="center">
  <a href="public/recording.mp4">▶ Watch the full demo with sound (50 s, 2.2 MB)</a>
</p>

A personal Flutter project exploring audio-reactive rendering: real-time FFT analysis drives fragment shaders and a particle system, tuned for a calm, meditative aesthetic rather than a beat-synced light show.
Everything renders over a static theme image with zero widget rebuilds per frame.

## Visualizers

- **Aurora** — a full-screen fragment shader (`shaders/aurora.frag`) layering three FBM noise curtains in a teal→violet palette, composited with `BlendMode.plus`. Bass drives curtain width and height, mids drive brightness, treble adds ripple detail.
- **Fireflies** — ~90 particles rendered by a single-pass `CustomPainter`. They drift on slow curl noise while the audio modulates only their glow.
- **Both** — the two layers stacked, which is the intended viewing mode.

## Design decisions

**Swell, don't strobe.**
Band energies pass through asymmetric attack/release smoothing (~50 ms attack, ~800 ms release), so visuals rise quickly with the music and fade out slowly instead of flickering on every transient.

**Audio maps to glow, never to speed.**
Particle motion stays slow and constant regardless of the track; loudness only changes brightness and bloom.
Keeping motion decoupled from the beat is what preserves the wellness mood.

**Zero widget rebuilds per frame.**
A single `Ticker` advances a `ValueNotifier<double>` clock and pumps the audio engine once per frame.
Both painters repaint via `Listenable.merge([time, bands])` — no `setState` in the render path (mode switching is the only rebuild).
Both layers hold 60 fps on device: the aurora runs on the GPU and the fireflies are one `drawCircle` pass.

**One seam to the audio library.**
`flutter_soloud` provides playback and FFT; its raw output is normalized into smoothed bass/mid/treble/energy bands behind a single reader method, so the visualizers never touch the audio API directly.

## Running it

```bash
flutter pub get
flutter run   # use a physical device — simulators misrepresent shader performance
```

Both assets ship with the repo (royalty-free sources, credited below).

## Possible extensions

Ripples (radial distance field in the same shader pattern), constellations (particles plus proximity lines), sacred geometry (polar-coordinate shaders).
For low-end devices: reduce the particle count and drop FBM octaves from 5 to 3.

## Credits

- Audio: "Zin Uru" by Arulo (royalty-free ambient track)
- Theme image: photo by [Vincentiu Solomon](https://unsplash.com/@vincentiu) on Unsplash
