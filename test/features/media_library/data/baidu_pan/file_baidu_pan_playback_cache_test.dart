import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ktv2_example/core/models/song.dart';
import 'package:ktv2_example/core/models/song_identity.dart';
import 'package:ktv2_example/features/media_library/data/baidu_pan/baidu_pan_auth_repository.dart';
import 'package:ktv2_example/features/media_library/data/baidu_pan/baidu_pan_models.dart';
import 'package:ktv2_example/features/media_library/data/baidu_pan/baidu_pan_remote_data_source.dart';
import 'package:ktv2_example/features/media_library/data/baidu_pan/file_baidu_pan_playback_cache.dart';

void main() {
  test(
    'resolve downloads on cache miss and reuses local file on next hit',
    () async {
      final Directory tempDirectory = await Directory.systemTemp.createTemp(
        'baidu-pan-cache-test-',
      );
      addTearDown(() async {
        if (await tempDirectory.exists()) {
          await tempDirectory.delete(recursive: true);
        }
      });

      int downloadCount = 0;
      final _FakeBaiduPanRemoteDataSource remoteDataSource =
          _FakeBaiduPanRemoteDataSource();
      Uri? downloadedUri;
      final FileBaiduPanPlaybackCache cache = FileBaiduPanPlaybackCache(
        authRepository: _FakeBaiduPanAuthRepository(),
        remoteDataSource: remoteDataSource,
        cacheDirectoryProvider: () async => tempDirectory,
        fileDownloader: ({required Uri uri, required File targetFile}) async {
          downloadCount += 1;
          downloadedUri = uri;
          await targetFile.writeAsString('mock video payload', flush: true);
        },
      );
      final Song song = _song();

      final first = await cache.resolve(
        song: song,
        sourceSongId: song.sourceSongId,
      );
      final second = await cache.resolve(
        song: song,
        sourceSongId: song.sourceSongId,
      );

      expect(remoteDataSource.getPlayableFileMetaCallCount, 1);
      expect(downloadCount, 1);
      expect(first.cacheHit, isFalse);
      expect(second.cacheHit, isTrue);
      expect(first.localPath, second.localPath);
      expect(await File(first.localPath).exists(), isTrue);
      expect(
        downloadedUri?.queryParameters['access_token'],
        'mock-access-token',
      );
    },
  );
}

Song _song() {
  return Song(
    songId: buildAggregateSongId(title: '青花瓷', artist: '周杰伦'),
    sourceId: 'baidu_pan',
    sourceSongId: '12345',
    title: '青花瓷',
    artist: '周杰伦',
    languages: const <String>['国语'],
    searchIndex: '青花瓷 周杰伦',
    mediaPath: '',
  );
}

class _FakeBaiduPanRemoteDataSource implements BaiduPanRemoteDataSource {
  int getPlayableFileMetaCallCount = 0;

  @override
  Future<BaiduPanRemoteFile> getPlayableFileMeta(String fsid) async {
    getPlayableFileMetaCallCount += 1;
    return const BaiduPanRemoteFile(
      fsid: '12345',
      path: '/KTV/周杰伦-青花瓷-国语.mp4',
      serverFilename: '周杰伦-青花瓷-国语.mp4',
      isDirectory: false,
      size: 1024,
      modifiedAtMillis: 1710000000000,
      dlink: 'https://example.com/file.mp4',
    );
  }

  @override
  Future<List<BaiduPanRemoteFile>> scanRoot(String rootPath) async {
    throw UnimplementedError();
  }

  @override
  Future<List<BaiduPanRemoteFile>> searchFiles({
    required String keyword,
    String? rootPath,
  }) async {
    throw UnimplementedError();
  }
}

class _FakeBaiduPanAuthRepository implements BaiduPanAuthRepository {
  @override
  Future<Uri> buildAuthorizeUri() async => Uri.parse('https://example.com');

  @override
  Future<String> getValidAccessToken() async => 'mock-access-token';

  @override
  Future<bool> hasValidSession() async => true;

  @override
  Future<void> loginWithAuthorizationCode(String code) async {}

  @override
  Future<void> logout() async {}

  @override
  Future<BaiduPanAuthToken?> readToken() async => null;
}
