import 'package:flutter/material.dart';

import '../features/ktv_demo/presentation/ktv_demo_shell.dart';

class KtvDemoApp extends StatelessWidget {
  const KtvDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFFFFD85E),
        secondary: Color(0xFFFF4D8D),
        surface: Color(0xFF16012D),
      ),
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '金调KTV Demo',
      theme: base.copyWith(
        scaffoldBackgroundColor: const Color(0xFF070012),
        textTheme: base.textTheme.apply(
          bodyColor: const Color(0xFFFFF7FF),
          displayColor: const Color(0xFFFFF7FF),
        ),
      ),
      home: const KtvDemoShell(),
    );
  }
}
