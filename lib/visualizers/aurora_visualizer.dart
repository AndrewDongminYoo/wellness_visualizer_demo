// Dart imports:
import 'dart:async';
import 'dart:ui' as ui;

// Flutter imports:
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// Project imports:
import 'package:wellness_visualizer_demo/audio/audio_engine.dart';

/// Draws the aurora fragment shader full-screen, additively over whatever
/// sits below it in the Stack (the track's theme image).
class AuroraVisualizer extends StatefulWidget {
  const AuroraVisualizer({super.key, required this.time});

  /// Elapsed time in seconds, driven by the app-level ticker.
  final ValueListenable<double> time;

  @override
  State<AuroraVisualizer> createState() => _AuroraVisualizerState();
}

class _AuroraVisualizerState extends State<AuroraVisualizer> {
  ui.FragmentShader? _shader;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final program = await ui.FragmentProgram.fromAsset('shaders/aurora.frag');
    if (!mounted) return;
    setState(() => _shader = program.fragmentShader());
  }

  @override
  Widget build(BuildContext context) {
    final shader = _shader;
    if (shader == null) return const SizedBox.expand();
    return CustomPaint(
      size: Size.infinite,
      painter: _AuroraPainter(
        shader: shader,
        time: widget.time,
        bands: AudioEngine.instance.bands,
      ),
    );
  }
}

class _AuroraPainter extends CustomPainter {
  _AuroraPainter({
    required this.shader,
    required this.time,
    required this.bands,
  }) : super(repaint: Listenable.merge([time, bands]));

  final ui.FragmentShader shader;
  final ValueListenable<double> time;
  final ValueListenable<Bands> bands;

  @override
  void paint(Canvas canvas, Size size) {
    final b = bands.value;
    shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, time.value)
      ..setFloat(3, b.bass)
      ..setFloat(4, b.mid)
      ..setFloat(5, b.treble);

    final paint = Paint()
      ..shader = shader
      ..blendMode = BlendMode.plus;
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(covariant _AuroraPainter oldDelegate) => false;
}
