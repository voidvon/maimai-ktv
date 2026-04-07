import 'dart:io';

import 'package:path/path.dart' as path;

import '../../../../core/models/song.dart';
import '../android_storage_data_source.dart';
import '_baidu_pan_file_store_support.dart';
import 'baidu_pan_playback_cache.dart';

class BaiduPanDownloadResult {
  const BaiduPanDownloadResult({
    required this.savedPath,
    required this.usedPreferredDirectory,
  });

  final String savedPath;
  final bool usedPreferredDirectory;
}

class BaiduPanSongDownloadService {
  BaiduPanSongDownloadService({
    required BaiduPanPlaybackCache playbackCache,
    AndroidStorageDataSource? androidStorageDataSource,
    Future<Directory> Function()? fallbackDirectoryProvider,
    Future<File> Function()? downloadIndexFileProvider,
  }) : _playbackCache = playbackCache,
       _androidStorageDataSource =
           androidStorageDataSource ?? AndroidStorageDataSource(),
       _fallbackDirectoryProvider =
           fallbackDirectoryProvider ?? resolveBaiduPanDownloadsDirectory,
       _downloadIndexFileProvider =
           downloadIndexFileProvider ??
           (() => resolveBaiduPanStoreFile('downloaded_songs.json'));

  final BaiduPanPlaybackCache _playbackCache;
  final AndroidStorageDataSource _androidStorageDataSource;
  final Future<Directory> Function() _fallbackDirectoryProvider;
  final Future<File> Function() _downloadIndexFileProvider;

  Future<Set<String>> loadDownloadedSourceSongIds() async {
    final Map<String, String> index = await _loadDownloadIndex();
    final Set<String> downloadedIds = <String>{};
    bool changed = false;

    for (final MapEntry<String, String> entry in index.entries) {
      final String savedPath = entry.value.trim();
      if (savedPath.isEmpty || !await File(savedPath).exists()) {
        changed = true;
        continue;
      }
      downloadedIds.add(entry.key);
    }

    if (changed) {
      final Map<String, String> nextIndex = <String, String>{
        for (final String sourceSongId in downloadedIds)
          sourceSongId: index[sourceSongId]!,
      };
      await _saveDownloadIndex(nextIndex);
    }

    return downloadedIds;
  }

  Future<BaiduPanDownloadResult> downloadSong({
    required Song song,
    String? preferredDirectory,
  }) async {
    if (song.sourceId != 'baidu_pan') {
      throw StateError('仅支持下载百度网盘歌曲: ${song.songId}');
    }

    final BaiduPanCachedMedia media = await _playbackCache.resolve(
      song: song,
      sourceSongId: song.sourceSongId,
    );
    final File sourceFile = File(media.localPath);
    if (!await sourceFile.exists()) {
      throw StateError('百度网盘缓存文件不存在: ${sourceFile.path}');
    }

    final _ResolvedTargetDirectory target = await _resolveTargetDirectory(
      preferredDirectory,
    );
    final String destinationPath = await _buildUniqueDestinationPath(
      directory: target.directory,
      song: song,
      sourceFile: sourceFile,
    );
    await sourceFile.copy(destinationPath);
    await _recordDownloadedSong(
      sourceSongId: song.sourceSongId,
      savedPath: destinationPath,
    );

    return BaiduPanDownloadResult(
      savedPath: destinationPath,
      usedPreferredDirectory: target.usedPreferredDirectory,
    );
  }

  Future<_ResolvedTargetDirectory> _resolveTargetDirectory(
    String? preferredDirectory,
  ) async {
    final String normalizedPreferredDirectory =
        preferredDirectory?.trim() ?? '';
    if (normalizedPreferredDirectory.isNotEmpty &&
        !_androidStorageDataSource.isDocumentTreeUri(
          normalizedPreferredDirectory,
        )) {
      final Directory directory = Directory(normalizedPreferredDirectory);
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      return _ResolvedTargetDirectory(
        directory: directory,
        usedPreferredDirectory: true,
      );
    }

    return _ResolvedTargetDirectory(
      directory: await _fallbackDirectoryProvider(),
      usedPreferredDirectory: false,
    );
  }

  Future<String> _buildUniqueDestinationPath({
    required Directory directory,
    required Song song,
    required File sourceFile,
  }) async {
    final String extension = path.extension(sourceFile.path).trim().isEmpty
        ? '.mp4'
        : path.extension(sourceFile.path);
    final String fileStem = _sanitizeFileName(
      '${song.artist} - ${song.title}'.trim(),
    );

    String candidatePath = path.join(directory.path, '$fileStem$extension');
    int suffix = 1;
    while (await File(candidatePath).exists()) {
      candidatePath = path.join(
        directory.path,
        '$fileStem ($suffix)$extension',
      );
      suffix += 1;
    }
    return candidatePath;
  }

  String _sanitizeFileName(String value) {
    final String sanitized = value.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final String trimmed = sanitized.trim();
    return trimmed.isEmpty ? 'baidu_pan_song' : trimmed;
  }

  Future<void> _recordDownloadedSong({
    required String sourceSongId,
    required String savedPath,
  }) async {
    final Map<String, String> index = await _loadDownloadIndex();
    index[sourceSongId] = savedPath;
    await _saveDownloadIndex(index);
  }

  Future<Map<String, String>> _loadDownloadIndex() async {
    final File file = await _downloadIndexFileProvider();
    final Map<String, Object?>? json = await readJsonMapFile(file);
    if (json == null) {
      return <String, String>{};
    }
    return <String, String>{
      for (final MapEntry<String, Object?> entry in json.entries)
        if (entry.key.trim().isNotEmpty &&
            (entry.value?.toString().trim().isNotEmpty ?? false))
          entry.key: entry.value!.toString(),
    };
  }

  Future<void> _saveDownloadIndex(Map<String, String> index) async {
    final File file = await _downloadIndexFileProvider();
    await writeJsonMapFile(file, <String, Object?>{...index});
  }
}

class _ResolvedTargetDirectory {
  const _ResolvedTargetDirectory({
    required this.directory,
    required this.usedPreferredDirectory,
  });

  final Directory directory;
  final bool usedPreferredDirectory;
}
