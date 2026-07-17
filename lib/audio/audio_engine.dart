// Dart imports:
import 'dart:math' as math;

// Flutter imports:
import 'package:flutter/foundation.dart';

// Package imports:
import 'package:flutter_soloud/flutter_soloud.dart';

/// Wraps SoLoud playback + FFT analysis and exposes *smoothed* band energies
/// tuned for a wellness aesthetic: fast attack, slow release, so visuals
/// "swell" with the music instead of strobing on every beat.
///
/// NOTE: flutter_soloud's AudioData API has had breaking changes between
/// major versions. This file is written against ^4.x, where per-sample
/// getters (`getLinearFft`) were replaced by [AudioData.getAudioData]. If the
/// API drifts again, only [_readBands] needs edits — everything else
/// consumes [Bands].
class AudioEngine {
  AudioEngine._();
  static final AudioEngine instance = AudioEngine._();

  final SoLoud _soloud = SoLoud.instance;
  late AudioSource _source;
  SoundHandle? _handle;
  AudioData? _audioData;

  /// Smoothed 0..1 energies, updated once per frame via [update].
  final ValueNotifier<Bands> bands = ValueNotifier(Bands.zero);

  bool get isPlaying => _handle != null;

  Future<void> init() async {
    if (_soloud.isInitialized) return;
    await _soloud.init();
    _soloud.setVisualizationEnabled(true);
    // Smooth SoLoud's own FFT windowing a touch; we do the musical
    // smoothing ourselves in [update].
    _soloud.setFftSmoothing(0.6);
  }

  Future<void> playAsset(String assetPath) async {
    await init();
    await stop();
    _source = await _soloud.loadAsset(assetPath);
    _handle = _soloud.play(_source, looping: true);
    _audioData = AudioData(GetSamplesKind.linear);
  }

  Future<void> stop() async {
    final h = _handle;
    _handle = null;
    if (h != null) await _soloud.stop(h);
    _audioData?.dispose();
    _audioData = null;
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
    final data = _audioData;
    if (data != null && _handle != null) {
      data.updateSamples();
      _readBands(data);
    }

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

  void _readBands(AudioData data) {
    // With GetSamplesKind.linear the first 256 floats are FFT bins spanning
    // ~0..22kHz (~86Hz per bin); the next 256 are raw wave samples.
    final samples = data.getAudioData();
    if (samples.length < 256) return;

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

  Future<void> dispose() async {
    await stop();
    _soloud.deinit();
  }
}

@immutable
class Bands {
  const Bands({
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
