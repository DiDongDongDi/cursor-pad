import 'package:flutter/material.dart';

import '../features/browser/browser_screen.dart';

class CursorPadApp extends StatelessWidget {
  const CursorPadApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cursor Pad',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const BrowserScreen(),
    );
  }
}
