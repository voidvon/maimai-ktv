import '../../../core/models/song.dart';
import '../../media_library/data/baidu_pan/baidu_pan_playback_cache.dart';

class PlayableMediaResolution {
  const PlayableMediaResolution({
    required this.song,
    required this.localPath,
    required this.displayName,
    this.cacheHit = false,
  });

  final Song song;
  final String localPath;
  final String displayName;
  final bool cacheHit;
}

abstract class PlayableSongResolver {
  Future<PlayableMediaResolution> resolve(Song song);
}

class DefaultPlayableSongResolver implements PlayableSongResolver {
  const DefaultPlayableSongResolver({this.baiduPanPlaybackCache});

  final BaiduPanPlaybackCache? baiduPanPlaybackCache;

  @override
  Future<PlayableMediaResolution> resolve(Song song) async {
    if (song.sourceId == 'baidu_pan') {
      final BaiduPanPlaybackCache? playbackCache = baiduPanPlaybackCache;
      if (playbackCache == null) {
        throw StateError('百度网盘歌曲 ${song.songId} 缺少播放缓存实现');
      }
      final BaiduPanCachedMedia media = await playbackCache.resolve(
        song: song,
        sourceSongId: song.sourceSongId,
      );
      return PlayableMediaResolution(
        song: song,
        localPath: media.localPath,
        displayName: media.displayName,
        cacheHit: media.cacheHit,
      );
    }

    final String localPath = song.mediaPath.trim();
    if (localPath.isEmpty) {
      throw StateError('歌曲 ${song.songId} 缺少可播放媒体路径');
    }
    return PlayableMediaResolution(
      song: song,
      localPath: localPath,
      displayName: song.title,
    );
  }
}
