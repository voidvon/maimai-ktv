import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../core/persistence/sqflite_factory.dart';
import '../../../core/models/artist.dart';
import '../../../core/models/artist_page.dart';
import '../../../core/models/song.dart';
import '../../../core/models/song_identity.dart';
import '../../../core/models/song_page.dart';
import 'media_library_data_source.dart';

class CachedLocalSongFingerprint {
  const CachedLocalSongFingerprint({
    required this.fileSize,
    required this.modifiedAtMillis,
    required this.sourceFingerprint,
  });

  final int fileSize;
  final int modifiedAtMillis;
  final String sourceFingerprint;

  bool matches({required int nextFileSize, required int nextModifiedAtMillis}) {
    return fileSize == nextFileSize && modifiedAtMillis == nextModifiedAtMillis;
  }
}

class SourceSongRecord {
  const SourceSongRecord({
    required this.sourceType,
    required this.sourceSongId,
    required this.sourceRootId,
    required this.title,
    required this.artist,
    required this.languages,
    required this.tags,
    required this.searchIndex,
    required this.mediaLocator,
    required this.fileFingerprint,
    required this.fileSize,
    required this.modifiedAtMillis,
    this.availabilityStatus = 'ready',
    this.rawPayloadJson = '{}',
  });

  final String sourceType;
  final String sourceSongId;
  final String sourceRootId;
  final String title;
  final String artist;
  final List<String> languages;
  final List<String> tags;
  final String searchIndex;
  final String mediaLocator;
  final String fileFingerprint;
  final int fileSize;
  final int modifiedAtMillis;
  final String availabilityStatus;
  final String rawPayloadJson;
}

class MediaIndexStore {
  MediaIndexStore();

  static const String _databaseName = 'ktv_media_index.db';
  static const int _databaseVersion = 3;

  static const String sourceSongItemsTable = 'source_song_items';
  static const String aggregateSongItemsTable = 'aggregate_song_items';
  static const String aggregateSongLinksTable = 'aggregate_song_links';
  static const String sourceSyncStatesTable = 'source_sync_states';

  static const String columnSourceType = 'source_type';
  static const String columnSourceSongId = 'source_song_id';
  static const String columnSourceRootId = 'source_root_id';
  static const String columnTitle = 'title';
  static const String columnArtist = 'artist';
  static const String columnLanguagesJson = 'languages_json';
  static const String columnTagsJson = 'tags_json';
  static const String columnSearchIndex = 'search_index';
  static const String columnMediaLocator = 'media_locator';
  static const String columnFileFingerprint = 'file_fingerprint';
  static const String columnFileSize = 'file_size';
  static const String columnModifiedAt = 'modified_at';
  static const String columnAvailabilityStatus = 'availability_status';
  static const String columnRawPayloadJson = 'raw_payload_json';
  static const String columnUpdatedAt = 'updated_at';

  static const String columnAggregateSongId = 'aggregate_song_id';
  static const String columnCanonicalTitle = 'canonical_title';
  static const String columnCanonicalArtist = 'canonical_artist';
  static const String columnPrimarySourceType = 'primary_source_type';
  static const String columnPrimarySourceSongId = 'primary_source_song_id';
  static const String columnMatchScore = 'match_score';
  static const String columnIsPrimary = 'is_primary';
  static const String columnLinkedAt = 'linked_at';

  static const String columnSyncToken = 'sync_token';
  static const String columnLastSyncedAt = 'last_synced_at';
  static const String columnSyncStatus = 'sync_status';
  static const String columnLastError = 'last_error';

  Future<Database>? _database;
  Future<void>? _pendingAggregateIndexCheck;
  bool _aggregateIndexVerified = false;

  Future<Database> get database => _database ??= _openDatabase();

  Future<void> close() async {
    final Future<Database>? databaseFuture = _database;
    _database = null;
    _pendingAggregateIndexCheck = null;
    _aggregateIndexVerified = false;
    if (databaseFuture == null) {
      return;
    }
    final Database openedDatabase = await databaseFuture;
    await openedDatabase.close();
  }

  Future<Map<String, CachedLocalSongFingerprint>> loadLocalFingerprintCache({
    required String sourceRootId,
  }) async {
    final Database db = await database;
    final List<Map<String, Object?>> rows = await db.query(
      sourceSongItemsTable,
      columns: <String>[
        columnMediaLocator,
        columnFileSize,
        columnModifiedAt,
        columnFileFingerprint,
      ],
      where: '$columnSourceType = ? AND $columnSourceRootId = ?',
      whereArgs: <Object?>['local', sourceRootId],
    );
    return <String, CachedLocalSongFingerprint>{
      for (final Map<String, Object?> row in rows)
        row[columnMediaLocator]?.toString() ?? '': CachedLocalSongFingerprint(
          fileSize: _readInt(row[columnFileSize]),
          modifiedAtMillis: _readInt(row[columnModifiedAt]),
          sourceFingerprint: row[columnFileFingerprint]?.toString() ?? '',
        ),
    }..removeWhere(
      (String key, CachedLocalSongFingerprint value) => key.isEmpty,
    );
  }

