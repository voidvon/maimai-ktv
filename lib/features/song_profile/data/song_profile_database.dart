import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../core/models/song_identity.dart';
import '../../../core/persistence/sqflite_factory.dart';

class SongProfileDatabase {
  SongProfileDatabase();

  static const String tableName = 'song_profiles';
  static const String columnSongId = 'song_id';
  static const String columnSourceId = 'source_id';
  static const String columnSourceSongId = 'source_song_id';
  static const String columnMediaPath = 'media_path';
  static const String columnDirectoryPath = 'directory_path';
  static const String columnTitle = 'title';
  static const String columnArtist = 'artist';
  static const String columnLanguages = 'languages';
  static const String columnTags = 'tags';
  static const String columnSearchIndex = 'search_index';
  static const String columnIsFavorite = 'is_favorite';
  static const String columnFavoritedAt = 'favorited_at';
  static const String columnPlayCount = 'play_count';
  static const String columnLastPlayedAt = 'last_played_at';
  static const String columnLastRequestedAt = 'last_requested_at';
  static const String columnUpdatedAt = 'updated_at';

  Future<Database>? _database;

  Future<Database> get database => _database ??= _openDatabase();

  Future<void> close() async {
    final Future<Database>? databaseFuture = _database;
    _database = null;
    if (databaseFuture == null) {
      return;
    }
    final Database openedDatabase = await databaseFuture;
    await openedDatabase.close();
  }

