import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/orientation_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await OrientationController.lockLandscape();
  runApp(
    const ProviderScope(
      child: CursorPadApp(),
    ),
  );
}