  Future<int> replaceLocalSongs({
    required String sourceRootId,
    required List<LibrarySong> songs,
  }) async {
    return replaceSourceSongs(
      sourceType: 'local',
      sourceRootId: sourceRootId,
      songs: songs
          .map(
            (LibrarySong song) => SourceSongRecord(
              sourceType: 'local',
              sourceSongId: song.sourceSongId,
              sourceRootId: sourceRootId,
              title: song.title,
              artist: song.artist,
              languages: song.languages,
              tags: song.tags,
              searchIndex: song.searchIndex,
              mediaLocator: song.mediaPath,
              fileFingerprint: song.sourceFingerprint,
              fileSize: song.fileSize,
              modifiedAtMillis: song.modifiedAtMillis,
            ),
          )
          .toList(growable: false),
    );
  }

  Future<int> replaceSourceSongs({
    required String sourceType,
    required String sourceRootId,
    required List<SourceSongRecord> songs,
  }) async {
    final Database db = await database;
    _aggregateIndexVerified = false;
    final int now = DateTime.now().millisecondsSinceEpoch;
    return db.transaction((Transaction txn) async {
      final List<Map<String, Object?>> oldAggregateRows = await txn.query(
        aggregateSongLinksTable,
        columns: <String>[columnAggregateSongId],
        where: '$columnSourceType = ? AND $columnSourceRootId = ?',
        whereArgs: <Object?>[sourceType, sourceRootId],
      );
      final Set<String> affectedAggregateIds = oldAggregateRows
          .map(
            (Map<String, Object?> row) =>
                row[columnAggregateSongId]?.toString() ?? '',
          )
          .where((String value) => value.isNotEmpty)
          .toSet();

      await txn.delete(
        aggregateSongLinksTable,
        where: '$columnSourceType = ? AND $columnSourceRootId = ?',
        whereArgs: <Object?>[sourceType, sourceRootId],
      );
      await txn.delete(
        sourceSongItemsTable,
        where: '$columnSourceType = ? AND $columnSourceRootId = ?',
        whereArgs: <Object?>[sourceType, sourceRootId],
      );

      for (final SourceSongRecord song in songs) {
        final String aggregateSongId = buildAggregateSongId(
          title: song.title,
          artist: song.artist,
        );
        affectedAggregateIds.add(aggregateSongId);
        await txn.insert(sourceSongItemsTable, <String, Object?>{
          columnSourceType: song.sourceType,
          columnSourceSongId: song.sourceSongId,
          columnSourceRootId: song.sourceRootId,
          columnTitle: song.title,
          columnArtist: song.artist,
          columnLanguagesJson: _encodeList(song.languages),
          columnTagsJson: _encodeList(song.tags),
          columnSearchIndex: song.searchIndex,
          columnMediaLocator: song.mediaLocator,
          columnFileFingerprint: song.fileFingerprint,
          columnFileSize: song.fileSize,
          columnModifiedAt: song.modifiedAtMillis,
          columnAvailabilityStatus: song.availabilityStatus,
          columnRawPayloadJson: song.rawPayloadJson,
          columnUpdatedAt: now,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        await txn.insert(aggregateSongLinksTable, <String, Object?>{
          columnAggregateSongId: aggregateSongId,
          columnSourceType: song.sourceType,
          columnSourceSongId: song.sourceSongId,
          columnSourceRootId: song.sourceRootId,
          columnMatchScore: 1.0,
          columnIsPrimary: 0,
          columnLinkedAt: now,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      for (final String aggregateSongId in affectedAggregateIds) {
        await _refreshAggregateEntry(txn, aggregateSongId: aggregateSongId);
      }

      await txn.insert(sourceSyncStatesTable, <String, Object?>{
        columnSourceType: sourceType,
        columnSourceRootId: sourceRootId,
        columnSyncToken: null,
        columnLastSyncedAt: now,
        columnSyncStatus: 'ready',
        columnLastError: null,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      return songs.length;
    });
  }

  Future<void> clearSourceSongs({
    required String sourceType,
    String? sourceRootId,
  }) async {
    final Database db = await database;
    _aggregateIndexVerified = false;
    await db.transaction((Transaction txn) async {
      final String whereClause = sourceRootId == null
          ? '$columnSourceType = ?'
          : '$columnSourceType = ? AND $columnSourceRootId = ?';
      final List<Object?> whereArgs = sourceRootId == null
          ? <Object?>[sourceType]
          : <Object?>[sourceType, sourceRootId];

      final List<Map<String, Object?>> oldAggregateRows = await txn.query(
        aggregateSongLinksTable,
        columns: <String>[columnAggregateSongId],
        where: whereClause,
        whereArgs: whereArgs,
      );
      final Set<String> affectedAggregateIds = oldAggregateRows
          .map(
            (Map<String, Object?> row) =>
                row[columnAggregateSongId]?.toString() ?? '',
          )
          .where((String value) => value.isNotEmpty)
          .toSet();

      await txn.delete(
        aggregateSongLinksTable,
        where: whereClause,
        whereArgs: whereArgs,
      );
      await txn.delete(
        sourceSongItemsTable,
        where: whereClause,
        whereArgs: whereArgs,
      );
      await txn.delete(
        sourceSyncStatesTable,
        where: whereClause,
        whereArgs: whereArgs,
      );

      for (final String aggregateSongId in affectedAggregateIds) {
        await _refreshAggregateEntry(txn, aggregateSongId: aggregateSongId);
      }
    });
  }

  Future<void> upsertSourceSyncState({
    required String sourceType,
    required String sourceRootId,
    String? syncToken,
    int? lastSyncedAt,
    String syncStatus = 'configured',
    String? lastError,
  }) async {
    final Database db = await database;
    await db.insert(sourceSyncStatesTable, <String, Object?>{
      columnSourceType: sourceType,
      columnSourceRootId: sourceRootId,
      columnSyncToken: syncToken,
      columnLastSyncedAt: lastSyncedAt,
      columnSyncStatus: syncStatus,
      columnLastError: lastError,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<bool> hasConfiguredAggregateSources({
    String? activeLocalRootId,
  }) async {
    final Database db = await database;
    final String normalizedLocalRootId = activeLocalRootId?.trim() ?? '';
    final List<Map<String, Object?>> rows = await db.rawQuery(
      '''
      SELECT 1
      FROM $sourceSyncStatesTable
      WHERE (
          $columnSourceType != ?
          OR ($columnSourceType = ? AND $columnSourceRootId = ?)
        )
        AND $columnSyncStatus != ?
      LIMIT 1
      ''',
      <Object?>['local', 'local', normalizedLocalRootId, 'deleted'],
    );
    return rows.isNotEmpty;
  }

  Future<List<Song>> loadLocalSongs({required String sourceRootId}) async {
    final Database db = await database;
    final List<Map<String, Object?>> rows = await db.rawQuery(
      '''
      SELECT
        l.$columnAggregateSongId,
        s.$columnSourceType,
        s.$columnSourceSongId,
        s.$columnTitle,
        s.$columnArtist,
        s.$columnLanguagesJson,
        s.$columnTagsJson,
        s.$columnSearchIndex,
        s.$columnMediaLocator
      FROM $sourceSongItemsTable s
      INNER JOIN $aggregateSongLinksTable l
        ON l.$columnSourceType = s.$columnSourceType
       AND l.$columnSourceSongId = s.$columnSourceSongId
      WHERE s.$columnSourceType = ?
        AND s.$columnSourceRootId = ?
        AND s.$columnAvailabilityStatus = 'ready'
      ORDER BY s.$columnTitle COLLATE NOCASE ASC,
               s.$columnArtist COLLATE NOCASE ASC
      ''',
      <Object?>['local', sourceRootId],
    );
    return rows.map(_mapSourceRowToSong).toList(growable: false);
  }

  Future<List<Song>> loadAggregateSongs({String? activeLocalRootId}) async {
    await _ensureAggregateIndexHealthy();
    final Database db = await database;
    final ({String clause, List<Object?> args}) availability =
        _buildAvailability(activeLocalRootId: activeLocalRootId);
    final List<Map<String, Object?>> rows = await db.rawQuery('''
      SELECT
        a.$columnAggregateSongId,
        a.$columnCanonicalTitle,
        a.$columnCanonicalArtist,
        a.$columnLanguagesJson,
        a.$columnTagsJson,
        a.$columnSearchIndex,
        s.$columnSourceType,
        s.$columnSourceSongId,
        s.$columnMediaLocator,
        s.$columnUpdatedAt
      FROM $aggregateSongItemsTable a
      INNER JOIN $aggregateSongLinksTable l
        ON l.$columnAggregateSongId = a.$columnAggregateSongId
      INNER JOIN $sourceSongItemsTable s
        ON s.$columnSourceType = l.$columnSourceType
       AND s.$columnSourceSongId = l.$columnSourceSongId
      WHERE ${availability.clause}
        AND s.$columnAvailabilityStatus = 'ready'
      ORDER BY a.$columnCanonicalTitle COLLATE NOCASE ASC,
               ${_sourcePriorityCase('s.$columnSourceType')} ASC,
               l.$columnMatchScore DESC,
               s.$columnUpdatedAt DESC
      ''', availability.args);

    final List<Song> songs = <Song>[];
    final Set<String> seenAggregateIds = <String>{};
    for (final Map<String, Object?> row in rows) {
      final String aggregateSongId =
          row[columnAggregateSongId]?.toString() ?? '';
      if (aggregateSongId.isEmpty || !seenAggregateIds.add(aggregateSongId)) {
        continue;
      }
      songs.add(_mapAggregateRowToSong(row));
    }
    return songs;
  }

  Future<List<Song>> loadAggregateSongsByIds({
    required List<String> aggregateSongIds,
    String? activeLocalRootId,
  }) async {
    if (aggregateSongIds.isEmpty) {
      return const <Song>[];
    }
    await _ensureAggregateIndexHealthy();
    final List<Song> songs = await _loadResolvedAggregateSongs(
      aggregateSongIds: aggregateSongIds,
      activeLocalRootId: activeLocalRootId,
    );
    final Map<String, Song> songsByAggregateId = <String, Song>{
      for (final Song song in songs) song.songId: song,
    };
    return aggregateSongIds
        .map((String songId) => songsByAggregateId[songId])
        .whereType<Song>()
        .toList(growable: false);
  }

  Future<SongPage> queryAggregateSongs({
    required int pageIndex,
    required int pageSize,
    String? activeLocalRootId,
    String language = '',
    String artist = '',
    String searchQuery = '',
  }) async {
    await _ensureAggregateIndexHealthy();
    final Database db = await database;
    final int normalizedPageIndex = pageIndex < 0 ? 0 : pageIndex;
    final int normalizedPageSize = pageSize <= 0 ? 1 : pageSize;
    final _SqlClause whereClause = _buildAggregateSongWhereClause(
      activeLocalRootId: activeLocalRootId,
      language: language,
      artist: artist,
      searchQuery: searchQuery,
      aggregateAlias: 'a',
    );
    final int totalCount = _firstIntValue(
      await db.rawQuery('''
        SELECT COUNT(*)
        FROM $aggregateSongItemsTable a
        WHERE ${whereClause.sql}
        ''', whereClause.args),
    );
    if (totalCount == 0) {
      return SongPage(
        songs: const <Song>[],
        totalCount: 0,
        pageIndex: normalizedPageIndex,
        pageSize: normalizedPageSize,
      );
    }

    final List<Map<String, Object?>> pageRows = await db.rawQuery(
      '''
      SELECT a.$columnAggregateSongId
      FROM $aggregateSongItemsTable a
      WHERE ${whereClause.sql}
      ORDER BY a.$columnCanonicalTitle COLLATE NOCASE ASC,
               a.$columnCanonicalArtist COLLATE NOCASE ASC,
               a.$columnAggregateSongId ASC
      LIMIT ? OFFSET ?
      ''',
      <Object?>[
        ...whereClause.args,
        normalizedPageSize,
        normalizedPageIndex * normalizedPageSize,
      ],
    );
    final List<String> aggregateSongIds = pageRows
        .map((Map<String, Object?> row) => row[columnAggregateSongId])
        .whereType<String>()
        .toList(growable: false);
    final List<Song> songs = await _loadResolvedAggregateSongs(
      aggregateSongIds: aggregateSongIds,
      activeLocalRootId: activeLocalRootId,
    );
    final Map<String, Song> songsById = <String, Song>{
      for (final Song song in songs) song.songId: song,
    };
    return SongPage(
      songs: aggregateSongIds
          .map((String songId) => songsById[songId])
          .whereType<Song>()
          .toList(growable: false),
      totalCount: totalCount,
      pageIndex: normalizedPageIndex,
      pageSize: normalizedPageSize,
    );
  }

  Future<ArtistPage> queryAggregateArtists({
    required int pageIndex,
    required int pageSize,
    String? activeLocalRootId,
    String language = '',
    String searchQuery = '',
  }) async {
    await _ensureAggregateIndexHealthy();
    final Database db = await database;
    final int normalizedPageIndex = pageIndex < 0 ? 0 : pageIndex;
    final int normalizedPageSize = pageSize <= 0 ? 1 : pageSize;
    final _SqlClause whereClause = _buildAggregateSongWhereClause(
      activeLocalRootId: activeLocalRootId,
      language: language,
      searchQuery: '',
      aggregateAlias: 'a',
    );
    final String artistNameFilter = searchQuery.trim().toLowerCase();
    final String searchFilterSql = artistNameFilter.isEmpty
        ? ''
        : 'WHERE artist_name_lower LIKE ?';
    final List<Object?> searchFilterArgs = artistNameFilter.isEmpty
        ? const <Object?>[]
        : <Object?>['%$artistNameFilter%'];
    final String baseArtistSql =
        '''
      WITH RECURSIVE available_aggregate_songs AS (
        SELECT
          a.$columnAggregateSongId AS aggregate_song_id,
          REPLACE(a.$columnCanonicalArtist, ' & ', '&') AS artist_value
        FROM $aggregateSongItemsTable a
        WHERE ${whereClause.sql}
      ),
      split_artists(aggregate_song_id, artist_name, remaining) AS (
        SELECT
          aggregate_song_id,
          TRIM(
            CASE
              WHEN INSTR(artist_value, '&') > 0
              THEN SUBSTR(artist_value, 1, INSTR(artist_value, '&') - 1)
              ELSE artist_value
            END
          ) AS artist_name,
          CASE
            WHEN INSTR(artist_value, '&') > 0
            THEN SUBSTR(artist_value, INSTR(artist_value, '&') + 1)
            ELSE ''
          END AS remaining
        FROM available_aggregate_songs
        UNION ALL
        SELECT
          aggregate_song_id,
          TRIM(
            CASE
              WHEN INSTR(remaining, '&') > 0
              THEN SUBSTR(remaining, 1, INSTR(remaining, '&') - 1)
              ELSE remaining
            END
          ) AS artist_name,
          CASE
            WHEN INSTR(remaining, '&') > 0
            THEN SUBSTR(remaining, INSTR(remaining, '&') + 1)
            ELSE ''
          END AS remaining
        FROM split_artists
        WHERE remaining != ''
      ),
      artist_counts AS (
        SELECT
          artist_name,
          LOWER(artist_name) AS artist_name_lower,
          COUNT(DISTINCT aggregate_song_id) AS song_count
        FROM split_artists
        WHERE artist_name != ''
        GROUP BY artist_name
      )
    ''';
    final int totalCount = _firstIntValue(
      await db.rawQuery(
        '''
        $baseArtistSql
        SELECT COUNT(*)
        FROM artist_counts
        $searchFilterSql
        ''',
        <Object?>[...whereClause.args, ...searchFilterArgs],
      ),
    );
    if (totalCount == 0) {
      return ArtistPage(
        artists: const <Artist>[],
        totalCount: 0,
        pageIndex: normalizedPageIndex,
        pageSize: normalizedPageSize,
      );
    }

    final List<Map<String, Object?>> rows = await db.rawQuery(
      '''
      $baseArtistSql
      SELECT artist_name, song_count, artist_name_lower
      FROM artist_counts
      $searchFilterSql
      ORDER BY artist_name COLLATE NOCASE ASC
      LIMIT ? OFFSET ?
      ''',
      <Object?>[
        ...whereClause.args,
        ...searchFilterArgs,
        normalizedPageSize,
        normalizedPageIndex * normalizedPageSize,
      ],
    );
    return ArtistPage(
      artists: rows
          .map(
            (Map<String, Object?> row) => Artist(
              name: row['artist_name']?.toString() ?? '未识别歌手',
              songCount: _readInt(row['song_count']),
              searchIndex: row['artist_name_lower']?.toString() ?? '',
            ),
          )
          .toList(growable: false),
      totalCount: totalCount,
      pageIndex: normalizedPageIndex,
      pageSize: normalizedPageSize,
    );
  }

  Future<void> _refreshAggregateEntry(
    Transaction txn, {
    required String aggregateSongId,
  }) async {
    final List<Map<String, Object?>> rows = await txn.rawQuery(
      '''
      SELECT
        s.$columnSourceType,
        s.$columnSourceSongId,
        s.$columnTitle,
        s.$columnArtist,
        s.$columnLanguagesJson,
        s.$columnTagsJson,
        s.$columnSearchIndex,
        s.$columnUpdatedAt,
        l.$columnMatchScore
      FROM $aggregateSongLinksTable l
      INNER JOIN $sourceSongItemsTable s
        ON s.$columnSourceType = l.$columnSourceType
       AND s.$columnSourceSongId = l.$columnSourceSongId
      WHERE l.$columnAggregateSongId = ?
        AND s.$columnAvailabilityStatus = 'ready'
      ORDER BY ${_sourcePriorityCase('s.$columnSourceType')} ASC,
               l.$columnMatchScore DESC,
               s.$columnUpdatedAt DESC
      ''',
      <Object?>[aggregateSongId],
    );

    if (rows.isEmpty) {
      await txn.delete(
        aggregateSongItemsTable,
        where: '$columnAggregateSongId = ?',
        whereArgs: <Object?>[aggregateSongId],
      );
      return;
    }

    final Map<String, Object?> primaryRow = rows.first;
    await txn.insert(aggregateSongItemsTable, <String, Object?>{
      columnAggregateSongId: aggregateSongId,
      columnCanonicalTitle: primaryRow[columnTitle]?.toString() ?? '未知歌曲',
      columnCanonicalArtist: primaryRow[columnArtist]?.toString() ?? '未识别歌手',
      columnLanguagesJson: primaryRow[columnLanguagesJson]?.toString() ?? '[]',
      columnTagsJson: primaryRow[columnTagsJson]?.toString() ?? '[]',
      columnSearchIndex: primaryRow[columnSearchIndex]?.toString() ?? '',
      columnPrimarySourceType:
          primaryRow[columnSourceType]?.toString() ?? 'local',
      columnPrimarySourceSongId:
          primaryRow[columnSourceSongId]?.toString() ?? '',
      columnUpdatedAt: _readInt(primaryRow[columnUpdatedAt]),
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    await txn.update(
      aggregateSongLinksTable,
      <String, Object?>{columnIsPrimary: 0},
      where: '$columnAggregateSongId = ?',
      whereArgs: <Object?>[aggregateSongId],
    );
    await txn.update(
      aggregateSongLinksTable,
      <String, Object?>{columnIsPrimary: 1},
      where:
          '$columnAggregateSongId = ? AND $columnSourceType = ? AND $columnSourceSongId = ?',
      whereArgs: <Object?>[
        aggregateSongId,
        primaryRow[columnSourceType],
        primaryRow[columnSourceSongId],
      ],
    );
  }

  Song _mapSourceRowToSong(Map<String, Object?> row) {
    return Song(
      songId: row[columnAggregateSongId]?.toString() ?? '',
      sourceId: row[columnSourceType]?.toString() ?? 'local',
      sourceSongId: row[columnSourceSongId]?.toString() ?? '',
      title: row[columnTitle]?.toString() ?? '未知歌曲',
      artist: row[columnArtist]?.toString() ?? '未识别歌手',
      languages: _decodeList(row[columnLanguagesJson]),
      tags: _decodeList(row[columnTagsJson]),
      searchIndex: row[columnSearchIndex]?.toString() ?? '',
      mediaPath: row[columnMediaLocator]?.toString() ?? '',
    );
  }

  Song _mapAggregateRowToSong(Map<String, Object?> row) {
    return Song(
      songId: row[columnAggregateSongId]?.toString() ?? '',
      sourceId: row[columnSourceType]?.toString() ?? 'local',
      sourceSongId: row[columnSourceSongId]?.toString() ?? '',
      title: row[columnCanonicalTitle]?.toString() ?? '未知歌曲',
      artist: row[columnCanonicalArtist]?.toString() ?? '未识别歌手',
      languages: _decodeList(row[columnLanguagesJson]),
      tags: _decodeList(row[columnTagsJson]),
      searchIndex: row[columnSearchIndex]?.toString() ?? '',
      mediaPath: row[columnMediaLocator]?.toString() ?? '',
    );
  }

  ({String clause, List<Object?> args}) _buildAvailability({
    required String? activeLocalRootId,
  }) {
    if (activeLocalRootId == null || activeLocalRootId.trim().isEmpty) {
      return (clause: 's.$columnSourceType != ?', args: <Object?>['local']);
    }
    return (
      clause:
          '((s.$columnSourceType = ? AND s.$columnSourceRootId = ?) OR s.$columnSourceType != ?)',
      args: <Object?>['local', activeLocalRootId, 'local'],
    );
  }

  Future<List<Song>> _loadResolvedAggregateSongs({
    required List<String> aggregateSongIds,
    required String? activeLocalRootId,
  }) async {
    if (aggregateSongIds.isEmpty) {
      return const <Song>[];
    }
    final Database db = await database;
    final ({String clause, List<Object?> args}) availability =
        _buildAvailability(activeLocalRootId: activeLocalRootId);
    final String placeholders = List<String>.filled(
      aggregateSongIds.length,
      '?',
    ).join(', ');
    final List<Map<String, Object?>> rows = await db.rawQuery(
      '''
      SELECT
        a.$columnAggregateSongId,
        a.$columnCanonicalTitle,
        a.$columnCanonicalArtist,
        a.$columnLanguagesJson,
        a.$columnTagsJson,
        a.$columnSearchIndex,
        s.$columnSourceType,
        s.$columnSourceSongId,
        s.$columnMediaLocator,
        s.$columnUpdatedAt,
        l.$columnMatchScore
      FROM $aggregateSongItemsTable a
      INNER JOIN $aggregateSongLinksTable l
        ON l.$columnAggregateSongId = a.$columnAggregateSongId
      INNER JOIN $sourceSongItemsTable s
        ON s.$columnSourceType = l.$columnSourceType
       AND s.$columnSourceSongId = l.$columnSourceSongId
      WHERE a.$columnAggregateSongId IN ($placeholders)
        AND ${availability.clause}
        AND s.$columnAvailabilityStatus = 'ready'
      ORDER BY a.$columnCanonicalTitle COLLATE NOCASE ASC,
               a.$columnCanonicalArtist COLLATE NOCASE ASC,
               ${_sourcePriorityCase('s.$columnSourceType')} ASC,
               l.$columnMatchScore DESC,
               s.$columnUpdatedAt DESC,
               s.$columnSourceSongId ASC
      ''',
      <Object?>[...aggregateSongIds, ...availability.args],
    );
    final List<Song> songs = <Song>[];
    final Set<String> seenAggregateIds = <String>{};
    for (final Map<String, Object?> row in rows) {
      final String aggregateSongId =
          row[columnAggregateSongId]?.toString() ?? '';
      if (aggregateSongId.isEmpty || !seenAggregateIds.add(aggregateSongId)) {
        continue;
      }
      songs.add(_mapAggregateRowToSong(row));
    }
    return songs;
  }

  _SqlClause _buildAggregateSongWhereClause({
    required String? activeLocalRootId,
    required String language,
    String artist = '',
    required String searchQuery,
    required String aggregateAlias,
  }) {
    final List<String> parts = <String>[
      _buildAvailabilityExistsClause(
        aggregateAlias: aggregateAlias,
        activeLocalRootId: activeLocalRootId,
      ),
    ];
    final List<Object?> args = <Object?>[
      ..._buildAvailability(activeLocalRootId: activeLocalRootId).args,
    ];
    final String normalizedLanguage = language.trim();
    if (normalizedLanguage.isNotEmpty) {
      parts.add('$aggregateAlias.$columnLanguagesJson LIKE ?');
      args.add('%"$normalizedLanguage"%');
    }
    final String normalizedArtist = artist.trim();
    if (normalizedArtist.isNotEmpty) {
      final String artistExpr =
          "REPLACE(REPLACE(REPLACE($aggregateAlias.$columnCanonicalArtist, ' & ', '&'), '& ', '&'), ' &', '&')";
      parts.add(
        '('
        '$artistExpr = ? OR '
        '$artistExpr LIKE ? OR '
        '$artistExpr LIKE ? OR '
        '$artistExpr LIKE ?'
        ')',
      );
      args.addAll(<Object?>[
        normalizedArtist,
        '$normalizedArtist&%',
        '%&$normalizedArtist',
        '%&$normalizedArtist&%',
      ]);
    }
    final String normalizedQuery = searchQuery.trim().toLowerCase();
    if (normalizedQuery.isNotEmpty) {
      parts.add('$aggregateAlias.$columnSearchIndex LIKE ?');
      args.add('%$normalizedQuery%');
    }
    return _SqlClause(parts.join(' AND '), args);
  }

  String _buildAvailabilityExistsClause({
    required String aggregateAlias,
    required String? activeLocalRootId,
  }) {
    final ({String clause, List<Object?> args}) availability =
        _buildAvailability(activeLocalRootId: activeLocalRootId);
    return '''
      EXISTS (
        SELECT 1
        FROM $aggregateSongLinksTable l
        INNER JOIN $sourceSongItemsTable s
          ON s.$columnSourceType = l.$columnSourceType
         AND s.$columnSourceSongId = l.$columnSourceSongId
        WHERE l.$columnAggregateSongId = $aggregateAlias.$columnAggregateSongId
          AND ${availability.clause}
          AND s.$columnAvailabilityStatus = 'ready'
      )
    ''';
  }

  String _encodeList(List<String> values) => jsonEncode(values);

  List<String> _decodeList(Object? rawValue) {
    if (rawValue is String && rawValue.isNotEmpty) {
      final Object? decoded = jsonDecode(rawValue);
      if (decoded is List) {
        return decoded
            .map((Object? item) => item?.toString().trim() ?? '')
            .where((String item) => item.isNotEmpty)
            .toList(growable: false);
      }
    }
    return const <String>[];
  }

  int _readInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  int _firstIntValue(List<Map<String, Object?>> rows) {
    if (rows.isEmpty || rows.first.isEmpty) {
      return 0;
    }
    return _readInt(rows.first.values.first);
  }

  Future<Database> _openDatabase() async {
    configureSqfliteFactoryForPlatform();

    if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) {
      return openDatabase(
        inMemoryDatabasePath,
        version: _databaseVersion,
        onCreate: (Database db, int version) async {
          await _createSchema(db);
        },
        onUpgrade: (Database db, int oldVersion, int newVersion) async {
          await _resetSchema(db);
        },
        onOpen: (Database db) async {
          await _ensureSchema(db);
        },
      );
    }

    final Directory supportDirectory = await getApplicationSupportDirectory();
    final String databasePath = path.join(supportDirectory.path, _databaseName);

    return openDatabase(
      databasePath,
      version: _databaseVersion,
      onCreate: (Database db, int version) async {
        await _createSchema(db);
      },
      onUpgrade: (Database db, int oldVersion, int newVersion) async {
        await _resetSchema(db);
      },
      onOpen: (Database db) async {
        await _ensureSchema(db);
      },
    );
  }

  Future<void> _createSchema(Database db) async {
    await _ensureSchema(db);
  }

  Future<void> _resetSchema(Database db) async {
    await db.execute('DROP TABLE IF EXISTS $aggregateSongLinksTable');
    await db.execute('DROP TABLE IF EXISTS $aggregateSongItemsTable');
    await db.execute('DROP TABLE IF EXISTS $sourceSongItemsTable');
    await db.execute('DROP TABLE IF EXISTS $sourceSyncStatesTable');
    await _ensureSchema(db);
  }

  Future<void> _ensureSchema(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $sourceSongItemsTable (
        $columnSourceType TEXT NOT NULL,
        $columnSourceSongId TEXT NOT NULL,
        $columnSourceRootId TEXT,
        $columnTitle TEXT NOT NULL,
        $columnArtist TEXT NOT NULL,
        $columnLanguagesJson TEXT NOT NULL DEFAULT '[]',
        $columnTagsJson TEXT NOT NULL DEFAULT '[]',
        $columnSearchIndex TEXT NOT NULL,
        $columnMediaLocator TEXT,
        $columnFileFingerprint TEXT,
        $columnFileSize INTEGER,
        $columnModifiedAt INTEGER,
        $columnAvailabilityStatus TEXT NOT NULL DEFAULT 'ready',
        $columnRawPayloadJson TEXT NOT NULL DEFAULT '{}',
        $columnUpdatedAt INTEGER NOT NULL,
        PRIMARY KEY ($columnSourceType, $columnSourceSongId)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $aggregateSongItemsTable (
        $columnAggregateSongId TEXT PRIMARY KEY,
        $columnCanonicalTitle TEXT NOT NULL,
        $columnCanonicalArtist TEXT NOT NULL,
        $columnLanguagesJson TEXT NOT NULL DEFAULT '[]',
        $columnTagsJson TEXT NOT NULL DEFAULT '[]',
        $columnSearchIndex TEXT NOT NULL,
        $columnPrimarySourceType TEXT,
        $columnPrimarySourceSongId TEXT,
        $columnUpdatedAt INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $aggregateSongLinksTable (
        $columnAggregateSongId TEXT NOT NULL,
        $columnSourceType TEXT NOT NULL,
        $columnSourceSongId TEXT NOT NULL,
        $columnSourceRootId TEXT,
        $columnMatchScore REAL NOT NULL DEFAULT 1.0,
        $columnIsPrimary INTEGER NOT NULL DEFAULT 0,
        $columnLinkedAt INTEGER NOT NULL,
        PRIMARY KEY ($columnAggregateSongId, $columnSourceType, $columnSourceSongId)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $sourceSyncStatesTable (
        $columnSourceType TEXT NOT NULL,
        $columnSourceRootId TEXT NOT NULL,
        $columnSyncToken TEXT,
        $columnLastSyncedAt INTEGER,
        $columnSyncStatus TEXT NOT NULL DEFAULT 'idle',
        $columnLastError TEXT,
        PRIMARY KEY ($columnSourceType, $columnSourceRootId)
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_source_song_root
      ON $sourceSongItemsTable($columnSourceType, $columnSourceRootId, $columnTitle, $columnArtist)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_aggregate_song_title
      ON $aggregateSongItemsTable($columnCanonicalTitle, $columnCanonicalArtist)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_aggregate_links_source
      ON $aggregateSongLinksTable($columnSourceType, $columnSourceSongId)
    ''');
  }

  Future<void> _ensureAggregateIndexHealthy() {
    if (_aggregateIndexVerified) {
      return Future<void>.value();
    }
    final Future<void> pending = _pendingAggregateIndexCheck ??=
        _verifyAndRepairAggregateIndex();
    return pending.whenComplete(() {
      if (identical(_pendingAggregateIndexCheck, pending)) {
        _pendingAggregateIndexCheck = null;
      }
    });
  }

  Future<void> _verifyAndRepairAggregateIndex() async {
    final Database db = await database;
    await _ensureSchema(db);
    await db.transaction((Transaction txn) async {
      final List<Map<String, Object?>> missingLinkRows = await txn.query(
        sourceSongItemsTable,
        columns: <String>[
          columnSourceType,
          columnSourceSongId,
          columnSourceRootId,
          columnTitle,
          columnArtist,
          columnUpdatedAt,
        ],
        where:
            '''
            $columnAvailabilityStatus = 'ready'
            AND NOT EXISTS (
              SELECT 1
              FROM $aggregateSongLinksTable l
              WHERE l.$columnSourceType = $sourceSongItemsTable.$columnSourceType
                AND l.$columnSourceSongId = $sourceSongItemsTable.$columnSourceSongId
            )
            ''',
      );
      final Set<String> aggregateIdsToRefresh = <String>{};
      final int now = DateTime.now().millisecondsSinceEpoch;
      for (final Map<String, Object?> row in missingLinkRows) {
        final String title = row[columnTitle]?.toString() ?? '';
        final String artist = row[columnArtist]?.toString() ?? '';
        if (title.isEmpty || artist.isEmpty) {
          continue;
        }
        final String aggregateSongId = buildAggregateSongId(
          title: title,
          artist: artist,
        );
        aggregateIdsToRefresh.add(aggregateSongId);
        await txn.insert(aggregateSongLinksTable, <String, Object?>{
          columnAggregateSongId: aggregateSongId,
          columnSourceType: row[columnSourceType]?.toString() ?? '',
          columnSourceSongId: row[columnSourceSongId]?.toString() ?? '',
          columnSourceRootId: row[columnSourceRootId]?.toString(),
          columnMatchScore: 1.0,
          columnIsPrimary: 0,
          columnLinkedAt: _readInt(row[columnUpdatedAt]) > 0
              ? _readInt(row[columnUpdatedAt])
              : now,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      final List<Map<String, Object?>> missingAggregateRows = await txn
          .rawQuery('''
        SELECT DISTINCT l.$columnAggregateSongId
        FROM $aggregateSongLinksTable l
        INNER JOIN $sourceSongItemsTable s
          ON s.$columnSourceType = l.$columnSourceType
         AND s.$columnSourceSongId = l.$columnSourceSongId
        LEFT JOIN $aggregateSongItemsTable a
          ON a.$columnAggregateSongId = l.$columnAggregateSongId
        WHERE s.$columnAvailabilityStatus = 'ready'
          AND a.$columnAggregateSongId IS NULL
        ''');
      aggregateIdsToRefresh.addAll(
        missingAggregateRows
            .map(
              (Map<String, Object?> row) =>
                  row[columnAggregateSongId]?.toString() ?? '',
            )
            .where((String value) => value.isNotEmpty),
      );

      final List<Map<String, Object?>> staleAggregateRows = await txn.rawQuery(
        '''
        SELECT a.$columnAggregateSongId
        FROM $aggregateSongItemsTable a
        WHERE NOT EXISTS (
          SELECT 1
          FROM $aggregateSongLinksTable l
          INNER JOIN $sourceSongItemsTable s
            ON s.$columnSourceType = l.$columnSourceType
           AND s.$columnSourceSongId = l.$columnSourceSongId
          WHERE l.$columnAggregateSongId = a.$columnAggregateSongId
            AND s.$columnAvailabilityStatus = 'ready'
        )
        ''',
      );
      aggregateIdsToRefresh.addAll(
        staleAggregateRows
            .map(
              (Map<String, Object?> row) =>
                  row[columnAggregateSongId]?.toString() ?? '',
            )
            .where((String value) => value.isNotEmpty),
      );

      for (final String aggregateSongId in aggregateIdsToRefresh) {
        await _refreshAggregateEntry(txn, aggregateSongId: aggregateSongId);
      }
    });
    _aggregateIndexVerified = true;
  }

  static String _sourcePriorityCase(String expression) {
    return "CASE $expression WHEN 'local' THEN 0 WHEN '115' THEN 1 ELSE 9 END";
  }
}

class _SqlClause {
  const _SqlClause(this.sql, this.args);

  final String sql;
  final List<Object?> args;
}