  Future<Database> _openDatabase() async {
    configureSqfliteFactoryForPlatform();

    final Directory supportDirectory = await getApplicationSupportDirectory();
    final String databasePath = path.join(
      supportDirectory.path,
      'ktv_song_profiles.db',
    );

    return openDatabase(
      databasePath,
      version: 3,
      onCreate: (Database db, int version) async {
        await _createSchema(db);
      },
      onUpgrade: (Database db, int oldVersion, int newVersion) async {
        if (oldVersion < 2) {
          final List<Map<String, Object?>> oldRows = await db.query(tableName);
          final Map<String, Map<String, Object?>> mergedRows =
              <String, Map<String, Object?>>{};
          for (final Map<String, Object?> row in oldRows) {
            final String title = row[columnTitle]?.toString() ?? '';
            final String artist = row[columnArtist]?.toString() ?? '';
            if (title.isEmpty || artist.isEmpty) {
              continue;
            }
            final String songId = buildAggregateSongId(
              title: title,
              artist: artist,
            );
            final Map<String, Object?> nextValues = <String, Object?>{
              columnSongId: songId,
              columnSourceId: 'local',
              columnSourceSongId: buildLocalSourceSongId(
                fingerprint: buildLocalMetadataFingerprint(
                  locator: row[columnMediaPath]?.toString() ?? '$artist/$title',
                ),
              ),
              columnMediaPath: row[columnMediaPath]?.toString() ?? '',
              columnDirectoryPath: row[columnDirectoryPath]?.toString() ?? '',
              columnTitle: title,
              columnArtist: artist,
              columnLanguages: row[columnLanguages]?.toString() ?? '',
              columnTags: row[columnTags]?.toString() ?? '',
              columnSearchIndex: row[columnSearchIndex]?.toString() ?? '',
              columnIsFavorite: _readInt(row[columnIsFavorite]) > 0 ? 1 : 0,
              columnFavoritedAt: row[columnFavoritedAt],
              columnPlayCount: _readInt(row[columnPlayCount]),
              columnLastPlayedAt: row[columnLastPlayedAt],
              columnLastRequestedAt: row[columnLastRequestedAt],
              columnUpdatedAt: _readInt(row[columnUpdatedAt]),
            };
            final Map<String, Object?>? existing = mergedRows[songId];
            if (existing == null) {
              mergedRows[songId] = nextValues;
              continue;
            }
            mergedRows[songId] = <String, Object?>{
              columnSongId: songId,
              columnSourceId: 'local',
              columnSourceSongId: _pickString(
                existing[columnSourceSongId],
                nextValues[columnSourceSongId],
              ),
              columnMediaPath: _pickString(
                existing[columnMediaPath],
                nextValues[columnMediaPath],
              ),
              columnDirectoryPath: _pickString(
                existing[columnDirectoryPath],
                nextValues[columnDirectoryPath],
              ),
              columnTitle: title,
              columnArtist: artist,
              columnLanguages: _pickString(
                existing[columnLanguages],
                nextValues[columnLanguages],
              ),
              columnTags: _pickString(
                existing[columnTags],
                nextValues[columnTags],
              ),
              columnSearchIndex: _pickString(
                existing[columnSearchIndex],
                nextValues[columnSearchIndex],
              ),
              columnIsFavorite:
                  _readInt(existing[columnIsFavorite]) > 0 ||
                      _readInt(nextValues[columnIsFavorite]) > 0
                  ? 1
                  : 0,
              columnFavoritedAt: _maxNullableInt(
                existing[columnFavoritedAt],
                nextValues[columnFavoritedAt],
              ),
              columnPlayCount:
                  _readInt(existing[columnPlayCount]) +
                  _readInt(nextValues[columnPlayCount]),
              columnLastPlayedAt: _maxNullableInt(
                existing[columnLastPlayedAt],
                nextValues[columnLastPlayedAt],
              ),
              columnLastRequestedAt: _maxNullableInt(
                existing[columnLastRequestedAt],
                nextValues[columnLastRequestedAt],
              ),
              columnUpdatedAt: _maxInt(
                existing[columnUpdatedAt],
                nextValues[columnUpdatedAt],
              ),
            };
          }

          await db.execute('DROP TABLE $tableName');
          await _createSchema(db);
          final Batch batch = db.batch();
          for (final Map<String, Object?> row in mergedRows.values) {
            batch.insert(tableName, row);
          }
          await batch.commit(noResult: true);
        }
        if (oldVersion == 2) {
          await db.execute('''
            ALTER TABLE $tableName
            ADD COLUMN $columnSourceSongId TEXT NOT NULL DEFAULT ''
          ''');
          final List<Map<String, Object?>> rows = await db.query(
            tableName,
            columns: <String>[columnSongId, columnSourceId, columnMediaPath],
          );
          final Batch batch = db.batch();
          for (final Map<String, Object?> row in rows) {
            final String sourceId = row[columnSourceId]?.toString() ?? 'local';
            final String mediaPath = row[columnMediaPath]?.toString() ?? '';
            batch.update(
              tableName,
              <String, Object?>{
                columnSourceSongId: sourceId == 'local'
                    ? buildLocalSourceSongId(
                        fingerprint: buildLocalMetadataFingerprint(
                          locator: mediaPath.isNotEmpty
                              ? mediaPath
                              : row[columnSongId]?.toString() ?? '',
                        ),
                      )
                    : row[columnSongId]?.toString() ?? '',
              },
              where: '$columnSongId = ?',
              whereArgs: <Object?>[row[columnSongId]],
            );
          }
          await batch.commit(noResult: true);
        }
      },
    );
  }

  Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE $tableName (
        $columnSongId TEXT PRIMARY KEY,
        $columnSourceId TEXT NOT NULL DEFAULT 'local',
        $columnSourceSongId TEXT NOT NULL DEFAULT '',
        $columnMediaPath TEXT,
        $columnDirectoryPath TEXT NOT NULL,
        $columnTitle TEXT NOT NULL,
        $columnArtist TEXT NOT NULL,
        $columnLanguages TEXT NOT NULL,
        $columnTags TEXT NOT NULL,
        $columnSearchIndex TEXT NOT NULL,
        $columnIsFavorite INTEGER NOT NULL DEFAULT 0,
        $columnFavoritedAt INTEGER,
        $columnPlayCount INTEGER NOT NULL DEFAULT 0,
        $columnLastPlayedAt INTEGER,
        $columnLastRequestedAt INTEGER,
        $columnUpdatedAt INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE INDEX song_profiles_favorite_idx
      ON $tableName($columnIsFavorite, $columnFavoritedAt)
    ''');
    await db.execute('''
      CREATE INDEX song_profiles_frequent_idx
      ON $tableName($columnPlayCount, $columnLastPlayedAt)
    ''');
  }

  static int _readInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int _maxInt(Object? left, Object? right) {
    final int leftValue = _readInt(left);
    final int rightValue = _readInt(right);
    return leftValue >= rightValue ? leftValue : rightValue;
  }

  static int? _maxNullableInt(Object? left, Object? right) {
    final int? leftValue = int.tryParse(left?.toString() ?? '');
    final int? rightValue = int.tryParse(right?.toString() ?? '');
    if (leftValue == null) {
      return rightValue;
    }
    if (rightValue == null) {
      return leftValue;
    }
    return leftValue >= rightValue ? leftValue : rightValue;
  }

  static String _pickString(Object? left, Object? right) {
    final String leftValue = left?.toString().trim() ?? '';
    if (leftValue.isNotEmpty) {
      return leftValue;
    }
    return right?.toString().trim() ?? '';
  }
}
