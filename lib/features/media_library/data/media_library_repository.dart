import 'package:flutter/foundation.dart';
import 'package:file_selector/file_selector.dart';

import '../../../core/models/artist.dart';
import '../../../core/models/artist_page.dart';
import '../../../core/models/song.dart';
import '../../../core/models/song_identity.dart';
import '../../../core/models/song_page.dart';
import '../../../core/search/song_search_matcher.dart';
import 'android_storage_data_source.dart';
import 'media_index_store.dart';
import 'media_library_data_source.dart';
import 'scan_directory_data_source.dart';

class MediaLibraryRepository {
  factory MediaLibraryRepository({
    MediaLibraryDataSource? mediaLibraryDataSource,
    ScanDirectoryDataSource? scanDirectoryDataSource,
    AndroidStorageDataSource? androidStorageDataSource,
    MediaIndexStore? mediaIndexStore,
  }) {
    final MediaIndexStore resolvedMediaIndexStore =
        mediaIndexStore ?? MediaIndexStore();
    final AndroidStorageDataSource resolvedAndroidStorageDataSource =
        androidStorageDataSource ?? AndroidStorageDataSource();
    return MediaLibraryRepository._(
      mediaLibraryDataSource:
          mediaLibraryDataSource ?? MediaLibraryDataSource(),
      scanDirectoryDataSource:
          scanDirectoryDataSource ??
          ScanDirectoryDataSource(
            androidStorageDataSource: resolvedAndroidStorageDataSource,
            mediaIndexStore: resolvedMediaIndexStore,
          ),
      androidStorageDataSource: resolvedAndroidStorageDataSource,
      mediaIndexStore: resolvedMediaIndexStore,
    );
  }

  MediaLibraryRepository._({
    required MediaLibraryDataSource mediaLibraryDataSource,
    required ScanDirectoryDataSource scanDirectoryDataSource,
    required AndroidStorageDataSource androidStorageDataSource,
    required MediaIndexStore mediaIndexStore,
  }) : _mediaLibraryDataSource = mediaLibraryDataSource,
       _scanDirectoryDataSource = scanDirectoryDataSource,
       _androidStorageDataSource = androidStorageDataSource,
       _mediaIndexStore = mediaIndexStore;

  final MediaLibraryDataSource _mediaLibraryDataSource;
  final ScanDirectoryDataSource _scanDirectoryDataSource;
  final AndroidStorageDataSource _androidStorageDataSource;
  final MediaIndexStore _mediaIndexStore;
  final Map<String, List<Song>> _cachedSongsByDirectory =
      <String, List<Song>>{};
  _SongFilterSnapshot? _songFilterSnapshot;
  _ArtistFilterSnapshot? _artistFilterSnapshot;

  MediaIndexStore get mediaIndexStore => _mediaIndexStore;

  Future<String?> pickDirectory({String? initialDirectory}) {
    return _scanDirectoryDataSource.pickDirectory(
      initialDirectory: initialDirectory,
    );
  }

  Future<List<XFile>> pickImportFiles({String? initialDirectory}) {
    return _scanDirectoryDataSource.pickImportFiles(
      initialDirectory: initialDirectory,
    );
  }

  Future<String?> importPickedFiles(List<XFile> selectedFiles) {
    return _scanDirectoryDataSource.importPickedFiles(selectedFiles);
  }

  Future<bool> ensureDirectoryAccess(String path) {
    return _scanDirectoryDataSource.ensureDirectoryAccess(path);
  }

  Future<void> clearDirectoryAccess({String? path}) {
    return _scanDirectoryDataSource.clearDirectoryAccess(path: path);
  }

  Future<void> saveSelectedDirectory(String path) {
    return _scanDirectoryDataSource.saveSelectedDirectory(path);
  }

  Future<String?> loadSelectedDirectory() {
    return _scanDirectoryDataSource.loadSelectedDirectory();
  }

  Future<void> markSourceConfigured({
    required String sourceType,
    required String sourceRootId,
  }) {
    return _mediaIndexStore.upsertSourceSyncState(
      sourceType: sourceType,
      sourceRootId: sourceRootId,
    );
  }

  Future<bool> hasConfiguredAggregatedSources({String? localDirectory}) async {
    if (localDirectory != null && localDirectory.trim().isNotEmpty) {
      return true;
    }
    return _mediaIndexStore.hasConfiguredAggregateSources(
      activeLocalRootId: localDirectory,
    );
  }

