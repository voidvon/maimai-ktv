import 'dart:collection';

import 'package:flutter_test/flutter_test.dart';
import 'package:maimai_ktv/core/models/song.dart';
import 'package:maimai_ktv/core/models/song_page.dart';
import 'package:maimai_ktv/features/media_library/data/media_index_store.dart';
import 'package:maimai_ktv/features/media_library/data/media_library_data_source.dart';
import 'package:maimai_ktv/features/media_library/data/media_library_repository.dart';

class _FakeMediaLibraryDataSource extends MediaLibraryDataSource {
  _FakeMediaLibraryDataSource(this.songs);

  final List<LibrarySong> songs;
  int scanCallCount = 0;

  @override
  Future<List<LibrarySong>> scanLibrary(
    String rootPath, {
    Map<String, CachedLocalSongFingerprint> cachedFingerprintsByPath =
        const <String, CachedLocalSongFingerprint>{},
  }) async {
    scanCallCount += 1;
    return songs;
  }
}

class _FakeMediaIndexStore extends MediaIndexStore {
  final Map<String, List<Song>> localSongsByRoot = <String, List<Song>>{};
  bool hasConfiguredAggregateSourcesValue = false;

  @override
  Future<Map<String, CachedLocalSongFingerprint>> loadLocalFingerprintCache({
    required String sourceRootId,
  }) async {
    return const <String, CachedLocalSongFingerprint>{};
  }

  @override
  Future<int> replaceLocalSongs({
    required String sourceRootId,
    required List<LibrarySong> songs,
  }) async {
    localSongsByRoot[sourceRootId] = songs
        .map(
          (LibrarySong song) => Song(
            songId: 'local:${song.title}:${song.artist}',
            sourceId: 'local',
            sourceSongId: song.sourceSongId,
            title: song.title,
            artist: song.artist,
            languages: song.languages,
            tags: song.tags,
            searchIndex: song.searchIndex,
            mediaPath: song.mediaPath,
          ),
        )
        .toList(growable: false);
    return songs.length;
  }

  @override
  Future<List<Song>> loadLocalSongs({required String sourceRootId}) async {
    return localSongsByRoot[sourceRootId] ?? const <Song>[];
  }

  @override
  Future<bool> hasConfiguredAggregateSources({
    String? activeLocalRootId,
  }) async {
    return hasConfiguredAggregateSourcesValue;
  }
}

class _CountingSongList extends ListBase<Song> {
  _CountingSongList(this._songs);

  final List<Song> _songs;
  int elementReadCount = 0;

  @override
  int get length => _songs.length;

  @override
  set length(int value) => throw UnsupportedError('read only');

  @override
  Song operator [](int index) {
    elementReadCount += 1;
    return _songs[index];
  }

  @override
  void operator []=(int index, Song value) {
    throw UnsupportedError('read only');
  }
}

Song _song(int index, {String language = '国语'}) {
  return Song(
    songId: 'song-$index',
    sourceId: 'local',
    sourceSongId: 'source-song-$index',
    title: 'Song $index',
    artist: 'Singer $index',
    languages: <String>[language],
    searchIndex: 'song $index singer $index $language'.toLowerCase(),
    mediaPath: '/music/song-$index.mp4',
  );
}

LibrarySong _librarySong({required String title, required String artist}) {
  return LibrarySong(
    title: title,
    artist: artist,
    mediaPath: '/music/$title.mp4',
    fileName: '$artist-$title-国语.mp4',
    relativePath: '$artist-$title-国语.mp4',
    fileSize: 1,
    modifiedAtMillis: 1,
    sourceFingerprint: 'fingerprint-$title',
    extension: '.mp4',
    languages: const <String>['国语'],
  );
}

