import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ktv2/ktv2.dart';
import 'package:ktv2_example/core/models/demo_artist.dart';
import 'package:ktv2_example/core/models/demo_artist_page.dart';
import 'package:ktv2_example/core/models/demo_song.dart';
import 'package:ktv2_example/core/models/demo_song_page.dart';
import 'package:ktv2_example/features/ktv_demo/application/ktv_demo_controller.dart';
import 'package:ktv2_example/features/media_library/data/demo_media_library_repository.dart';

void main() {
  test('initialize restores saved directory and scans songs', () async {
    final FakeDemoMediaLibraryRepository repository =
        FakeDemoMediaLibraryRepository(
          savedDirectory: 'content://demo/tree',
          accessibleDirectories: <String>{'content://demo/tree'},
          indexedResults: <String, List<DemoSong>>{
            'content://demo/tree': <DemoSong>[
              _song(title: '海阔天空', artist: 'Beyond'),
            ],
          },
          scanResults: <String, List<DemoSong>>{
            'content://demo/tree': <DemoSong>[
              _song(title: '海阔天空', artist: 'Beyond'),
            ],
          },
        );
    final FakePlayerController playerController = FakePlayerController();
    final KtvDemoController controller = KtvDemoController(
      mediaLibraryRepository: repository,
      playerController: playerController,
    );

    await controller.initialize();

    expect(controller.scanDirectoryPath, 'content://demo/tree');
    expect(controller.route, DemoRoute.home);
    expect(controller.breadcrumbLabel, '‹ 主页');
    expect(controller.librarySongs, hasLength(1));
    await _settleLibraryQuery();
    expect(repository.scanLibraryCallCount, 1);
    expect(controller.currentSubtitle, contains('已从扫描目录加载 1 首歌曲'));
  });

  test(
    'initialize shows indexed songs first then refreshes in background',
    () async {
      final FakeDemoMediaLibraryRepository repository =
          FakeDemoMediaLibraryRepository(
            savedDirectory: 'content://demo/tree',
            accessibleDirectories: <String>{'content://demo/tree'},
            indexedResults: <String, List<DemoSong>>{
              'content://demo/tree': <DemoSong>[
                _song(title: '沧海一声笑-国语-单音轨', artist: '任贤齐'),
              ],
            },
            scanResults: <String, List<DemoSong>>{
              'content://demo/tree': <DemoSong>[
                _song(title: '沧海一声笑', artist: '任贤齐', language: '国语'),
              ],
            },
          );
      final KtvDemoController controller = KtvDemoController(
        mediaLibraryRepository: repository,
        playerController: FakePlayerController(),
      );

      await controller.initialize();

      expect(controller.librarySongs.single.title, '沧海一声笑-国语-单音轨');

      await _settleLibraryQuery();

      expect(repository.scanLibraryCallCount, 1);
      expect(controller.librarySongs.single.title, '沧海一声笑');
      expect(controller.librarySongs.single.language, '国语');
    },
  );

  test(
    'scanLibrary resets search and language and filters with state',
    () async {
      final FakeDemoMediaLibraryRepository repository =
          FakeDemoMediaLibraryRepository(
            scanResults: <String, List<DemoSong>>{
              '/media': <DemoSong>[
                _song(title: 'K Song', artist: 'Singer A', language: '英语'),
                _song(title: '青花瓷', artist: '周杰伦', language: '国语'),
              ],
            },
          );
      final KtvDemoController controller = KtvDemoController(
        mediaLibraryRepository: repository,
        playerController: FakePlayerController(),
      );

      controller.selectLanguage('英语');
      controller.setSearchQuery('k');
      final bool success = await controller.scanLibrary('/media');

      expect(success, isTrue);
      expect(controller.selectedLanguage, KtvDemoController.allLanguagesLabel);
      expect(controller.state.searchQuery, isEmpty);

      controller.selectLanguage('国语');
      await _settleLibraryQuery();
      expect(controller.filteredSongs.single.title, '青花瓷');

      controller.setSearchQuery('zhou');
      await _settleSearchRefresh();
      expect(controller.filteredSongs, isEmpty);
    },
  );

  test(
    'enter artist book loads artist mode and selectArtist filters songs',
    () async {
      final FakeDemoMediaLibraryRepository repository =
          FakeDemoMediaLibraryRepository(
            scanResults: <String, List<DemoSong>>{
              '/media': <DemoSong>[
                _song(title: '青花瓷', artist: '周杰伦', language: '国语'),
                _song(title: '夜曲', artist: '周杰伦', language: '国语'),
                _song(title: '后来', artist: '刘若英', language: '国语'),
              ],
            },
          );
      final KtvDemoController controller = KtvDemoController(
        mediaLibraryRepository: repository,
        playerController: FakePlayerController(),
      );

      await controller.scanLibrary('/media');
      controller.enterSongBook(mode: DemoSongBookMode.artists);
      await _settleLibraryQuery();

      expect(controller.songBookMode, DemoSongBookMode.artists);
      expect(controller.selectedArtist, isNull);
      expect(
        controller.libraryArtists.map((DemoArtist artist) => artist.name),
        containsAll(<String>['周杰伦', '刘若英']),
      );

      await controller.selectArtist('周杰伦');

      expect(controller.songBookMode, DemoSongBookMode.songs);
      expect(controller.selectedArtist, '周杰伦');
      expect(
        controller.librarySongs.map((DemoSong song) => song.title),
        <String>['青花瓷', '夜曲'],
      );
    },
  );

  test('returnFromSelectedArtist goes back to artist overview', () async {
    final FakeDemoMediaLibraryRepository repository =
        FakeDemoMediaLibraryRepository(
          scanResults: <String, List<DemoSong>>{
            '/media': <DemoSong>[
              _song(title: '青花瓷', artist: '周杰伦', language: '国语'),
              _song(title: '后来', artist: '刘若英', language: '国语'),
            ],
          },
        );
    final KtvDemoController controller = KtvDemoController(
      mediaLibraryRepository: repository,
      playerController: FakePlayerController(),
    );

    await controller.scanLibrary('/media');
    controller.enterSongBook(mode: DemoSongBookMode.artists);
    await _settleLibraryQuery();
    await controller.selectArtist('周杰伦');

    final bool handled = await controller.returnFromSelectedArtist();

    expect(handled, isTrue);
    expect(controller.songBookMode, DemoSongBookMode.artists);
    expect(controller.selectedArtist, isNull);
    expect(controller.libraryArtists, isNotEmpty);
  });

  test(
    'requestSong keeps current playback and appends new songs to queue',
    () async {
      final FakePlayerController playerController = FakePlayerController();
      final KtvDemoController controller = KtvDemoController(
        mediaLibraryRepository: FakeDemoMediaLibraryRepository(),
        playerController: playerController,
      );
      final DemoSong first = _song(title: '第一首', artist: '歌手甲');
      final DemoSong second = _song(title: '第二首', artist: '歌手乙');

      await controller.requestSong(first);
      await controller.requestSong(second);
      await controller.requestSong(first);

      expect(playerController.lastOpenedSource?.displayName, '第一首');
      expect(controller.queuedSongs.first, first);
      expect(controller.queuedSongs, <DemoSong>[first, second]);
      expect(controller.currentTitle, '第一首');
    },
  );

  test(
    'prioritizeQueuedSong moves later queued item behind current song',
    () async {
      final KtvDemoController controller = KtvDemoController(
        mediaLibraryRepository: FakeDemoMediaLibraryRepository(),
        playerController: FakePlayerController(),
      );
      final DemoSong current = _song(title: '当前播放', artist: '歌手甲');
      final DemoSong next = _song(title: '下一首', artist: '歌手乙');
      final DemoSong later = _song(title: '后面那首', artist: '歌手丙');

      await controller.requestSong(current);
      await controller.requestSong(next);
      await controller.requestSong(later);

      controller.prioritizeQueuedSong(later);

      expect(controller.queuedSongs, <DemoSong>[current, later, next]);
    },
  );

  test('removeQueuedSong only removes non-current queued items', () async {
    final KtvDemoController controller = KtvDemoController(
      mediaLibraryRepository: FakeDemoMediaLibraryRepository(),
      playerController: FakePlayerController(),
    );
    final DemoSong current = _song(title: '当前播放', artist: '歌手甲');
    final DemoSong next = _song(title: '下一首', artist: '歌手乙');

    await controller.requestSong(current);
    await controller.requestSong(next);

    controller.removeQueuedSong(current);
    controller.removeQueuedSong(next);

    expect(controller.queuedSongs, <DemoSong>[current]);
  });

  test('stopPlayback pauses current media and rewinds to start', () async {
    final FakePlayerController playerController = FakePlayerController();
    final KtvDemoController controller = KtvDemoController(
      mediaLibraryRepository: FakeDemoMediaLibraryRepository(),
      playerController: playerController,
    );

    await controller.requestSong(_song(title: '夜空中最亮的星', artist: '逃跑计划'));
    await playerController.seekToProgress(0.5);

    await controller.stopPlayback();

    expect(playerController.isPlaying, isFalse);
    expect(playerController.playbackPosition, Duration.zero);
  });

  test('skipCurrentSong keeps selected audio mode for next song', () async {
    final FakePlayerController playerController = FakePlayerController();
    final KtvDemoController controller = KtvDemoController(
      mediaLibraryRepository: FakeDemoMediaLibraryRepository(),
      playerController: playerController,
    );
    final DemoSong current = _song(title: '第一首', artist: '歌手甲');
    final DemoSong next = _song(title: '第二首', artist: '歌手乙');

    await controller.requestSong(current);
    await controller.requestSong(next);
    controller.toggleAudioMode();

    expect(playerController.audioOutputMode, AudioOutputMode.accompaniment);

    await controller.skipCurrentSong();

    expect(playerController.lastOpenedSource?.displayName, '第二首');
    expect(playerController.audioOutputMode, AudioOutputMode.accompaniment);
  });
}

