import 'package:flutter_test/flutter_test.dart';
import 'package:maimai_ktv/features/media_library/data/media_index_store.dart';

void main() {
  late MediaIndexStore store;

  setUp(() async {
    store = MediaIndexStore();
    await store.replaceSourceSongs(
      sourceType: 'webdav',
      sourceRootId: 'webdav:/ktv',
      songs: <SourceSongRecord>[
        _record(sourceSongId: 'song-1', title: '中文歌曲', artist: '周杰伦'),
        _record(
          sourceSongId: 'song-2',
          title: 'Hello World',
          artist: 'Singer A',
        ),
      ],
    );
  });

  tearDown(() async {
    await store.close();
  });

  test(
    'aggregate song search matches initials and preserves exact search',
    () async {
      final initialsPage = await store.queryAggregateSongs(
        pageIndex: 0,
        pageSize: 10,
        searchQuery: 'zw',
      );
      final exactPage = await store.queryAggregateSongs(
        pageIndex: 0,
        pageSize: 10,
        searchQuery: '中文',
      );
      final englishPage = await store.queryAggregateSongs(
        pageIndex: 0,
        pageSize: 10,
        searchQuery: 'WORLD',
      );

      expect(initialsPage.songs.single.title, '中文歌曲');
      expect(exactPage.songs.single.title, '中文歌曲');
      expect(englishPage.songs.single.title, 'Hello World');
    },
  );

  test('aggregate song search rejects full pinyin', () async {
    final page = await store.queryAggregateSongs(
      pageIndex: 0,
      pageSize: 10,
      searchQuery: 'zhongwen',
    );

    expect(page.totalCount, 0);
    expect(page.songs, isEmpty);
  });

  test(
    'aggregate artist search matches initials but not full pinyin',
    () async {
      final initialsPage = await store.queryAggregateArtists(
        pageIndex: 0,
        pageSize: 10,
        searchQuery: 'zjl',
      );
      final fullPinyinPage = await store.queryAggregateArtists(
        pageIndex: 0,
        pageSize: 10,
        searchQuery: 'zhoujielun',
      );

      expect(initialsPage.artists.single.name, '周杰伦');
      expect(fullPinyinPage.totalCount, 0);
    },
  );
}

SourceSongRecord _record({
  required String sourceSongId,
  required String title,
  required String artist,
}) {
  return SourceSongRecord(
    sourceType: 'webdav',
    sourceSongId: sourceSongId,
    sourceRootId: 'webdav:/ktv',
    title: title,
    artist: artist,
    languages: const <String>['国语'],
    tags: const <String>[],
    searchIndex: '$title $artist'.toLowerCase(),
    mediaLocator: '/ktv/$sourceSongId.mp4',
    fileFingerprint: 'fingerprint-$sourceSongId',
    fileSize: 1,
    modifiedAtMillis: 1,
  );
}
