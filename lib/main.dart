// Dart imports:
import 'dart:async';

// Flutter imports:
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

// Project imports:
import 'package:wellness_visualizer_demo/audio/audio_engine.dart';
import 'package:wellness_visualizer_demo/visualizers/aurora_visualizer.dart';
import 'package:wellness_visualizer_demo/visualizers/fireflies_visualizer.dart';

void main() {
  runApp(const DemoApp());
}

class DemoApp extends StatelessWidget {
  const DemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const VisualizerScreen(),
    );
  }
}

enum VisualizerMode { aurora, fireflies, combined }

class VisualizerScreen extends StatefulWidget {
  const VisualizerScreen({super.key});

  @override
  State<VisualizerScreen> createState() => _VisualizerScreenState();
}

class _VisualizerScreenState extends State<VisualizerScreen> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final ValueNotifier<double> _time = ValueNotifier(0);
  Duration _last = Duration.zero;

  VisualizerMode _mode = VisualizerMode.combined;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    unawaited(_ticker.start());
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    _time.value = elapsed.inMicroseconds / 1e6;
    AudioEngine.instance.update(dt.clamp(0.0, 0.05));
  }

  Future<void> _start() async {
    await AudioEngine.instance.playAsset('assets/audio/ambient.mp3');
    setState(() => _started = true);
  }

  @override
  void dispose() {
    _ticker.dispose();
    unawaited(AudioEngine.instance.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showAurora = _mode == VisualizerMode.aurora || _mode == VisualizerMode.combined;
    final showFireflies = _mode == VisualizerMode.fireflies || _mode == VisualizerMode.combined;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // The track's static theme image, dimmed so the visualizer owns
          // the luminance range (mirrors the client's layering requirement).
          Image.asset('assets/images/theme.jpg', fit: BoxFit.cover),
          const ColoredBox(color: Color(0xA6000B14)),

          if (_started && showAurora) AuroraVisualizer(time: _time),
          if (_started && showFireflies) FirefliesVisualizer(time: _time),

          // Minimal chrome — keep the recording clean.
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: _started ? _modeSwitcher() : _playButton(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _playButton() {
    return FilledButton.tonalIcon(
      onPressed: _start,
      icon: const Icon(Icons.play_arrow_rounded),
      label: const Text('Play'),
    );
  }

  Widget _modeSwitcher() {
    return SegmentedButton<VisualizerMode>(
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(value: VisualizerMode.aurora, label: Text('Aurora')),
        ButtonSegment(value: VisualizerMode.fireflies, label: Text('Fireflies')),
        ButtonSegment(value: VisualizerMode.combined, label: Text('Both')),
      ],
      selected: {_mode},
      onSelectionChanged: (s) => setState(() => _mode = s.first),
    );
  }
}
