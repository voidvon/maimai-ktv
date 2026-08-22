import 'package:flutter_test/flutter_test.dart';
import 'package:maimai_ktv/core/models/song.dart';
import 'package:maimai_ktv/features/ktv/application/download_manager_models.dart';
import 'package:maimai_ktv/features/ktv/application/ktv_controller.dart';
import 'package:maimai_ktv/features/media_library/data/cloud/cloud_song_download_service.dart';
import 'package:maimai_ktv/features/song_profile/data/song_profile_repository.dart';

import '../../../test_support/ktv_test_doubles.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> settleControllerRefresh() {
    return Future<void>.delayed(const Duration(milliseconds: 260));
  }

  group('KtvController', () {
    test('initialize restores saved local directory and loads songs', () async {
      final FakeMediaIndexStore mediaIndexStore = FakeMediaIndexStore(
        savedDirectory: '/music',
      );
      final KtvController controller = KtvController(
        mediaLibraryRepository: createTestMediaLibraryRepository(
          savedDirectory: '/music',
          accessibleDirectories: <String>{'/music'},
          mediaIndexStore: mediaIndexStore,
        ),
        aggregatedLibraryRepository: FakeAggregatedLibraryRepository(
          localSongsByDirectory: <String, List<Song>>{
            '/music': <Song>[buildLocalSong(title: '海阔天空', artist: 'Beyond')],
          },
        ),
        songProfileRepository: _FakeSongProfileRepository(),
        playerController: FakePlayerController(),
        downloadTaskStore: MemoryDownloadTaskStore(),
        playbackSessionStore: MemoryPlaybackSessionStore(),
      );
      addTearDown(controller.dispose);

      await controller.initialize();

      expect(controller.route, KtvRoute.home);
      expect(controller.scanDirectoryPath, '/music');
      expect(controller.libraryTotalCount, 1);
      expect(controller.librarySongs.single.title, '海阔天空');
      expect(controller.breadcrumbLabel, '主页');
      expect(controller.currentSubtitle, '已从本地目录加载 1 首歌曲。');
      expect(
        mediaIndexStore.configuredSources,
        contains((sourceType: 'local', sourceRootId: '/music')),
      );
    });

    test('scanLibrary resets filters and reloads local songs', () async {
      final KtvController controller = KtvController(
        mediaLibraryRepository: createTestMediaLibraryRepository(),
        aggregatedLibraryRepository: FakeAggregatedLibraryRepository(
          localSongsByDirectory: <String, List<Song>>{
            '/library': <Song>[
              buildLocalSong(
                title: 'Blue Sky',
                artist: 'Singer A',
                language: 'English',
              ),
              buildLocalSong(title: '青花瓷', artist: '周杰伦', language: '国语'),
            ],
          },
        ),
        songProfileRepository: _FakeSongProfileRepository(),
        playerController: FakePlayerController(),
        downloadTaskStore: MemoryDownloadTaskStore(),
        playbackSessionStore: MemoryPlaybackSessionStore(),
      );
      addTearDown(controller.dispose);

      controller.selectLanguage('English');
      controller.setSearchQuery('blue');

      final bool success = await controller.scanLibrary('/library');
      expect(success, isTrue);
      expect(controller.selectedLanguage, KtvController.allLanguagesLabel);
      expect(controller.searchQuery, isEmpty);
      expect(controller.libraryTotalCount, 2);

      controller.selectLanguage('国语');
      await settleControllerRefresh();
      expect(controller.librarySongs.single.title, '青花瓷');

      controller.setSearchQuery('周杰');
      await settleControllerRefresh();
      expect(controller.librarySongs.single.artist, '周杰伦');
    });

    test(
      'artist navigation updates breadcrumbs and goes back correctly',
      () async {
        final KtvController controller = KtvController(
          mediaLibraryRepository: createTestMediaLibraryRepository(),
          aggregatedLibraryRepository: FakeAggregatedLibraryRepository(
            aggregatedSongs: <Song>[
              buildRemoteSong(
                title: '青花瓷',
                artist: '周杰伦',
                sourceId: 'baidu_pan',
                sourceSongId: 'song-1',
              ),
              buildRemoteSong(
                title: '夜曲',
                artist: '周杰伦',
                sourceId: 'baidu_pan',
                sourceSongId: 'song-2',
              ),
              buildRemoteSong(
                title: '后来',
                artist: '刘若英',
                sourceId: 'baidu_pan',
                sourceSongId: 'song-3',
              ),
            ],
          ),
          songProfileRepository: _FakeSongProfileRepository(),
          playerController: FakePlayerController(),
          downloadTaskStore: MemoryDownloadTaskStore(),
          playbackSessionStore: MemoryPlaybackSessionStore(),
        );
        addTearDown(controller.dispose);

        controller.enterSongBook(mode: SongBookMode.artists);
        await settleControllerRefresh();

        expect(controller.route, KtvRoute.songBook);
        expect(controller.songBookMode, SongBookMode.artists);
        expect(controller.breadcrumbLabel, '主页 / 歌星');
        expect(
          controller.libraryArtists.map((artist) => artist.name),
          containsAll(<String>['周杰伦', '刘若英']),
        );

        await controller.selectArtist('周杰伦');

        expect(controller.songBookMode, SongBookMode.songs);
        expect(controller.selectedArtist, '周杰伦');
        expect(controller.breadcrumbLabel, '主页 / 歌星 / 周杰伦');
        expect(
          controller.librarySongs.map((song) => song.title),
          containsAll(<String>['青花瓷', '夜曲']),
        );

        expect(await controller.navigateBack(), isTrue);
        expect(controller.songBookMode, SongBookMode.artists);
        expect(controller.selectedArtist, isNull);
        expect(controller.breadcrumbLabel, '主页 / 歌星');

        expect(await controller.navigateBack(), isTrue);
        expect(controller.route, KtvRoute.home);
        expect(controller.breadcrumbLabel, '主页');
      },
    );

    test('aggregated song book works without a local directory', () async {
      final Song remoteSong = buildRemoteSong(
        title: '遥远的她',
        artist: '张学友',
        sourceId: '115',
        sourceSongId: '115-song-1',
      );
      final KtvController controller = KtvController(
        mediaLibraryRepository: createTestMediaLibraryRepository(
          hasConfiguredAggregatedSources: true,
        ),
        aggregatedLibraryRepository: FakeAggregatedLibraryRepository(
          aggregatedSongs: <Song>[remoteSong],
        ),
        songProfileRepository: _FakeSongProfileRepository(),
        playerController: FakePlayerController(),
        downloadTaskStore: MemoryDownloadTaskStore(),
        playbackSessionStore: MemoryPlaybackSessionStore(),
      );
      addTearDown(controller.dispose);

      controller.enterSongBook(mode: SongBookMode.songs);
      await settleControllerRefresh();

      expect(controller.scanDirectoryPath, isNull);
      expect(controller.libraryScope, LibraryScope.aggregated);
      expect(controller.librarySongs, <Song>[remoteSong]);
      expect(controller.libraryTotalCount, 1);
      expect(controller.currentSubtitle, '已从聚合曲库加载 1 首歌曲。');
    });

    test(
      'loadMoreLibraryItems appends fixed-size song batches through the last page',
      () async {
        final List<Song> songs = List<Song>.generate(
          70,
          (int index) => buildRemoteSong(
            title: '歌曲 ${index.toString().padLeft(2, '0')}',
            artist: '歌手 ${index % 5}',
            sourceId: 'baidu_pan',
            sourceSongId: 'song-$index',
          ),
        );
        final KtvController controller = KtvController(
          mediaLibraryRepository: createTestMediaLibraryRepository(
            hasConfiguredAggregatedSources: true,
          ),
          aggregatedLibraryRepository: FakeAggregatedLibraryRepository(
            aggregatedSongs: songs,
          ),
          songProfileRepository: _FakeSongProfileRepository(),
          playerController: FakePlayerController(),
          downloadTaskStore: MemoryDownloadTaskStore(),
          playbackSessionStore: MemoryPlaybackSessionStore(),
        );
        addTearDown(controller.dispose);

        controller.enterSongBook(
          mode: SongBookMode.songs,
          scope: LibraryScope.aggregated,
        );
        await settleControllerRefresh();

        expect(controller.libraryPageSize, 32);
        expect(controller.libraryPageIndex, 0);
        expect(controller.libraryTotalCount, 70);
        expect(controller.librarySongs, hasLength(32));
        expect(controller.hasMoreLibraryItems, isTrue);

        await controller.loadMoreLibraryItems();

        expect(controller.libraryPageIndex, 1);
        expect(controller.librarySongs, hasLength(64));
        expect(controller.hasMoreLibraryItems, isTrue);

        await controller.loadMoreLibraryItems();

        expect(controller.libraryPageIndex, 2);
        expect(controller.librarySongs, hasLength(70));
        expect(controller.hasMoreLibraryItems, isFalse);
        final List<String> loadedSongIds = controller.librarySongs
            .map((Song song) => song.songId)
            .toList(growable: false);
        expect(loadedSongIds.toSet(), hasLength(70));

        await controller.loadMoreLibraryItems();

        expect(controller.libraryPageIndex, 2);
        expect(
          controller.librarySongs.map((Song song) => song.songId),
          orderedEquals(loadedSongIds),
        );
      },
    );

    test('loadMoreLibraryItems preserves already loaded artists', () async {
      final List<Song> songs = List<Song>.generate(
        40,
        (int index) => buildRemoteSong(
          title: '代表作 ${index.toString().padLeft(2, '0')}',
          artist: '歌手 ${index.toString().padLeft(2, '0')}',
          sourceId: 'baidu_pan',
          sourceSongId: 'artist-song-$index',
        ),
      );
      final KtvController controller = KtvController(
        mediaLibraryRepository: createTestMediaLibraryRepository(
          hasConfiguredAggregatedSources: true,
        ),
        aggregatedLibraryRepository: FakeAggregatedLibraryRepository(
          aggregatedSongs: songs,
        ),
        songProfileRepository: _FakeSongProfileRepository(),
        playerController: FakePlayerController(),
        downloadTaskStore: MemoryDownloadTaskStore(),
        playbackSessionStore: MemoryPlaybackSessionStore(),
      );
      addTearDown(controller.dispose);

      controller.enterSongBook(
        mode: SongBookMode.artists,
        scope: LibraryScope.aggregated,
      );
      await settleControllerRefresh();

      final List<String> firstBatch = controller.libraryArtists
          .map((artist) => artist.name)
          .toList(growable: false);
      expect(firstBatch, hasLength(32));
      expect(controller.hasMoreLibraryItems, isTrue);

      await controller.loadMoreLibraryItems();

      final List<String> allArtists = controller.libraryArtists
          .map((artist) => artist.name)
          .toList(growable: false);
      expect(allArtists, hasLength(40));
      expect(allArtists.take(firstBatch.length), orderedEquals(firstBatch));
      expect(allArtists.toSet(), hasLength(40));
      expect(controller.hasMoreLibraryItems, isFalse);
    });

    test(
      'favorite batches can advance past unresolved profile song IDs',
      () async {
        final Song validSong = buildRemoteSong(
          title: '仍然有效',
          artist: '测试歌手',
          sourceId: 'baidu_pan',
          sourceSongId: 'valid-song',
        );
        final _MutableSongProfileRepository profiles =
            _MutableSongProfileRepository(
              favoriteSongIds: <String>[
                ...List<String>.generate(32, (int index) => 'stale-$index'),
                validSong.songId,
              ],
            );
        final KtvController controller = KtvController(
          mediaLibraryRepository: createTestMediaLibraryRepository(
            hasConfiguredAggregatedSources: true,
          ),
          aggregatedLibraryRepository: FakeAggregatedLibraryRepository(
            aggregatedSongs: <Song>[validSong],
          ),
          songProfileRepository: profiles,
          playerController: FakePlayerController(),
          downloadTaskStore: MemoryDownloadTaskStore(),
          playbackSessionStore: MemoryPlaybackSessionStore(),
        );
        addTearDown(controller.dispose);

        controller.enterFavoritesBook();
        await settleControllerRefresh();

        expect(controller.librarySongs, isEmpty);
        expect(controller.libraryPageIndex, 0);
        expect(controller.hasMoreLibraryItems, isTrue);

        await controller.loadMoreLibraryItems();

        expect(controller.librarySongs, <Song>[validSong]);
        expect(controller.libraryPageIndex, 1);
        expect(controller.hasMoreLibraryItems, isFalse);
      },
    );

    test(
      'favorite refresh preserves the loaded prefix after removal',
      () async {
        final List<Song> songs = List<Song>.generate(
          70,
          (int index) => buildRemoteSong(
            title: '收藏歌曲 ${index.toString().padLeft(2, '0')}',
            artist: '测试歌手',
            sourceId: 'baidu_pan',
            sourceSongId: 'favorite-$index',
          ),
        );
        final _MutableSongProfileRepository profiles =
            _MutableSongProfileRepository(
              favoriteSongIds: songs.map((Song song) => song.songId).toList(),
            );
        final KtvController controller = KtvController(
          mediaLibraryRepository: createTestMediaLibraryRepository(
            hasConfiguredAggregatedSources: true,
          ),
          aggregatedLibraryRepository: FakeAggregatedLibraryRepository(
            aggregatedSongs: songs,
          ),
          songProfileRepository: profiles,
          playerController: FakePlayerController(),
          downloadTaskStore: MemoryDownloadTaskStore(),
          playbackSessionStore: MemoryPlaybackSessionStore(),
        );
        addTearDown(controller.dispose);

        controller.enterFavoritesBook();
        await settleControllerRefresh();
        await controller.loadMoreLibraryItems();

        expect(controller.libraryPageIndex, 1);
        expect(controller.librarySongs, hasLength(64));

        final Song removedSong = songs[10];
        final Song backfilledSong = songs[64];
        await controller.toggleFavorite(removedSong);

        expect(controller.libraryPageIndex, 1);
        expect(controller.libraryPageSize, 32);
        expect(controller.librarySongs, hasLength(64));
        expect(controller.librarySongs, isNot(contains(removedSong)));
        expect(controller.librarySongs, contains(backfilledSong));
        expect(controller.libraryTotalCount, 69);
        expect(controller.hasMoreLibraryItems, isTrue);
      },
    );

    test(
      'resolveSongSelectionAction distinguishes queue, start, and resume',
      () async {
        final Song localSong = buildLocalSong(title: '本地歌曲', artist: '歌手甲');
        final Song downloadedRemoteSong = buildRemoteSong(
          title: '已下载云端歌曲',
          artist: '歌手乙',
          sourceId: 'baidu_pan',
          sourceSongId: 'remote-downloaded',
        );
        final Song pendingRemoteSong = buildRemoteSong(
          title: '待下载云端歌曲',
          artist: '歌手丙',
          sourceId: 'baidu_pan',
          sourceSongId: 'remote-pending',
        );
        final Song pausedRemoteSong = buildRemoteSong(
          title: '暂停云端歌曲',
          artist: '歌手丁',
          sourceId: 'baidu_pan',
          sourceSongId: 'remote-paused',
        );
        final KtvController controller = KtvController(
          mediaLibraryRepository: createTestMediaLibraryRepository(),
          aggregatedLibraryRepository: FakeAggregatedLibraryRepository(),
          songProfileRepository: _FakeSongProfileRepository(),
          playerController: FakePlayerController(),
          songDownloadServices: <String, FakeCloudSongDownloadService>{
            'baidu_pan': FakeCloudSongDownloadService(
              sourceId: 'baidu_pan',
              downloadedSongs: <CloudDownloadedSongRecord>[
                CloudDownloadedSongRecord(
                  sourceId: 'baidu_pan',
                  sourceSongId: downloadedRemoteSong.sourceSongId,
                  title: downloadedRemoteSong.title,
                  artist: downloadedRemoteSong.artist,
                  savedPath: '/tmp/downloaded.mp4',
                  savedAtMillis: 1,
                ),
              ],
            ),
          },
          downloadTaskStore: MemoryDownloadTaskStore(<DownloadingSongItem>[
            DownloadingSongItem(
              songId: pausedRemoteSong.songId,
              sourceId: pausedRemoteSong.sourceId,
              sourceSongId: pausedRemoteSong.sourceSongId,
              title: pausedRemoteSong.title,
              artist: pausedRemoteSong.artist,
              startedAtMillis: 1,
              updatedAtMillis: 2,
              status: DownloadTaskStatus.paused,
            ),
          ]),
          playbackSessionStore: MemoryPlaybackSessionStore(),
        );
        addTearDown(controller.dispose);

        await controller.initialize();

        expect(
          controller.resolveSongSelectionAction(localSong),
          SongSelectionAction.queue,
        );
        expect(
          controller.resolveSongSelectionAction(downloadedRemoteSong),
          SongSelectionAction.queue,
        );
        expect(
          controller.resolveSongSelectionAction(pendingRemoteSong),
          SongSelectionAction.startDownload,
        );
        expect(
          controller.resolveSongSelectionAction(pausedRemoteSong),
          SongSelectionAction.resumeDownload,
        );
      },
    );
  });
}

