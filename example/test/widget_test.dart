import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ktv2/ktv2.dart';
import 'package:ktv2_example/core/models/demo_artist.dart';
import 'package:ktv2_example/core/models/demo_song.dart';
import 'package:ktv2_example/features/ktv_demo/application/ktv_demo_controller.dart';
import 'package:ktv2_example/features/ktv_demo/presentation/songbook_contracts.dart';
import 'package:ktv2_example/features/ktv_demo/presentation/songbook_page.dart';
import 'package:ktv2_example/features/ktv_demo/presentation/shared_widgets.dart';
import 'package:ktv2_example/main.dart';

void main() {
  testWidgets('shows home shell before media library is selected', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const KtvDemoApp());

    expect(find.text('我爱KTV'), findsOneWidget);
    expect(find.text('歌名'), findsOneWidget);
    expect(find.text('设置'), findsAtLeastNWidgets(1));
    expect(find.text('首页预览区'), findsNothing);
    expect(find.byType(Slider), findsOneWidget);
  });

  testWidgets('opens scan directory settings dialog from top actions', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const KtvDemoApp());

    await tester.tap(find.text('设置').first);
    await tester.pumpAndSettle();

    expect(find.text('媒体库设置'), findsOneWidget);
    expect(find.text('扫描目录'), findsOneWidget);
    expect(find.text('选择目录'), findsOneWidget);
  });

  testWidgets('opens queued songs page from home toolbar', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const KtvDemoApp());

    await tester.tap(find.text('已点0').first);
    await tester.pumpAndSettle();

    expect(find.text('‹ 主页 / 已点'), findsOneWidget);
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

    await tester.pumpWidget(const KtvDemoApp());

    await tester.tap(find.text('歌名'));
    await tester.pumpAndSettle();

    expect(find.text('请先在设置里选择扫描目录，扫描完成后这里会展示歌曲列表。'), findsOneWidget);
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

    await tester.pumpWidget(const KtvDemoApp());

    await tester.tap(find.text('歌名'));
    await tester.pumpAndSettle();

    expect(find.text('‹ 主页 / 歌名'), findsOneWidget);
    expect(find.text('请先在设置里选择扫描目录，扫描完成后这里会展示歌曲列表。'), findsOneWidget);
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
                route: DemoRoute.songBook,
                songBookMode: DemoSongBookMode.artists,
                selectedArtist: null,
                breadcrumbLabel: '‹ 主页 / 歌星',
              ),
              library: SongBookLibraryViewModel(
                searchQuery: '',
                selectedLanguage: '全部',
                songs: <DemoSong>[],
                artists: <DemoArtist>[
                  DemoArtist(
                    name: '周杰伦',
                    songCount: 12,
                    searchIndex: 'zhoujielun',
                  ),
                  DemoArtist(
                    name: '刘若英',
                    songCount: 8,
                    searchIndex: 'liuruoying',
                  ),
                  DemoArtist(
                    name: '张学友',
                    songCount: 15,
                    searchIndex: 'zhangxueyou',
                  ),
                  DemoArtist(name: 'A-Lin', songCount: 6, searchIndex: 'a-lin'),
                  DemoArtist(
                    name: '邓紫棋',
                    songCount: 10,
                    searchIndex: 'dengziqi',
                  ),
                  DemoArtist(
                    name: 'Beyond',
                    songCount: 9,
                    searchIndex: 'beyond',
                  ),
                ],
                totalCount: 6,
                pageIndex: 0,
                totalPages: 1,
                pageSize: 6,
                hasConfiguredDirectory: true,
                isScanning: false,
                isLoadingPage: false,
                scanErrorMessage: null,
              ),
              playback: SongBookPlaybackViewModel(queuedSongs: <DemoSong>[]),
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

    expect(find.text('‹ 主页 / 歌星'), findsOneWidget);
    expect(find.text('1/1'), findsOneWidget);
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
              viewModel: const SongBookViewModel(
                navigation: SongBookNavigationViewModel(
                  route: DemoRoute.songBook,
                  songBookMode: DemoSongBookMode.songs,
                  selectedArtist: null,
                  breadcrumbLabel: '‹ 主页 / 歌名',
                ),
                library: SongBookLibraryViewModel(
                  searchQuery: '',
                  selectedLanguage: '全部',
                  songs: <DemoSong>[
                    DemoSong(
                      title: '青花瓷',
                      artist: '周杰伦',
                      languages: <String>['国语'],
                      searchIndex: 'qinghuaci zhoujielun',
                      mediaPath: '/tmp/1.mp4',
                    ),
                    DemoSong(
                      title: '夜曲',
                      artist: '周杰伦',
                      languages: <String>['国语'],
                      searchIndex: 'yequ zhoujielun',
                      mediaPath: '/tmp/2.mp4',
                    ),
                    DemoSong(
                      title: '后来',
                      artist: '刘若英',
                      languages: <String>['国语'],
                      searchIndex: 'houlai liuruoying',
                      mediaPath: '/tmp/3.mp4',
                    ),
                    DemoSong(
                      title: '海阔天空',
                      artist: 'Beyond',
                      languages: <String>['粤语'],
                      searchIndex: 'haikuotiankong beyond',
                      mediaPath: '/tmp/4.mp4',
                    ),
                  ],
                  artists: <DemoArtist>[],
                  totalCount: 4,
                  pageIndex: 0,
                  totalPages: 2,
                  pageSize: 2,
                  hasConfiguredDirectory: true,
                  isScanning: false,
                  isLoadingPage: false,
                  scanErrorMessage: null,
                ),
                playback: SongBookPlaybackViewModel(queuedSongs: <DemoSong>[]),
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

  testWidgets('opens fullscreen preview and toggles overlay controls on tap', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const KtvDemoApp());
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
    await tester.pumpWidget(const KtvDemoApp());
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
        mediaPath: '/tmp/demo.mp4',
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
      mediaPath: '/tmp/demo.mp4',
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
