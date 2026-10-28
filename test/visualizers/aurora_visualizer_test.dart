// 🎯 Dart imports:
import 'dart:ui' as ui;

// 🐦 Flutter imports:
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

// 📦 Package imports:
import 'package:flutter_test/flutter_test.dart';

// 🌎 Project imports:
import 'package:wellness_visualizer_demo/audio/audio_engine.dart';
import 'package:wellness_visualizer_demo/visualizers/aurora_visualizer.dart';

import 'visualizer_test_harness.dart';

void main() {
  testWidgets('shader output matches named size, time, and audio uniforms', (tester) async {
    const bands = Bands(bass: 0.2, mid: 0.4, treble: 0.8, energy: 0.5);
    await mountVisualizer(tester, (time) => AuroraVisualizer(time: time), bands: bands);
    final actual = await capturePixels(tester);
    expect(totalColor(actual), greaterThan(0), reason: 'The shader must produce visible output.');

    // Named uniforms provide an independent check of the painter's positional binding.
    final expected = await tester.runAsync(() async {
      final program = await ui.FragmentProgram.fromAsset('shaders/aurora.frag');
      final shader = program.fragmentShader();
      shader.getUniformVec2('uSize').set(sceneSize.width, sceneSize.height);
      shader.getUniformFloat('uTime').set(7);
      shader.getUniformFloat('uBass').set(0.2);
      shader.getUniformFloat('uMid').set(0.4);
      shader.getUniformFloat('uTreble').set(0.8);
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder)..drawColor(const Color(0xFF000000), BlendMode.src);
      canvas.drawRect(
        Offset.zero & sceneSize,
        Paint()
          ..shader = shader
          ..blendMode = BlendMode.plus,
      );
      final picture = recorder.endRecording();
      final image = await picture.toImage(sceneSize.width.toInt(), sceneSize.height.toInt());
      try {
        final data = await image.toByteData();
        return data!.buffer.asUint8List();
      } finally {
        image.dispose();
        picture.dispose();
        shader.dispose();
      }
    });
    expect(listEquals(actual, expected), isTrue, reason: 'The positional and named uniform renders must agree.');
  });

  for (final entry in [
    (name: 'bass', bands: const Bands(bass: 0.8, mid: 0, treble: 0, energy: 0)),
    (name: 'mid', bands: const Bands(bass: 0, mid: 0.8, treble: 0, energy: 0)),
    (name: 'treble', bands: const Bands(bass: 0, mid: 0, treble: 0.8, energy: 0)),
  ]) {
    testWidgets('${entry.name} changes visible shader output without rebuilding the painter', (tester) async {
      await mountVisualizer(tester, (time) => AuroraVisualizer(time: time));
      final painter = visualizerPainter(tester);
      final before = await capturePixels(tester);

      AudioEngine.instance.bands.value = entry.bands;
      await tester.pump();
      final after = await capturePixels(tester);

      expect(totalColor(after), greaterThan(totalColor(before)));
      expect(visualizerPainter(tester), same(painter));
    });
  }

  testWidgets('time advances the shader without rebuilding the painter', (tester) async {
    final time = await mountVisualizer(tester, (time) => AuroraVisualizer(time: time));
    final painter = visualizerPainter(tester);
    final before = await capturePixels(tester);

    time.value = 19;
    await tester.pump();
    final after = await capturePixels(tester);

    expect(listEquals(before, after), isFalse, reason: 'Advancing time must change the rendered aurora.');
    expect(visualizerPainter(tester), same(painter));
  });

  testWidgets('unmount detaches the animation listener', (tester) async {
    final time = await mountVisualizer(tester, (time) => AuroraVisualizer(time: time));
    visualizerPainter(tester);
    expect(time.hasObservers, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());

    expect(time.hasObservers, isFalse);
  });
}
