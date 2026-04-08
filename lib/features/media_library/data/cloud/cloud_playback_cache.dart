import '../../../../core/models/song.dart';

class CloudDownloadCancelledException implements Exception {
  const CloudDownloadCancelledException([this.message = '下载已取消']);

  final String message;

  @override
  String toString() => 'CloudDownloadCancelledException: $message';
}

class CloudDownloadPausedException implements Exception {
  const CloudDownloadPausedException([this.message = '下载已暂停']);

  final String message;

  @override
  String toString() => 'CloudDownloadPausedException: $message';
}

class CloudDownloadCancellationToken {
  bool _isCancelled = false;
  bool _isPaused = false;

  bool get isCancelled => _isCancelled;
  bool get isPaused => _isPaused;

  void pause() {
    if (_isCancelled) {
      return;
    }
    _isPaused = true;
  }

  void cancel() {
    _isCancelled = true;
    _isPaused = false;
  }

  void throwIfCancelled() {
    if (_isCancelled) {
      throw const CloudDownloadCancelledException();
    }
    if (_isPaused) {
      throw const CloudDownloadPausedException();
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