void main() {
  test('scanLibrary caches songs and querySongs applies filters', () async {
    final _FakeMediaLibraryDataSource dataSource = _FakeMediaLibraryDataSource(
      <LibrarySong>[
        const LibrarySong(
          title: 'Blue Sky',
          artist: 'Singer A',
          mediaPath: '/music/blue-sky.mp4',
          fileName: 'Singer A-Blue Sky-English.mp4',
          relativePath: 'Singer A-Blue Sky-English.mp4',
          fileSize: 1,
          modifiedAtMillis: 1,
          sourceFingerprint: 'fp-1',
          extension: '.mp4',
          languages: <String>['English'],
        ),
        const LibrarySong(
          title: '青花瓷',
          artist: '周杰伦',
          mediaPath: '/music/qinghuaci.mp4',
          fileName: '周杰伦-青花瓷-国语.mp4',
          relativePath: '周杰伦-青花瓷-国语.mp4',
          fileSize: 1,
          modifiedAtMillis: 1,
          sourceFingerprint: 'fp-2',
          extension: '.mp4',
          languages: <String>['国语'],
        ),
      ],
    );
    final MediaLibraryRepository repository = MediaLibraryRepository(
      mediaLibraryDataSource: dataSource,
      mediaIndexStore: _FakeMediaIndexStore(),
    );

    expect(await repository.scanLibrary('/music'), 2);

    final SongPage exactPage = await repository.querySongs(
      directory: '/music',
      pageIndex: 0,
      pageSize: 10,
      language: '国语',
      searchQuery: '周杰',
    );
    final SongPage initialsPage = await repository.querySongs(
      directory: '/music',
      pageIndex: 0,
      pageSize: 10,
      language: '国语',
      searchQuery: 'qhc',
    );
    final SongPage fullPinyinPage = await repository.querySongs(
      directory: '/music',
      pageIndex: 0,
      pageSize: 10,
      language: '国语',
      searchQuery: 'qinghuaci',
    );

    expect(dataSource.scanCallCount, 1);
    expect(exactPage.totalCount, 1);
    expect(exactPage.songs.single.title, '青花瓷');
    expect(initialsPage.songs.single.title, '青花瓷');
    expect(fullPinyinPage.totalCount, 0);
  });

  test(
    'hasConfiguredAggregatedSources short-circuits when local directory exists',
    () async {
      final _FakeMediaIndexStore mediaIndexStore = _FakeMediaIndexStore()
        ..hasConfiguredAggregateSourcesValue = false;
      final MediaLibraryRepository repository = MediaLibraryRepository(
        mediaIndexStore: mediaIndexStore,
      );

      expect(
        await repository.hasConfiguredAggregatedSources(
          localDirectory: '/music',
        ),
        isTrue,
      );
      expect(
        await repository.hasConfiguredAggregatedSources(localDirectory: null),
        isFalse,
      );
    },
  );

  test('querySongs reuses the current filter snapshot across pages', () async {
    final _CountingSongList songs = _CountingSongList(
      List<Song>.generate(6, _song, growable: false),
    );
    final _FakeMediaIndexStore mediaIndexStore = _FakeMediaIndexStore()
      ..localSongsByRoot['/music'] = songs;
    final MediaLibraryRepository repository = MediaLibraryRepository(
      mediaIndexStore: mediaIndexStore,
    );

    final SongPage firstPage = await repository.querySongs(
      directory: '/music',
      pageIndex: 0,
      pageSize: 2,
      language: '国语',
      searchQuery: 'song',
    );
    final int readsAfterFirstPage = songs.elementReadCount;
    final SongPage secondPage = await repository.querySongs(
      directory: '/music',
      pageIndex: 1,
      pageSize: 2,
      language: ' 国语 ',
      searchQuery: ' SONG ',
    );

    expect(readsAfterFirstPage, greaterThanOrEqualTo(songs.length));
    expect(songs.elementReadCount, readsAfterFirstPage);
    expect(firstPage.songs.map((Song song) => song.title), <String>[
      'Song 0',
      'Song 1',
    ]);
    expect(secondPage.songs.map((Song song) => song.title), <String>[
      'Song 2',
      'Song 3',
    ]);
  });

  test(
    'queryArtists reuses the current artist snapshot across pages',
    () async {
      final _CountingSongList songs = _CountingSongList(
        List<Song>.generate(6, _song, growable: false),
      );
      final _FakeMediaIndexStore mediaIndexStore = _FakeMediaIndexStore()
        ..localSongsByRoot['/music'] = songs;
      final MediaLibraryRepository repository = MediaLibraryRepository(
        mediaIndexStore: mediaIndexStore,
      );

      final firstPage = await repository.queryArtists(
        directory: '/music',
        pageIndex: 0,
        pageSize: 2,
        language: '国语',
        searchQuery: 'singer',
      );
      final int readsAfterFirstPage = songs.elementReadCount;
      final secondPage = await repository.queryArtists(
        directory: '/music',
        pageIndex: 1,
        pageSize: 2,
        language: ' 国语 ',
        searchQuery: ' SINGER ',
      );

      expect(readsAfterFirstPage, greaterThanOrEqualTo(songs.length));
      expect(songs.elementReadCount, readsAfterFirstPage);
      expect(firstPage.artists.map((artist) => artist.name), <String>[
        'Singer 0',
        'Singer 1',
      ]);
      expect(secondPage.artists.map((artist) => artist.name), <String>[
        'Singer 2',
        'Singer 3',
      ]);
    },
  );

  test('scanLibrary invalidates local song and artist snapshots', () async {
    final List<LibrarySong> scannedSongs = <LibrarySong>[
      _librarySong(title: 'Old Song', artist: 'Old Singer'),
    ];
    final _FakeMediaLibraryDataSource dataSource = _FakeMediaLibraryDataSource(
      scannedSongs,
    );
    final MediaLibraryRepository repository = MediaLibraryRepository(
      mediaLibraryDataSource: dataSource,
      mediaIndexStore: _FakeMediaIndexStore(),
    );

    await repository.scanLibrary('/music');
    expect(
      (await repository.querySongs(
        directory: '/music',
        pageIndex: 0,
        pageSize: 10,
      )).songs.single.title,
      'Old Song',
    );
    expect(
      (await repository.queryArtists(
        directory: '/music',
        pageIndex: 0,
        pageSize: 10,
      )).artists.single.name,
      'Old Singer',
    );

    scannedSongs
      ..clear()
      ..add(_librarySong(title: 'New Song', artist: 'New Singer'));
    await repository.scanLibrary('/music');

    expect(
      (await repository.querySongs(
        directory: '/music',
        pageIndex: 0,
        pageSize: 10,
      )).songs.single.title,
      'New Song',
    );
    expect(
      (await repository.queryArtists(
        directory: '/music',
        pageIndex: 0,
        pageSize: 10,
      )).artists.single.name,
      'New Singer',
    );
  });
}
