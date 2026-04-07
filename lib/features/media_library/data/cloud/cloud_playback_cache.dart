import '../../../../core/models/song.dart';

class CloudDownloadCancelledException implements Exception {
  const CloudDownloadCancelledException([this.message = '下载已取消']);

  final String message;

  @override
  String toString() => 'CloudDownloadCancelledException: $message';
}

class CloudDownloadCancellationToken {
  bool _isCancelled = false;

  bool get isCancelled => _isCancelled;

  void cancel() {
    _isCancelled = true;
  }

  void throwIfCancelled() {
    if (_isCancelled) {
      throw const CloudDownloadCancelledException();
    }
  }
}

class CloudCachedMedia {
  const CloudCachedMedia({
    required this.localPath,
    required this.displayName,
    this.cacheHit = false,
  });

  final String localPath;
  final String displayName;
  final bool cacheHit;
}

abstract class CloudPlaybackCache {
  Future<CloudCachedMedia> resolve({
    required Song song,
    required String sourceSongId,
    void Function(double progress)? onProgress,
    CloudDownloadCancellationToken? cancellationToken,
  });

  Future<void> clearExpiredCache();
}
