import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ktv2/ktv2.dart';
import 'package:ktv2_example/core/models/demo_artist.dart';
import 'package:ktv2_example/core/models/demo_artist_page.dart';
import 'package:ktv2_example/core/models/demo_song.dart';
import 'package:ktv2_example/core/models/demo_song_page.dart';
import 'package:ktv2_example/features/ktv_demo/application/ktv_demo_controller.dart';
import 'package:ktv2_example/features/media_library/data/demo_media_library_repository.dart';

class _FakePlayerController extends PlayerController {
  @override
  PlayerState get state => const PlayerState();

  @override
  Future<void> applyAudioOutputMode(AudioOutputMode mode) async {}

  @override
  Widget? buildVideoView() => null;

  @override
  Future<void> openMedia(MediaSource source) async {}

  @override
  Future<void> seekToProgress(double progress) async {}

  @override
  Future<void> togglePlayback() async {}
}

class _FakeMediaLibraryRepository extends DemoMediaLibraryRepository {
  _FakeMediaLibraryRepository({this.savedDirectory});

  final String? savedDirectory;

  @override
  Future<void> clearDirectoryAccess({String? path}) async {}

  @override
  Future<bool> ensureDirectoryAccess(String path) async => true;

  @override
  Future<String?> loadSelectedDirectory() async => savedDirectory;

  @override
  Future<DemoArtistPage> queryArtists({
    required String directory,
    required int pageIndex,
    required int pageSize,
    String? language,
    String searchQuery = '',
  }) async {
    return const DemoArtistPage(
      artists: <DemoArtist>[],
      totalCount: 0,
      pageIndex: 0,
      pageSize: 8,
    );
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
    return const DemoSongPage(
      songs: <DemoSong>[],
      totalCount: 0,
      pageIndex: 0,
      pageSize: 8,
    );
  }

  @override
  Future<void> saveSelectedDirectory(String path) async {}

  @override
  Future<int> scanLibrary(String directory) async => 0;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('KtvDemoController navigation', () {
    test('initialize restores directory but keeps app on home page', () async {
      final KtvDemoController controller = KtvDemoController(
        mediaLibraryRepository: _FakeMediaLibraryRepository(
          savedDirectory: '/music',
        ),
        playerController: _FakePlayerController(),
      );

      await controller.initialize();

      expect(controller.route, DemoRoute.home);
      expect(controller.canNavigateBack, isFalse);
      expect(controller.scanDirectoryPath, '/music');
      expect(controller.breadcrumbLabel, '‹ 主页');
      expect(controller.libraryTotalCount, 0);

      controller.dispose();
    });

    test('back navigation unwinds artist stack level by level', () async {
      final KtvDemoController controller = KtvDemoController(
        mediaLibraryRepository: _FakeMediaLibraryRepository(),
        playerController: _FakePlayerController(),
      );

      controller.enterSongBook(mode: DemoSongBookMode.artists);
      expect(controller.route, DemoRoute.songBook);
      expect(controller.breadcrumbLabel, '‹ 主页 / 歌星');

      await controller.selectArtist('张学友');
      expect(controller.selectedArtist, '张学友');
      expect(controller.breadcrumbLabel, '‹ 主页 / 歌星 / 张学友');

      expect(await controller.navigateBack(), isTrue);
      expect(controller.route, DemoRoute.songBook);
      expect(controller.songBookMode, DemoSongBookMode.artists);
      expect(controller.selectedArtist, isNull);
      expect(controller.breadcrumbLabel, '‹ 主页 / 歌星');

      expect(await controller.navigateBack(), isTrue);
      expect(controller.route, DemoRoute.home);
      expect(controller.canNavigateBack, isFalse);
      expect(controller.breadcrumbLabel, '‹ 主页');

      controller.dispose();
    });

    test('queue page also follows the same stack when going back', () async {
      final KtvDemoController controller = KtvDemoController(
        mediaLibraryRepository: _FakeMediaLibraryRepository(),
        playerController: _FakePlayerController(),
      );

      controller.enterSongBook();
      controller.enterQueueList();
      expect(controller.route, DemoRoute.queueList);
      expect(controller.breadcrumbLabel, '‹ 主页 / 歌名 / 已点');

      expect(await controller.navigateBack(), isTrue);
      expect(controller.route, DemoRoute.songBook);
      expect(controller.breadcrumbLabel, '‹ 主页 / 歌名');

      expect(await controller.navigateBack(), isTrue);
      expect(controller.route, DemoRoute.home);
      expect(controller.breadcrumbLabel, '‹ 主页');

      controller.dispose();
    });
  });
}
