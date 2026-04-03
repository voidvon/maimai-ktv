import 'package:sqflite/sqflite.dart';

import '../../../core/models/song.dart';
import 'song_profile_database.dart';

class SongProfileRepository {
  SongProfileRepository({SongProfileDatabase? database})
    : _database = database ?? SongProfileDatabase();

  final SongProfileDatabase _database;

  static const String _listSeparator = '\n';

  Future<void> close() => _database.close();

  Future<bool> toggleFavorite({required Song song}) async {
    try {
      final Database database = await _database.database;
      return database.transaction((Transaction txn) async {
        final Map<String, Object?> values = await _loadOrCreateRow(
          txn,
          song: song,
        );
        final bool nextIsFavorite = !_readBool(
          values[SongProfileDatabase.columnIsFavorite],
        );
        final int now = DateTime.now().millisecondsSinceEpoch;
        values[SongProfileDatabase.columnIsFavorite] = nextIsFavorite ? 1 : 0;
        values[SongProfileDatabase.columnFavoritedAt] = nextIsFavorite
            ? now
            : null;
        values[SongProfileDatabase.columnUpdatedAt] = now;
        await txn.insert(
          SongProfileDatabase.tableName,
          values,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        return nextIsFavorite;
      });
    } catch (_) {
      return false;
    }
  }

  Future<void> recordSongRequested({required Song song}) async {
    try {
      final Database database = await _database.database;
      await database.transaction((Transaction txn) async {
        final Map<String, Object?> values = await _loadOrCreateRow(
          txn,
          song: song,
        );
        final int now = DateTime.now().millisecondsSinceEpoch;
        values[SongProfileDatabase.columnLastRequestedAt] = now;
        values[SongProfileDatabase.columnUpdatedAt] = now;
        await txn.insert(
          SongProfileDatabase.tableName,
          values,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      });
    } catch (_) {
      return;
    }
  }

  Future<void> recordSongStarted({required Song song}) async {
    try {
      final Database database = await _database.database;
      await database.transaction((Transaction txn) async {
        final Map<String, Object?> values = await _loadOrCreateRow(
          txn,
          song: song,
        );
        final int now = DateTime.now().millisecondsSinceEpoch;
        values[SongProfileDatabase.columnPlayCount] =
            _readInt(values[SongProfileDatabase.columnPlayCount]) + 1;
        values[SongProfileDatabase.columnLastPlayedAt] = now;
        values[SongProfileDatabase.columnUpdatedAt] = now;
        await txn.insert(
          SongProfileDatabase.tableName,
          values,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      });
    } catch (_) {
      return;
    }
  }

  Future<Set<String>> loadFavoriteSongIds(Iterable<String> songIds) async {
    final List<String> normalizedSongIds = songIds
        .map((String songId) => songId.trim())
        .where((String songId) => songId.isNotEmpty)
        .toList(growable: false);
    if (normalizedSongIds.isEmpty) {
      return <String>{};
    }

    try {
      final Database database = await _database.database;
      final String placeholders = List<String>.filled(
        normalizedSongIds.length,
        '?',
      ).join(', ');
      final List<Map<String, Object?>> rows = await database.rawQuery('''
        SELECT ${SongProfileDatabase.columnSongId}
        FROM ${SongProfileDatabase.tableName}
        WHERE ${SongProfileDatabase.columnSongId} IN ($placeholders)
          AND ${SongProfileDatabase.columnIsFavorite} = 1
        ''', normalizedSongIds);
      return rows
          .map(
            (Map<String, Object?> row) =>
                row[SongProfileDatabase.columnSongId]?.toString() ?? '',
          )
          .where((String songId) => songId.isNotEmpty)
          .toSet();
    } catch (_) {
      return <String>{};
    }
  }

  Future<List<String>> queryFavoriteSongIds({
    required int pageIndex,
    required int pageSize,
    String? language,
    String? artist,
    String searchQuery = '',
  }) {
    return _guardListResult(
      () => _querySongIds(
        pageIndex: pageIndex,
        pageSize: pageSize,
        language: language,
        artist: artist,
        searchQuery: searchQuery,
        whereClause: '${SongProfileDatabase.columnIsFavorite} = 1',
        whereArgs: const <Object?>[],
        orderBy:
            '${SongProfileDatabase.columnFavoritedAt} DESC, ${SongProfileDatabase.columnUpdatedAt} DESC, ${SongProfileDatabase.columnTitle} COLLATE NOCASE ASC',
      ),
    );
  }

  Future<int> countFavoriteSongs({
    String? language,
    String? artist,
    String searchQuery = '',
  }) {
    return _guardCountResult(
      () => _countSongs(
        language: language,
        artist: artist,
        searchQuery: searchQuery,
        whereClause: '${SongProfileDatabase.columnIsFavorite} = 1',
        whereArgs: const <Object?>[],
      ),
    );
  }

  Future<List<String>> queryFrequentSongIds({
    required int pageIndex,
    required int pageSize,
    String? language,
    String? artist,
    String searchQuery = '',
  }) {
    return _guardListResult(
      () => _querySongIds(
        pageIndex: pageIndex,
        pageSize: pageSize,
        language: language,
        artist: artist,
        searchQuery: searchQuery,
        whereClause: '${SongProfileDatabase.columnPlayCount} > 0',
        whereArgs: const <Object?>[],
        orderBy:
            '${SongProfileDatabase.columnPlayCount} DESC, ${SongProfileDatabase.columnLastPlayedAt} DESC, ${SongProfileDatabase.columnUpdatedAt} DESC, ${SongProfileDatabase.columnTitle} COLLATE NOCASE ASC',
      ),
    );
  }

  Future<int> countFrequentSongs({
    String? language,
    String? artist,
    String searchQuery = '',
  }) {
    return _guardCountResult(
      () => _countSongs(
        language: language,
        artist: artist,
        searchQuery: searchQuery,
        whereClause: '${SongProfileDatabase.columnPlayCount} > 0',
        whereArgs: const <Object?>[],
      ),
    );
  }

  Future<List<String>> _querySongIds({
    required int pageIndex,
    required int pageSize,
    required String? language,
    required String? artist,
    required String searchQuery,
    required String whereClause,
    required List<Object?> whereArgs,
    required String orderBy,
  }) async {
    final List<Map<String, Object?>> rows = await _loadFilteredRows(
      language: language,
      artist: artist,
      searchQuery: searchQuery,
      whereClause: whereClause,
      whereArgs: whereArgs,
      orderBy: orderBy,
    );
    final int normalizedPageIndex = pageIndex < 0 ? 0 : pageIndex;
    final int normalizedPageSize = pageSize <= 0 ? 1 : pageSize;
    final int start = normalizedPageIndex * normalizedPageSize;
    final int end = (start + normalizedPageSize).clamp(0, rows.length);
    final List<Map<String, Object?>> pageRows = start >= rows.length
        ? const <Map<String, Object?>>[]
        : rows.sublist(start, end);
    return pageRows
        .map(
          (Map<String, Object?> row) =>
              row[SongProfileDatabase.columnSongId]?.toString() ?? '',
        )
        .where((String songId) => songId.isNotEmpty)
        .toList(growable: false);
  }

  Future<int> _countSongs({
    required String? language,
    required String? artist,
    required String searchQuery,
    required String whereClause,
    required List<Object?> whereArgs,
  }) async {
    final List<Map<String, Object?>> rows = await _loadFilteredRows(
      language: language,
      artist: artist,
      searchQuery: searchQuery,
      whereClause: whereClause,
      whereArgs: whereArgs,
      orderBy:
          '${SongProfileDatabase.columnUpdatedAt} DESC, ${SongProfileDatabase.columnTitle} COLLATE NOCASE ASC',
    );
    return rows.length;
  }

  Future<List<Map<String, Object?>>> _loadFilteredRows({
    required String? language,
    required String? artist,
    required String searchQuery,
    required String whereClause,
    required List<Object?> whereArgs,
    required String orderBy,
  }) async {
    final String normalizedLanguage = (language ?? '').trim();
    final String normalizedArtist = (artist ?? '').trim();
    final String normalizedSearchQuery = searchQuery.trim().toLowerCase();
    final Database database = await _database.database;
    final List<Map<String, Object?>> rows = await database.query(
      SongProfileDatabase.tableName,
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: orderBy,
    );
    return rows
        .where((Map<String, Object?> row) {
          final Song song = _mapRowToSong(row);
          if (normalizedLanguage.isNotEmpty &&
              !song.languages.contains(normalizedLanguage)) {
            return false;
          }
          if (normalizedArtist.isNotEmpty &&
              !_extractArtistNames(song.artist).contains(normalizedArtist)) {
            return false;
          }
          if (normalizedSearchQuery.isEmpty) {
            return true;
          }
          return song.searchIndex.contains(normalizedSearchQuery);
        })
        .toList(growable: false);
  }

  Future<Map<String, Object?>> _loadOrCreateRow(
    DatabaseExecutor executor, {
    required Song song,
  }) async {
    final List<Map<String, Object?>> rows = await executor.query(
      SongProfileDatabase.tableName,
      where: '${SongProfileDatabase.columnSongId} = ?',
      whereArgs: <Object?>[song.songId],
      limit: 1,
    );
    final int now = DateTime.now().millisecondsSinceEpoch;
    final Map<String, Object?> values = <String, Object?>{
      SongProfileDatabase.columnSongId: song.songId,
      SongProfileDatabase.columnSourceId: song.sourceId,
      SongProfileDatabase.columnSourceSongId: song.sourceSongId,
      SongProfileDatabase.columnMediaPath: song.mediaPath,
      SongProfileDatabase.columnDirectoryPath: '',
      SongProfileDatabase.columnTitle: song.title,
      SongProfileDatabase.columnArtist: song.artist,
      SongProfileDatabase.columnLanguages: _encodeList(song.languages),
      SongProfileDatabase.columnTags: _encodeList(song.tags),
      SongProfileDatabase.columnSearchIndex: song.searchIndex,
      SongProfileDatabase.columnIsFavorite: 0,
      SongProfileDatabase.columnFavoritedAt: null,
      SongProfileDatabase.columnPlayCount: 0,
      SongProfileDatabase.columnLastPlayedAt: null,
      SongProfileDatabase.columnLastRequestedAt: null,
      SongProfileDatabase.columnUpdatedAt: now,
    };
    if (rows.isNotEmpty) {
      values.addAll(rows.first);
    }
    values.addAll(<String, Object?>{
      SongProfileDatabase.columnSongId: song.songId,
      SongProfileDatabase.columnSourceId: song.sourceId,
      SongProfileDatabase.columnSourceSongId: song.sourceSongId,
      SongProfileDatabase.columnMediaPath: song.mediaPath,
      SongProfileDatabase.columnTitle: song.title,
      SongProfileDatabase.columnArtist: song.artist,
      SongProfileDatabase.columnLanguages: _encodeList(song.languages),
      SongProfileDatabase.columnTags: _encodeList(song.tags),
      SongProfileDatabase.columnSearchIndex: song.searchIndex,
    });
    return values;
  }

  Song _mapRowToSong(Map<String, Object?> row) {
    return Song(
      songId:
          row[SongProfileDatabase.columnSongId]?.toString() ??
          row[SongProfileDatabase.columnMediaPath]?.toString() ??
          '',
      sourceId: row[SongProfileDatabase.columnSourceId]?.toString() ?? 'local',
      sourceSongId:
          row[SongProfileDatabase.columnSourceSongId]?.toString() ??
          row[SongProfileDatabase.columnMediaPath]?.toString() ??
          row[SongProfileDatabase.columnSongId]?.toString() ??
          '',
      title: row[SongProfileDatabase.columnTitle]?.toString() ?? '未知歌曲',
      artist: row[SongProfileDatabase.columnArtist]?.toString() ?? '未识别歌手',
      languages: _decodeList(row[SongProfileDatabase.columnLanguages]),
      tags: _decodeList(row[SongProfileDatabase.columnTags]),
      searchIndex: row[SongProfileDatabase.columnSearchIndex]?.toString() ?? '',
      mediaPath: row[SongProfileDatabase.columnMediaPath]?.toString() ?? '',
    );
  }

  String _encodeList(List<String> values) => values.join(_listSeparator);

  List<String> _decodeList(Object? rawValue) {
    final String serialized = rawValue?.toString() ?? '';
    if (serialized.isEmpty) {
      return const <String>[];
    }
    return serialized
        .split(_listSeparator)
        .map((String value) => value.trim())
        .where((String value) => value.isNotEmpty)
        .toList(growable: false);
  }

  int _readInt(Object? rawValue) {
    if (rawValue is int) {
      return rawValue;
    }
    if (rawValue is num) {
      return rawValue.toInt();
    }
    return int.tryParse(rawValue?.toString() ?? '') ?? 0;
  }

  bool _readBool(Object? rawValue) => _readInt(rawValue) != 0;

  Future<List<String>> _guardListResult(
    Future<List<String>> Function() action,
  ) async {
    try {
      return await action();
    } catch (_) {
      return const <String>[];
    }
  }

  Future<int> _guardCountResult(Future<int> Function() action) async {
    try {
      return await action();
    } catch (_) {
      return 0;
    }
  }

  List<String> _extractArtistNames(String artistDisplayName) {
    final List<String> artists = artistDisplayName
        .split('&')
        .map((String value) => value.trim())
        .where((String value) => value.isNotEmpty)
        .toList(growable: false);
    if (artists.isEmpty) {
      return <String>[artistDisplayName.trim()];
    }
    return artists;
  }
}
