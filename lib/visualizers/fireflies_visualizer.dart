// Dart imports:
import 'dart:math' as math;

// Flutter imports:
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// Project imports:
import 'package:wellness_visualizer_demo/audio/audio_engine.dart';

/// Floating particles / fireflies. CustomPainter, no shader required.
/// Motion is a slow curl-ish drift; audio maps to glow, not to velocity,
/// so the field stays calm even on louder passages.
class FirefliesVisualizer extends StatefulWidget {
  const FirefliesVisualizer({super.key, required this.time, this.count = 90});

  final ValueListenable<double> time;
  final int count;

  @override
  State<FirefliesVisualizer> createState() => _FirefliesVisualizerState();
}

class _FirefliesVisualizerState extends State<FirefliesVisualizer> {
  late final List<_Firefly> _flies;

  @override
  void initState() {
    super.initState();
    final rng = math.Random(7);
    _flies = List.generate(widget.count, (_) => _Firefly.random(rng));
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _FirefliesPainter(
        flies: _flies,
        time: widget.time,
        bands: AudioEngine.instance.bands,
      ),
    );
  }
}

class _Firefly {
  _Firefly({
    required this.seedX,
    required this.seedY,
    required this.radius,
    required this.phase,
    required this.hueShift,
    required this.drift,
  });

  factory _Firefly.random(math.Random rng) => _Firefly(
        seedX: rng.nextDouble(),
        seedY: rng.nextDouble(),
        radius: 1.2 + rng.nextDouble() * 2.6,
        phase: rng.nextDouble() * math.pi * 2,
        hueShift: rng.nextDouble(),
        drift: 0.6 + rng.nextDouble() * 0.8,
      );

  final double seedX;
  final double seedY;
  final double radius;
  final double phase;
  final double hueShift;
  final double drift;

  Offset positionAt(double t, Size size) {
    // Slow pseudo-curl drift: two incommensurate sine fields per axis.
    final x = seedX + 0.045 * math.sin(t * 0.11 * drift + phase) + 0.025 * math.sin(t * 0.043 * drift + seedY * 9.0);
    final y =
        seedY + 0.035 * math.cos(t * 0.09 * drift + phase * 1.7) + 0.02 * math.sin(t * 0.057 * drift + seedX * 7.0);
    return Offset((x % 1.0) * size.width, (y % 1.0) * size.height);
  }
}

class _FirefliesPainter extends CustomPainter {
  _FirefliesPainter({
    required this.flies,
    required this.time,
    required this.bands,
  }) : super(repaint: Listenable.merge([time, bands]));

  final List<_Firefly> flies;
  final ValueListenable<double> time;
  final ValueListenable<Bands> bands;

  @override
  void paint(Canvas canvas, Size size) {
    final t = time.value;
    final b = bands.value;

    // Base glow follows mid; sparkle chance follows treble.
    final baseGlow = 0.25 + 0.55 * b.mid;

    final glowPaint = Paint()
      ..blendMode = BlendMode.plus
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    final corePaint = Paint()..blendMode = BlendMode.plus;

    for (final f in flies) {
      final pos = f.positionAt(t, size);

      // Each fly twinkles on its own slow cycle; treble adds shimmer.
      final twinkle = 0.5 + 0.5 * math.sin(t * (0.6 + f.drift) + f.phase) * (0.6 + 0.4 * b.treble);
      final alpha = (baseGlow * twinkle).clamp(0.0, 1.0);
      if (alpha < 0.02) continue;

      // Warm amber ~ cool teal mix per firefly, muted for the wellness feel.
      final color = Color.lerp(
        const Color(0xFFFFD9A0),
        const Color(0xFF9FE8D8),
        f.hueShift,
      )!;

      glowPaint.color = color.withValues(alpha: alpha * 0.35);
      corePaint.color = color.withValues(alpha: alpha);

      final r = f.radius * (1.0 + 0.35 * b.bass);
      canvas.drawCircle(pos, r * 3.2, glowPaint);
      canvas.drawCircle(pos, r, corePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _FirefliesPainter oldDelegate) => false;
}
