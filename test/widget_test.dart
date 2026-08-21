import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maimai_ktv/core/localization/locale_controller.dart';
import 'package:maimai_ktv/core/localization/locale_preference_store.dart';
import 'package:maimai_ktv/features/ktv/application/ktv_controller.dart';
import 'package:maimai_ktv/features/ktv/presentation/home_page.dart';
import 'package:maimai_ktv/features/ktv/presentation/ktv_shell.dart';
import 'package:maimai_ktv/features/ktv/presentation/songbook_page.dart';
import 'package:maimai_ktv/features/update/application/app_version_source.dart';
import 'package:maimai_ktv/features/update/application/update_controller.dart';
import 'package:maimai_ktv/features/update/application/update_platform_adapter.dart';
import 'package:maimai_ktv/features/update/application/update_service.dart';
import 'package:maimai_ktv/features/update/data/update_manifest_client.dart';
import 'package:maimai_ktv/features/update/domain/app_update_info.dart';
import 'package:maimai_ktv/features/update/domain/app_version.dart';
import 'package:maimai_ktv/l10n/generated/app_localizations.dart';

import 'test_support/ktv_test_doubles.dart';

void main() {
  KtvController buildController() {
    return KtvController(
      mediaLibraryRepository: createTestMediaLibraryRepository(
        hasConfiguredAggregatedSources: true,
      ),
      aggregatedLibraryRepository: FakeAggregatedLibraryRepository(),
      playerController: FakePlayerController(),
      downloadTaskStore: MemoryDownloadTaskStore(),
      playbackSessionStore: MemoryPlaybackSessionStore(),
    );
  }

  UpdateController buildUpdateController() {
    return UpdateController(
      updateService: UpdateService(
        versionSource: _FakeVersionSource(
          AppVersion(displayVersion: '1.0.0-alpha.7', buildNumber: 7),
        ),
        manifestClient: UpdateManifestClient(manifestUri: null),
        platform: AppUpdatePlatform.android,
      ),
      platformAdapter: _FakeUpdatePlatformAdapter(),
    );
  }

  Widget buildTestApp({
    required KtvController controller,
    required UpdateController updateController,
    LocaleController? localeController,
  }) {
    final LocaleController resolvedLocaleController =
        localeController ??
        LocaleController(preferenceStore: _MemoryLocalePreferenceStore());
    if (localeController == null) {
      unawaited(
        resolvedLocaleController.setLocale(LocaleController.simplifiedChinese),
      );
    }
    addTearDown(resolvedLocaleController.dispose);
    return AnimatedBuilder(
      animation: resolvedLocaleController,
      builder: (BuildContext context, _) => MaterialApp(
        locale: resolvedLocaleController.locale,
        supportedLocales: LocaleController.supportedLocales,
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        home: KtvShell(
          controller: controller,
          updateController: updateController,
          localeController: resolvedLocaleController,
        ),
      ),
    );
  }

  testWidgets('renders the home shell with the main shortcuts', (
    WidgetTester tester,
  ) async {
    final KtvController controller = buildController();
    final UpdateController updateController = buildUpdateController();
    addTearDown(controller.dispose);
    addTearDown(updateController.dispose);

    await tester.pumpWidget(
      buildTestApp(controller: controller, updateController: updateController),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('麦麦KTV'), findsOneWidget);
    expect(find.text('歌名'), findsOneWidget);
    expect(find.text('歌星'), findsOneWidget);
    expect(find.text('设置'), findsWidgets);
  });

  testWidgets('opens the aggregated song book view from the home shell', (
    WidgetTester tester,
  ) async {
    final KtvController controller = buildController();
    final UpdateController updateController = buildUpdateController();
    addTearDown(controller.dispose);
    addTearDown(updateController.dispose);

    await tester.pumpWidget(
      buildTestApp(controller: controller, updateController: updateController),
    );
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('歌名'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('主页 / 歌名'), findsOneWidget);
    expect(find.byType(Scrollable), findsWidgets);
  });

  testWidgets('updates visible labels when the app language changes', (
    WidgetTester tester,
  ) async {
    final KtvController controller = buildController();
    final UpdateController updateController = buildUpdateController();
    final LocaleController localeController = LocaleController(
      preferenceStore: _MemoryLocalePreferenceStore(),
    );
    addTearDown(controller.dispose);
    addTearDown(updateController.dispose);

    await localeController.setLocale(LocaleController.simplifiedChinese);
    await tester.pumpWidget(
      buildTestApp(
        controller: controller,
        updateController: updateController,
        localeController: localeController,
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('歌名'), findsOneWidget);

    await localeController.setLocale(LocaleController.english);
    await tester.pump();

    expect(find.text('Karaoke Cinema'), findsOneWidget);
    expect(find.text('Songs'), findsOneWidget);
    expect(find.text('Artists'), findsOneWidget);
  });

  testWidgets(
    'uses the full portrait width for home shortcuts on larger screens',
    (WidgetTester tester) async {
      final KtvController controller = buildController();
      final UpdateController updateController = buildUpdateController();
      addTearDown(controller.dispose);
      addTearDown(updateController.dispose);

      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildTestApp(
          controller: controller,
          updateController: updateController,
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      final Finder songCard = find.ancestor(
        of: find.text('歌名'),
        matching: find.byType(Ink),
      );

      expect(songCard, findsOneWidget);
      expect(tester.getSize(songCard).width, greaterThan(200));
    },
  );

  testWidgets(
    'keeps the landscape song book panels balanced on larger screens',
    (WidgetTester tester) async {
      final KtvController controller = buildController();
      final UpdateController updateController = buildUpdateController();
      addTearDown(controller.dispose);
      addTearDown(updateController.dispose);

      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildTestApp(
          controller: controller,
          updateController: updateController,
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('歌名'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('主页 / 歌名'), findsOneWidget);

      final Size leftPanelSize = tester.getSize(
        find.byType(SongBookLeftColumn),
      );
      final Size rightPanelSize = tester.getSize(
        find.byType(SongBookRightColumn),
      );

      expect(leftPanelSize.width, greaterThan(320));
      expect(rightPanelSize.width, lessThanOrEqualTo(760));
    },
  );

  testWidgets(
    'centers the landscape song book preview and search controls vertically',
    (WidgetTester tester) async {
      final KtvController controller = buildController();
      final UpdateController updateController = buildUpdateController();
      addTearDown(controller.dispose);
      addTearDown(updateController.dispose);

      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildTestApp(
          controller: controller,
          updateController: updateController,
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('歌名'));
      await tester.pump(const Duration(milliseconds: 300));

      final Rect previewRect = tester.getRect(find.byType(HomePreviewCard));
      final Rect leftColumnRect = tester.getRect(
        find.byType(SongBookLeftColumn),
      );
      final Rect rightPanelRect = tester.getRect(
        find.byType(SongBookRightColumn),
      );
      final double leftGroupCenterY =
          (previewRect.top + leftColumnRect.bottom) / 2;

      expect(
        leftGroupCenterY,
        moreOrLessEquals(rightPanelRect.center.dy, epsilon: 8),
      );
    },
  );
}

class _FakeVersionSource implements AppVersionSource {
  const _FakeVersionSource(this.version);

  final AppVersion version;

  @override
  Future<AppVersion> readCurrentVersion() async => version;
}

class _FakeUpdatePlatformAdapter implements UpdatePlatformAdapter {
  @override
  Future<bool> openReleasePage() async => true;

  @override
  Future<bool> openUpdate(AppUpdateInfo updateInfo) async => true;
}

class _MemoryLocalePreferenceStore implements LocalePreferenceStore {
  String? languageTag;

  @override
  Future<String?> readLanguageTag() async => languageTag;

  @override
  Future<void> writeLanguageTag(String? languageTag) async {
    this.languageTag = languageTag;
  }
}
