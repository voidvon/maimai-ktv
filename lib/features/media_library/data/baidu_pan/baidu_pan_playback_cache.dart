import '../../../../core/models/song.dart';
import '../cloud/cloud_playback_cache.dart';

class BaiduPanCachedMedia extends CloudCachedMedia {
  const BaiduPanCachedMedia({
    required super.localPath,
    required super.displayName,
    super.cacheHit = false,
  });
}

abstract class BaiduPanPlaybackCache extends CloudPlaybackCache {
  @override
  Future<BaiduPanCachedMedia> resolve({
    required Song song,
    required String sourceSongId,
    void Function(double progress)? onProgress,
    CloudDownloadCancellationToken? cancellationToken,
  });

  @override
  Future<void> clearExpiredCache();
}
