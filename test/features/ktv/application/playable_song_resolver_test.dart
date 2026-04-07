import 'package:flutter_test/flutter_test.dart';
import 'package:ktv2_example/core/models/song.dart';
import 'package:ktv2_example/core/models/song_identity.dart';
import 'package:ktv2_example/features/ktv/application/playable_song_resolver.dart';
import 'package:ktv2_example/features/media_library/data/baidu_pan/baidu_pan_playback_cache.dart';
import 'package:ktv2_example/features/media_library/data/cloud/cloud_playback_cache.dart';

void main() {
  test('local song uses media path directly', () async {
    final DefaultPlayableSongResolver resolver =
        const DefaultPlayableSongResolver();
    final Song song = _song(
      title: '青花瓷',
      sourceId: 'local',
      sourceSongId: 'local-1',
      mediaPath: '/tmp/qinghua.mp4',
    );

    final PlayableMediaResolution media = await resolver.resolve(song);

    expect(media.localPath, '/tmp/qinghua.mp4');
    expect(media.displayName, '青花瓷');
    expect(media.cacheHit, isFalse);
  });

  test('baidu pan song resolves from playback cache', () async {
    final _FakeBaiduPanPlaybackCache cache = _FakeBaiduPanPlaybackCache();
    final DefaultPlayableSongResolver resolver = DefaultPlayableSongResolver(
      baiduPanPlaybackCache: cache,
    );
    final Song song = _song(
      title: '夜曲',
      sourceId: 'baidu_pan',
      sourceSongId: 'fsid-88',
      mediaPath: '',
    );

    final PlayableMediaResolution media = await resolver.resolve(song);

    expect(cache.lastSourceSongId, 'fsid-88');
    expect(media.localPath, '/cache/yequ.mp4');
    expect(media.displayName, '缓存夜曲');
    expect(media.cacheHit, isTrue);
  });
}

Song _song({
  required String title,
  required String sourceId,
  required String sourceSongId,
  required String mediaPath,
}) {
  return Song(
    songId: buildAggregateSongId(title: title, artist: '周杰伦'),
    sourceId: sourceId,
    sourceSongId: sourceSongId,
    title: title,
    artist: '周杰伦',
    languages: const <String>['国语'],
    searchIndex: title.toLowerCase(),
    mediaPath: mediaPath,
  );
}

class _FakeBaiduPanPlaybackCache implements BaiduPanPlaybackCache {
  String? lastSourceSongId;

  @override
  Future<void> clearExpiredCache() async {}

  @override
  Future<BaiduPanCachedMedia> resolve({
    required Song song,
    required String sourceSongId,
    void Function(double progress)? onProgress,
    CloudDownloadCancellationToken? cancellationToken,
  }) async {
    lastSourceSongId = sourceSongId;
    return const BaiduPanCachedMedia(
      localPath: '/cache/yequ.mp4',
      displayName: '缓存夜曲',
      cacheHit: true,
    );
  }
}
