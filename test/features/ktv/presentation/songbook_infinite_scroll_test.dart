import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maimai_ktv/core/models/song.dart';
import 'package:maimai_ktv/features/ktv/application/ktv_controller.dart';
import 'package:maimai_ktv/features/ktv/presentation/songbook_contracts.dart';
import 'package:maimai_ktv/features/ktv/presentation/songbook_right_column.dart';
import 'package:maimai_ktv/features/ktv/presentation/songbook_right_column_widgets.dart';
import 'package:maimai_ktv/l10n/generated/app_localizations.dart';

import '../../../test_support/ktv_test_doubles.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'queue uses one continuous scroll view beyond the former 20-page cap',
    (WidgetTester tester) async {
      _setTestViewport(tester);
      final List<Song> queuedSongs = _buildSongs(1000, prefix: '队列歌曲');
      final FakePlayerController controller = FakePlayerController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _buildHarness(
          controller: controller,
          viewModel: _buildViewModel(
            route: KtvRoute.queueList,
            songs: const <Song>[],
            queuedSongs: queuedSongs,
          ),
        ),
      );

      expect(
        find.byWidgetPredicate(
          (Widget widget) => widget.runtimeType.toString() == 'PaginationBar',
        ),
        findsNothing,
      );
      expect(find.text('上一页'), findsNothing);
      expect(find.text('下一页'), findsNothing);
      expect(find.byType(CustomScrollView), findsOneWidget);

      final Finder scrollable = find.descendant(
        of: find.byType(CustomScrollView),
        matching: find.byType(Scrollable),
      );
      final ScrollableState originalScrollableState = tester
          .state<ScrollableState>(scrollable);
      final String lastTitle = queuedSongs.last.title;

      await tester.scrollUntilVisible(
        find.text(lastTitle),
        1000,
        scrollable: scrollable,
        maxScrolls: 30,
        duration: const Duration(milliseconds: 1),
      );
      await tester.pump();

      expect(find.text(lastTitle), findsOneWidget);
      expect(find.byType(CustomScrollView), findsOneWidget);
      expect(
        tester.state<ScrollableState>(scrollable),
        same(originalScrollableState),
      );
      expect(originalScrollableState.position.pixels, greaterThan(0));
    },
  );

  testWidgets('library lazily builds tiles and gates near-bottom load more', (
    WidgetTester tester,
  ) async {
    _setTestViewport(tester);
    final List<Song> songs = _buildSongs(200, prefix: '曲库歌曲');
    final FakePlayerController controller = FakePlayerController();
    addTearDown(controller.dispose);
    int loadMoreCalls = 0;

    await tester.pumpWidget(
      _buildHarness(
        controller: controller,
        viewModel: _buildViewModel(
          route: KtvRoute.songBook,
          songs: songs,
          queuedSongs: const <Song>[],
          hasMore: true,
        ),
        onLoadMore: () => loadMoreCalls += 1,
      ),
    );
    await tester.pump();

    final int initiallyBuiltTiles = find.byType(SongTile).evaluate().length;
    expect(initiallyBuiltTiles, greaterThan(0));
    expect(initiallyBuiltTiles, lessThan(100));
    expect(loadMoreCalls, 0);

    final Finder scrollable = find.descendant(
      of: find.byType(CustomScrollView),
      matching: find.byType(Scrollable),
    );
    final ScrollPosition position = tester
        .state<ScrollableState>(scrollable)
        .position;
    position.jumpTo(position.maxScrollExtent - 300);
    await tester.pump();

    expect(loadMoreCalls, 1);

    position.jumpTo(position.maxScrollExtent);
    await tester.pump();
    position.jumpTo(position.maxScrollExtent - 100);
    await tester.pump();

    expect(loadMoreCalls, 1);
    expect(find.byType(SongTile).evaluate().length, lessThan(100));
  });

  testWidgets(
    'empty unresolved profile batch automatically loads the next batch',
    (WidgetTester tester) async {
      _setTestViewport(tester);
      final FakePlayerController controller = FakePlayerController();
      addTearDown(controller.dispose);
      int loadMoreCalls = 0;

      await tester.pumpWidget(
        _buildHarness(
          controller: controller,
          viewModel: _buildViewModel(
            route: KtvRoute.songBook,
            mode: SongBookMode.favorites,
            songs: const <Song>[],
            queuedSongs: const <Song>[],
            totalCount: 33,
            hasMore: true,
          ),
          onLoadMore: () => loadMoreCalls += 1,
        ),
      );
      await tester.pump();

      expect(find.byType(CustomScrollView), findsOneWidget);
      expect(loadMoreCalls, 1);

      await tester.pump();
      expect(loadMoreCalls, 1);
    },
  );

  testWidgets('empty load-more failure exposes a retry action', (
    WidgetTester tester,
  ) async {
    _setTestViewport(tester);
    final FakePlayerController controller = FakePlayerController();
    addTearDown(controller.dispose);
    int loadMoreCalls = 0;

    await tester.pumpWidget(
      _buildHarness(
        controller: controller,
        viewModel: _buildViewModel(
          route: KtvRoute.songBook,
          mode: SongBookMode.frequent,
          songs: const <Song>[],
          queuedSongs: const <Song>[],
          totalCount: 33,
          hasMore: true,
          loadMoreErrorMessage: '加载失败',
        ),
        onLoadMore: () => loadMoreCalls += 1,
      ),
    );
    await tester.pump();

    expect(loadMoreCalls, 0);
    expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.refresh_rounded));
    await tester.pump();

    expect(loadMoreCalls, 1);
  });

  testWidgets('refreshing a loaded favorite prefix keeps the scroll position', (
    WidgetTester tester,
  ) async {
    _setTestViewport(tester);
    final FakePlayerController controller = FakePlayerController();
    addTearDown(controller.dispose);
    final List<Song> songs = _buildSongs(100, prefix: '收藏歌曲');

    await tester.pumpWidget(
      _buildHarness(
        controller: controller,
        viewModel: _buildViewModel(
          route: KtvRoute.songBook,
          mode: SongBookMode.favorites,
          songs: songs,
          queuedSongs: const <Song>[],
          pageIndex: 2,
        ),
      ),
    );
    await tester.pump();

    final Finder scrollable = find.descendant(
      of: find.byType(CustomScrollView),
      matching: find.byType(Scrollable),
    );
    final ScrollPosition position = tester
        .state<ScrollableState>(scrollable)
        .position;
    position.jumpTo(600);
    await tester.pump();
    expect(position.pixels, greaterThan(0));

    await tester.pumpWidget(
      _buildHarness(
        controller: controller,
        viewModel: _buildViewModel(
          route: KtvRoute.songBook,
          mode: SongBookMode.favorites,
          songs: <Song>[...songs.skip(1), songs.first],
          queuedSongs: const <Song>[],
          pageIndex: 2,
        ),
      ),
    );
    await tester.pump();

    expect(
      tester.state<ScrollableState>(scrollable).position.pixels,
      greaterThan(0),
    );
  });
}

