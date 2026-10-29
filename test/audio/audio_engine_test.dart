// 🎯 Dart imports:
import 'dart:async';
import 'dart:typed_data';

// 🐦 Flutter imports:
import 'package:flutter/services.dart';

// 📦 Package imports:
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:flutter_test/flutter_test.dart';

// 🌎 Project imports:
import 'package:wellness_visualizer_demo/audio/audio_engine.dart';

void main() {
  late _FakeSoLoud soloud;
  late AudioEngine engine;

  setUp(() {
    soloud = _FakeSoLoud();
    engine = AudioEngine(soloud: soloud);
  });

  tearDown(() async {
    await engine.dispose();
    await soloud.visualization.close();
  });

  test('initializes a 256-bin FFT stream once', () async {
    await engine.init();
    await engine.init();

    expect(soloud.initCalls, 1);
    expect(soloud.visualizationEnabled, isTrue);
    expect(soloud.windowSize, 512);
    expect(soloud.kind, VisualizationKind.fft);
    expect(soloud.channel, VisualizationChannel.merged);
    expect(soloud.smoothing, 0.6);
  });

  test('maps streamed FFT bins to bands only when a frame advances', () async {
    await engine.playAsset('track.mp3');
    final packet = _packet(bass: 0.125, mid: 0.1, treble: 0.05);
    // DC and bins above the treble range must not influence the bands.
    packet.fftData![0] = 1;
    packet.fftData!.fillRange(192, 256, 1);
    soloud.emit(packet);

    expect(engine.bands.value, same(Bands.zero));
    engine.update(10);

    _expectBands(engine.bands.value, bass: 0.2, mid: 0.3, treble: 0.3, energy: 0.25);
    expect(engine.isPlaying, isTrue);
    expect(soloud.loadedAssets, ['track.mp3']);
    expect(soloud.looping, isTrue);
  });

  for (final band in [
    (name: 'bass', bass: 0.1, mid: 0.0, treble: 0.0, wantBass: 0.16, wantMid: 0.0, wantTreble: 0.0, energy: 0.08),
    (name: 'mid', bass: 0.0, mid: 0.1, treble: 0.0, wantBass: 0.0, wantMid: 0.3, wantTreble: 0.0, energy: 0.105),
    (name: 'treble', bass: 0.0, mid: 0.0, treble: 0.1, wantBass: 0.0, wantMid: 0.0, wantTreble: 0.6, energy: 0.09),
  ]) {
    test('keeps ${band.name} FFT energy in its own band', () async {
      await engine.playAsset('track.mp3');
      soloud.emit(_packet(bass: band.bass, mid: band.mid, treble: band.treble));
      engine.update(10);

      _expectBands(
        engine.bands.value,
        bass: band.wantBass,
        mid: band.wantMid,
        treble: band.wantTreble,
        energy: band.energy,
      );
    });
  }

  test('ignores missing or short FFT packets without losing the last targets', () async {
    await engine.playAsset('track.mp3');
    soloud.emit(_packet(bass: 0.125));
    soloud.emit(const AudioVisualizationData(channelCount: 1, wave: [], fft: []));
    soloud.emit(AudioVisualizationData(channelCount: 1, wave: [], fft: [Float32List(128)]));
    engine.update(10);

    _expectBands(engine.bands.value, bass: 0.2, energy: 0.1);
  });

  test('clamps amplified FFT bands to the normalized range', () async {
    await engine.playAsset('track.mp3');
    soloud.emit(_packet(bass: 1, mid: 1, treble: 1));
    engine.update(10);
    _expectBands(engine.bands.value, bass: 1, mid: 1, treble: 1, energy: 1);

    soloud.emit(_packet(bass: -1, mid: -1, treble: -1));
    engine.update(30);
    _expectBands(engine.bands.value);
  });

  test('uses fast attack and slow release at the frame delta', () async {
    await engine.playAsset('track.mp3');
    soloud.emit(_packet(bass: 1, mid: 1, treble: 1));
    engine.update(0);
    _expectBands(engine.bands.value);
    engine.update(0.05);
    _expectBands(engine.bands.value, bass: 0.63212056, mid: 0.63212056, treble: 0.63212056, energy: 0.63212056);

    soloud.emit(_packet());
    engine.update(0.8);
    _expectBands(engine.bands.value, bass: 0.23254416, mid: 0.23254416, treble: 0.23254416, energy: 0.23254416);
  });

  test('uses the latest packet when several arrive before a frame', () async {
    await engine.playAsset('track.mp3');
    soloud.emit(_packet(bass: 1));
    soloud.emit(_packet(bass: 0.125));
    engine.update(10);

    _expectBands(engine.bands.value, bass: 0.2, energy: 0.1);
  });

  test('stop cancels FFT delivery and lets existing energy decay', () async {
    await engine.playAsset('track.mp3');
    soloud.emit(_packet(bass: 0.125));
    engine.update(10);

    await engine.stop();
    expect(engine.isPlaying, isFalse);
    expect(soloud.visualization.hasListener, isFalse);
    expect(soloud.stoppedHandles, [const SoundHandle(1)]);
    soloud.emit(_packet(bass: 1, mid: 1, treble: 1));
    engine.update(0.8);
    _expectBands(engine.bands.value, bass: 0.07357589, energy: 0.03678794);
    engine.update(30);
    _expectBands(engine.bands.value);
  });

  test('replacing a track stops the old voice and receives new FFT packets', () async {
    await engine.playAsset('first.mp3');
    soloud.emit(_packet(bass: 1));
    engine.update(10);

    await engine.playAsset('second.mp3');
    expect(soloud.stoppedHandles, [const SoundHandle(1)]);
    expect(soloud.loadedAssets, ['first.mp3', 'second.mp3']);
    engine.update(30);
    _expectBands(engine.bands.value);

    soloud.emit(_packet(mid: 0.1));
    engine.update(10);
    _expectBands(engine.bands.value, mid: 0.3, energy: 0.105);
  });

  test('dispose releases the stream and allows initialization for replay', () async {
    await engine.playAsset('track.mp3');
    soloud.emit(_packet(bass: 1));
    engine.update(10);
    await engine.dispose();

    expect(engine.isPlaying, isFalse);
    expect(soloud.isInitialized, isFalse);
    expect(soloud.visualization.hasListener, isFalse);
    engine.update(30);
    _expectBands(engine.bands.value);

    await engine.playAsset('track.mp3');
    soloud.emit(_packet(treble: 0.1));
    engine.update(10);
    _expectBands(engine.bands.value, treble: 0.6, energy: 0.09);
    expect(soloud.initCalls, 2);
  });

  test('overlapping plays do not leave FFT delivery active after stop', () async {
    await engine.init();
    final barrier = Completer<void>();
    soloud.loadBarrier = barrier;

    final first = engine.playAsset('first.mp3');
    await Future<void>.delayed(Duration.zero);
    final second = engine.playAsset('second.mp3');
    await Future<void>.delayed(Duration.zero);
    expect(soloud.loadedAssets, ['first.mp3', 'second.mp3']);

    barrier.complete();
    await Future.wait([first, second]);
    await engine.stop();
    soloud.emit(_packet(bass: 1, mid: 1, treble: 1));
    engine.update(10);

    _expectBands(engine.bands.value);
    expect(soloud.visualization.hasListener, isFalse);
  });

  for (final olderFinishesFirst in [true, false]) {
    test('only the latest load plays when older finishes first: $olderFinishesFirst', () async {
      final older = Completer<void>();
      final newer = Completer<void>();
      soloud.loadBarriers.addAll({'first.mp3': older, 'second.mp3': newer});

      final first = engine.playAsset('first.mp3');
      await Future<void>.delayed(Duration.zero);
      final second = engine.playAsset('second.mp3');
      await Future<void>.delayed(Duration.zero);
      expect(soloud.loadedAssets, ['first.mp3', 'second.mp3']);

      if (olderFinishesFirst) {
        older.complete();
        await first;
        expect(soloud.playedAssets, isEmpty);
        newer.complete();
      } else {
        newer.complete();
        await second;
        older.complete();
      }
      await Future.wait([first, second]);

      expect(soloud.playedAssets, ['second.mp3']);
      expect(soloud.activeHandles, hasLength(1));
      await engine.stop();
      expect(soloud.activeHandles, isEmpty);
    });
  }

  test('stop invalidates a pending asset load', () async {
    final barrier = Completer<void>();
    soloud.loadBarrier = barrier;
    final playback = engine.playAsset('track.mp3');
    await Future<void>.delayed(Duration.zero);
    expect(soloud.loadedAssets, ['track.mp3']);

    await engine.stop();
    barrier.complete();
    await playback;

    expect(engine.isPlaying, isFalse);
    expect(soloud.playedAssets, isEmpty);
    expect(soloud.activeHandles, isEmpty);
    expect(soloud.visualization.hasListener, isFalse);
  });

  test('dispose invalidates a pending asset load', () async {
    final barrier = Completer<void>();
    soloud.loadBarrier = barrier;
    final playback = engine.playAsset('track.mp3');
    await Future<void>.delayed(Duration.zero);

    await engine.dispose();
    barrier.complete();
    await playback;

    expect(soloud.isInitialized, isFalse);
    expect(engine.isPlaying, isFalse);
    expect(soloud.activeHandles, isEmpty);
    expect(soloud.visualization.hasListener, isFalse);
  });

  test('simultaneous plays share engine initialization', () async {
    final barrier = Completer<void>();
    soloud.initBarrier = barrier;
    final first = engine.playAsset('first.mp3');
    final second = engine.playAsset('second.mp3');
    await Future<void>.delayed(Duration.zero);
    expect(soloud.initCalls, 1);

    barrier.complete();
    await Future.wait([first, second]);
    expect(soloud.playedAssets, ['second.mp3']);
    expect(soloud.activeHandles, hasLength(1));
  });

  test('dispose waits for pending initialization before deinitializing', () async {
    final barrier = Completer<void>();
    soloud.initBarrier = barrier;
    final playback = engine.playAsset('track.mp3');
    await Future<void>.delayed(Duration.zero);
    final disposal = engine.dispose();
    barrier.complete();
    await Future.wait([playback, disposal]);

    expect(soloud.isInitialized, isFalse);
    expect(soloud.activeHandles, isEmpty);
    expect(soloud.playedAssets, isEmpty);
  });

  test('new playback waits for disposal and then reinitializes', () async {
    final barrier = Completer<void>();
    soloud.initBarrier = barrier;
    final first = engine.playAsset('first.mp3');
    await Future<void>.delayed(Duration.zero);
    final disposal = engine.dispose();
    final second = engine.playAsset('second.mp3');
    barrier.complete();
    await Future.wait([first, disposal, second]);

    expect(soloud.initCalls, 2);
    expect(soloud.isInitialized, isTrue);
    expect(soloud.playedAssets, ['second.mp3']);
    expect(soloud.activeHandles, hasLength(1));
  });

  test('a superseded load failure does not reject the latest playback', () async {
    final barrier = Completer<void>();
    soloud.loadBarriers['first.mp3'] = barrier;
    soloud.loadErrors['first.mp3'] = Exception('cancelled load');
    final first = engine.playAsset('first.mp3');
    await Future<void>.delayed(Duration.zero);
    await engine.playAsset('second.mp3');
    barrier.complete();
    await first;

    expect(soloud.playedAssets, ['second.mp3']);
    expect(soloud.activeHandles, hasLength(1));
  });

  test('a failed asset load leaves playback stopped without an FFT subscription', () async {
    await engine.playAsset('track.mp3');
    soloud.emit(_packet(bass: 1));
    engine.update(10);
    soloud.loadError = Exception('asset load failed');

    await expectLater(engine.playAsset('missing.mp3'), throwsA(same(soloud.loadError)));
    expect(engine.isPlaying, isFalse);
    expect(soloud.visualization.hasListener, isFalse);
    engine.update(30);
    _expectBands(engine.bands.value);
  });
}

