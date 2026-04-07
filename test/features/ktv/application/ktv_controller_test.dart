import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ktv2/ktv2.dart';
import 'package:ktv2_example/core/models/artist.dart';
import 'package:ktv2_example/core/models/artist_page.dart';
import 'package:ktv2_example/core/models/song.dart';
import 'package:ktv2_example/core/models/song_identity.dart';
import 'package:ktv2_example/core/models/song_page.dart';
import 'package:ktv2_example/features/ktv/application/ktv_controller.dart';
import 'package:ktv2_example/features/media_library/data/aggregated_library_repository.dart';
import 'package:ktv2_example/features/media_library/data/cloud/cloud_playback_cache.dart';
import 'package:ktv2_example/features/media_library/data/cloud/cloud_song_download_service.dart';
import 'package:ktv2_example/features/media_library/data/media_library_repository.dart';

void main() {
  test('initialize keeps restored directory on home route', () async {
    final FakeMediaLibraryRepository repository = FakeMediaLibraryRepository(
      savedDirectory: '/music',
      accessibleDirectories: <String>{'/music'},
      indexedResults: <String, List<Song>>{'/music': <Song>[]},
      scanResults: <String, List<Song>>{'/music': <Song>[]},
    );
    final KtvController controller = KtvController(
      mediaLibraryRepository: repository,
      playerController: FakePlayerController(),
    );

    await controller.initialize();

    expect(controller.route, KtvRoute.home);
    expect(controller.canNavigateBack, isFalse);
    expect(controller.scanDirectoryPath, '/music');
    expect(controller.breadcrumbLabel, '主页');
    expect(controller.libraryTotalCount, 0);
  });

  test('initialize restores saved directory and scans songs', () async {
    final FakeMediaLibraryRepository repository = FakeMediaLibraryRepository(
      savedDirectory: 'content://library/tree',
      accessibleDirectories: <String>{'content://library/tree'},
      indexedResults: <String, List<Song>>{
        'content://library/tree': <Song>[
          _song(title: '海阔天空', artist: 'Beyond'),
        ],
      },
      scanResults: <String, List<Song>>{
        'content://library/tree': <Song>[
          _song(title: '海阔天空', artist: 'Beyond'),
        ],
      },
    );
    final FakePlayerController playerController = FakePlayerController();
    final KtvController controller = KtvController(
      mediaLibraryRepository: repository,
      playerController: playerController,
    );

    await controller.initialize();

    expect(controller.scanDirectoryPath, 'content://library/tree');
    expect(controller.route, KtvRoute.home);
    expect(controller.breadcrumbLabel, '主页');
    expect(controller.librarySongs, hasLength(1));
    await _settleLibraryQuery();
    expect(repository.scanLibraryCallCount, 1);
    expect(controller.currentSubtitle, contains('已从本地目录加载 1 首歌曲'));
  });

  test(
    'initialize always rescans restored directory before showing songs',
    () async {
      final FakeMediaLibraryRepository repository = FakeMediaLibraryRepository(
        savedDirectory: 'content://library/tree',
        accessibleDirectories: <String>{'content://library/tree'},
        indexedResults: <String, List<Song>>{
          'content://library/tree': <Song>[
            _song(title: '沧海一声笑-国语-单音轨', artist: '任贤齐'),
          ],
        },
        scanResults: <String, List<Song>>{
          'content://library/tree': <Song>[
            _song(title: '沧海一声笑', artist: '任贤齐', language: '国语'),
          ],
        },
      );
      final KtvController controller = KtvController(
        mediaLibraryRepository: repository,
        playerController: FakePlayerController(),
      );

      await controller.initialize();

      expect(repository.scanLibraryCallCount, 1);
      expect(controller.librarySongs.single.title, '沧海一声笑');
      expect(controller.librarySongs.single.language, '国语');
    },
  );

  test(
    'scanLibrary resets search and language and filters with state',
    () async {
      final FakeMediaLibraryRepository repository = FakeMediaLibraryRepository(
        scanResults: <String, List<Song>>{
          '/media': <Song>[
            _song(title: 'K Song', artist: 'Singer A', language: '英语'),
            _song(title: '青花瓷', artist: '周杰伦', language: '国语'),
          ],
        },
      );
      final KtvController controller = KtvController(
        mediaLibraryRepository: repository,
        playerController: FakePlayerController(),
      );

      controller.selectLanguage('英语');
      controller.setSearchQuery('k');
      final bool success = await controller.scanLibrary('/media');

      expect(success, isTrue);
      expect(controller.selectedLanguage, KtvController.allLanguagesLabel);
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
      final FakeMediaLibraryRepository repository = FakeMediaLibraryRepository(
        scanResults: <String, List<Song>>{
          '/media': <Song>[
            _song(title: '青花瓷', artist: '周杰伦', language: '国语'),
            _song(title: '夜曲', artist: '周杰伦', language: '国语'),
            _song(title: '后来', artist: '刘若英', language: '国语'),
          ],
        },
      );
      final KtvController controller = KtvController(
        mediaLibraryRepository: repository,
        playerController: FakePlayerController(),
      );

      await controller.scanLibrary('/media');
      controller.enterSongBook(mode: SongBookMode.artists);
      await _settleLibraryQuery();

      expect(controller.songBookMode, SongBookMode.artists);
      expect(controller.selectedArtist, isNull);
      expect(
        controller.libraryArtists.map((Artist artist) => artist.name),
        containsAll(<String>['周杰伦', '刘若英']),
      );

      await controller.selectArtist('周杰伦');

      expect(controller.songBookMode, SongBookMode.songs);
      expect(controller.selectedArtist, '周杰伦');
      expect(
        controller.librarySongs.map((Song song) => song.title),
        containsAll(<String>['青花瓷', '夜曲']),
      );
    },
  );

  test('returnFromSelectedArtist goes back to artist overview', () async {
    final FakeMediaLibraryRepository repository = FakeMediaLibraryRepository(
      scanResults: <String, List<Song>>{
        '/media': <Song>[
          _song(title: '青花瓷', artist: '周杰伦', language: '国语'),
          _song(title: '后来', artist: '刘若英', language: '国语'),
        ],
      },
    );
    final KtvController controller = KtvController(
      mediaLibraryRepository: repository,
      playerController: FakePlayerController(),
    );

    await controller.scanLibrary('/media');
    controller.enterSongBook(mode: SongBookMode.artists);
    await _settleLibraryQuery();
    await controller.selectArtist('周杰伦');

    final bool handled = await controller.returnFromSelectedArtist();

    expect(handled, isTrue);
    expect(controller.songBookMode, SongBookMode.artists);
    expect(controller.selectedArtist, isNull);
    expect(controller.libraryArtists, isNotEmpty);
  });

  test('navigateBack unwinds artist stack level by level', () async {
    final KtvController controller = KtvController(
      mediaLibraryRepository: FakeMediaLibraryRepository(),
      playerController: FakePlayerController(),
    );

    controller.enterSongBook(mode: SongBookMode.artists);
    expect(controller.route, KtvRoute.songBook);
    expect(controller.breadcrumbLabel, '主页 / 歌星');

    await controller.selectArtist('张学友');
    expect(controller.selectedArtist, '张学友');
    expect(controller.breadcrumbLabel, '主页 / 歌星 / 张学友');

    expect(await controller.navigateBack(), isTrue);
    expect(controller.route, KtvRoute.songBook);
    expect(controller.songBookMode, SongBookMode.artists);
    expect(controller.selectedArtist, isNull);
    expect(controller.breadcrumbLabel, '主页 / 歌星');

    expect(await controller.navigateBack(), isTrue);
    expect(controller.route, KtvRoute.home);
    expect(controller.canNavigateBack, isFalse);
    expect(controller.breadcrumbLabel, '主页');
  });

  test('navigateBack unwinds queue page to song book then home', () async {
    final KtvController controller = KtvController(
      mediaLibraryRepository: FakeMediaLibraryRepository(),
      playerController: FakePlayerController(),
    );

    controller.enterSongBook();
    controller.enterQueueList();

    expect(controller.route, KtvRoute.queueList);
    expect(controller.breadcrumbLabel, '主页 / 歌名 / 已点');

    expect(await controller.navigateBack(), isTrue);
    expect(controller.route, KtvRoute.songBook);
    expect(controller.breadcrumbLabel, '主页 / 歌名');

    expect(await controller.navigateBack(), isTrue);
    expect(controller.route, KtvRoute.home);
    expect(controller.breadcrumbLabel, '主页');
  });

  test('aggregated song book can load without local directory', () async {
    final Song remoteSong = Song(
      songId: buildAggregateSongId(title: '远程歌曲', artist: '云端歌手'),
      sourceId: '115',
      sourceSongId: '115-song-1',
      title: '远程歌曲',
      artist: '云端歌手',
      languages: const <String>['国语'],
      searchIndex: '远程歌曲 云端歌手',
      mediaPath: '115://remote-song',
    );
    final KtvController controller = KtvController(
      mediaLibraryRepository: FakeMediaLibraryRepository(),
      aggregatedLibraryRepository: FakeAggregatedLibraryRepository(
        songs: <Song>[remoteSong],
      ),
      playerController: FakePlayerController(),
    );

    controller.enterSongBook(mode: SongBookMode.songs);
    await _settleLibraryQuery();

    expect(controller.scanDirectoryPath, isNull);
    expect(controller.songBookMode, SongBookMode.songs);
    expect(controller.libraryScope, LibraryScope.aggregated);
    expect(controller.librarySongs, <Song>[remoteSong]);
    expect(controller.libraryTotalCount, 1);
    expect(controller.currentSubtitle, contains('聚合曲库'));
  });

  test(
    'requestSong keeps current playback and appends new songs to queue',
    () async {
      final FakePlayerController playerController = FakePlayerController();
      final KtvController controller = KtvController(
        mediaLibraryRepository: FakeMediaLibraryRepository(),
        playerController: playerController,
      );
      final Song first = _song(title: '第一首', artist: '歌手甲');
      final Song second = _song(title: '第二首', artist: '歌手乙');

      await controller.requestSong(first);
      await controller.requestSong(second);
      await controller.requestSong(first);

      expect(playerController.lastOpenedSource?.displayName, '第一首');
      expect(controller.queuedSongs.first, first);
      expect(controller.queuedSongs, <Song>[first, second]);
      expect(controller.currentTitle, '第一首');
    },
  );

  test(
    'prioritizeQueuedSong moves later queued item behind current song',
    () async {
      final KtvController controller = KtvController(
        mediaLibraryRepository: FakeMediaLibraryRepository(),
        playerController: FakePlayerController(),
      );
      final Song current = _song(title: '当前播放', artist: '歌手甲');
      final Song next = _song(title: '下一首', artist: '歌手乙');
      final Song later = _song(title: '后面那首', artist: '歌手丙');

      await controller.requestSong(current);
      await controller.requestSong(next);
      await controller.requestSong(later);

      controller.prioritizeQueuedSong(later);

      expect(controller.queuedSongs, <Song>[current, later, next]);
    },
  );

  test('removeQueuedSong only removes non-current queued items', () async {
    final KtvController controller = KtvController(
      mediaLibraryRepository: FakeMediaLibraryRepository(),
      playerController: FakePlayerController(),
    );
    final Song current = _song(title: '当前播放', artist: '歌手甲');
    final Song next = _song(title: '下一首', artist: '歌手乙');

    await controller.requestSong(current);
    await controller.requestSong(next);

    controller.removeQueuedSong(current);
    controller.removeQueuedSong(next);

    expect(controller.queuedSongs, <Song>[current]);
  });

  test('stopPlayback pauses current media and rewinds to start', () async {
    final FakePlayerController playerController = FakePlayerController();
    final KtvController controller = KtvController(
      mediaLibraryRepository: FakeMediaLibraryRepository(),
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
    final KtvController controller = KtvController(
      mediaLibraryRepository: FakeMediaLibraryRepository(),
      playerController: playerController,
    );
    final Song current = _song(title: '第一首', artist: '歌手甲');
    final Song next = _song(title: '第二首', artist: '歌手乙');

    await controller.requestSong(current);
    await controller.requestSong(next);
    controller.toggleAudioMode();

    expect(playerController.audioOutputMode, AudioOutputMode.accompaniment);

    await controller.skipCurrentSong();

    expect(playerController.lastOpenedSource?.displayName, '第二首');
    expect(playerController.audioOutputMode, AudioOutputMode.accompaniment);
  });

  test(
    'initialize loads downloaded song records for download manager',
    () async {
      final _FakeCloudSongDownloadService downloadService =
          _FakeCloudSongDownloadService(
            sourceId: 'baidu_pan',
            downloadedSongs: <CloudDownloadedSongRecord>[
              const CloudDownloadedSongRecord(
                sourceId: 'baidu_pan',
                sourceSongId: 'fsid-1',
                title: '夜曲',
                artist: '周杰伦',
                savedPath: '/tmp/night.mp4',
                savedAtMillis: 100,
              ),
            ],
          );
      final KtvController controller = KtvController(
        mediaLibraryRepository: FakeMediaLibraryRepository(),
        playerController: FakePlayerController(),
        songDownloadServices: <String, CloudSongDownloadService>{
          'baidu_pan': downloadService,
        },
      );

      await controller.initialize();

      expect(controller.downloadedSongs, hasLength(1));
      expect(controller.downloadedSongs.single.title, '夜曲');
      expect(controller.downloadedSongs.single.sourceLabel, '百度网盘');
      expect(controller.downloadedSongKeys, contains('baidu_pan::fsid-1'));
    },
  );

  test(
    'downloadSongToLocal updates downloading and downloaded lists',
    () async {
      final Song remoteSong = Song(
        songId: buildAggregateSongId(title: '夜曲', artist: '周杰伦'),
        sourceId: 'baidu_pan',
        sourceSongId: 'fsid-2',
        title: '夜曲',
        artist: '周杰伦',
        languages: const <String>['国语'],
        searchIndex: '夜曲 周杰伦',
        mediaPath: '',
      );
      final _FakeCloudSongDownloadService downloadService =
          _FakeCloudSongDownloadService(
            sourceId: 'baidu_pan',
            onDownloadSong:
                ({
                  required Song song,
                  String? preferredDirectory,
                  void Function(CloudDownloadProgress progress)? onProgress,
                  CloudDownloadCancellationToken? cancellationToken,
                }) async {
                  onProgress?.call(
                    const CloudDownloadProgress(
                      phaseLabel: '缓存云端文件',
                      value: 0.4,
                    ),
                  );
                  await Future<void>.delayed(const Duration(milliseconds: 10));
                  return const CloudSongDownloadResult(
                    savedPath: '/tmp/downloaded/night.mp4',
                    usedPreferredDirectory: false,
                  );
                },
          );
      final KtvController controller = KtvController(
        mediaLibraryRepository: FakeMediaLibraryRepository(),
        playerController: FakePlayerController(),
        songDownloadServices: <String, CloudSongDownloadService>{
          'baidu_pan': downloadService,
        },
      );

      final Future<CloudSongDownloadResult> future = controller
          .downloadSongToLocal(remoteSong);
      await Future<void>.delayed(const Duration(milliseconds: 1));

      expect(controller.downloadingSongs, hasLength(1));
      expect(controller.downloadingSongs.single.title, '夜曲');
      expect(controller.downloadingSongs.single.sourceLabel, '百度网盘');
      expect(controller.downloadingSongs.single.progress, 0.4);

      await future;

      expect(controller.downloadingSongs, isEmpty);
      expect(controller.downloadedSongs, hasLength(1));
      expect(
        controller.downloadedSongs.single.savedPath,
        '/tmp/downloaded/night.mp4',
      );
    },
  );

  test(
    'cancelDownload cancels active task and clears downloading item',
    () async {
      final Song remoteSong = Song(
        songId: buildAggregateSongId(title: '稻香', artist: '周杰伦'),
        sourceId: 'baidu_pan',
        sourceSongId: 'fsid-3',
        title: '稻香',
        artist: '周杰伦',
        languages: const <String>['国语'],
        searchIndex: '稻香 周杰伦',
        mediaPath: '',
      );
      final Completer<void> gate = Completer<void>();
      final _FakeCloudSongDownloadService downloadService =
          _FakeCloudSongDownloadService(
            sourceId: 'baidu_pan',
            onDownloadSong:
                ({
                  required Song song,
                  String? preferredDirectory,
                  void Function(CloudDownloadProgress progress)? onProgress,
                  CloudDownloadCancellationToken? cancellationToken,
                }) async {
                  onProgress?.call(
                    const CloudDownloadProgress(
                      phaseLabel: '缓存云端文件',
                      value: 0.2,
                    ),
                  );
                  await gate.future;
                  cancellationToken?.throwIfCancelled();
                  return const CloudSongDownloadResult(
                    savedPath: '/tmp/should-not-exist.mp4',
                    usedPreferredDirectory: false,
                  );
                },
          );
      final KtvController controller = KtvController(
        mediaLibraryRepository: FakeMediaLibraryRepository(),
        playerController: FakePlayerController(),
        songDownloadServices: <String, CloudSongDownloadService>{
          'baidu_pan': downloadService,
        },
      );

      final Future<CloudSongDownloadResult> future = controller
          .downloadSongToLocal(remoteSong);
      await Future<void>.delayed(const Duration(milliseconds: 1));

      controller.cancelDownload(
        sourceId: remoteSong.sourceId,
        sourceSongId: remoteSong.sourceSongId,
      );
      gate.complete();

      await expectLater(
        future,
        throwsA(isA<CloudDownloadCancelledException>()),
      );
      expect(controller.downloadingSongs, isEmpty);
      expect(controller.downloadedSongs, isEmpty);
    },
  );

  test('deleteDownloadedSong deletes source file entry from manager', () async {
    final _FakeCloudSongDownloadService downloadService =
        _FakeCloudSongDownloadService(
          sourceId: 'baidu_pan',
          downloadedSongs: <CloudDownloadedSongRecord>[
            const CloudDownloadedSongRecord(
              sourceId: 'baidu_pan',
              sourceSongId: 'fsid-4',
              title: '青花瓷',
              artist: '周杰伦',
              savedPath: '/tmp/qinghuaci.mp4',
              savedAtMillis: 200,
            ),
          ],
        );
    final KtvController controller = KtvController(
      mediaLibraryRepository: FakeMediaLibraryRepository(),
      playerController: FakePlayerController(),
      songDownloadServices: <String, CloudSongDownloadService>{
        'baidu_pan': downloadService,
      },
    );
    await controller.initialize();

    await controller.deleteDownloadedSong(
      sourceId: 'baidu_pan',
      sourceSongId: 'fsid-4',
    );

    expect(downloadService.deletedSourceSongIds, <String>['fsid-4']);
    expect(controller.downloadedSongs, isEmpty);
    expect(controller.downloadedSongKeys, isEmpty);
  });
}

Song _song({
  required String title,
  required String artist,
  String language = '其它',
  String? mediaPath,
}) {
  return Song(
    songId: buildAggregateSongId(title: title, artist: artist),
    sourceId: 'local',
    sourceSongId: buildLocalSourceSongId(
      fingerprint: buildLocalMetadataFingerprint(
        locator: mediaPath ?? '/tmp/$title.mp4',
      ),
    ),
    title: title,
    artist: artist,
    languages: <String>[language],
    searchIndex: '$title $artist'.toLowerCase(),
    mediaPath: mediaPath ?? '/tmp/$title.mp4',
  );
}

class FakeMediaLibraryRepository extends MediaLibraryRepository {
  FakeMediaLibraryRepository({
    this.savedDirectory,
    Set<String>? accessibleDirectories,
    Map<String, List<Song>>? indexedResults,
    Map<String, List<Song>>? scanResults,
  }) : _accessibleDirectories = accessibleDirectories ?? <String>{},
       _indexedResults = indexedResults ?? <String, List<Song>>{},
       _scanResults = scanResults ?? <String, List<Song>>{};

  final String? savedDirectory;
  final Set<String> _accessibleDirectories;
  final Map<String, List<Song>> _indexedResults;
  final Map<String, List<Song>> _scanResults;
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
    final List<Song>? result = _scanResults[directory];
    if (result == null) {
      throw StateError('missing scan result for $directory');
    }
    _indexedResults[directory] = List<Song>.of(result);
    return result.length;
  }

  @override
  Future<SongPage> querySongs({
    required String directory,
    required int pageIndex,
    required int pageSize,
    String? language,
    String? artist,
    String searchQuery = '',
  }) async {
    final List<Song>? result =
        _indexedResults[directory] ?? _scanResults[directory];
    if (result == null) {
      throw StateError('missing scan result for $directory');
    }
    final String normalizedQuery = searchQuery.trim().toLowerCase();
    final String normalizedLanguage = (language ?? '').trim();
    final String normalizedArtist = (artist ?? '').trim();
    final List<Song> filteredSongs = result
        .where((Song song) {
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
    return SongPage(
      songs: start >= filteredSongs.length
          ? const <Song>[]
          : filteredSongs.sublist(start, end),
      totalCount: filteredSongs.length,
      pageIndex: pageIndex,
      pageSize: pageSize,
    );
  }

  @override
  Future<ArtistPage> queryArtists({
    required String directory,
    required int pageIndex,
    required int pageSize,
    String? language,
    String searchQuery = '',
  }) async {
    final List<Song>? result =
        _indexedResults[directory] ?? _scanResults[directory];
    if (result == null) {
      throw StateError('missing scan result for $directory');
    }
    final String normalizedQuery = searchQuery.trim().toLowerCase();
    final String normalizedLanguage = (language ?? '').trim();
    final Map<String, int> songCountByArtist = <String, int>{};
    for (final Song song in result) {
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
    final List<Artist> filteredArtists = songCountByArtist.entries
        .map(
          (MapEntry<String, int> entry) => Artist(
            name: entry.key,
            songCount: entry.value,
            searchIndex: entry.key.toLowerCase(),
          ),
        )
        .where((Artist artist) {
          if (normalizedQuery.isEmpty) {
            return true;
          }
          return artist.searchIndex.contains(normalizedQuery);
        })
        .toList(growable: false);
    final int start = pageIndex * pageSize;
    final int end = (start + pageSize).clamp(0, filteredArtists.length);
    return ArtistPage(
      artists: start >= filteredArtists.length
          ? const <Artist>[]
          : filteredArtists.sublist(start, end),
      totalCount: filteredArtists.length,
      pageIndex: pageIndex,
      pageSize: pageSize,
    );
  }

  @override
  Future<List<Song>> loadAllSongs({required String directory}) async {
    return List<Song>.of(
      _indexedResults[directory] ?? _scanResults[directory] ?? const <Song>[],
    );
  }

  @override
  Future<List<Song>> getSongsByIds({
    required String directory,
    required List<String> songIds,
  }) async {
    final Map<String, Song> songsById = <String, Song>{
      for (final Song song in await loadAllSongs(directory: directory))
        song.songId: song,
    };
    return songIds
        .map((String songId) => songsById[songId])
        .whereType<Song>()
        .toList(growable: false);
  }

  @override
  Future<Song?> getSongById({
    required String directory,
    required String songId,
  }) async {
    final List<Song> songs = await getSongsByIds(
      directory: directory,
      songIds: <String>[songId],
    );
    if (songs.isEmpty) {
      return null;
    }
    return songs.first;
  }

  @override
  Future<List<Song>> loadAggregatedSongs({String? localDirectory}) async {
    if (localDirectory == null) {
      return const <Song>[];
    }
    return loadAllSongs(directory: localDirectory);
  }

  @override
  Future<SongPage> queryAggregatedSongs({
    required int pageIndex,
    required int pageSize,
    String? localDirectory,
    String? language,
    String? artist,
    String searchQuery = '',
  }) async {
    if (localDirectory == null) {
      return SongPage(
        songs: const <Song>[],
        totalCount: 0,
        pageIndex: pageIndex,
        pageSize: pageSize,
      );
    }
    return querySongs(
      directory: localDirectory,
      pageIndex: pageIndex,
      pageSize: pageSize,
      language: language,
      artist: artist,
      searchQuery: searchQuery,
    );
  }

  @override
  Future<ArtistPage> queryAggregatedArtists({
    required int pageIndex,
    required int pageSize,
    String? localDirectory,
    String? language,
    String searchQuery = '',
  }) async {
    if (localDirectory == null) {
      return ArtistPage(
        artists: const <Artist>[],
        totalCount: 0,
        pageIndex: pageIndex,
        pageSize: pageSize,
      );
    }
    return queryArtists(
      directory: localDirectory,
      pageIndex: pageIndex,
      pageSize: pageSize,
      language: language,
      searchQuery: searchQuery,
    );
  }

  @override
  Future<List<Song>> getAggregatedSongsByIds({
    required List<String> songIds,
    String? localDirectory,
  }) async {
    if (localDirectory == null) {
      return const <Song>[];
    }
    return getSongsByIds(directory: localDirectory, songIds: songIds);
  }

  @override
  Future<Song?> getAggregatedSongById({
    required String songId,
    String? localDirectory,
  }) async {
    if (localDirectory == null) {
      return null;
    }
    return getSongById(directory: localDirectory, songId: songId);
  }
}

class _FakeCloudSongDownloadService extends CloudSongDownloadService {
  _FakeCloudSongDownloadService({
    required super.sourceId,
    this.downloadedSongs = const <CloudDownloadedSongRecord>[],
    this.onDownloadSong,
  }) : super(
         playbackCache: const _FakeCloudPlaybackCache(),
         fallbackDirectoryProvider: _fallbackDirectoryProvider,
         downloadIndexFileProvider: _downloadIndexFileProvider,
       );

  final List<CloudDownloadedSongRecord> downloadedSongs;
  final List<String> deletedSourceSongIds = <String>[];
  final Future<CloudSongDownloadResult> Function({
    required Song song,
    String? preferredDirectory,
    void Function(CloudDownloadProgress progress)? onProgress,
    CloudDownloadCancellationToken? cancellationToken,
  })?
  onDownloadSong;

  static Future<Directory> _fallbackDirectoryProvider() async {
    return Directory.systemTemp;
  }

  static Future<File> _downloadIndexFileProvider() async {
    return File(
      '${Directory.systemTemp.path}/ktv-controller-test-downloads.json',
    );
  }

  @override
  Future<List<CloudDownloadedSongRecord>> loadDownloadedSongs() async {
    return downloadedSongs;
  }

  @override
  Future<CloudSongDownloadResult> downloadSong({
    required Song song,
    String? preferredDirectory,
    void Function(CloudDownloadProgress progress)? onProgress,
    CloudDownloadCancellationToken? cancellationToken,
  }) async {
    final Future<CloudSongDownloadResult> Function({
      required Song song,
      String? preferredDirectory,
      void Function(CloudDownloadProgress progress)? onProgress,
      CloudDownloadCancellationToken? cancellationToken,
    })?
    handler = onDownloadSong;
    if (handler == null) {
      throw UnimplementedError('downloadSong handler is not configured');
    }
    return handler(
      song: song,
      preferredDirectory: preferredDirectory,
      onProgress: onProgress,
      cancellationToken: cancellationToken,
    );
  }

  @override
  Future<void> deleteDownloadedSong({required String sourceSongId}) async {
    deletedSourceSongIds.add(sourceSongId);
  }
}

class _FakeCloudPlaybackCache implements CloudPlaybackCache {
  const _FakeCloudPlaybackCache();

  @override
  Future<void> clearExpiredCache() async {}

  @override
  Future<CloudCachedMedia> resolve({
    required Song song,
    required String sourceSongId,
    void Function(double progress)? onProgress,
    CloudDownloadCancellationToken? cancellationToken,
  }) {
    throw UnimplementedError();
  }
}

class FakeAggregatedLibraryRepository implements AggregatedLibraryRepository {
  FakeAggregatedLibraryRepository({required this.songs});

  final List<Song> songs;

  @override
  Future<void> refreshSources({String? localDirectory}) async {}

  @override
  Future<SongPage> querySongs({
    required LibraryScope scope,
    required int pageIndex,
    required int pageSize,
    String? localDirectory,
    String? language,
    String? artist,
    String searchQuery = '',
  }) async {
    final int start = pageIndex * pageSize;
    final int end = (start + pageSize).clamp(0, songs.length);
    return SongPage(
      songs: start >= songs.length ? const <Song>[] : songs.sublist(start, end),
      totalCount: songs.length,
      pageIndex: pageIndex,
      pageSize: pageSize,
    );
  }

  @override
  Future<ArtistPage> queryArtists({
    required LibraryScope scope,
    required int pageIndex,
    required int pageSize,
    String? localDirectory,
    String? language,
    String searchQuery = '',
  }) async {
    final Map<String, int> songCountByArtist = <String, int>{};
    for (final Song song in songs) {
      songCountByArtist.update(
        song.artist,
        (int count) => count + 1,
        ifAbsent: () => 1,
      );
    }
    final List<Artist> artists = songCountByArtist.entries
        .map(
          (MapEntry<String, int> entry) => Artist(
            name: entry.key,
            songCount: entry.value,
            searchIndex: entry.key.toLowerCase(),
          ),
        )
        .toList(growable: false);
    final int start = pageIndex * pageSize;
    final int end = (start + pageSize).clamp(0, artists.length);
    return ArtistPage(
      artists: start >= artists.length
          ? const <Artist>[]
          : artists.sublist(start, end),
      totalCount: artists.length,
      pageIndex: pageIndex,
      pageSize: pageSize,
    );
  }

  @override
  Future<List<Song>> getSongsByIds({
    required List<String> songIds,
    String? localDirectory,
  }) async {
    final Map<String, Song> songsById = <String, Song>{
      for (final Song song in songs) song.songId: song,
    };
    return songIds
        .map((String songId) => songsById[songId])
        .whereType<Song>()
        .toList(growable: false);
  }

  @override
  Future<Song?> getSongById({
    required String songId,
    String? localDirectory,
  }) async {
    final List<Song> results = await getSongsByIds(
      songIds: <String>[songId],
      localDirectory: localDirectory,
    );
    if (results.isEmpty) {
      return null;
    }
    return results.first;
  }

  @override
  Future<String?> resolvePlayableMediaPath({
    required String songId,
    String? localDirectory,
  }) async {
    return (await getSongById(
      songId: songId,
      localDirectory: localDirectory,
    ))?.mediaPath;
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
