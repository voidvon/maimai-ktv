import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ktv2/ktv2.dart';
import 'package:ktv2_example/core/models/demo_song.dart';
import 'package:ktv2_example/features/ktv_demo/application/ktv_demo_controller.dart';
import 'package:ktv2_example/features/media_library/data/demo_media_library_repository.dart';

void main() {
  test('initialize restores saved directory and scans songs', () async {
    final FakeDemoMediaLibraryRepository repository =
        FakeDemoMediaLibraryRepository(
          savedDirectory: 'content://demo/tree',
          accessibleDirectories: <String>{'content://demo/tree'},
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
    expect(controller.route, DemoRoute.songBook);
    expect(controller.librarySongs, hasLength(1));
    expect(controller.currentSubtitle, contains('已从扫描目录加载 1 首歌曲'));
  });

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
      expect(controller.filteredSongs.single.title, '青花瓷');

      controller.setSearchQuery('zhou');
      expect(controller.filteredSongs, isEmpty);
    },
  );

  test('playSong opens media and moves song to queue head', () async {
    final FakePlayerController playerController = FakePlayerController();
    final KtvDemoController controller = KtvDemoController(
      mediaLibraryRepository: FakeDemoMediaLibraryRepository(),
      playerController: playerController,
    );
    final DemoSong first = _song(title: '第一首', artist: '歌手甲');
    final DemoSong second = _song(title: '第二首', artist: '歌手乙');

    await controller.playSong(first);
    await controller.playSong(second);
    await controller.playSong(first);

    expect(playerController.lastOpenedSource?.displayName, '第一首');
    expect(controller.queuedSongs.first, first);
    expect(controller.queuedSongs, <DemoSong>[first, second]);
    expect(controller.currentTitle, '第一首');
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
    language: language,
    searchIndex: '$title $artist'.toLowerCase(),
    mediaPath: mediaPath ?? '/tmp/$title.mp4',
  );
}

class FakeDemoMediaLibraryRepository extends DemoMediaLibraryRepository {
  FakeDemoMediaLibraryRepository({
    this.savedDirectory,
    Set<String>? accessibleDirectories,
    Map<String, List<DemoSong>>? scanResults,
  }) : _accessibleDirectories = accessibleDirectories ?? <String>{},
       _scanResults = scanResults ?? <String, List<DemoSong>>{};

  final String? savedDirectory;
  final Set<String> _accessibleDirectories;
  final Map<String, List<DemoSong>> _scanResults;
  String? lastSavedDirectory;
  String? clearedDirectory;

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
  Future<List<DemoSong>> scanLibrary(String directory) async {
    final List<DemoSong>? result = _scanResults[directory];
    if (result == null) {
      throw StateError('missing scan result for $directory');
    }
    return result;
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