DemoSong _song({
  required String title,
  required String artist,
  String language = '其它',
  String? mediaPath,
}) {
  return DemoSong(
    title: title,
    artist: artist,
    languages: <String>[language],
    searchIndex: '$title $artist'.toLowerCase(),
    mediaPath: mediaPath ?? '/tmp/$title.mp4',
  );
}

class FakeDemoMediaLibraryRepository extends DemoMediaLibraryRepository {
  FakeDemoMediaLibraryRepository({
    this.savedDirectory,
    Set<String>? accessibleDirectories,
    Map<String, List<DemoSong>>? indexedResults,
    Map<String, List<DemoSong>>? scanResults,
  }) : _accessibleDirectories = accessibleDirectories ?? <String>{},
       _indexedResults = indexedResults ?? <String, List<DemoSong>>{},
       _scanResults = scanResults ?? <String, List<DemoSong>>{};

  final String? savedDirectory;
  final Set<String> _accessibleDirectories;
  final Map<String, List<DemoSong>> _indexedResults;
  final Map<String, List<DemoSong>> _scanResults;
  String? lastSavedDirectory;
  String? clearedDirectory;
  int scanLibraryCallCount = 0;

  @override
  Future<String?> loadSelectedDirectory() async => savedDirectory;

  @override
  Future<bool> ensureDirectoryAccess(String path) async {
    return _accessibleDirectories.contains(path);
  }