AudioVisualizationData _packet({double bass = 0, double mid = 0, double treble = 0}) {
  final fft = Float32List(256)
    ..fillRange(1, 8, bass)
    ..fillRange(8, 64, mid)
    ..fillRange(64, 192, treble);
  return AudioVisualizationData(
    channelCount: 1,
    wave: [Float32List.fromList(List.filled(512, 1))],
    fft: [fft],
  );
}

void _expectBands(Bands bands, {double bass = 0, double mid = 0, double treble = 0, double energy = 0}) {
  expect(bands.bass, closeTo(bass, 0.000001));
  expect(bands.mid, closeTo(mid, 0.000001));
  expect(bands.treble, closeTo(treble, 0.000001));
  expect(bands.energy, closeTo(energy, 0.000001));
}

/// Replaces the native audio device boundary while retaining real stream delivery.
class _FakeSoLoud implements SoLoud {
  final visualization = StreamController<AudioVisualizationData>.broadcast(sync: true);
  final loadedAssets = <String>[];
  final stoppedHandles = <SoundHandle>[];
  final playedAssets = <String>[];
  final activeHandles = <SoundHandle>{};
  final loadBarriers = <String, Completer<void>>{};
  final loadErrors = <String, Exception>{};
  int initCalls = 0;
  int _nextHandle = 0;
  bool _initialized = false;
  bool visualizationEnabled = false;
  int? windowSize;
  VisualizationKind? kind;
  int? channel;
  double? smoothing;
  bool? looping;
  Exception? loadError;
  Completer<void>? loadBarrier;
  Completer<void>? initBarrier;

