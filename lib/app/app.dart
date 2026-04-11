import 'package:flutter/material.dart';

import '../features/ktv/application/ktv_controller.dart';
import '../features/ktv/presentation/ktv_shell.dart';
import 'ktv_dependencies.dart';

class KtvApp extends StatefulWidget {
  const KtvApp({super.key});

  @override
  State<KtvApp> createState() => _KtvAppState();
}

class _KtvAppState extends State<KtvApp> {
  late final KtvController _controller = createKtvController();

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
      title: '麦麦KTV',
      theme: base.copyWith(
        scaffoldBackgroundColor: const Color(0xFF070012),
        textTheme: base.textTheme.apply(
          bodyColor: const Color(0xFFFFF7FF),
          displayColor: const Color(0xFFFFF7FF),
        ),
      ),
      home: KtvShell(controller: _controller),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