  Future<int> scanLibrary(String directory) async {
    if (_usesIndexedAndroidLibrary(directory)) {
      final List<AndroidLibrarySong> androidSongs =
          await _androidStorageDataSource.scanLibrary(directory);
      return _replaceLocalSongs(
        sourceRootId: directory,
        songs: androidSongs
            .map(_mapIndexedAndroidLibrarySong)
            .toList(growable: false),
      );
    }

    final Map<String, CachedLocalSongFingerprint> fingerprintCache =
        await _mediaIndexStore.loadLocalFingerprintCache(
          sourceRootId: directory,
        );
    final List<LibrarySong> songs = await _mediaLibraryDataSource.scanLibrary(
      directory,
      cachedFingerprintsByPath: fingerprintCache,
    );
    return _replaceLocalSongs(sourceRootId: directory, songs: songs);
  }

  Future<SongPage> querySongs({
    required String directory,
    required int pageIndex,
    required int pageSize,
    String? language,
    String? artist,
    String searchQuery = '',
  }) async {
    final int normalizedPageIndex = pageIndex < 0 ? 0 : pageIndex;
    final int normalizedPageSize = pageSize <= 0 ? 1 : pageSize;
    final String normalizedLanguage = (language ?? '').trim();
    final String normalizedArtist = (artist ?? '').trim();
    final String normalizedQuery = searchQuery.trim().toLowerCase();

    final List<Song> songs = await _loadOrRestoreLocalSongs(directory);
    final _SongFilterSnapshot? cachedSnapshot = _songFilterSnapshot;
    final List<Song> filteredSongs;
    if (cachedSnapshot != null &&
        cachedSnapshot.matches(
          directory: directory,
          sourceSongs: songs,
          language: normalizedLanguage,
          artist: normalizedArtist,
          searchQuery: normalizedQuery,
        )) {
      filteredSongs = cachedSnapshot.songs;
    } else {
      filteredSongs = _filterSongs(
        songs,
        language: normalizedLanguage,
        artist: normalizedArtist,
        searchQuery: normalizedQuery,
      );
      _songFilterSnapshot = _SongFilterSnapshot(
        directory: directory,
        sourceSongs: songs,
        language: normalizedLanguage,
        artist: normalizedArtist,
        searchQuery: normalizedQuery,
        songs: filteredSongs,
      );
    }
    return _buildSongPage(
      filteredSongs,
      pageIndex: normalizedPageIndex,
      pageSize: normalizedPageSize,
    );
  }

  Future<List<Song>> loadAllSongs({required String directory}) async {
    final List<Song>? cachedSongs = _cachedSongsByDirectory[directory];
    if (cachedSongs != null) {
      return cachedSongs;
    }
    return _loadOrRestoreLocalSongs(directory);
  }

  Future<List<Song>> getSongsByIds({
    required String directory,
    required List<String> songIds,
  }) async {
    if (songIds.isEmpty) {
      return const <Song>[];
    }

    final List<Song> songs = await loadAllSongs(directory: directory);
    final Map<String, Song> songsById = <String, Song>{
      for (final Song song in songs) song.songId: song,
    };
    return songIds
        .map((String songId) => songsById[songId])
        .whereType<Song>()
        .toList(growable: false);
  }

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

  Future<ArtistPage> queryArtists({
    required String directory,
    required int pageIndex,
    required int pageSize,
    String? language,
    String searchQuery = '',
  }) async {
    final int normalizedPageIndex = pageIndex < 0 ? 0 : pageIndex;
    final int normalizedPageSize = pageSize <= 0 ? 1 : pageSize;
    final String normalizedLanguage = (language ?? '').trim();
    final String normalizedQuery = searchQuery.trim().toLowerCase();

    final List<Song> songs = await _loadOrRestoreLocalSongs(directory);
    final _ArtistFilterSnapshot? cachedSnapshot = _artistFilterSnapshot;
    final List<Artist> artists;
    if (cachedSnapshot != null &&
        cachedSnapshot.matches(
          directory: directory,
          sourceSongs: songs,
          language: normalizedLanguage,
          searchQuery: normalizedQuery,
        )) {
      artists = cachedSnapshot.artists;
    } else {
      artists = _buildArtistsFromSongs(
        songs,
        language: normalizedLanguage,
        searchQuery: normalizedQuery,
      );
      _artistFilterSnapshot = _ArtistFilterSnapshot(
        directory: directory,
        sourceSongs: songs,
        language: normalizedLanguage,
        searchQuery: normalizedQuery,
        artists: artists,
      );
    }
    return _buildArtistPage(
      artists,
      pageIndex: normalizedPageIndex,
      pageSize: normalizedPageSize,
    );
  }

  Future<List<Song>> loadAggregatedSongs({String? localDirectory}) {
    return _mediaIndexStore.loadAggregateSongs(
      activeLocalRootId: localDirectory,
    );
  }

