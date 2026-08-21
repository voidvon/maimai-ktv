import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/localization/locale_controller.dart';
import '../features/ktv/application/ktv_controller.dart';
import '../features/update/application/update_controller.dart';
import '../features/ktv/presentation/ktv_shell.dart';
import '../l10n/generated/app_localizations.dart';
import 'ktv_dependencies.dart';

class KtvApp extends StatefulWidget {
  const KtvApp({super.key, required this.localeController});

  final LocaleController localeController;

  @override
  State<KtvApp> createState() => _KtvAppState();
}

class _KtvAppState extends State<KtvApp> {
  late final KtvController _controller = createKtvController();
  late final UpdateController _updateController = createUpdateController();

  @override
  void initState() {
    super.initState();
    unawaited(_updateController.initialize());
  }

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

    return AnimatedBuilder(
      animation: widget.localeController,
      builder: (BuildContext context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          onGenerateTitle: (BuildContext context) =>
              AppLocalizations.of(context).appName,
          locale: widget.localeController.locale,
          supportedLocales: LocaleController.supportedLocales,
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          theme: base.copyWith(
            scaffoldBackgroundColor: const Color(0xFF070012),
            textTheme: base.textTheme.apply(
              bodyColor: const Color(0xFFFFF7FF),
              displayColor: const Color(0xFFFFF7FF),
            ),
          ),
          home: KtvShell(
            controller: _controller,
            updateController: _updateController,
            localeController: widget.localeController,
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _updateController.dispose();
    _controller.dispose();
    super.dispose();
  }
}
