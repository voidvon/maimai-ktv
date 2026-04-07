import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ktv2/ktv2.dart';
import 'package:ktv2_example/core/models/artist.dart';
import 'package:ktv2_example/core/models/song.dart';
import 'package:ktv2_example/core/models/song_identity.dart';
import 'package:ktv2_example/features/ktv/application/ktv_controller.dart';
import 'package:ktv2_example/features/ktv/presentation/songbook_contracts.dart';
import 'package:ktv2_example/features/ktv/presentation/songbook_page.dart';
import 'package:ktv2_example/features/ktv/presentation/songbook_right_column_widgets.dart';
import 'package:ktv2_example/features/ktv/presentation/shared_widgets.dart';
import 'package:ktv2_example/main.dart';

void main() {
  SongBookCallbacks buildSongBookCallbacks() {
    return SongBookCallbacks(
      navigation: SongBookNavigationCallbacks(
        onBackPressed: () {},
        onQueuePressed: () {},
        onSelectArtist: (_) {},
        onSettingsPressed: () {},
      ),
      library: SongBookLibraryCallbacks(
        onLanguageSelected: (_) {},
        onAppendSearchToken: (_) {},
        onRemoveSearchCharacter: () {},
        onClearSearch: () {},
        onRequestLibraryPage: (_, _) {},
        onRequestSong: (_) {},
        onToggleFavorite: (_) {},
        onDownloadSong: (_) {},
      ),
      playback: SongBookPlaybackCallbacks(
        onPrioritizeQueuedSong: (_) {},
        onRemoveQueuedSong: (_) {},
        onToggleAudioMode: () {},
        onTogglePlayback: () {},
        onRestartPlayback: () {},
        onSkipSong: () {},
      ),
    );
  }

  testWidgets('shows home shell before media library is selected', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const KtvApp());

    expect(find.text('我爱KTV'), findsOneWidget);
    expect(find.text('歌名'), findsOneWidget);
    expect(find.text('设置'), findsAtLeastNWidgets(1));
    expect(find.text('首页预览区'), findsNothing);
    expect(find.byType(Slider), findsOneWidget);
  });

  testWidgets('opens scan directory settings dialog from top actions', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const KtvApp());

    await tester.tap(find.text('设置').first);
    await tester.pumpAndSettle();

    expect(find.text('设置'), findsOneWidget);
    expect(find.text('本地目录'), findsOneWidget);
    expect(find.text('百度网盘'), findsOneWidget);
  });

  testWidgets('opens queued songs page from home toolbar', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const KtvApp());

    await tester.tap(find.text('已点0').first);
    await tester.pumpAndSettle();

    expect(find.text('主页 / 已点'), findsOneWidget);
    expect(find.text('当前还没有已点歌曲，点歌后会在这里显示。'), findsOneWidget);
    expect(find.text('搜索已点歌曲 / 歌手'), findsOneWidget);
  });

  testWidgets('renders compact song book without layout exceptions', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 932);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const KtvApp());

    await tester.tap(find.text('歌名'));
    await tester.pumpAndSettle();

    expect(find.text('请先在设置里配置数据源，配置完成后这里会展示聚合曲库。'), findsOneWidget);
  });

  testWidgets('renders landscape song book without layout exceptions', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(932, 430);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const KtvApp());

    await tester.tap(find.text('歌名'));
    await tester.pumpAndSettle();

    expect(find.text('主页 / 歌名'), findsOneWidget);
    expect(find.text('请先在设置里配置数据源，配置完成后这里会展示聚合曲库。'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders landscape artist grid without layout exceptions', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(932, 430);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final TextEditingController searchController = TextEditingController();
    addTearDown(searchController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SongBookPage(
            controller: _TestPlayerController(),
            searchController: searchController,
            viewModel: const SongBookViewModel(
              navigation: SongBookNavigationViewModel(
                route: KtvRoute.songBook,
                songBookMode: SongBookMode.artists,
                libraryScope: LibraryScope.aggregated,
                selectedArtist: null,
                breadcrumbLabel: '主页 / 歌星',
              ),
              library: SongBookLibraryViewModel(
                searchQuery: '',
                selectedLanguage: '全部',
                songs: <Song>[],
                artists: <Artist>[
                  Artist(name: '周杰伦', songCount: 12, searchIndex: 'zhoujielun'),
                  Artist(name: '刘若英', songCount: 8, searchIndex: 'liuruoying'),
                  Artist(
                    name: '张学友',
                    songCount: 15,
                    searchIndex: 'zhangxueyou',
                  ),
                  Artist(name: 'A-Lin', songCount: 6, searchIndex: 'a-lin'),
                  Artist(name: '邓紫棋', songCount: 10, searchIndex: 'dengziqi'),
                  Artist(name: 'Beyond', songCount: 9, searchIndex: 'beyond'),
                ],
                favoriteSongIds: <String>[],
                downloadingSongIds: <String>{},
                downloadedSourceSongIds: <String>{},
                totalCount: 6,
                pageIndex: 0,
                totalPages: 1,
                pageSize: 6,
                hasConfiguredDirectory: true,
                hasConfiguredAggregatedSources: true,
                isScanning: false,
                isLoadingPage: false,
                scanErrorMessage: null,
              ),
              playback: SongBookPlaybackViewModel(queuedSongs: <Song>[]),
            ),
            callbacks: SongBookCallbacks(
              navigation: SongBookNavigationCallbacks(
                onBackPressed: () {},
                onQueuePressed: () {},
                onSelectArtist: (_) {},
                onSettingsPressed: () {},
              ),
              library: SongBookLibraryCallbacks(
                onLanguageSelected: (_) {},
                onAppendSearchToken: (_) {},
                onRemoveSearchCharacter: () {},
                onClearSearch: () {},
                onRequestLibraryPage: (_, _) {},
                onRequestSong: (_) {},
                onToggleFavorite: (_) {},
                onDownloadSong: (_) {},
              ),
              playback: SongBookPlaybackCallbacks(
                onPrioritizeQueuedSong: (_) {},
                onRemoveQueuedSong: (_) {},
                onToggleAudioMode: () {},
                onTogglePlayback: () {},
                onRestartPlayback: () {},
                onSkipSong: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('主页 / 歌星'), findsOneWidget);
    expect(find.text('周杰伦'), findsAtLeastNWidgets(1));
    expect(find.text('刘若英'), findsAtLeastNWidgets(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('landscape song book uses visible capacity to show page count', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 700,
            height: 520,
            child: SongBookRightColumn(
              controller: _TestPlayerController(),
              viewModel: SongBookViewModel(
                navigation: const SongBookNavigationViewModel(
                  route: KtvRoute.songBook,
                  songBookMode: SongBookMode.songs,
                  libraryScope: LibraryScope.aggregated,
                  selectedArtist: null,
                  breadcrumbLabel: '主页 / 歌名',
                ),
                library: SongBookLibraryViewModel(
                  searchQuery: '',
                  selectedLanguage: '全部',
                  songs: <Song>[
                    Song(
                      songId: buildAggregateSongId(title: '青花瓷', artist: '周杰伦'),
                      sourceId: 'local',
                      sourceSongId: buildLocalSourceSongId(
                        fingerprint: buildLocalMetadataFingerprint(
                          locator: '/tmp/1.mp4',
                        ),
                      ),
                      title: '青花瓷',
                      artist: '周杰伦',
                      languages: <String>['国语'],
                      searchIndex: 'qinghuaci zhoujielun',
                      mediaPath: '/tmp/1.mp4',
                    ),
                    Song(
                      songId: buildAggregateSongId(title: '夜曲', artist: '周杰伦'),
                      sourceId: 'local',
                      sourceSongId: buildLocalSourceSongId(
                        fingerprint: buildLocalMetadataFingerprint(
                          locator: '/tmp/2.mp4',
                        ),
                      ),
                      title: '夜曲',
                      artist: '周杰伦',
                      languages: <String>['国语'],
                      searchIndex: 'yequ zhoujielun',
                      mediaPath: '/tmp/2.mp4',
                    ),
                    Song(
                      songId: buildAggregateSongId(title: '后来', artist: '刘若英'),
                      sourceId: 'local',
                      sourceSongId: buildLocalSourceSongId(
                        fingerprint: buildLocalMetadataFingerprint(
                          locator: '/tmp/3.mp4',
                        ),
                      ),
                      title: '后来',
                      artist: '刘若英',
                      languages: <String>['国语'],
                      searchIndex: 'houlai liuruoying',
                      mediaPath: '/tmp/3.mp4',
                    ),
                    Song(
                      songId: buildAggregateSongId(
                        title: '海阔天空',
                        artist: 'Beyond',
                      ),
                      sourceId: 'local',
                      sourceSongId: buildLocalSourceSongId(
                        fingerprint: buildLocalMetadataFingerprint(
                          locator: '/tmp/4.mp4',
                        ),
                      ),
                      title: '海阔天空',
                      artist: 'Beyond',
                      languages: <String>['粤语'],
                      searchIndex: 'haikuotiankong beyond',
                      mediaPath: '/tmp/4.mp4',
                    ),
                  ],
                  artists: <Artist>[],
                  favoriteSongIds: <String>[],
                  downloadingSongIds: <String>{},
                  downloadedSourceSongIds: <String>{},
                  totalCount: 4,
                  pageIndex: 0,
                  totalPages: 2,
                  pageSize: 2,
                  hasConfiguredDirectory: true,
                  hasConfiguredAggregatedSources: true,
                  isScanning: false,
                  isLoadingPage: false,
                  scanErrorMessage: null,
                ),
                playback: SongBookPlaybackViewModel(queuedSongs: <Song>[]),
              ),
              callbacks: SongBookCallbacks(
                navigation: SongBookNavigationCallbacks(
                  onBackPressed: () {},
                  onQueuePressed: () {},
                  onSelectArtist: (_) {},
                  onSettingsPressed: () {},
                ),
                library: SongBookLibraryCallbacks(
                  onLanguageSelected: (_) {},
                  onAppendSearchToken: (_) {},
                  onRemoveSearchCharacter: () {},
                  onClearSearch: () {},
                  onRequestLibraryPage: (_, _) {},
                  onRequestSong: (_) {},
                  onToggleFavorite: (_) {},
                  onDownloadSong: (_) {},
                ),
                playback: SongBookPlaybackCallbacks(
                  onPrioritizeQueuedSong: (_) {},
                  onRemoveQueuedSong: (_) {},
                  onToggleAudioMode: () {},
                  onTogglePlayback: () {},
                  onRestartPlayback: () {},
                  onSkipSong: () {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1/1'), findsOneWidget);
  });

  testWidgets(
    'landscape song book increases visible capacity on larger window',
    (WidgetTester tester) async {
      String resolvePaginationLabel() {
        final Iterable<Text> textWidgets = tester
            .widgetList<Text>(find.byType(Text))
            .where((Text text) => text.data != null);
        final Text pagination = textWidgets.firstWhere(
          (Text text) => RegExp(r'^\d+/\d+$').hasMatch(text.data!),
        );
        return pagination.data!;
      }

      ({int currentPage, int totalPages}) parsePaginationLabel(String label) {
        final List<String> parts = label.split('/');
        return (
          currentPage: int.parse(parts[0]),
          totalPages: int.parse(parts[1]),
        );
      }

      Future<void> pumpSongBook(double width, double height) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: width,
                height: height,
                child: SongBookRightColumn(
                  controller: _TestPlayerController(),
                  viewModel: SongBookViewModel(
                    navigation: const SongBookNavigationViewModel(
                      route: KtvRoute.songBook,
                      songBookMode: SongBookMode.songs,
                      libraryScope: LibraryScope.aggregated,
                      selectedArtist: null,
                      breadcrumbLabel: '主页 / 歌名',
                    ),
                    library: SongBookLibraryViewModel(
                      searchQuery: '',
                      selectedLanguage: '全部',
                      songs: List<Song>.generate(
                        9,
                        (int index) => Song(
                          songId: buildAggregateSongId(
                            title: '歌曲$index',
                            artist: '歌手$index',
                          ),
                          sourceId: 'local',
                          sourceSongId: buildLocalSourceSongId(
                            fingerprint: buildLocalMetadataFingerprint(
                              locator: '/tmp/$index.mp4',
                            ),
                          ),
                          title: '歌曲$index',
                          artist: '歌手$index',
                          languages: const <String>['国语'],
                          searchIndex: 'gequ$index geshou$index',
                          mediaPath: '/tmp/$index.mp4',
                        ),
                      ),
                      artists: <Artist>[],
                      favoriteSongIds: <String>[],
                      downloadingSongIds: <String>{},
                      downloadedSourceSongIds: <String>{},
                      totalCount: 9,
                      pageIndex: 0,
                      totalPages: 5,
                      pageSize: 2,
                      hasConfiguredDirectory: true,
                      hasConfiguredAggregatedSources: true,
                      isScanning: false,
                      isLoadingPage: false,
                      scanErrorMessage: null,
                    ),
                    playback: const SongBookPlaybackViewModel(
                      queuedSongs: <Song>[],
                    ),
                  ),
                  callbacks: SongBookCallbacks(
                    navigation: SongBookNavigationCallbacks(
                      onBackPressed: () {},
                      onQueuePressed: () {},
                      onSelectArtist: (_) {},
                      onSettingsPressed: () {},
                    ),
                    library: SongBookLibraryCallbacks(
                      onLanguageSelected: (_) {},
                      onAppendSearchToken: (_) {},
                      onRemoveSearchCharacter: () {},
                      onClearSearch: () {},
                      onRequestLibraryPage: (_, _) {},
                      onRequestSong: (_) {},
                      onToggleFavorite: (_) {},
                      onDownloadSong: (_) {},
                    ),
                    playback: SongBookPlaybackCallbacks(
                      onPrioritizeQueuedSong: (_) {},
                      onRemoveQueuedSong: (_) {},
                      onToggleAudioMode: () {},
                      onTogglePlayback: () {},
                      onRestartPlayback: () {},
                      onSkipSong: () {},
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await pumpSongBook(700, 250);
      final smallWindowPagination = parsePaginationLabel(
        resolvePaginationLabel(),
      );

      await pumpSongBook(980, 620);
      final largeWindowPagination = parsePaginationLabel(
        resolvePaginationLabel(),
      );

      expect(smallWindowPagination.currentPage, 1);
      expect(largeWindowPagination.currentPage, 1);
      expect(
        largeWindowPagination.totalPages,
        lessThan(smallWindowPagination.totalPages),
      );
    },
  );

  testWidgets('compact song grid keeps at least two columns', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            height: 640,
            child: SongBookRightColumn(
              controller: _TestPlayerController(),
              viewModel: SongBookViewModel(
                navigation: const SongBookNavigationViewModel(
                  route: KtvRoute.songBook,
                  songBookMode: SongBookMode.songs,
                  libraryScope: LibraryScope.aggregated,
                  selectedArtist: null,
                  breadcrumbLabel: '主页 / 歌名',
                ),
                library: SongBookLibraryViewModel(
                  searchQuery: '',
                  selectedLanguage: '全部',
                  songs: List<Song>.generate(
                    6,
                    (int index) => Song(
                      songId: buildAggregateSongId(
                        title: '歌曲$index',
                        artist: '歌手$index',
                      ),
                      sourceId: 'local',
                      sourceSongId: buildLocalSourceSongId(
                        fingerprint: buildLocalMetadataFingerprint(
                          locator: '/tmp/song_$index.mp4',
                        ),
                      ),
                      title: '歌曲$index',
                      artist: '歌手$index',
                      languages: const <String>['国语'],
                      searchIndex: 'gequ$index geshou$index',
                      mediaPath: '/tmp/song_$index.mp4',
                    ),
                  ),
                  artists: const <Artist>[],
                  favoriteSongIds: const <String>[],
                  downloadingSongIds: <String>{},
                  downloadedSourceSongIds: <String>{},
                  totalCount: 6,
                  pageIndex: 0,
                  totalPages: 1,
                  pageSize: 6,
                  hasConfiguredDirectory: true,
                  hasConfiguredAggregatedSources: true,
                  isScanning: false,
                  isLoadingPage: false,
                  scanErrorMessage: null,
                ),
                playback: const SongBookPlaybackViewModel(
                  queuedSongs: <Song>[],
                ),
              ),
              callbacks: buildSongBookCallbacks(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final GridView grid = tester.widget<GridView>(find.byType(GridView).first);
    final SliverGridDelegateWithFixedCrossAxisCount delegate =
        grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.crossAxisCount, 2);
  });

  testWidgets('compact artist grid keeps at least three columns', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            height: 640,
            child: SongBookRightColumn(
              controller: _TestPlayerController(),
              viewModel: const SongBookViewModel(
                navigation: SongBookNavigationViewModel(
                  route: KtvRoute.songBook,
                  songBookMode: SongBookMode.artists,
                  libraryScope: LibraryScope.aggregated,
                  selectedArtist: null,
                  breadcrumbLabel: '主页 / 歌星',
                ),
                library: SongBookLibraryViewModel(
                  searchQuery: '',
                  selectedLanguage: '全部',
                  songs: <Song>[],
                  artists: <Artist>[
                    Artist(
                      name: '周杰伦',
                      songCount: 12,
                      searchIndex: 'zhoujielun',
                    ),
                    Artist(
                      name: '林俊杰',
                      songCount: 10,
                      searchIndex: 'linjunjie',
                    ),
                    Artist(
                      name: '张学友',
                      songCount: 8,
                      searchIndex: 'zhangxueyou',
                    ),
                    Artist(
                      name: '刘若英',
                      songCount: 6,
                      searchIndex: 'liuruoying',
                    ),
                    Artist(name: '陈奕迅', songCount: 9, searchIndex: 'chenyixun'),
                    Artist(name: '孙燕姿', songCount: 7, searchIndex: 'sunyanzi'),
                  ],
                  favoriteSongIds: <String>[],
                  downloadingSongIds: <String>{},
                  downloadedSourceSongIds: <String>{},
                  totalCount: 6,
                  pageIndex: 0,
                  totalPages: 1,
                  pageSize: 6,
                  hasConfiguredDirectory: true,
                  hasConfiguredAggregatedSources: true,
                  isScanning: false,
                  isLoadingPage: false,
                  scanErrorMessage: null,
                ),
                playback: SongBookPlaybackViewModel(queuedSongs: <Song>[]),
              ),
              callbacks: buildSongBookCallbacks(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final GridView grid = tester.widget<GridView>(find.byType(GridView).first);
    final SliverGridDelegateWithFixedCrossAxisCount delegate =
        grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.crossAxisCount, greaterThanOrEqualTo(3));
  });

  testWidgets('wide artist grid increases columns responsively', (
    WidgetTester tester,
  ) async {
    Future<int> pumpArtistGrid(double width) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: width,
              height: 430,
              child: SongBookRightColumn(
                controller: _TestPlayerController(),
                viewModel: const SongBookViewModel(
                  navigation: SongBookNavigationViewModel(
                    route: KtvRoute.songBook,
                    songBookMode: SongBookMode.artists,
                    libraryScope: LibraryScope.aggregated,
                    selectedArtist: null,
                    breadcrumbLabel: '主页 / 歌星',
                  ),
                  library: SongBookLibraryViewModel(
                    searchQuery: '',
                    selectedLanguage: '全部',
                    songs: <Song>[],
                    artists: <Artist>[
                      Artist(
                        name: '周杰伦',
                        songCount: 12,
                        searchIndex: 'zhoujielun',
                      ),
                      Artist(
                        name: '林俊杰',
                        songCount: 10,
                        searchIndex: 'linjunjie',
                      ),
                      Artist(
                        name: '张学友',
                        songCount: 8,
                        searchIndex: 'zhangxueyou',
                      ),
                      Artist(
                        name: '刘若英',
                        songCount: 6,
                        searchIndex: 'liuruoying',
                      ),
                      Artist(
                        name: '陈奕迅',
                        songCount: 9,
                        searchIndex: 'chenyixun',
                      ),
                      Artist(
                        name: '孙燕姿',
                        songCount: 7,
                        searchIndex: 'sunyanzi',
                      ),
                      Artist(name: '王菲', songCount: 5, searchIndex: 'wangfei'),
                      Artist(
                        name: '五月天',
                        songCount: 11,
                        searchIndex: 'wuyuetian',
                      ),
                    ],
                    favoriteSongIds: <String>[],
                    downloadingSongIds: <String>{},
                    downloadedSourceSongIds: <String>{},
                    totalCount: 8,
                    pageIndex: 0,
                    totalPages: 1,
                    pageSize: 8,
                    hasConfiguredDirectory: true,
                    hasConfiguredAggregatedSources: true,
                    isScanning: false,
                    isLoadingPage: false,
                    scanErrorMessage: null,
                  ),
                  playback: SongBookPlaybackViewModel(queuedSongs: <Song>[]),
                ),
                callbacks: buildSongBookCallbacks(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final GridView grid = tester.widget<GridView>(
        find.byType(GridView).first,
      );
      final SliverGridDelegateWithFixedCrossAxisCount delegate =
          grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      return delegate.crossAxisCount;
    }

    final int mediumColumns = await pumpArtistGrid(430);
    final int expandedColumns = await pumpArtistGrid(540);
    final int wideColumns = await pumpArtistGrid(900);

    expect(mediumColumns, 6);
    expect(expandedColumns, greaterThan(mediumColumns));
    expect(expandedColumns, 7);
    expect(wideColumns, greaterThan(mediumColumns));
  });

  testWidgets('artist tile keeps artist name below avatar in compact mode', (
    WidgetTester tester,
  ) async {
    const Artist artist = Artist(
      name: 'Alice Singer',
      songCount: 12,
      searchIndex: 'alice singer',
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 76,
              height: 65,
              child: ArtistTile(artist: artist),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Rect avatarRect = tester.getRect(find.text(artist.avatarLabel));
    final Rect nameRect = tester.getRect(find.text(artist.name));
    expect(nameRect.top, greaterThan(avatarRect.bottom));
  });

  testWidgets('phone-height song grid uses bottom space to fit one more row', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 430,
            height: 430,
            child: SongBookRightColumn(
              controller: _TestPlayerController(),
              viewModel: SongBookViewModel(
                navigation: const SongBookNavigationViewModel(
                  route: KtvRoute.songBook,
                  songBookMode: SongBookMode.songs,
                  libraryScope: LibraryScope.aggregated,
                  selectedArtist: null,
                  breadcrumbLabel: '主页 / 歌名',
                ),
                library: SongBookLibraryViewModel(
                  searchQuery: '',
                  selectedLanguage: '全部',
                  songs: List<Song>.generate(
                    11,
                    (int index) => Song(
                      songId: buildAggregateSongId(
                        title: '歌曲$index',
                        artist: '歌手$index',
                      ),
                      sourceId: 'local',
                      sourceSongId: buildLocalSourceSongId(
                        fingerprint: buildLocalMetadataFingerprint(
                          locator: '/tmp/phone_song_$index.mp4',
                        ),
                      ),
                      title: '歌曲$index',
                      artist: '歌手$index',
                      languages: const <String>['国语'],
                      searchIndex: 'gequ$index geshou$index',
                      mediaPath: '/tmp/phone_song_$index.mp4',
                    ),
                  ),
                  artists: const <Artist>[],
                  favoriteSongIds: const <String>[],
                  downloadingSongIds: <String>{},
                  downloadedSourceSongIds: <String>{},
                  totalCount: 11,
                  pageIndex: 0,
                  totalPages: 2,
                  pageSize: 11,
                  hasConfiguredDirectory: true,
                  hasConfiguredAggregatedSources: true,
                  isScanning: false,
                  isLoadingPage: false,
                  scanErrorMessage: null,
                ),
                playback: const SongBookPlaybackViewModel(
                  queuedSongs: <Song>[],
                ),
              ),
              callbacks: buildSongBookCallbacks(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1/1'), findsOneWidget);
  });

  testWidgets('opens fullscreen preview and toggles overlay controls on tap', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const KtvApp());
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey<String>('preview-tap-target')));
    await tester.pumpAndSettle();

    expect(find.text('返回点歌'), findsNothing);

    final Finder fullscreenScaffold = find.byType(Scaffold).last;
    await tester.tapAt(tester.getCenter(fullscreenScaffold));
    await tester.pumpAndSettle();

    expect(find.text('返回点歌'), findsOneWidget);
    expect(find.text('伴唱'), findsAtLeastNWidgets(1));
    expect(find.text('播放'), findsAtLeastNWidgets(1));
    expect(find.text('重唱'), findsAtLeastNWidgets(1));
    expect(find.text('切歌'), findsAtLeastNWidgets(1));

    await tester.tapAt(tester.getCenter(fullscreenScaffold));
    await tester.pumpAndSettle();

    expect(find.text('返回点歌'), findsNothing);
  });

  testWidgets('tapping non-fullscreen progress bar does not enter fullscreen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const KtvApp());
    await tester.pump();

    final Finder slider = find.byType(Slider).first;
    final Rect sliderRect = tester.getRect(slider);

    await tester.tapAt(Offset(sliderRect.center.dx, sliderRect.bottom - 8));
    await tester.pumpAndSettle();

    expect(find.text('返回点歌'), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('preview-tap-target')),
      findsOneWidget,
    );
  });

  testWidgets(
    'player progress track rebuilds when controller progress changes',
    (WidgetTester tester) async {
      final _TestPlayerController controller = _TestPlayerController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 240,
              child: PlayerProgressTrack(
                controller: controller,
                thickness: 6,
                barHeight: 28,
              ),
            ),
          ),
        ),
      );

      Slider slider = tester.widget<Slider>(find.byType(Slider));
      expect(slider.value, 0);

      controller.setProgress(
        position: const Duration(seconds: 30),
        duration: const Duration(minutes: 2),
        mediaPath: '/tmp/sample.mp4',
      );
      await tester.pump();

      slider = tester.widget<Slider>(find.byType(Slider));
      expect(slider.value, closeTo(0.25, 0.001));
    },
  );

  testWidgets('player progress track forwards seek changes', (
    WidgetTester tester,
  ) async {
    final _TestPlayerController controller = _TestPlayerController();
    controller.setProgress(
      position: Duration.zero,
      duration: const Duration(minutes: 2),
      mediaPath: '/tmp/sample.mp4',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 240,
            child: PlayerProgressTrack(
              controller: controller,
              thickness: 6,
              barHeight: 28,
            ),
          ),
        ),
      ),
    );

    final Slider slider = tester.widget<Slider>(find.byType(Slider));
    expect(slider.onChanged, isNotNull);

    slider.onChanged!(0.5);

    expect(controller.lastSeekProgress, 0.5);
  });
}

class _TestPlayerController extends PlayerController {
  PlayerState _state = const PlayerState();
  double? lastSeekProgress;

  @override
  PlayerState get state => _state;

  void setProgress({
    required Duration position,
    required Duration duration,
    required String mediaPath,
  }) {
    _state = PlayerState(
      currentMediaPath: mediaPath,
      playbackPosition: position,
      playbackDuration: duration,
    );
    notifyListeners();
  }

  @override
  Future<void> applyAudioOutputMode(AudioOutputMode mode) async {}

  @override
  Widget? buildVideoView() => null;

  @override
  Future<void> openMedia(MediaSource source) async {}

  @override
  Future<void> seekToProgress(double progress) async {
    lastSeekProgress = progress;
  }

  @override
  Future<void> togglePlayback() async {}
}