  Future<SongPage> queryAggregatedSongs({
    required int pageIndex,
    required int pageSize,
    String? localDirectory,
    String? language,
    String? artist,
    String searchQuery = '',
  }) {
    return _mediaIndexStore.queryAggregateSongs(
      pageIndex: pageIndex,
      pageSize: pageSize,
      activeLocalRootId: localDirectory,
      language: (language ?? '').trim(),
      artist: (artist ?? '').trim(),
      searchQuery: searchQuery.trim().toLowerCase(),
    );
  }

  Future<ArtistPage> queryAggregatedArtists({
    required int pageIndex,
    required int pageSize,
    String? localDirectory,
    String? language,
    String searchQuery = '',
  }) {
    return _mediaIndexStore.queryAggregateArtists(
      pageIndex: pageIndex,
      pageSize: pageSize,
      activeLocalRootId: localDirectory,
      language: (language ?? '').trim(),
      searchQuery: searchQuery.trim().toLowerCase(),
    );
  }

  Future<List<Song>> getAggregatedSongsByIds({
    required List<String> songIds,
    String? localDirectory,
  }) {
    return _mediaIndexStore.loadAggregateSongsByIds(
      aggregateSongIds: songIds,
      activeLocalRootId: localDirectory,
    );
  }

  Future<Song?> getAggregatedSongById({
    required String songId,
    String? localDirectory,
  }) async {
    final List<Song> songs = await getAggregatedSongsByIds(
      songIds: <String>[songId],
      localDirectory: localDirectory,
    );
    if (songs.isEmpty) {
      return null;
    }
    return songs.first;
  }

  Future<List<Song>> _loadOrRestoreLocalSongs(String directory) async {
    final List<Song>? cachedSongs = _cachedSongsByDirectory[directory];
    if (cachedSongs != null) {
      return cachedSongs;
    }
    final List<Song> storedSongs = await _mediaIndexStore.loadLocalSongs(
      sourceRootId: directory,
    );
    if (storedSongs.isNotEmpty) {
      _cachedSongsByDirectory[directory] = storedSongs;
      return storedSongs;
    }
    await scanLibrary(directory);
    return _cachedSongsByDirectory[directory] ?? const <Song>[];
  }

  Song _mapLibrarySong(LibrarySong song) {
    return Song(
      songId: buildAggregateSongId(title: song.title, artist: song.artist),
      sourceId: 'local',
      sourceSongId: song.sourceSongId,
      title: song.title,
      artist: song.artist,
      languages: song.languages,
      tags: song.tags,
      searchIndex: song.searchIndex,
      mediaPath: song.mediaPath,
    );
  }

  LibrarySong _mapIndexedAndroidLibrarySong(AndroidLibrarySong song) {
    final String title = song.title;
    final String artist = song.artist;
    final String safeExtension = song.extension.trim().isEmpty
        ? 'mp4'
        : song.extension.trim().toLowerCase();
    final String fallbackFileName = '$artist - $title.$safeExtension';
    final String fileName = song.fileName.trim().isEmpty
        ? fallbackFileName
        : song.fileName.trim();
    final String locator = song.mediaPath.trim().isNotEmpty
        ? song.mediaPath.trim()
        : '$artist/$fileName';
    final String raw = '$title $artist $fileName $safeExtension'.toLowerCase();
    return _IndexedAndroidLibrarySong(
      title: title,
      artist: artist,
      mediaPath: song.mediaPath,
      fileName: fileName,
      relativePath: fileName,
      fileSize: 0,
      modifiedAtMillis: 0,
      sourceFingerprint: buildLocalMetadataFingerprint(locator: locator),
      extension: safeExtension,
      searchIndexOverride: raw,
    );
  }

  Future<int> _replaceLocalSongs({
    required String sourceRootId,
    required List<LibrarySong> songs,
  }) async {
    final int count = await _mediaIndexStore.replaceLocalSongs(
      sourceRootId: sourceRootId,
      songs: songs,
    );
    _cachedSongsByDirectory[sourceRootId] = songs
        .map(_mapLibrarySong)
        .toList(growable: false);
    if (_songFilterSnapshot?.directory == sourceRootId) {
      _songFilterSnapshot = null;
    }
    if (_artistFilterSnapshot?.directory == sourceRootId) {
      _artistFilterSnapshot = null;
    }
    return count;
  }