  @override
  bool get isInitialized => _initialized;

  @override
  Stream<AudioVisualizationData> get audioVisualizationEvents => visualization.stream;

  void emit(AudioVisualizationData packet) {
    if (visualizationEnabled) visualization.add(packet);
  }

  @override
  Future<void> init({
    PlaybackDevice? device,
    bool automaticCleanup = false,
    int sampleRate = 44100,
    int bufferSize = 2048,
    Channels channels = Channels.stereo,
    bool lowLatency = true,
    AndroidAAudioAttributes androidAAudioAttributes = AndroidAAudioAttributes.mediaMusic,
    LinuxAudioBackend linuxAudioBackend = LinuxAudioBackend.auto,
    int? devicePeriodFrames,
    int? renderAheadFrames,
  }) async {
    initCalls++;
    if (initBarrier case final barrier?) await barrier.future;
    _initialized = true;
  }

  @override
  void setVisualizationEnabled(
    bool enabled, {
    int windowSize = 256,
    VisualizationKind kind = VisualizationKind.waveAndFft,
    int channel = VisualizationChannel.merged,
  }) {
    if (!_initialized) throw StateError('Visualization requires initialization');
    visualizationEnabled = enabled;
    this.windowSize = windowSize;
    this.kind = kind;
    this.channel = channel;
  }