class _FakeSongProfileRepository extends SongProfileRepository {
  @override
  Future<Set<String>> loadFavoriteSongIds(Iterable<String> songIds) async {
    return <String>{};
  }

  @override
  Future<void> close() async {}
}

class _MutableSongProfileRepository extends SongProfileRepository {
  _MutableSongProfileRepository({required List<String> favoriteSongIds})
    : _favoriteSongIds = Set<String>.of(favoriteSongIds);

  final Set<String> _favoriteSongIds;

  @override
  Future<bool> toggleFavorite({required Song song}) async {
    if (_favoriteSongIds.remove(song.songId)) {
      return false;
    }
    _favoriteSongIds.add(song.songId);
    return true;
  }

  @override
  Future<Set<String>> loadFavoriteSongIds(Iterable<String> songIds) async {
    return songIds.where(_favoriteSongIds.contains).toSet();
  }

  @override
  Future<List<String>> queryFavoriteSongIds({
    required int pageIndex,
    required int pageSize,
    String? language,
    String? artist,
    String searchQuery = '',
  }) async {
    final List<String> songIds = _favoriteSongIds.toList(growable: false);
    final int start = pageIndex * pageSize;
    if (start >= songIds.length) {
      return const <String>[];
    }
    final int end = (start + pageSize).clamp(0, songIds.length);
    return songIds.sublist(start, end);
  }

  @override
  Future<int> countFavoriteSongs({
    String? language,
    String? artist,
    String searchQuery = '',
  }) async {
    return _favoriteSongIds.length;
  }

  @override
  Future<void> close() async {}
}
