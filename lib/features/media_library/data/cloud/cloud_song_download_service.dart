import 'dart:io';

import 'package:path/path.dart' as path;

import '../../../../core/models/song.dart';
import '../android_storage_data_source.dart';
import 'cloud_playback_cache.dart';

class CloudSongDownloadResult {
  const CloudSongDownloadResult({
    required this.savedPath,
    required this.usedPreferredDirectory,
  });

  final String savedPath;
  final bool usedPreferredDirectory;
}

class CloudDownloadedSongRecord {
  const CloudDownloadedSongRecord({
    required this.sourceId,
    required this.sourceSongId,
    required this.title,
    required this.artist,
    required this.savedPath,
    required this.savedAtMillis,
  });

  final String sourceId;
  final String sourceSongId;
  final String title;
  final String artist;
  final String savedPath;
  final int savedAtMillis;
}

class CloudDownloadProgress {
  const CloudDownloadProgress({required this.phaseLabel, required this.value});

  final String phaseLabel;
  final double value;
}

typedef CloudJsonMapReader = Future<Map<String, Object?>?> Function(File file);
typedef CloudJsonMapWriter =
    Future<void> Function(File file, Map<String, Object?> data);

class CloudSongDownloadService {
  CloudSongDownloadService({
    required this.sourceId,
    required CloudPlaybackCache playbackCache,
    required Future<Directory> Function() fallbackDirectoryProvider,
    required Future<File> Function() downloadIndexFileProvider,
    AndroidStorageDataSource? androidStorageDataSource,
    CloudJsonMapReader? jsonMapReader,
    CloudJsonMapWriter? jsonMapWriter,
    this.defaultFileStem = 'cloud_song',
  }) : _playbackCache = playbackCache,
       _fallbackDirectoryProvider = fallbackDirectoryProvider,
       _downloadIndexFileProvider = downloadIndexFileProvider,
       _androidStorageDataSource =
           androidStorageDataSource ?? AndroidStorageDataSource(),
       _jsonMapReader = jsonMapReader,
       _jsonMapWriter = jsonMapWriter;

  final String sourceId;
  final CloudPlaybackCache _playbackCache;
  final Future<Directory> Function() _fallbackDirectoryProvider;
  final Future<File> Function() _downloadIndexFileProvider;
  final AndroidStorageDataSource _androidStorageDataSource;
  final CloudJsonMapReader? _jsonMapReader;
  final CloudJsonMapWriter? _jsonMapWriter;
  final String defaultFileStem;

  Future<Set<String>> loadDownloadedSourceSongIds() async {
    final List<CloudDownloadedSongRecord> records = await loadDownloadedSongs();
    return records
        .map((CloudDownloadedSongRecord record) => record.sourceSongId)
        .toSet();
  }

  Future<List<CloudDownloadedSongRecord>> loadDownloadedSongs() async {
    final Map<String, _DownloadIndexEntry> entries = await _loadDownloadIndex();
    final List<CloudDownloadedSongRecord> records =
        <CloudDownloadedSongRecord>[];
    bool changed = false;

    for (final _DownloadIndexEntry entry in entries.values) {
      final String savedPath = entry.savedPath.trim();
      if (savedPath.isEmpty || !await File(savedPath).exists()) {
        changed = true;
        continue;
      }
      records.add(
        CloudDownloadedSongRecord(
          sourceId: sourceId,
          sourceSongId: entry.sourceSongId,
          title: entry.title,
          artist: entry.artist,
          savedPath: savedPath,
          savedAtMillis: entry.savedAtMillis,
        ),
      );
    }

    if (changed) {
      await _saveDownloadIndex(<String, _DownloadIndexEntry>{
        for (final CloudDownloadedSongRecord record in records)
          record.sourceSongId: _DownloadIndexEntry(
            sourceSongId: record.sourceSongId,
            title: record.title,
            artist: record.artist,
            savedPath: record.savedPath,
            savedAtMillis: record.savedAtMillis,
          ),
      });
    }

    records.sort(
      (CloudDownloadedSongRecord a, CloudDownloadedSongRecord b) =>
          b.savedAtMillis.compareTo(a.savedAtMillis),
    );
    return records;
  }

