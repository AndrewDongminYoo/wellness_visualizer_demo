// 🎯 Dart imports:
import 'dart:async';
import 'dart:math' as math;

// 🐦 Flutter imports:
import 'package:flutter/foundation.dart';

// 📦 Package imports:
import 'package:flutter_soloud/flutter_soloud.dart';

/// Wraps SoLoud playback + FFT analysis and exposes *smoothed* band energies tuned for a wellness aesthetic: fast attack, slow release, so visuals "swell" with the music instead of strobing on every beat.
///
/// Receives FFT packets from SoLoud's visualization stream and applies frame-based smoothing in [update].
/// Visualizers consume [Bands] independently of the plugin's visualization API.
class AudioEngine {
  new({SoLoud? soloud}) : _soloud = soloud ?? SoLoud.instance;
  static final AudioEngine instance = AudioEngine();

  final SoLoud _soloud;
  SoundHandle? _handle;
  StreamSubscription<AudioVisualizationData>? _visualizationSubscription;
  Future<void>? _initializing;
  Future<void>? _disposing;
  int _playbackRequest = 0;

  /// Smoothed 0..1 energies, updated once per frame via [update].
  final ValueNotifier<Bands> bands = ValueNotifier(Bands.zero);

  bool get isPlaying => _handle != null;

  Future<void> init() async {
    if (_disposing case final disposal?) await disposal;
    if (_initializing case final initialization?) {
      await initialization;
      return;
    }
    if (_soloud.isInitialized) return;
    final initialization = _initialize();
    _initializing = initialization;
    try {
      await initialization;
    } finally {
      _initializing = null;
    }
  }

  Future<void> _initialize() async {
    await _soloud.init();
    _soloud.setVisualizationEnabled(
      true,
      windowSize: 512,
      kind: VisualizationKind.fft,
    );
    // Smooth SoLoud's own FFT windowing a touch; we do the musical
    // smoothing ourselves in [update].
    _soloud.setFftSmoothing(0.6);
  }

  Future<void> playAsset(String assetPath) async {
    final request = ++_playbackRequest;
    try {
      if (_disposing case final disposal?) await disposal;
      if (request != _playbackRequest) return;
      await init();
      if (request != _playbackRequest) return;
      await _stopCurrentPlayback();
      if (request != _playbackRequest) return;
      final source = await _soloud.loadAsset(assetPath);
      if (request != _playbackRequest) return;
      _handle = _soloud.play(source, looping: true);
      unawaited(_visualizationSubscription?.cancel());
      _visualizationSubscription = _soloud.audioVisualizationEvents.listen(_readBands);
    } catch (_) {
      if (request != _playbackRequest) return;
      rethrow;
    }
  }

  Future<void> stop() {
    _playbackRequest++;
    return _stopCurrentPlayback();
  }

  Future<void> _stopCurrentPlayback() async {
    final h = _handle;
    final subscription = _visualizationSubscription;
    _handle = null;
    _visualizationSubscription = null;
    _rawBass = 0;
    _rawMid = 0;
    _rawTreble = 0;
    await subscription?.cancel();
    if (h != null) await _soloud.stop(h);
  }

  // -- analysis ------------------------------------------------------------

  // Raw (pre-smoothing) band values from the last FFT read.
  double _rawBass = 0;
  double _rawMid = 0;
  double _rawTreble = 0;

  // Attack/release smoothing state.
  double _bass = 0;
  double _mid = 0;
  double _treble = 0;
  double _energy = 0;

  /// Call once per frame with the frame delta in seconds.
  void update(double dt) {
    // Wellness tuning: reach ~90% of a rising value in ~120ms (attack),
    // but take ~1.8s to decay (release). No strobe, only swell.
    double follow(double current, double target) {
      final tau = target > current ? 0.05 : 0.80; // seconds
      final k = 1 - math.exp(-dt / tau);
      return current + (target - current) * k;
    }

    _bass = follow(_bass, _rawBass);
    _mid = follow(_mid, _rawMid);
    _treble = follow(_treble, _rawTreble);
    _energy = follow(_energy, _rawBass * 0.5 + _rawMid * 0.35 + _rawTreble * 0.15);

    bands.value = Bands(bass: _bass, mid: _mid, treble: _treble, energy: _energy);
  }

  void _readBands(AudioVisualizationData data) {
    // A 512-sample window provides 256 FFT bins (~86Hz per bin at 44.1kHz).
    final samples = data.fftData;
    if (samples == null || samples.length < 256) return;

    double avg(int from, int to) {
      var sum = 0.0;
      for (var i = from; i < to; i++) {
        sum += samples[i];
      }
      return sum / (to - from);
    }

    // Perceptual-ish normalization; ambient/wellness tracks are bass-heavy,
    // so treble gets a generous boost to stay expressive.
    _rawBass = (avg(1, 8) * 1.6).clamp(0.0, 1.0);
    _rawMid = (avg(8, 64) * 3.0).clamp(0.0, 1.0);
    _rawTreble = (avg(64, 192) * 6.0).clamp(0.0, 1.0);
  }

  Future<void> dispose() {
    _playbackRequest++;
    return _disposing ??= _dispose().whenComplete(() => _disposing = null);
  }

  Future<void> _dispose() async {
    await _stopCurrentPlayback();
    try {
      await _initializing;
    } finally {
      _soloud.deinit();
    }
  }
}

@immutable
class Bands {
  const new({
    required this.bass,
    required this.mid,
    required this.treble,
    required this.energy,
  });

  static const zero = Bands(bass: 0, mid: 0, treble: 0, energy: 0);

  final double bass;
  final double mid;
  final double treble;

  /// Weighted overall loudness, 0..1.
  final double energy;
}
