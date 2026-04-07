import 'dart:io';

import 'package:path/path.dart' as path;

import '../../../../core/models/song.dart';
import '_baidu_pan_file_store_support.dart';
import 'baidu_pan_auth_repository.dart';
import 'baidu_pan_models.dart';
import 'baidu_pan_playback_cache.dart';
import '../cloud/cloud_playback_cache.dart';
import 'baidu_pan_remote_data_source.dart';

typedef BaiduPanFileDownloader =
    Future<void> Function({
      required Uri uri,
      required File targetFile,
      void Function(double progress)? onProgress,
      CloudDownloadCancellationToken? cancellationToken,
    });

class FileBaiduPanPlaybackCache implements BaiduPanPlaybackCache {
  FileBaiduPanPlaybackCache({
    required BaiduPanAuthRepository authRepository,
    required BaiduPanRemoteDataSource remoteDataSource,
    Future<Directory> Function()? cacheDirectoryProvider,
    BaiduPanFileDownloader? fileDownloader,
    Duration expireAfter = const Duration(days: 7),
  }) : _authRepository = authRepository,
       _remoteDataSource = remoteDataSource,
       _cacheDirectoryProvider =
           cacheDirectoryProvider ?? resolveBaiduPanCacheDirectory,
       _fileDownloader = fileDownloader ?? _defaultDownloadToFile,
       _expireAfter = expireAfter;

  final BaiduPanAuthRepository _authRepository;
  final BaiduPanRemoteDataSource _remoteDataSource;
  final Future<Directory> Function() _cacheDirectoryProvider;
  final BaiduPanFileDownloader _fileDownloader;
  final Duration _expireAfter;
  final Map<String, Future<BaiduPanCachedMedia>> _pendingResolutions =
      <String, Future<BaiduPanCachedMedia>>{};

  @override
  Future<void> clearExpiredCache() async {
    final Directory directory = await _cacheDirectoryProvider();
    if (!await directory.exists()) {
      return;
    }
    final DateTime expireBefore = DateTime.now().subtract(_expireAfter);
    await for (final FileSystemEntity entity in directory.list()) {
      if (entity is! File) {
        continue;
      }
      final String name = path.basename(entity.path);
      if (name.endsWith('.part')) {
        await entity.delete();
        continue;
      }
      final DateTime lastModified = await entity.lastModified();
      if (lastModified.isBefore(expireBefore)) {
        await entity.delete();
      }
    }
  }

  @override
  Future<BaiduPanCachedMedia> resolve({
    required Song song,
    required String sourceSongId,
    void Function(double progress)? onProgress,
    CloudDownloadCancellationToken? cancellationToken,
  }) {
    final String normalizedSourceSongId = sourceSongId.trim();
    if (normalizedSourceSongId.isEmpty) {
      throw StateError('百度网盘歌曲 ${song.songId} 缺少 sourceSongId');
    }
    final Future<BaiduPanCachedMedia>? existing =
        _pendingResolutions[normalizedSourceSongId];
    if (existing != null) {
      return existing;
    }
    final Future<BaiduPanCachedMedia> future = _resolveInternal(
      song: song,
      sourceSongId: normalizedSourceSongId,
      onProgress: onProgress,
      cancellationToken: cancellationToken,
    );
    _pendingResolutions[normalizedSourceSongId] = future;
    return future.whenComplete(() {
      _pendingResolutions.remove(normalizedSourceSongId);
    });
  }

