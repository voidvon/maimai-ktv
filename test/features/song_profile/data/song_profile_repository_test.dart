import 'package:flutter_test/flutter_test.dart';
import 'package:maimai_ktv/core/models/song.dart';
import 'package:maimai_ktv/features/song_profile/data/song_profile_database.dart';
import 'package:maimai_ktv/features/song_profile/data/song_profile_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database database;
  late _CountingDatabase countingDatabase;
  late SongProfileRepository repository;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    database = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    await _createSchema(database);
    countingDatabase = _CountingDatabase(database);
    repository = SongProfileRepository(
      database: _TestSongProfileDatabase(countingDatabase),
    );
  });

  tearDown(() async {
    await repository.close();
  });

  test(
    'favorite pages and count reuse the current filtered snapshot',
    () async {
      await _insertProfile(
        database,
        _song('favorite-new', title: 'Song New'),
        isFavorite: true,
        favoritedAt: 300,
        updatedAt: 300,
      );
      await _insertProfile(
        database,
        _song('favorite-old', title: 'Song Old'),
        isFavorite: true,
        favoritedAt: 200,
        updatedAt: 200,
      );
      await _insertProfile(
        database,
        _song('not-favorite', title: 'Song Hidden'),
        updatedAt: 400,
      );

      final Future<List<String>> firstPage = repository.queryFavoriteSongIds(
        pageIndex: 0,
        pageSize: 1,
        language: ' Mandarin ',
        artist: ' Singer A ',
        searchQuery: ' SONG ',
      );
      final Future<int> count = repository.countFavoriteSongs(
        language: 'Mandarin',
        artist: 'Singer A',
        searchQuery: 'song',
      );

      expect(await firstPage, <String>['favorite-new']);
      expect(await count, 2);
      expect(
        await repository.queryFavoriteSongIds(
          pageIndex: 1,
          pageSize: 1,
          language: 'Mandarin',
          artist: 'Singer A',
          searchQuery: 'song',
        ),
        <String>['favorite-old'],
      );
      expect(countingDatabase.favoriteSnapshotQueryCount, 1);

      await repository.countFavoriteSongs(language: 'Cantonese');
      expect(countingDatabase.favoriteSnapshotQueryCount, 2);
      await repository.countFavoriteSongs(
        language: 'Mandarin',
        artist: 'Singer A',
        searchQuery: 'song',
      );
      expect(countingDatabase.favoriteSnapshotQueryCount, 3);
    },
  );

  test(
    'frequent pages and count reuse one correctly ordered snapshot',
    () async {
      await _insertProfile(
        database,
        _song('played-most', title: 'Most Played'),
        playCount: 5,
        lastPlayedAt: 200,
        updatedAt: 200,
      );
      await _insertProfile(
        database,
        _song('played-less', title: 'Less Played'),
        playCount: 2,
        lastPlayedAt: 300,
        updatedAt: 300,
      );

      expect(
        await repository.queryFrequentSongIds(pageIndex: 0, pageSize: 1),
        <String>['played-most'],
      );
      expect(await repository.countFrequentSongs(), 2);
      expect(
        await repository.queryFrequentSongIds(pageIndex: 1, pageSize: 1),
        <String>['played-less'],
      );
      expect(countingDatabase.frequentSnapshotQueryCount, 1);
    },
  );

  test('toggleFavorite invalidates a snapshot when toggling off', () async {
    final Song song = _song('favorite');
    await _insertProfile(
      database,
      song,
      isFavorite: true,
      favoritedAt: 100,
      updatedAt: 100,
    );
    expect(
      await repository.queryFavoriteSongIds(pageIndex: 0, pageSize: 10),
      <String>['favorite'],
    );

    expect(await repository.toggleFavorite(song: song), isFalse);

    expect(
      await repository.queryFavoriteSongIds(pageIndex: 0, pageSize: 10),
      isEmpty,
    );
    expect(countingDatabase.favoriteSnapshotQueryCount, 2);
  });

  test('recordSongRequested invalidates favorite ordering', () async {
    final Song requestedSong = _song('requested', title: 'Requested');
    await _insertProfile(
      database,
      requestedSong,
      isFavorite: true,
      favoritedAt: 100,
      updatedAt: 100,
    );
    await _insertProfile(
      database,
      _song('other', title: 'Other'),
      isFavorite: true,
      favoritedAt: 100,
      updatedAt: 200,
    );
    expect(
      await repository.queryFavoriteSongIds(pageIndex: 0, pageSize: 10),
      <String>['other', 'requested'],
    );

    await repository.recordSongRequested(song: requestedSong);

    expect(
      await repository.queryFavoriteSongIds(pageIndex: 0, pageSize: 10),
      <String>['requested', 'other'],
    );
    expect(countingDatabase.favoriteSnapshotQueryCount, 2);
  });

  test('recordSongStarted invalidates the frequent snapshot', () async {
    final Song song = _song('started');
    await _insertProfile(database, song, updatedAt: 100);
    expect(
      await repository.queryFrequentSongIds(pageIndex: 0, pageSize: 10),
      isEmpty,
    );

    await repository.recordSongStarted(song: song);

    expect(
      await repository.queryFrequentSongIds(pageIndex: 0, pageSize: 10),
      <String>['started'],
    );
    expect(countingDatabase.frequentSnapshotQueryCount, 2);
  });
}

