import 'package:flutter/foundation.dart';

import '../../../core/models/artist.dart';
import '../../../core/models/artist_page.dart';
import '../../../core/models/song.dart';
import '../../../core/models/song_identity.dart';
import '../../../core/models/song_page.dart';
import 'android_storage_data_source.dart';
import 'media_index_store.dart';
import 'media_library_data_source.dart';
import 'scan_directory_data_source.dart';

class MediaLibraryRepository {
  MediaLibraryRepository({
    MediaLibraryDataSource? mediaLibraryDataSource,
    ScanDirectoryDataSource? scanDirectoryDataSource,
    AndroidStorageDataSource? androidStorageDataSource,
    MediaIndexStore? mediaIndexStore,
  }) : _mediaLibraryDataSource =
           mediaLibraryDataSource ?? MediaLibraryDataSource(),
       _scanDirectoryDataSource =
           scanDirectoryDataSource ?? ScanDirectoryDataSource(),
       _androidStorageDataSource =
           androidStorageDataSource ?? AndroidStorageDataSource(),
       _mediaIndexStore = mediaIndexStore ?? MediaIndexStore();

  final MediaLibraryDataSource _mediaLibraryDataSource;
  final ScanDirectoryDataSource _scanDirectoryDataSource;
  final AndroidStorageDataSource _androidStorageDataSource;
  final MediaIndexStore _mediaIndexStore;
  final Map<String, List<Song>> _cachedSongsByDirectory =
      <String, List<Song>>{};

  MediaIndexStore get mediaIndexStore => _mediaIndexStore;

  Future<String?> pickDirectory({String? initialDirectory}) {
    return _scanDirectoryDataSource.pickDirectory(
      initialDirectory: initialDirectory,
    );
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
      _cachedSongsByDirectory.remove(directory);
      return _androidStorageDataSource.scanLibraryIntoIndex(directory);
    }

    final Map<String, CachedLocalSongFingerprint> fingerprintCache =
        await _mediaIndexStore.loadLocalFingerprintCache(
          sourceRootId: directory,
        );
    final List<LibrarySong> songs = await _mediaLibraryDataSource.scanLibrary(
      directory,
      cachedFingerprintsByPath: fingerprintCache,
    );
    final int count = await _mediaIndexStore.replaceLocalSongs(
      sourceRootId: directory,
      songs: songs,
    );
    final List<Song> mappedSongs = songs
        .map(_mapLibrarySong)
        .toList(growable: false);
    _cachedSongsByDirectory[directory] = mappedSongs;
    return count;
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

    if (_usesIndexedAndroidLibrary(directory)) {
      return _androidStorageDataSource.queryIndexedSongs(
        rootUri: directory,
        language: normalizedLanguage,
        artist: normalizedArtist,
        searchQuery: normalizedQuery,
        pageIndex: normalizedPageIndex,
        pageSize: normalizedPageSize,
      );
    }

    final List<Song> songs = await _loadOrRestoreLocalSongs(directory);
    final List<Song> filteredSongs = _filterSongs(
      songs,
      language: normalizedLanguage,
      artist: normalizedArtist,
      searchQuery: normalizedQuery,
    );
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

    if (_usesIndexedAndroidLibrary(directory)) {
      final List<AndroidLibrarySong> songs = await _androidStorageDataSource
          .scanLibrary(directory);
      final List<Song> mappedSongs =
          songs.map(_mapAndroidSong).toList(growable: false)
            ..sort(_compareSongs);
      _cachedSongsByDirectory[directory] = mappedSongs;
      return mappedSongs;
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

    if (_usesIndexedAndroidLibrary(directory)) {
      return _androidStorageDataSource.queryIndexedArtists(
        rootUri: directory,
        language: normalizedLanguage,
        searchQuery: normalizedQuery,
        pageIndex: normalizedPageIndex,
        pageSize: normalizedPageSize,
      );
    }

    final List<Song> songs = await _loadOrRestoreLocalSongs(directory);
    final List<Artist> artists = _buildArtistsFromSongs(
      songs,
      language: normalizedLanguage,
      searchQuery: normalizedQuery,
    );
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

  Song _mapAndroidSong(AndroidLibrarySong song) {
    final String title = song.title;
    final String artist = song.artist;
    final String raw = '$title $artist ${song.fileName} ${song.extension}'
        .toLowerCase();
    return Song(
      songId: buildAggregateSongId(title: title, artist: artist),
      sourceId: 'local',
      sourceSongId: buildLocalSourceSongId(
        fingerprint: buildLocalMetadataFingerprint(
          locator: song.mediaPath.isNotEmpty ? song.mediaPath : song.fileName,
        ),
      ),
      title: title,
      artist: artist,
      languages: const <String>['其它'],
      tags: const <String>[],
      searchIndex: raw,
      mediaPath: song.mediaPath,
    );
  }

  int _compareSongs(Song left, Song right) {
    final int titleCompare = left.title.compareTo(right.title);
    if (titleCompare != 0) {
      return titleCompare;
    }
    return left.artist.compareTo(right.artist);
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
          return song.searchIndex.contains(searchQuery);
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
              return item.searchIndex.contains(searchQuery);
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