  @override
  Future<void> clearDirectoryAccess({String? path}) async {
    clearedDirectory = path;
  }

  @override
  Future<void> saveSelectedDirectory(String path) async {
    lastSavedDirectory = path;
  }

  @override
  Future<int> scanLibrary(String directory) async {
    scanLibraryCallCount += 1;
    final List<DemoSong>? result = _scanResults[directory];
    if (result == null) {
      throw StateError('missing scan result for $directory');
    }
    _indexedResults[directory] = List<DemoSong>.of(result);
    return result.length;
  }

  @override
  Future<DemoSongPage> querySongs({
    required String directory,
    required int pageIndex,
    required int pageSize,
    String? language,
    String? artist,
    String searchQuery = '',
  }) async {
    final List<DemoSong>? result =
        _indexedResults[directory] ?? _scanResults[directory];
    if (result == null) {
      throw StateError('missing scan result for $directory');
    }
    final String normalizedQuery = searchQuery.trim().toLowerCase();
    final String normalizedLanguage = (language ?? '').trim();
    final String normalizedArtist = (artist ?? '').trim();
    final List<DemoSong> filteredSongs = result
        .where((DemoSong song) {
          if (normalizedLanguage.isNotEmpty &&
              song.language != normalizedLanguage) {
            return false;
          }
          if (normalizedArtist.isNotEmpty && song.artist != normalizedArtist) {
            return false;
          }
          if (normalizedQuery.isEmpty) {
            return true;
          }
          return song.searchIndex.contains(normalizedQuery);
        })
        .toList(growable: false);
    final int start = pageIndex * pageSize;
    final int end = (start + pageSize).clamp(0, filteredSongs.length);
    return DemoSongPage(
      songs: start >= filteredSongs.length
          ? const <DemoSong>[]
          : filteredSongs.sublist(start, end),
      totalCount: filteredSongs.length,
      pageIndex: pageIndex,
      pageSize: pageSize,
    );
  }

