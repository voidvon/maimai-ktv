import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ktv2_example/core/models/artist.dart';
import 'package:ktv2_example/core/models/artist_page.dart';
import 'package:ktv2_example/core/models/song.dart';
import 'package:ktv2_example/core/models/song_identity.dart';
import 'package:ktv2_example/core/models/song_page.dart';
import 'package:ktv2_example/features/media_library/data/android_storage_data_source.dart';
import 'package:ktv2_example/features/media_library/data/media_index_store.dart';
import 'package:ktv2_example/features/media_library/data/media_library_repository.dart';
import 'package:ktv2_example/features/media_library/data/media_library_data_source.dart';

void main() {
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  test('scanLibrary uses local data source for file paths', () async {
    final FakeMediaLibraryDataSource localDataSource =
        FakeMediaLibraryDataSource(
          songsByDirectory: <String, List<LibrarySong>>{
            '/media': <LibrarySong>[
              const LibrarySong(
                title: '青花瓷',
                artist: '周杰伦',
                mediaPath: '/media/青花瓷.mp4',
                fileName: '周杰伦 - 青花瓷.mp4',
                relativePath: '青花瓷.mp4',
                fileSize: 1024,
                modifiedAtMillis: 1710000000000,
                sourceFingerprint: 'content:1024:aaaa',
                extension: 'mp4',
              ),
            ],
          },
        );
    final FakeAndroidStorageDataSource androidStorageDataSource =
        FakeAndroidStorageDataSource();
    final MediaLibraryRepository repository = MediaLibraryRepository(
      mediaLibraryDataSource: localDataSource,
      androidStorageDataSource: androidStorageDataSource,
    );

    final int count = await repository.scanLibrary('/media');

    expect(count, 1);
    expect(localDataSource.scannedDirectories, <String>['/media']);
    expect(androidStorageDataSource.scanIntoIndexCalls, isEmpty);
  });

  test('content uri uses indexed android source on Android', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final FakeMediaLibraryDataSource localDataSource =
        FakeMediaLibraryDataSource(
          songsByDirectory: <String, List<LibrarySong>>{},
        );
    final FakeAndroidStorageDataSource androidStorageDataSource =
        FakeAndroidStorageDataSource(
          scanCounts: <String, int>{'content://library/tree': 3},
          songPages: <String, SongPage>{
            'content://library/tree': SongPage(
              songs: <Song>[song(title: '海阔天空', artist: 'Beyond')],
              totalCount: 1,
              pageIndex: 0,
              pageSize: 8,
            ),
          },
          artistPages: <String, ArtistPage>{
            'content://library/tree': const ArtistPage(
              artists: <Artist>[],
              totalCount: 0,
              pageIndex: 0,
              pageSize: 8,
            ),
          },
        );
    final MediaLibraryRepository repository = MediaLibraryRepository(
      mediaLibraryDataSource: localDataSource,
      androidStorageDataSource: androidStorageDataSource,
    );

    final int count = await repository.scanLibrary('content://library/tree');
    final SongPage songPage = await repository.querySongs(
      directory: 'content://library/tree',
      pageIndex: 0,
      pageSize: 8,
    );

    expect(count, 3);
    expect(localDataSource.scannedDirectories, isEmpty);
    expect(androidStorageDataSource.scanIntoIndexCalls, <String>[
      'content://library/tree',
    ]);
    expect(songPage.songs.single.title, '海阔天空');
    expect(androidStorageDataSource.querySongCalls, <String>[
      'content://library/tree',
    ]);
  });

  test('getSongsByIds resolves exact songs beyond 10000 entries', () async {
    final List<LibrarySong> librarySongs = List<LibrarySong>.generate(
      10050,
      (int index) => LibrarySong(
        title: '歌曲$index',
        artist: '歌手',
        mediaPath: '/media/$index.mp4',
        fileName: '歌手 - 歌曲$index.mp4',
        relativePath: '$index.mp4',
        fileSize: 2048 + index,
        modifiedAtMillis: 1710000000000 + index,
        sourceFingerprint: 'content:${2048 + index}:$index',
        extension: 'mp4',
      ),
      growable: false,
    );
    final FakeMediaLibraryDataSource localDataSource =
        FakeMediaLibraryDataSource(
          songsByDirectory: <String, List<LibrarySong>>{'/media': librarySongs},
        );
    final MediaLibraryRepository repository = MediaLibraryRepository(
      mediaLibraryDataSource: localDataSource,
      androidStorageDataSource: FakeAndroidStorageDataSource(),
    );
    await repository.scanLibrary('/media');

    final List<Song> songs = await repository.getSongsByIds(
      directory: '/media',
      songIds: <String>[buildAggregateSongId(title: '歌曲10049', artist: '歌手')],
    );

    expect(songs, hasLength(1));
    expect(songs.single.title, '歌曲10049');
  });

  test(
    'local songs keep aggregate id and file-derived source song id',
    () async {
      final FakeMediaLibraryDataSource localDataSource =
          FakeMediaLibraryDataSource(
            songsByDirectory: <String, List<LibrarySong>>{
              '/media': <LibrarySong>[
                const LibrarySong(
                  title: '同一首歌',
                  artist: '同一歌手',
                  mediaPath: '/media/a.mp4',
                  fileName: '同一歌手 - 同一首歌.mp4',
                  relativePath: 'a.mp4',
                  fileSize: 100,
                  modifiedAtMillis: 1710000000001,
                  sourceFingerprint: 'content:100:aaaa',
                  extension: 'mp4',
                ),
                const LibrarySong(
                  title: '同一首歌',
                  artist: '同一歌手',
                  mediaPath: '/media/b.mp4',
                  fileName: '同一歌手 - 同一首歌.mp4',
                  relativePath: 'b.mp4',
                  fileSize: 100,
                  modifiedAtMillis: 1710000000002,
                  sourceFingerprint: 'content:100:bbbb',
                  extension: 'mp4',
                ),
              ],
            },
          );
      final MediaLibraryRepository repository = MediaLibraryRepository(
        mediaLibraryDataSource: localDataSource,
        androidStorageDataSource: FakeAndroidStorageDataSource(),
      );

      await repository.scanLibrary('/media');
      final List<Song> songs = await repository.loadAllSongs(
        directory: '/media',
      );

      expect(songs, hasLength(2));
      expect(songs.first.songId, songs.last.songId);
      expect(songs.first.sourceSongId, isNot(songs.last.sourceSongId));
    },
  );

  test('local source song id stays stable after rename', () async {
    final Directory root = await Directory.systemTemp.createTemp(
      'ktv_song_id_',
    );
    addTearDown(() async {
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    });

    final File originalFile = File('${root.path}/歌手 - 同一首歌.mp4');
    final List<int> bytes = List<int>.generate(
      200000,
      (int index) => index % 251,
      growable: false,
    );
    await originalFile.writeAsBytes(bytes, flush: true);

    final MediaLibraryDataSource dataSource = MediaLibraryDataSource();
    final List<LibrarySong> firstScan = await dataSource.scanLibrary(root.path);
    expect(firstScan, hasLength(1));

    await originalFile.rename('${root.path}/已改名.mp4');
    final List<LibrarySong> secondScan = await dataSource.scanLibrary(
      root.path,
    );
    expect(secondScan, hasLength(1));
    expect(firstScan.single.sourceSongId, secondScan.single.sourceSongId);
  });

  test('aggregated song queries filter and paginate in sqlite', () async {
    final MediaLibraryRepository repository = MediaLibraryRepository(
      mediaLibraryDataSource: FakeMediaLibraryDataSource(
        songsByDirectory: <String, List<LibrarySong>>{
          '/media': <LibrarySong>[
            const TestLibrarySong(
              title: '珊瑚海',
              artist: '周杰伦 & Lara',
              mediaPath: '/media/1.mp4',
              fileName: '周杰伦 & Lara - 珊瑚海.mp4',
              relativePath: '1.mp4',
              fileSize: 1001,
              modifiedAtMillis: 1710000000001,
              sourceFingerprint: 'content:1001:a',
              languages: <String>['国语'],
              searchIndex: 'shanhuhai zhoujielun lara',
              extension: 'mp4',
            ),
            const TestLibrarySong(
              title: '夜曲',
              artist: '周杰伦',
              mediaPath: '/media/2.mp4',
              fileName: '周杰伦 - 夜曲.mp4',
              relativePath: '2.mp4',
              fileSize: 1002,
              modifiedAtMillis: 1710000000002,
              sourceFingerprint: 'content:1002:b',
              languages: <String>['国语'],
              searchIndex: 'yequ zhoujielun',
              extension: 'mp4',
            ),
            const TestLibrarySong(
              title: '海阔天空',
              artist: 'Beyond',
              mediaPath: '/media/3.mp4',
              fileName: 'Beyond - 海阔天空.mp4',
              relativePath: '3.mp4',
              fileSize: 1003,
              modifiedAtMillis: 1710000000003,
              sourceFingerprint: 'content:1003:c',
              languages: <String>['粤语'],
              searchIndex: 'haikuotiankong beyond',
              extension: 'mp4',
            ),
          ],
        },
      ),
      androidStorageDataSource: FakeAndroidStorageDataSource(),
    );
    addTearDown(repository.mediaIndexStore.close);

    await repository.scanLibrary('/media');

    final SongPage page = await repository.queryAggregatedSongs(
      pageIndex: 0,
      pageSize: 1,
      localDirectory: '/media',
      language: '国语',
      artist: '周杰伦',
    );
    final SongPage secondPage = await repository.queryAggregatedSongs(
      pageIndex: 1,
      pageSize: 1,
      localDirectory: '/media',
      language: '国语',
      artist: '周杰伦',
    );

    expect(page.totalCount, 2);
    expect(page.songs.single.title, '夜曲');
    expect(secondPage.songs.single.title, '珊瑚海');
  });

  test(
    'aggregated artist queries split artist names and getSongsByIds keeps requested order',
    () async {
      final MediaLibraryRepository repository = MediaLibraryRepository(
        mediaLibraryDataSource: FakeMediaLibraryDataSource(
          songsByDirectory: <String, List<LibrarySong>>{
            '/media': <LibrarySong>[
              const TestLibrarySong(
                title: '珊瑚海',
                artist: '周杰伦 & Lara',
                mediaPath: '/media/1.mp4',
                fileName: '周杰伦 & Lara - 珊瑚海.mp4',
                relativePath: '1.mp4',
                fileSize: 1001,
                modifiedAtMillis: 1710000000001,
                sourceFingerprint: 'content:1001:a',
                languages: <String>['国语'],
                searchIndex: 'shanhuhai zhoujielun lara',
                extension: 'mp4',
              ),
              const TestLibrarySong(
                title: '简单爱',
                artist: '周杰伦',
                mediaPath: '/media/2.mp4',
                fileName: '周杰伦 - 简单爱.mp4',
                relativePath: '2.mp4',
                fileSize: 1002,
                modifiedAtMillis: 1710000000002,
                sourceFingerprint: 'content:1002:b',
                languages: <String>['国语'],
                searchIndex: 'jiandanai zhoujielun',
                extension: 'mp4',
              ),
            ],
          },
        ),
        androidStorageDataSource: FakeAndroidStorageDataSource(),
      );
      addTearDown(repository.mediaIndexStore.close);

      await repository.scanLibrary('/media');

      final ArtistPage artistPage = await repository.queryAggregatedArtists(
        pageIndex: 0,
        pageSize: 10,
        localDirectory: '/media',
        searchQuery: 'lara',
      );
      final List<Song> songs = await repository.getAggregatedSongsByIds(
        localDirectory: '/media',
        songIds: <String>[
          buildAggregateSongId(title: '简单爱', artist: '周杰伦'),
          buildAggregateSongId(title: '珊瑚海', artist: '周杰伦 & Lara'),
        ],
      );

      expect(artistPage.totalCount, 1);
      expect(artistPage.artists.single.name, 'Lara');
      expect(artistPage.artists.single.songCount, 1);
      expect(songs.map((Song song) => song.title).toList(), <String>[
        '简单爱',
        '珊瑚海',
      ]);
    },
  );
}

