import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ktv2/ktv2.dart';
import 'package:maimai_ktv/features/ktv/presentation/songbook_right_column_widgets.dart';
import 'package:maimai_ktv/l10n/generated/app_localizations.dart';

import '../../../test_support/ktv_test_doubles.dart';

void main() {
  testWidgets('song book hides pitch shift controls', (
    WidgetTester tester,
  ) async {
    final FakePlayerController controller = FakePlayerController();
    controller.setState(
      const PlayerState(
        currentMediaPath: '/tmp/demo.mp4',
        playbackDuration: Duration(minutes: 4),
      ),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SongBookActionRow(
            controller: controller,
            queueCount: 0,
            compact: true,
            onQueuePressed: null,
            onSettingsPressed: () {},
            onToggleAudioMode: () {},
            onTogglePlayback: () {},
            onRestartPlayback: () {},
            onSkipSong: () {},
          ),
        ),
      ),
    );

    expect(find.text('降调'), findsNothing);
    expect(find.text('原调'), findsNothing);
    expect(find.text('升调'), findsNothing);
  });
}
