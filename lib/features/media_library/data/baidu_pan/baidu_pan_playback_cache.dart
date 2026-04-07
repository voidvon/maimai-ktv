import '../../../../core/models/song.dart';

class BaiduPanCachedMedia {
  const BaiduPanCachedMedia({
    required this.localPath,
    required this.displayName,
    this.cacheHit = false,
  });

  final String localPath;
  final String displayName;
  final bool cacheHit;
}

abstract class BaiduPanPlaybackCache {
  Future<BaiduPanCachedMedia> resolve({
    required Song song,
    required String sourceSongId,
  });

  Future<void> clearExpiredCache();
}