Song song({required String title, required String artist}) {
  return Song(
    songId: buildAggregateSongId(title: title, artist: artist),
    sourceId: 'local',
    sourceSongId: buildLocalSourceSongId(
      fingerprint: buildLocalMetadataFingerprint(locator: '/tmp/$title.mp4'),
    ),
    title: title,
    artist: artist,
    languages: const <String>['其它'],
    searchIndex: '$title $artist'.toLowerCase(),
    mediaPath: '/tmp/$title.mp4',
  );
}

class FakeMediaLibraryDataSource extends MediaLibraryDataSource {
  FakeMediaLibraryDataSource({required this.songsByDirectory});

  final Map<String, List<LibrarySong>> songsByDirectory;
  final List<String> scannedDirectories = <String>[];

  @override
  Future<List<LibrarySong>> scanLibrary(
    String rootPath, {
    Map<String, CachedLocalSongFingerprint> cachedFingerprintsByPath =
        const <String, CachedLocalSongFingerprint>{},
  }) async {
    scannedDirectories.add(rootPath);
    return songsByDirectory[rootPath] ?? const <LibrarySong>[];
  }
}

class TestLibrarySong extends LibrarySong {
  const TestLibrarySong({
    required super.title,
    required super.artist,
    required super.mediaPath,
    required super.fileName,
    required super.relativePath,
    required super.fileSize,
    required super.modifiedAtMillis,
    required super.sourceFingerprint,
    required super.extension,
    this.languages = const <String>['其它'],
    this.tags = const <String>[],
    required this.searchIndex,
  });

