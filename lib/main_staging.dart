import 'package:wellness_visualizer_demo/app/app.dart';
import 'package:wellness_visualizer_demo/bootstrap.dart';

Future<void> main() async {
  await bootstrap(() => const App());
}
