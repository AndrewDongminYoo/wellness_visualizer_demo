// 🐦 Flutter imports:
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

// 📦 Package imports:
import 'package:flutter_test/flutter_test.dart';

// 🌎 Project imports:
import 'package:wellness_visualizer_demo/audio/audio_engine.dart';

const sceneSize = Size(160, 120);
const ValueKey<String> _captureKey = ValueKey('visualizer-capture');

class AnimationTime extends ValueNotifier<double> {
  new() : super(0);

  bool get hasObservers => hasListeners;
}

Future<AnimationTime> mountVisualizer(
  WidgetTester tester,
  Widget Function(ValueNotifier<double>) create, {
  double seconds = 7,
  Bands bands = Bands.zero,
}) async {
  final time = AnimationTime()..value = seconds;
  final previousBands = AudioEngine.instance.bands.value;
  AudioEngine.instance.bands.value = bands;
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    time.dispose();
    AudioEngine.instance.bands.value = previousBands;
  });
  await tester.pumpWidget(
    Center(
      child: SizedBox.fromSize(
        size: sceneSize,
        child: RepaintBoundary(
          key: _captureKey,
          child: ColoredBox(color: const Color(0xFF000000), child: create(time)),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return time;
}

CustomPainter visualizerPainter(WidgetTester tester) {
  final finder = find.descendant(of: find.byKey(_captureKey), matching: find.byType(CustomPaint));
  expect(finder, findsOneWidget, reason: 'The visualizer must finish loading and install its painter.');
  return tester.widget<CustomPaint>(finder).painter!;
}

Future<Uint8List> capturePixels(WidgetTester tester) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(_captureKey));
  return (await tester.runAsync(() async {
    final image = await boundary.toImage();
    try {
      final data = await image.toByteData();
      return data!.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }))!;
}

int totalColor(Uint8List pixels) {
  var total = 0;
  for (var i = 0; i < pixels.length; i += 4) {
    total += pixels[i] + pixels[i + 1] + pixels[i + 2];
  }
  return total;
}

typedef PaintedCircle = ({Offset center, double radius, Color color, BlendMode blendMode});

List<PaintedCircle> paintCircles(CustomPainter painter, {Size size = sceneSize}) {
  final canvas = TestRecordingCanvas();
  painter.paint(canvas, size);
  return [
    for (final call in canvas.invocations)
      if (call.invocation.memberName == #drawCircle)
        (
          center: call.invocation.positionalArguments[0] as Offset,
          radius: call.invocation.positionalArguments[1] as double,
          color: (call.invocation.positionalArguments[2] as Paint).color,
          blendMode: (call.invocation.positionalArguments[2] as Paint).blendMode,
        ),
  ];
}