  bool _usesIndexedAndroidLibrary(String directory) {
    return !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        _androidStorageDataSource.isDocumentTreeUri(directory);
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

  List<Song> _filterSongs(
    List<Song> songs, {
    required String language,
    required String artist,
    required String searchQuery,
  }) {
    return songs
        .where((Song song) {
          if (language.isNotEmpty && !song.languages.contains(language)) {
            return false;
          }
          if (artist.isNotEmpty &&
              !_extractArtistNames(song.artist).contains(artist)) {
            return false;
          }
          if (searchQuery.isEmpty) {
            return true;
          }
          return matchesSongSearch(song, searchQuery);
        })
        .toList(growable: false);
  }

  List<Artist> _buildArtistsFromSongs(
    List<Song> songs, {
    required String language,
    required String searchQuery,
  }) {
    final Map<String, int> songCountByArtist = <String, int>{};
    for (final Song song in songs) {
      if (language.isNotEmpty && !song.languages.contains(language)) {
        continue;
      }
      for (final String artistName in _extractArtistNames(song.artist)) {
        songCountByArtist.update(
          artistName,
          (int count) => count + 1,
          ifAbsent: () => 1,
        );
      }
    }
    final List<Artist> artists =
        songCountByArtist.entries
            .map(
              (MapEntry<String, int> entry) => Artist(
                name: entry.key,
                songCount: entry.value,
                searchIndex: entry.key.toLowerCase(),
              ),
            )
            .where((Artist item) {
              if (searchQuery.isEmpty) {
                return true;
              }
              return matchesTextSearch(
                item.name,
                searchQuery,
                exactSearchIndex: item.searchIndex,
              );
            })
            .toList(growable: false)
          ..sort(
            (Artist left, Artist right) => left.name.compareTo(right.name),
          );
    return artists;
  }

  SongPage _buildSongPage(
    List<Song> songs, {
    required int pageIndex,
    required int pageSize,
  }) {
    final int normalizedPageIndex = pageIndex < 0 ? 0 : pageIndex;
    final int normalizedPageSize = pageSize <= 0 ? 1 : pageSize;
    final int start = normalizedPageIndex * normalizedPageSize;
    final int end = (start + normalizedPageSize).clamp(0, songs.length);
    return SongPage(
      songs: start >= songs.length ? const <Song>[] : songs.sublist(start, end),
      totalCount: songs.length,
      pageIndex: normalizedPageIndex,
      pageSize: normalizedPageSize,
    );
  }

  ArtistPage _buildArtistPage(
    List<Artist> artists, {
    required int pageIndex,
    required int pageSize,
  }) {
    final int normalizedPageIndex = pageIndex < 0 ? 0 : pageIndex;
    final int normalizedPageSize = pageSize <= 0 ? 1 : pageSize;
    final int start = normalizedPageIndex * normalizedPageSize;
    final int end = (start + normalizedPageSize).clamp(0, artists.length);
    return ArtistPage(
      artists: start >= artists.length
          ? const <Artist>[]
          : artists.sublist(start, end),
      totalCount: artists.length,
      pageIndex: normalizedPageIndex,
      pageSize: normalizedPageSize,
    );
  }
}

class _SongFilterSnapshot {
  const _SongFilterSnapshot({
    required this.directory,
    required this.sourceSongs,
    required this.language,
    required this.artist,
    required this.searchQuery,
    required this.songs,
  });

  final String directory;
  final List<Song> sourceSongs;
  final String language;
  final String artist;
  final String searchQuery;
  final List<Song> songs;

  bool matches({
    required String directory,
    required List<Song> sourceSongs,
    required String language,
    required String artist,
    required String searchQuery,
  }) {
    return this.directory == directory &&
        identical(this.sourceSongs, sourceSongs) &&
        this.language == language &&
        this.artist == artist &&
        this.searchQuery == searchQuery;
  }
}

class _ArtistFilterSnapshot {
  const _ArtistFilterSnapshot({
    required this.directory,
    required this.sourceSongs,
    required this.language,
    required this.searchQuery,
    required this.artists,
  });

  final String directory;
  final List<Song> sourceSongs;
  final String language;
  final String searchQuery;
  final List<Artist> artists;

  bool matches({
    required String directory,
    required List<Song> sourceSongs,
    required String language,
    required String searchQuery,
  }) {
    return this.directory == directory &&
        identical(this.sourceSongs, sourceSongs) &&
        this.language == language &&
        this.searchQuery == searchQuery;
  }
}

class _IndexedAndroidLibrarySong extends LibrarySong {
  const _IndexedAndroidLibrarySong({
    required super.title,
    required super.artist,
    required super.mediaPath,
    required super.fileName,
    required super.relativePath,
    required super.fileSize,
    required super.modifiedAtMillis,
    required super.sourceFingerprint,
    required super.extension,
    required this.searchIndexOverride,
  });

  final String searchIndexOverride;

  @override
  String get searchIndex => searchIndexOverride;
}