  @override
  void setFftSmoothing(double smooth) {
    smoothing = smooth;
  }

  @override
  Future<AudioSource> loadAsset(
    String key, {
    LoadMode mode = LoadMode.memory,
    AssetBundle? assetBundle,
    bool autoDispose = false,
  }) async {
    if (loadError case final error?) throw error;
    loadedAssets.add(key);
    final barrier = loadBarriers[key] ?? loadBarrier;
    if (barrier != null) await barrier.future;
    if (loadErrors[key] case final error?) throw error;
    return _FakeAudioSource(key);
  }

  @override
  SoundHandle play(
    AudioSource sound, {
    int busId = 0,
    double volume = 1,
    double pan = 0,
    bool paused = false,
    bool looping = false,
    Duration loopingStartAt = Duration.zero,
    Duration? loopingEndAt,
    int? loopingStartOffsetAt,
    int? loopingEndOffsetAt,
    double scale = 1,
  }) {
    if (!_initialized) throw const SoLoudNotInitializedException();
    this.looping = looping;
    playedAssets.add(sound.soundPath);
    final handle = SoundHandle(++_nextHandle);
    activeHandles.add(handle);
    return handle;
  }

  @override
  Future<void> stop(SoundHandle handle) async {
    stoppedHandles.add(handle);
    activeHandles.remove(handle);
  }

  @override
  void deinit() {
    _initialized = false;
    visualizationEnabled = false;
    activeHandles.clear();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAudioSource implements AudioSource {
  new(this.soundPath);

  @override
  String soundPath;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
