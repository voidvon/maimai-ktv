import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;

import '../../../../core/models/song.dart';
import '../cloud/cloud_playback_cache.dart';
import 'file_smb_store.dart';
import 'smb_client.dart';
import 'smb_remote_data_source.dart';

class FileSmbPlaybackCache implements CloudPlaybackCache {
  FileSmbPlaybackCache({
    required SmbClient client,
    required SmbRemoteDataSource remoteDataSource,
    Future<Directory> Function()? cacheDirectoryProvider,
    this.expireAfter = const Duration(days: 7),
  }) : _client = client,
       _remoteDataSource = remoteDataSource,
       _cacheDirectoryProvider =
           cacheDirectoryProvider ?? resolveSmbCacheDirectory;

  final SmbClient _client;
  final SmbRemoteDataSource _remoteDataSource;
  final Future<Directory> Function() _cacheDirectoryProvider;
  final Duration expireAfter;
  final Map<String, Future<CloudCachedMedia>> _pending =
      <String, Future<CloudCachedMedia>>{};

  @override
  Future<void> clearExpiredCache() async {
    final Directory directory = await _cacheDirectoryProvider();
    if (!await directory.exists()) {
      return;
    }
    final DateTime cutoff = DateTime.now().subtract(expireAfter);
    await for (final FileSystemEntity entity in directory.list()) {
      if (entity is File && (await entity.lastModified()).isBefore(cutoff)) {
        await entity.delete();
      }
    }
  }

  @override
  Future<CloudCachedMedia> resolve({
    required Song song,
    required String sourceSongId,
    void Function(double progress)? onProgress,
    CloudDownloadCancellationToken? cancellationToken,
  }) {
    final String id = sourceSongId.trim();
    if (id.isEmpty) {
      throw StateError('SMB 歌曲 ${song.songId} 缺少 sourceSongId');
    }
    final Future<CloudCachedMedia>? existing = _pending[id];
    if (existing != null) {
      return existing;
    }
    final Future<CloudCachedMedia> resolution = _resolveInternal(
      song: song,
      sourceSongId: id,
      onProgress: onProgress,
      cancellationToken: cancellationToken,
    );
    _pending[id] = resolution;
    return resolution.whenComplete(() => _pending.remove(id));
  }

  Future<CloudCachedMedia> _resolveInternal({
    required Song song,
    required String sourceSongId,
    void Function(double progress)? onProgress,
    CloudDownloadCancellationToken? cancellationToken,
  }) async {
    final Directory directory = await _cacheDirectoryProvider();
    final String prefix = '${sha1.convert(utf8.encode(sourceSongId))}__';
    if (await directory.exists()) {
      await for (final FileSystemEntity entity in directory.list()) {
        if (entity is File &&
            path.basename(entity.path).startsWith(prefix) &&
            !entity.path.endsWith('.part')) {
          onProgress?.call(1);
          return CloudCachedMedia(
            localPath: entity.path,
            displayName: song.title,
            cacheHit: true,
          );
        }
      }
    }

    cancellationToken?.throwIfCancelled();
    final meta = await _remoteDataSource.getPlayableFileMeta(sourceSongId);
    final String extension = path.extension(meta.serverFilename).isEmpty
        ? '.mp4'
        : path.extension(meta.serverFilename).toLowerCase();
    final String safeName = path
        .basenameWithoutExtension(meta.serverFilename)
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
    final File target = File(
      path.join(
        directory.path,
        '$prefix${safeName.isEmpty ? 'media' : safeName}$extension',
      ),
    );
    final File partial = File('${target.path}.part');
    try {
      await _client.downloadFile(
        remotePath: sourceSongId,
        targetFile: partial,
        onProgress: onProgress,
        cancellationToken: cancellationToken,
      );
      cancellationToken?.throwIfCancelled();
      if (await target.exists()) {
        await target.delete();
      }
      await partial.rename(target.path);
    } on CloudDownloadCancelledException {
      if (await partial.exists()) {
        await partial.delete();
      }
      rethrow;
    }
    return CloudCachedMedia(localPath: target.path, displayName: song.title);
  }
}
