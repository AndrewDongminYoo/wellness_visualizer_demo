// 🐦 Flutter imports:
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

// 📦 Package imports:
import 'package:flutter_test/flutter_test.dart';

// 🌎 Project imports:
import 'package:wellness_visualizer_demo/audio/audio_engine.dart';
import 'package:wellness_visualizer_demo/visualizers/fireflies_visualizer.dart';

import 'visualizer_test_harness.dart';

void main() {
  for (final count in [0, 1, 90]) {
    testWidgets('draws a core and additive glow for each of $count particles', (tester) async {
      await mountVisualizer(tester, (time) => FirefliesVisualizer(time: time, count: count));
      final circles = paintCircles(visualizerPainter(tester));

      expect(circles, hasLength(count * 2));
      for (var i = 0; i < circles.length; i += 2) {
        expect(circles[i].center, circles[i + 1].center);
        expect(circles[i].radius, greaterThan(circles[i + 1].radius));
        expect(circles[i].blendMode, BlendMode.plus);
        expect(circles[i + 1].blendMode, BlendMode.plus);
      }
    });
  }

  testWidgets('identical inputs produce stable particle drawings', (tester) async {
    await mountVisualizer(tester, (time) => FirefliesVisualizer(time: time));
    final painter = visualizerPainter(tester);
    final before = paintCircles(painter);
    expect(before, isNotEmpty);
    expect(paintCircles(painter), before);
  });

  testWidgets('bass enlarges particles without changing their positions', (tester) async {
    await mountVisualizer(tester, (time) => FirefliesVisualizer(time: time));
    final painter = visualizerPainter(tester);
    final before = paintCircles(painter);

    AudioEngine.instance.bands.value = const Bands(bass: 1, mid: 0, treble: 0, energy: 0.5);
    final after = paintCircles(painter);

    expect(after, hasLength(before.length));
    for (var i = 0; i < before.length; i++) {
      expect(after[i].center, before[i].center);
      expect(after[i].radius, greaterThan(before[i].radius));
      expect(after[i].color, before[i].color);
    }
  });

  testWidgets('mid brightens particles without changing their motion or size', (tester) async {
    await mountVisualizer(tester, (time) => FirefliesVisualizer(time: time));
    final painter = visualizerPainter(tester);
    final before = paintCircles(painter);

    AudioEngine.instance.bands.value = const Bands(bass: 0, mid: 1, treble: 0, energy: 0.5);
    final after = paintCircles(painter);

    expect(after, hasLength(before.length));
    for (var i = 0; i < before.length; i++) {
      expect(after[i].center, before[i].center);
      expect(after[i].radius, before[i].radius);
      expect(after[i].color.a, greaterThan(before[i].color.a));
    }
  });

  testWidgets('treble changes sparkle without changing particle positions', (tester) async {
    await mountVisualizer(tester, (time) => FirefliesVisualizer(time: time, count: 1));
    final painter = visualizerPainter(tester);
    final before = paintCircles(painter);

    AudioEngine.instance.bands.value = const Bands(bass: 0, mid: 0, treble: 0.5, energy: 0.5);
    final after = paintCircles(painter);

    expect(before, hasLength(2));
    expect(after, hasLength(2));
    expect(after.first.center, before.first.center);
    expect(after.last.radius, before.last.radius);
    expect(after.last.color.a, isNot(before.last.color.a));
  });

  testWidgets('particle positions scale with the canvas while radii stay constant', (tester) async {
    await mountVisualizer(tester, (time) => FirefliesVisualizer(time: time));
    final painter = visualizerPainter(tester);
    final before = paintCircles(painter);
    final after = paintCircles(painter, size: sceneSize * 2);

    expect(after, hasLength(before.length));
    for (var i = 0; i < before.length; i++) {
      expect(after[i].center, before[i].center * 2);
      expect(after[i].radius, before[i].radius);
    }
  });

  testWidgets('time repaints moving particles without rebuilding the painter', (tester) async {
    final time = await mountVisualizer(tester, (time) => FirefliesVisualizer(time: time));
    final painter = visualizerPainter(tester);
    final before = await capturePixels(tester);
    expect(totalColor(before), greaterThan(0));

    time.value = 19;
    await tester.pump();
    final after = await capturePixels(tester);

    expect(listEquals(before, after), isFalse, reason: 'Advancing time must change the particle rendering.');
    expect(visualizerPainter(tester), same(painter));
  });

  testWidgets('audio repaints brighter particles without rebuilding the painter', (tester) async {
    await mountVisualizer(tester, (time) => FirefliesVisualizer(time: time));
    final painter = visualizerPainter(tester);
    final before = await capturePixels(tester);

    AudioEngine.instance.bands.value = const Bands(bass: 0, mid: 1, treble: 0, energy: 0.5);
    await tester.pump();
    final after = await capturePixels(tester);

    expect(totalColor(after), greaterThan(totalColor(before)));
    expect(visualizerPainter(tester), same(painter));
  });

  testWidgets('unmount detaches the animation listener', (tester) async {
    final time = await mountVisualizer(tester, (time) => FirefliesVisualizer(time: time));
    expect(time.hasObservers, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());

    expect(time.hasObservers, isFalse);
  });
}