  Future<CloudSongDownloadResult> downloadSong({
    required Song song,
    String? preferredDirectory,
    void Function(CloudDownloadProgress progress)? onProgress,
    CloudDownloadCancellationToken? cancellationToken,
  }) async {
    if (song.sourceId != sourceId) {
      throw StateError('仅支持下载 $sourceId 歌曲: ${song.songId}');
    }
    cancellationToken?.throwIfCancelled();
    onProgress?.call(const CloudDownloadProgress(phaseLabel: '准备下载', value: 0));

    final CloudCachedMedia media = await _playbackCache.resolve(
      song: song,
      sourceSongId: song.sourceSongId,
      onProgress: (double progress) {
        onProgress?.call(
          CloudDownloadProgress(
            phaseLabel: '缓存云端文件',
            value: progress.clamp(0, 1) * 0.8,
          ),
        );
      },
      cancellationToken: cancellationToken,
    );
    cancellationToken?.throwIfCancelled();
    onProgress?.call(
      const CloudDownloadProgress(phaseLabel: '缓存完成', value: 0.8),
    );
    final File sourceFile = File(media.localPath);
    if (!await sourceFile.exists()) {
      throw StateError('$sourceId 缓存文件不存在: ${sourceFile.path}');
    }

    final _ResolvedTargetDirectory target = await _resolveTargetDirectory(
      preferredDirectory,
    );
    final String destinationPath = await _buildUniqueDestinationPath(
      directory: target.directory,
      song: song,
      sourceFile: sourceFile,
    );
    await _copyFileWithProgress(
      sourceFile: sourceFile,
      destinationFile: File(destinationPath),
      onProgress: (double progress) {
        onProgress?.call(
          CloudDownloadProgress(
            phaseLabel: '保存到本地',
            value: 0.8 + progress.clamp(0, 1) * 0.2,
          ),
        );
      },
      cancellationToken: cancellationToken,
    );
    await _recordDownloadedSong(
      _DownloadIndexEntry(
        sourceSongId: song.sourceSongId,
        title: song.title,
        artist: song.artist,
        savedPath: destinationPath,
        savedAtMillis: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    onProgress?.call(const CloudDownloadProgress(phaseLabel: '下载完成', value: 1));

    return CloudSongDownloadResult(
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

  Future<void> deleteDownloadedSong({required String sourceSongId}) async {
    final Map<String, _DownloadIndexEntry> index = await _loadDownloadIndex();
    final _DownloadIndexEntry? entry = index[sourceSongId];
    if (entry == null) {
      return;
    }
    final String savedPath = entry.savedPath.trim();
    if (savedPath.isNotEmpty) {
      final File file = File(savedPath);
      if (await file.exists()) {
        await file.delete();
      }
    }
    index.remove(sourceSongId);
    await _saveDownloadIndex(index);
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

  Future<void> _copyFileWithProgress({
    required File sourceFile,
    required File destinationFile,
    void Function(double progress)? onProgress,
    CloudDownloadCancellationToken? cancellationToken,
  }) async {
    await destinationFile.parent.create(recursive: true);
    if (await destinationFile.exists()) {
      await destinationFile.delete();
    }
    final int totalBytes = await sourceFile.length();
    final Stream<List<int>> stream = sourceFile.openRead();
    final IOSink sink = destinationFile.openWrite();
    int writtenBytes = 0;
    bool shouldDelete = false;
    try {
      await for (final List<int> chunk in stream) {
        cancellationToken?.throwIfCancelled();
        sink.add(chunk);
        writtenBytes += chunk.length;
        if (totalBytes > 0) {
          onProgress?.call(writtenBytes / totalBytes);
        }
      }
    } catch (_) {
      shouldDelete = true;
      rethrow;
    } finally {
      await sink.close();
      if (shouldDelete && await destinationFile.exists()) {
        await destinationFile.delete();
      }
    }
  }

  String _sanitizeFileName(String value) {
    final String sanitized = value.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final String trimmed = sanitized.trim();
    return trimmed.isEmpty ? defaultFileStem : trimmed;
  }

  Future<void> _recordDownloadedSong(_DownloadIndexEntry entry) async {
    final Map<String, _DownloadIndexEntry> index = await _loadDownloadIndex();
    index[entry.sourceSongId] = entry;
    await _saveDownloadIndex(index);
  }

  Future<Map<String, _DownloadIndexEntry>> _loadDownloadIndex() async {
    final File file = await _downloadIndexFileProvider();
    final Map<String, Object?>? json = _jsonMapReader == null
        ? null
        : await _jsonMapReader(file);
    if (json == null) {
      return <String, _DownloadIndexEntry>{};
    }
    final Object? songsObject = json['songs'];
    if (songsObject is Map) {
      return <String, _DownloadIndexEntry>{
        for (final MapEntry<Object?, Object?> entry in songsObject.entries)
          if (entry.key?.toString().trim().isNotEmpty ?? false)
            entry.key.toString(): _parseStructuredIndexEntry(
              sourceSongId: entry.key.toString(),
              raw: entry.value,
            ),
      };
    }

    return <String, _DownloadIndexEntry>{
      for (final MapEntry<String, Object?> entry in json.entries)
        if (entry.key.trim().isNotEmpty &&
            (entry.value?.toString().trim().isNotEmpty ?? false) &&
            entry.key != 'version' &&
            entry.key != 'songs')
          entry.key: _DownloadIndexEntry(
            sourceSongId: entry.key,
            title: '',
            artist: '',
            savedPath: entry.value!.toString(),
            savedAtMillis: 0,
          ),
    };
  }

  _DownloadIndexEntry _parseStructuredIndexEntry({
    required String sourceSongId,
    required Object? raw,
  }) {
    if (raw is Map) {
      final Map<String, Object?> map = raw.map(
        (Object? key, Object? value) => MapEntry(key.toString(), value),
      );
      return _DownloadIndexEntry(
        sourceSongId: sourceSongId,
        title: map['title']?.toString() ?? '',
        artist: map['artist']?.toString() ?? '',
        savedPath: map['savedPath']?.toString() ?? '',
        savedAtMillis:
            int.tryParse(map['savedAtMillis']?.toString() ?? '') ?? 0,
      );
    }
    return _DownloadIndexEntry(
      sourceSongId: sourceSongId,
      title: '',
      artist: '',
      savedPath: raw?.toString() ?? '',
      savedAtMillis: 0,
    );
  }

  Future<void> _saveDownloadIndex(
    Map<String, _DownloadIndexEntry> index,
  ) async {
    final File file = await _downloadIndexFileProvider();
    if (_jsonMapWriter == null) {
      throw StateError('未配置下载索引写入能力');
    }
    await _jsonMapWriter(file, <String, Object?>{
      'version': 2,
      'songs': <String, Object?>{
        for (final MapEntry<String, _DownloadIndexEntry> entry in index.entries)
          entry.key: <String, Object?>{
            'savedPath': entry.value.savedPath,
            'title': entry.value.title,
            'artist': entry.value.artist,
            'savedAtMillis': entry.value.savedAtMillis,
          },
      },
    });
  }
}

class _DownloadIndexEntry {
  const _DownloadIndexEntry({
    required this.sourceSongId,
    required this.title,
    required this.artist,
    required this.savedPath,
    required this.savedAtMillis,
  });

  final String sourceSongId;
  final String title;
  final String artist;
  final String savedPath;
  final int savedAtMillis;
}

class _ResolvedTargetDirectory {
  const _ResolvedTargetDirectory({
    required this.directory,
    required this.usedPreferredDirectory,
  });

  final Directory directory;
  final bool usedPreferredDirectory;
}