  @override
  final List<String> languages;

  @override
  final List<String> tags;

  @override
  final String searchIndex;
}

class FakeAndroidStorageDataSource extends AndroidStorageDataSource {
  FakeAndroidStorageDataSource({
    Map<String, int>? scanCounts,
    Map<String, SongPage>? songPages,
    Map<String, ArtistPage>? artistPages,
  }) : _scanCounts = scanCounts ?? <String, int>{},
       _songPages = songPages ?? <String, SongPage>{},
       _artistPages = artistPages ?? <String, ArtistPage>{};

  final Map<String, int> _scanCounts;
  final Map<String, SongPage> _songPages;
  final Map<String, ArtistPage> _artistPages;
  final List<String> scanIntoIndexCalls = <String>[];
  final List<String> querySongCalls = <String>[];

  @override
  Future<int> scanLibraryIntoIndex(String rootUri) async {
    scanIntoIndexCalls.add(rootUri);
    return _scanCounts[rootUri] ?? 0;
  }

  @override
  Future<SongPage> queryIndexedSongs({
    required String rootUri,
    required int pageIndex,
    required int pageSize,
    String language = '',
    String artist = '',
    String searchQuery = '',
  }) async {
    querySongCalls.add(rootUri);
    return _songPages[rootUri] ??
        SongPage(
          songs: const <Song>[],
          totalCount: 0,
          pageIndex: pageIndex,
          pageSize: pageSize,
        );
  }

  @override
  Future<ArtistPage> queryIndexedArtists({
    required String rootUri,
    required int pageIndex,
    required int pageSize,
    String language = '',
    String searchQuery = '',
  }) async {
    return _artistPages[rootUri] ??
        ArtistPage(
          artists: const <Artist>[],
          totalCount: 0,
          pageIndex: pageIndex,
          pageSize: pageSize,
        );
  }
}
