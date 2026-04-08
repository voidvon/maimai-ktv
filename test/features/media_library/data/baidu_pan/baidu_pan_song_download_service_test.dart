import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ktv2_example/core/models/song.dart';
import 'package:ktv2_example/core/models/song_identity.dart';
import 'package:ktv2_example/features/media_library/data/baidu_pan/baidu_pan_playback_cache.dart';
import 'package:ktv2_example/features/media_library/data/baidu_pan/baidu_pan_song_download_service.dart';
import 'package:ktv2_example/features/media_library/data/cloud/cloud_playback_cache.dart';
import 'package:ktv2_example/features/media_library/data/cloud/cloud_song_download_service.dart';

void main() {
  test(
    'downloadSong copies cached baidu pan media into preferred directory',
    () async {
      final Directory sourceDirectory = await Directory.systemTemp.createTemp(
        'baidu-pan-source-',
      );
      final Directory targetDirectory = await Directory.systemTemp.createTemp(
        'baidu-pan-target-',
      );
      final Directory storeDirectory = await Directory.systemTemp.createTemp(
        'baidu-pan-store-',
      );
      addTearDown(() async {
        if (await sourceDirectory.exists()) {
          await sourceDirectory.delete(recursive: true);
        }
        if (await targetDirectory.exists()) {
          await targetDirectory.delete(recursive: true);
        }
        if (await storeDirectory.exists()) {
          await storeDirectory.delete(recursive: true);
        }
      });

      final File cachedFile = File('${sourceDirectory.path}/cached_song.mp4');
      await cachedFile.writeAsString('video-payload', flush: true);
      final File indexFile = File(
        '${storeDirectory.path}/downloaded_songs.json',
      );

      final BaiduPanSongDownloadService service = BaiduPanSongDownloadService(
        playbackCache: _FakeBaiduPanPlaybackCache(cachedFile.path),
        downloadIndexFileProvider: () async => indexFile,
      );
      final Song song = Song(
        songId: buildAggregateSongId(title: '夜曲', artist: '周杰伦'),
        sourceId: 'baidu_pan',
        sourceSongId: 'fsid-1',
        title: '夜曲',
        artist: '周杰伦',
        languages: const <String>['国语'],
        searchIndex: 'yequ zhoujielun',
        mediaPath: '',
      );

      final BaiduPanDownloadResult result = await service.downloadSong(
        song: song,
        preferredDirectory: targetDirectory.path,
      );

      expect(result.usedPreferredDirectory, isTrue);
      expect(await File(result.savedPath).readAsString(), 'video-payload');
      expect(result.savedPath, contains('周杰伦 - 夜曲'));
      expect(
        await service.loadDownloadedSourceSongIds(),
        contains(song.sourceSongId),
      );
      final List<CloudDownloadedSongRecord> records = await service
          .loadDownloadedSongs();
      expect(records, hasLength(1));
      expect(records.single.sourceId, 'baidu_pan');
      expect(records.single.sourceSongId, song.sourceSongId);
      expect(records.single.title, '夜曲');
      expect(records.single.artist, '周杰伦');
      expect(records.single.savedPath, result.savedPath);
    },
  );

  test('loadDownloadedSongs supports legacy string index entries', () async {
    final Directory storeDirectory = await Directory.systemTemp.createTemp(
      'baidu-pan-legacy-store-',
    );
    addTearDown(() async {
      if (await storeDirectory.exists()) {
        await storeDirectory.delete(recursive: true);
      }
    });

    final File savedFile = File('${storeDirectory.path}/legacy_song.mp4');
    await savedFile.writeAsString('legacy', flush: true);
    final File indexFile = File('${storeDirectory.path}/downloaded_songs.json');
    await indexFile.writeAsString(
      '{"legacy-fsid":"${savedFile.path.replaceAll(r'\', r'\\')}"}',
      flush: true,
    );

    final BaiduPanSongDownloadService service = BaiduPanSongDownloadService(
      playbackCache: _FakeBaiduPanPlaybackCache(savedFile.path),
      downloadIndexFileProvider: () async => indexFile,
    );

    final List<CloudDownloadedSongRecord> records = await service
        .loadDownloadedSongs();

    expect(records, hasLength(1));
    expect(records.single.sourceSongId, 'legacy-fsid');
    expect(records.single.savedPath, savedFile.path);
    expect(records.single.title, isEmpty);
    expect(records.single.artist, isEmpty);
  });

  test('downloadSong resumes local copy from existing temp file', () async {
    final Directory sourceDirectory = await Directory.systemTemp.createTemp(
      'baidu-pan-resume-source-',
    );
    final Directory targetDirectory = await Directory.systemTemp.createTemp(
      'baidu-pan-resume-target-',
    );
    final Directory storeDirectory = await Directory.systemTemp.createTemp(
      'baidu-pan-resume-store-',
    );
    addTearDown(() async {
      if (await sourceDirectory.exists()) {
        await sourceDirectory.delete(recursive: true);
      }
      if (await targetDirectory.exists()) {
        await targetDirectory.delete(recursive: true);
      }
      if (await storeDirectory.exists()) {
        await storeDirectory.delete(recursive: true);
      }
    });

    final File cachedFile = File('${sourceDirectory.path}/cached_song.mp4');
    await cachedFile.writeAsString('video-payload', flush: true);
    final File partialFile = File(
      '${targetDirectory.path}/周杰伦 - 夜曲.mp4.download',
    );
    await partialFile.writeAsString('video-', flush: true);
    final File indexFile = File('${storeDirectory.path}/downloaded_songs.json');

    final BaiduPanSongDownloadService service = BaiduPanSongDownloadService(
      playbackCache: _FakeBaiduPanPlaybackCache(cachedFile.path),
      downloadIndexFileProvider: () async => indexFile,
    );
    final Song song = Song(
      songId: buildAggregateSongId(title: '夜曲', artist: '周杰伦'),
      sourceId: 'baidu_pan',
      sourceSongId: 'fsid-resume',
      title: '夜曲',
      artist: '周杰伦',
      languages: const <String>['国语'],
      searchIndex: 'yequ zhoujielun',
      mediaPath: '',
    );

    final BaiduPanDownloadResult result = await service.downloadSong(
      song: song,
      preferredDirectory: targetDirectory.path,
    );

    expect(await File(result.savedPath).readAsString(), 'video-payload');
    expect(await partialFile.exists(), isFalse);
  });
}

class _FakeBaiduPanPlaybackCache implements BaiduPanPlaybackCache {
  _FakeBaiduPanPlaybackCache(this.cachedPath);

  final String cachedPath;

  @override
  Future<void> clearExpiredCache() async {}

  @override
  Future<BaiduPanCachedMedia> resolve({
    required Song song,
    required String sourceSongId,
    void Function(double progress)? onProgress,
    CloudDownloadCancellationToken? cancellationToken,
  }) async {
    return BaiduPanCachedMedia(
      localPath: cachedPath,
      displayName: song.title,
      cacheHit: true,
    );
  }
}