Future<void> _createSchema(Database database) async {
  await database.execute('''
    CREATE TABLE ${SongProfileDatabase.tableName} (
      ${SongProfileDatabase.columnSongId} TEXT PRIMARY KEY,
      ${SongProfileDatabase.columnSourceId} TEXT NOT NULL,
      ${SongProfileDatabase.columnSourceSongId} TEXT NOT NULL,
      ${SongProfileDatabase.columnMediaPath} TEXT,
      ${SongProfileDatabase.columnDirectoryPath} TEXT NOT NULL,
      ${SongProfileDatabase.columnTitle} TEXT NOT NULL,
      ${SongProfileDatabase.columnArtist} TEXT NOT NULL,
      ${SongProfileDatabase.columnLanguages} TEXT NOT NULL,
      ${SongProfileDatabase.columnTags} TEXT NOT NULL,
      ${SongProfileDatabase.columnSearchIndex} TEXT NOT NULL,
      ${SongProfileDatabase.columnIsFavorite} INTEGER NOT NULL,
      ${SongProfileDatabase.columnFavoritedAt} INTEGER,
      ${SongProfileDatabase.columnPlayCount} INTEGER NOT NULL,
      ${SongProfileDatabase.columnLastPlayedAt} INTEGER,
      ${SongProfileDatabase.columnLastRequestedAt} INTEGER,
      ${SongProfileDatabase.columnUpdatedAt} INTEGER NOT NULL
    )
  ''');
}

Future<void> _insertProfile(
  Database database,
  Song song, {
  bool isFavorite = false,
  int? favoritedAt,
  int playCount = 0,
  int? lastPlayedAt,
  required int updatedAt,
}) async {
  await database.insert(SongProfileDatabase.tableName, <String, Object?>{
    SongProfileDatabase.columnSongId: song.songId,
    SongProfileDatabase.columnSourceId: song.sourceId,
    SongProfileDatabase.columnSourceSongId: song.sourceSongId,
    SongProfileDatabase.columnMediaPath: song.mediaPath,
    SongProfileDatabase.columnDirectoryPath: '',
    SongProfileDatabase.columnTitle: song.title,
    SongProfileDatabase.columnArtist: song.artist,
    SongProfileDatabase.columnLanguages: song.languages.join('\n'),
    SongProfileDatabase.columnTags: song.tags.join('\n'),
    SongProfileDatabase.columnSearchIndex: song.searchIndex,
    SongProfileDatabase.columnIsFavorite: isFavorite ? 1 : 0,
    SongProfileDatabase.columnFavoritedAt: favoritedAt,
    SongProfileDatabase.columnPlayCount: playCount,
    SongProfileDatabase.columnLastPlayedAt: lastPlayedAt,
    SongProfileDatabase.columnLastRequestedAt: null,
    SongProfileDatabase.columnUpdatedAt: updatedAt,
  });
}

Song _song(String songId, {String title = 'Song'}) {
  return Song(
    songId: songId,
    sourceId: 'local',
    sourceSongId: 'source-$songId',
    title: title,
    artist: 'Singer A & Singer B',
    languages: const <String>['Mandarin'],
    searchIndex: '${title.toLowerCase()} singer a singer b',
    mediaPath: '/music/$songId.mp4',
  );
}

class _TestSongProfileDatabase extends SongProfileDatabase {
  _TestSongProfileDatabase(this._testDatabase);

  final Database _testDatabase;

  @override
  Future<Database> get database => Future<Database>.value(_testDatabase);

  @override
  Future<void> close() => _testDatabase.close();
}

class _CountingDatabase implements Database {
  _CountingDatabase(this._delegate);

  final Database _delegate;
  int favoriteSnapshotQueryCount = 0;
  int frequentSnapshotQueryCount = 0;

  @override
  Database get database => this;

  @override
  bool get isOpen => _delegate.isOpen;

  @override
  String get path => _delegate.path;

  @override
  Future<void> close() => _delegate.close();

  @override
  Future<List<Map<String, Object?>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) {
    if (table == SongProfileDatabase.tableName &&
        where == '${SongProfileDatabase.columnIsFavorite} = 1') {
      favoriteSnapshotQueryCount += 1;
    }
    if (table == SongProfileDatabase.tableName &&
        where == '${SongProfileDatabase.columnPlayCount} > 0') {
      frequentSnapshotQueryCount += 1;
    }
    return _delegate.query(
      table,
      distinct: distinct,
      columns: columns,
      where: where,
      whereArgs: whereArgs,
      groupBy: groupBy,
      having: having,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
  }

  @override
  Future<T> transaction<T>(
    Future<T> Function(Transaction txn) action, {
    bool? exclusive,
  }) {
    return _delegate.transaction(action, exclusive: exclusive);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