void _setTestViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 600);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

List<Song> _buildSongs(int count, {required String prefix}) {
  return List<Song>.generate(
    count,
    (int index) => buildLocalSong(
      title: '$prefix ${index.toString().padLeft(4, '0')}',
      artist: '测试歌手',
      mediaPath: '/library/$prefix-$index.mp4',
    ),
  );
}

SongBookViewModel _buildViewModel({
  required KtvRoute route,
  required List<Song> songs,
  required List<Song> queuedSongs,
  SongBookMode mode = SongBookMode.songs,
  int? totalCount,
  int pageIndex = 0,
  bool hasMore = false,
  String? loadMoreErrorMessage,
}) {
  return SongBookViewModel(
    navigation: SongBookNavigationViewModel(
      route: route,
      songBookMode: mode,
      libraryScope: LibraryScope.aggregated,
      selectedArtist: null,
      breadcrumbLabel: route == KtvRoute.queueList ? '主页 / 已点' : '主页 / 歌名',
    ),
    library: SongBookLibraryViewModel(
      searchQuery: '',
      selectedLanguage: '全部',
      songs: songs,
      artists: const [],
      favoriteSongIds: const <String>{},
      downloadableSourceIds: const <String>{},
      downloadingSongIds: const <String>{},
      downloadedSongKeys: const <String>{},
      totalCount: totalCount ?? songs.length,
      pageIndex: pageIndex,
      hasMore: hasMore,
      hasConfiguredDirectory: true,
      hasConfiguredAggregatedSources: true,
      isScanning: false,
      isLoadingPage: false,
      scanErrorMessage: null,
      loadMoreErrorMessage: loadMoreErrorMessage,
    ),
    playback: SongBookPlaybackViewModel(queuedSongs: queuedSongs),
  );
}

Widget _buildHarness({
  required FakePlayerController controller,
  required SongBookViewModel viewModel,
  VoidCallback? onLoadMore,
}) {
  return MaterialApp(
    locale: const Locale('zh'),
    localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: SongBookRightColumn(
        controller: controller,
        viewModel: viewModel,
        callbacks: SongBookCallbacks(
          navigation: SongBookNavigationCallbacks(
            onBackPressed: _noop,
            onQueuePressed: _noop,
            onSelectArtist: _noopString,
            onSettingsPressed: _noop,
          ),
          library: SongBookLibraryCallbacks(
            onLanguageSelected: _noopString,
            onAppendSearchToken: _noopString,
            onRemoveSearchCharacter: _noop,
            onClearSearch: _noop,
            onLoadMore: onLoadMore ?? _noop,
            onRequestSong: _noopSong,
            onToggleFavorite: _noopSong,
            onDownloadSong: _noopSong,
          ),
          playback: SongBookPlaybackCallbacks(
            onPrioritizeQueuedSong: _noopSong,
            onRemoveQueuedSong: _noopSong,
            onToggleAudioMode: _noop,
            onTogglePlayback: _noop,
            onRestartPlayback: _noop,
            onSkipSong: _noop,
          ),
        ),
      ),
    ),
  );
}

void _noop() {}

void _noopString(String _) {}

void _noopSong(Song _) {}
