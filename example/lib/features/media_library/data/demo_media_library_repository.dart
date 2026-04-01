import 'package:flutter/foundation.dart';

import '../../../core/models/demo_song.dart';
import '../../../core/models/demo_song_page.dart';
import 'android_storage_data_source.dart';
import 'media_library_data_source.dart';
import 'scan_directory_data_source.dart';

class DemoMediaLibraryRepository {
  DemoMediaLibraryRepository({
    DemoMediaLibraryDataSource? mediaLibraryDataSource,
    DemoScanDirectoryDataSource? scanDirectoryDataSource,
  }) : _mediaLibraryDataSource =
           mediaLibraryDataSource ?? DemoMediaLibraryDataSource(),
       _scanDirectoryDataSource =
           scanDirectoryDataSource ?? DemoScanDirectoryDataSource();

  final DemoMediaLibraryDataSource _mediaLibraryDataSource;
  final DemoScanDirectoryDataSource _scanDirectoryDataSource;
  final DemoAndroidStorageDataSource _androidStorageDataSource =
      DemoAndroidStorageDataSource();
  final Map<String, List<DemoSong>> _cachedSongsByDirectory =
      <String, List<DemoSong>>{};

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

  Future<int> scanLibrary(String directory) async {
    if (!kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        _androidStorageDataSource.isDocumentTreeUri(directory)) {
      return _androidStorageDataSource.scanLibraryIntoIndex(directory);
    }

    final List<DemoLibrarySong> songs = await _mediaLibraryDataSource
        .scanLibrary(directory);
    final List<DemoSong> mappedSongs = songs
        .map(
          (DemoLibrarySong song) => DemoSong(
            title: song.title,
            artist: song.artist,
            language: song.language,
            searchIndex: song.searchIndex,
            mediaPath: song.mediaPath,
          ),
        )
        .toList(growable: false);
    _cachedSongsByDirectory[directory] = mappedSongs;
    return mappedSongs.length;
  }

  Future<DemoSongPage> querySongs({
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

    if (!kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        _androidStorageDataSource.isDocumentTreeUri(directory)) {
      return _androidStorageDataSource.queryIndexedSongs(
        rootUri: directory,
        language: normalizedLanguage,
        searchQuery: normalizedQuery,
        pageIndex: normalizedPageIndex,
        pageSize: normalizedPageSize,
      );
    }

    final List<DemoSong> cachedSongs =
        _cachedSongsByDirectory[directory] ??
        await _scanAndCacheDirectory(directory);
    final List<DemoSong> filteredSongs =
        cachedSongs.where((DemoSong song) {
          if (normalizedLanguage.isNotEmpty &&
              song.language != normalizedLanguage) {
            return false;
          }
          if (normalizedQuery.isEmpty) {
            return true;
          }
          return song.searchIndex.contains(normalizedQuery);
        }).toList(growable: false);
    final int start = normalizedPageIndex * normalizedPageSize;
    final int end = (start + normalizedPageSize).clamp(0, filteredSongs.length);
    final List<DemoSong> pageSongs = start >= filteredSongs.length
        ? const <DemoSong>[]
        : filteredSongs.sublist(start, end);
    return DemoSongPage(
      songs: pageSongs,
      totalCount: filteredSongs.length,
      pageIndex: normalizedPageIndex,
      pageSize: normalizedPageSize,
    );
  }

  Future<List<DemoSong>> _scanAndCacheDirectory(String directory) async {
    await scanLibrary(directory);
    return _cachedSongsByDirectory[directory] ?? const <DemoSong>[];
  }
}