  Future<BaiduPanCachedMedia> _resolveInternal({
    required Song song,
    required String sourceSongId,
    void Function(double progress)? onProgress,
    CloudDownloadCancellationToken? cancellationToken,
  }) async {
    final Directory directory = await _cacheDirectoryProvider();
    cancellationToken?.throwIfCancelled();
    final File? cachedFile = await _findCachedFile(
      directory: directory,
      sourceSongId: sourceSongId,
    );
    if (cachedFile != null) {
      onProgress?.call(1);
      return BaiduPanCachedMedia(
        localPath: cachedFile.path,
        displayName: song.title,
        cacheHit: true,
      );
    }

    final BaiduPanRemoteFile fileMeta = await _remoteDataSource
        .getPlayableFileMeta(sourceSongId);
    final String dlink = fileMeta.dlink?.trim() ?? '';
    if (dlink.isEmpty) {
      throw StateError('百度网盘歌曲 ${song.songId} 缺少可下载 dlink');
    }
    final String accessToken = await _authRepository.getValidAccessToken();

    final String cacheFileName = _buildCacheFileName(
      sourceSongId: sourceSongId,
      serverFilename: fileMeta.serverFilename,
      remotePath: fileMeta.path,
    );
    final File targetFile = File(path.join(directory.path, cacheFileName));
    final File tempFile = File('${targetFile.path}.part');

    if (await targetFile.exists()) {
      return BaiduPanCachedMedia(
        localPath: targetFile.path,
        displayName: song.title,
        cacheHit: true,
      );
    }

    if (await tempFile.exists()) {
      await tempFile.delete();
    }

    try {
      await _fileDownloader(
        uri: _appendAccessToken(dlink, accessToken),
        targetFile: tempFile,
        onProgress: onProgress,
        cancellationToken: cancellationToken,
      );
      cancellationToken?.throwIfCancelled();
      if (await targetFile.exists()) {
        await targetFile.delete();
      }
      await tempFile.rename(targetFile.path);
    } catch (_) {
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
      rethrow;
    }

    return BaiduPanCachedMedia(
      localPath: targetFile.path,
      displayName: song.title,
      cacheHit: false,
    );
  }

  Future<File?> _findCachedFile({
    required Directory directory,
    required String sourceSongId,
  }) async {
    if (!await directory.exists()) {
      return null;
    }
    final String prefix = _cacheFilePrefix(sourceSongId);
    await for (final FileSystemEntity entity in directory.list()) {
      if (entity is! File) {
        continue;
      }
      final String name = path.basename(entity.path);
      if (name.endsWith('.part')) {
        continue;
      }
      if (name.startsWith(prefix)) {
        return entity;
      }
    }
    return null;
  }

  String _buildCacheFileName({
    required String sourceSongId,
    required String serverFilename,
    required String remotePath,
  }) {
    final String extension = _resolveExtension(
      serverFilename: serverFilename,
      remotePath: remotePath,
    );
    final String basename = path
        .basenameWithoutExtension(serverFilename)
        .trim();
    final String safeBasename = _sanitizeFileSegment(
      basename.isEmpty ? 'media' : basename,
    );
    return '${_cacheFilePrefix(sourceSongId)}$safeBasename$extension';
  }

  String _resolveExtension({
    required String serverFilename,
    required String remotePath,
  }) {
    final String fromFilename = path.extension(serverFilename).trim();
    if (fromFilename.isNotEmpty) {
      return fromFilename.toLowerCase();
    }
    final String fromPath = path.extension(remotePath).trim();
    if (fromPath.isNotEmpty) {
      return fromPath.toLowerCase();
    }
    return '.mp4';
  }

  String _cacheFilePrefix(String sourceSongId) {
    return '${_sanitizeFileSegment(sourceSongId)}__';
  }

  String _sanitizeFileSegment(String value) {
    final String sanitized = value.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
    final String trimmed = sanitized.replaceAll(RegExp(r'_+'), '_').trim();
    if (trimmed.isEmpty) {
      return 'media';
    }
    return trimmed.length <= 64 ? trimmed : trimmed.substring(0, 64);
  }

  Uri _appendAccessToken(String dlink, String accessToken) {
    final Uri uri = Uri.parse(dlink);
    return uri.replace(
      queryParameters: <String, String>{
        ...uri.queryParameters,
        'access_token': accessToken,
      },
    );
  }

  static Future<void> _defaultDownloadToFile({
    required Uri uri,
    required File targetFile,
    void Function(double progress)? onProgress,
    CloudDownloadCancellationToken? cancellationToken,
  }) async {
    final HttpClient client = HttpClient();
    try {
      final HttpClientRequest request = await client.getUrl(uri);
      request.followRedirects = true;
      request.maxRedirects = 5;
      request.headers.set(HttpHeaders.userAgentHeader, 'pan.baidu.com');
      final HttpClientResponse response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('百度网盘下载失败: ${response.statusCode}', uri: uri);
      }
      await targetFile.parent.create(recursive: true);
      final IOSink sink = targetFile.openWrite();
      final int totalBytes = response.contentLength;
      int receivedBytes = 0;
      try {
        await for (final List<int> chunk in response) {
          cancellationToken?.throwIfCancelled();
          sink.add(chunk);
          receivedBytes += chunk.length;
          if (totalBytes > 0) {
            onProgress?.call(receivedBytes / totalBytes);
          }
        }
      } finally {
        await sink.close();
      }
    } finally {
      client.close(force: true);
    }
  }
}
