import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../core/models/demo_artist.dart';
import '../../../core/models/demo_artist_page.dart';
import '../../../core/models/demo_song.dart';
import '../../../core/models/demo_song_page.dart';

class DemoAndroidStorageDataSource {
  static const MethodChannel _channel = MethodChannel(
    'ktv2_example/android_storage',
  );

  bool isDocumentTreeUri(String path) => path.startsWith('content://');

  Future<String?> pickDirectory({String? initialDirectory}) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return null;
    }

    final String? selectedUri = await _channel.invokeMethod<String>(
      'pickDirectory',
      <String, Object?>{'initialDirectory': initialDirectory},
    );
    if (selectedUri == null || selectedUri.trim().isEmpty) {
      return null;
    }
    return selectedUri;
  }

  Future<bool> ensureDirectoryAccess(String path) async {
    if (kIsWeb ||
        defaultTargetPlatform != TargetPlatform.android ||
        !isDocumentTreeUri(path)) {
      return true;
    }

    final bool? accessible = await _channel.invokeMethod<bool>(
      'ensureDirectoryAccess',
      <String, Object?>{'path': path},
    );
    return accessible ?? false;
  }

  Future<void> clearDirectoryAccess({String? path}) async {
    if (kIsWeb ||
        defaultTargetPlatform != TargetPlatform.android ||
        path == null ||
        !isDocumentTreeUri(path)) {
      return;
    }

    await _channel.invokeMethod<void>('clearDirectoryAccess', <String, Object?>{
      'path': path,
    });
  }

  Future<void> saveSelectedDirectory(String path) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }

    await _channel.invokeMethod<void>(
      'saveSelectedDirectory',
      <String, Object?>{'path': path},
    );
  }

  Future<String?> loadSelectedDirectory() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return null;
    }

    final String? path = await _channel.invokeMethod<String>(
      'loadSelectedDirectory',
    );
    if (path == null || path.trim().isEmpty) {
      return null;
    }
    return path;
  }

  Future<List<DemoAndroidLibrarySong>> scanLibrary(String rootUri) async {
    final List<dynamic>? result = await _channel.invokeMethod<List<dynamic>>(
      'scanLibrary',
      <String, Object?>{'rootUri': rootUri},
    );

    final List<DemoAndroidLibrarySong> songs = <DemoAndroidLibrarySong>[];
    for (final dynamic item in result ?? const <dynamic>[]) {
      if (item is! Map) {
        continue;
      }

      final Map<Object?, Object?> map = Map<Object?, Object?>.from(item);
      songs.add(
        DemoAndroidLibrarySong(
          title: (map['title'] as String?) ?? '未知歌曲',
          artist: (map['artist'] as String?) ?? '未识别歌手',
          mediaPath: (map['filePath'] as String?) ?? '',
          fileName: (map['fileName'] as String?) ?? '',
          extension: (map['extension'] as String?) ?? '',
        ),
      );
    }
    return songs;
  }

  Future<int> scanLibraryIntoIndex(String rootUri) async {
    final int? indexedCount = await _channel.invokeMethod<int>(
      'scanLibraryIntoIndex',
      <String, Object?>{'rootUri': rootUri},
    );
    return indexedCount ?? 0;
  }

  Future<DemoSongPage> queryIndexedSongs({
    required String rootUri,
    required int pageIndex,
    required int pageSize,
    String language = '',
    String artist = '',
    String searchQuery = '',
  }) async {
    final Map<dynamic, dynamic>? result = await _channel
        .invokeMethod<Map<dynamic, dynamic>>(
          'queryIndexedSongs',
          <String, Object?>{
            'rootUri': rootUri,
            'pageIndex': pageIndex,
            'pageSize': pageSize,
            'language': language,
            'artist': artist,
            'searchQuery': searchQuery,
          },
        );

    final Map<Object?, Object?> pageMap = Map<Object?, Object?>.from(
      result ?? const <Object?, Object?>{},
    );
    final List<dynamic> items =
        (pageMap['songs'] as List<dynamic>?) ?? const <dynamic>[];
    final List<DemoSong> songs = items
        .whereType<Map>()
        .map((Map item) {
          final Map<Object?, Object?> map = Map<Object?, Object?>.from(item);
          final List<String> languages = _parseStringList(map['languages']);
          final List<String> tags = _parseStringList(map['tags']);
          return DemoSong(
            title: (map['title'] as String?) ?? '未知歌曲',
            artist: (map['artist'] as String?) ?? '未识别歌手',
            languages: languages.isEmpty
                ? <String>[(map['language'] as String?) ?? '其它']
                : languages,
            tags: tags,
            searchIndex: (map['searchIndex'] as String?) ?? '',
            mediaPath: (map['mediaPath'] as String?) ?? '',
          );
        })
        .toList(growable: false);
    return DemoSongPage(
      songs: songs,
      totalCount: (pageMap['totalCount'] as num?)?.toInt() ?? 0,
      pageIndex: (pageMap['pageIndex'] as num?)?.toInt() ?? pageIndex,
      pageSize: (pageMap['pageSize'] as num?)?.toInt() ?? pageSize,
    );
  }

  Future<DemoArtistPage> queryIndexedArtists({
    required String rootUri,
    required int pageIndex,
    required int pageSize,
    String language = '',
    String searchQuery = '',
  }) async {
    final Map<dynamic, dynamic>? result = await _channel
        .invokeMethod<Map<dynamic, dynamic>>(
          'queryIndexedArtists',
          <String, Object?>{
            'rootUri': rootUri,
            'pageIndex': pageIndex,
            'pageSize': pageSize,
            'language': language,
            'searchQuery': searchQuery,
          },
        );

    final Map<Object?, Object?> pageMap = Map<Object?, Object?>.from(
      result ?? const <Object?, Object?>{},
    );
    final List<dynamic> items =
        (pageMap['artists'] as List<dynamic>?) ?? const <dynamic>[];
    final List<DemoArtist> artists = items
        .whereType<Map>()
        .map((Map item) {
          final Map<Object?, Object?> map = Map<Object?, Object?>.from(item);
          return DemoArtist(
            name: (map['name'] as String?) ?? '未识别歌手',
            songCount: (map['songCount'] as num?)?.toInt() ?? 0,
            searchIndex: (map['searchIndex'] as String?) ?? '',
          );
        })
        .toList(growable: false);
    return DemoArtistPage(
      artists: artists,
      totalCount: (pageMap['totalCount'] as num?)?.toInt() ?? 0,
      pageIndex: (pageMap['pageIndex'] as num?)?.toInt() ?? pageIndex,
      pageSize: (pageMap['pageSize'] as num?)?.toInt() ?? pageSize,
    );
  }

  List<String> _parseStringList(Object? value) {
    if (value is! List) {
      return const <String>[];
    }
    return value
        .whereType<Object?>()
        .map((Object? item) => item?.toString().trim() ?? '')
        .where((String item) => item.isNotEmpty)
        .toList(growable: false);
  }
}

class DemoAndroidLibrarySong {
  const DemoAndroidLibrarySong({
    required this.title,
    required this.artist,
    required this.mediaPath,
    required this.fileName,
    required this.extension,
  });

  final String title;
  final String artist;
  final String mediaPath;
  final String fileName;
  final String extension;
}