  @override
  Future<DemoArtistPage> queryArtists({
    required String directory,
    required int pageIndex,
    required int pageSize,
    String? language,
    String searchQuery = '',
  }) async {
    final List<DemoSong>? result =
        _indexedResults[directory] ?? _scanResults[directory];
    if (result == null) {
      throw StateError('missing scan result for $directory');
    }
    final String normalizedQuery = searchQuery.trim().toLowerCase();
    final String normalizedLanguage = (language ?? '').trim();
    final Map<String, int> songCountByArtist = <String, int>{};
    for (final DemoSong song in result) {
      if (normalizedLanguage.isNotEmpty &&
          song.language != normalizedLanguage) {
        continue;
      }
      songCountByArtist.update(
        song.artist,
        (int count) => count + 1,
        ifAbsent: () => 1,
      );
    }
    final List<DemoArtist> filteredArtists = songCountByArtist.entries
        .map(
          (MapEntry<String, int> entry) => DemoArtist(
            name: entry.key,
            songCount: entry.value,
            searchIndex: entry.key.toLowerCase(),
          ),
        )
        .where((DemoArtist artist) {
          if (normalizedQuery.isEmpty) {
            return true;
          }
          return artist.searchIndex.contains(normalizedQuery);
        })
        .toList(growable: false);
    final int start = pageIndex * pageSize;
    final int end = (start + pageSize).clamp(0, filteredArtists.length);
    return DemoArtistPage(
      artists: start >= filteredArtists.length
          ? const <DemoArtist>[]
          : filteredArtists.sublist(start, end),
      totalCount: filteredArtists.length,
      pageIndex: pageIndex,
      pageSize: pageSize,
    );
  }
}

class FakePlayerController extends PlayerController {
  PlayerState _state = const PlayerState();
  MediaSource? lastOpenedSource;

  @override
  PlayerState get state => _state;

  @override
  Future<void> applyAudioOutputMode(AudioOutputMode mode) async {
    _state = PlayerState(
      audioOutputMode: mode,
      currentMediaPath: _state.currentMediaPath,
      isPlaying: _state.isPlaying,
      playbackDuration: _state.playbackDuration,
      playbackPosition: _state.playbackPosition,
    );
    notifyListeners();
  }

  @override
  Widget? buildVideoView() => null;

  @override
  Future<void> openMedia(MediaSource source) async {
    lastOpenedSource = source;
    _state = PlayerState(
      audioOutputMode: _state.audioOutputMode,
      currentMediaPath: source.path,
      isPlaying: true,
      playbackDuration: const Duration(minutes: 4),
      playbackPosition: Duration.zero,
    );
    notifyListeners();
  }

  @override
  Future<void> seekToProgress(double progress) async {
    _state = PlayerState(
      audioOutputMode: _state.audioOutputMode,
      currentMediaPath: _state.currentMediaPath,
      isPlaying: _state.isPlaying,
      playbackDuration: _state.playbackDuration,
      playbackPosition: Duration(
        milliseconds: (_state.playbackDuration.inMilliseconds * progress)
            .round(),
      ),
    );
    notifyListeners();
  }

  @override
  Future<void> togglePlayback() async {
    _state = PlayerState(
      audioOutputMode: _state.audioOutputMode,
      currentMediaPath: _state.currentMediaPath,
      isPlaying: !_state.isPlaying,
      playbackDuration: _state.playbackDuration,
      playbackPosition: _state.playbackPosition,
    );
    notifyListeners();
  }
}

Future<void> _settleLibraryQuery() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

Future<void> _settleSearchRefresh() async {
  await Future<void>.delayed(const Duration(milliseconds: 250));
  await _settleLibraryQuery();
}
