import 'package:flutter_test/flutter_test.dart';
import 'package:maimai_ktv/features/media_library/data/baidu_pan/baidu_pan_models.dart';
import 'package:maimai_ktv/features/media_library/data/baidu_pan/baidu_pan_remote_data_source.dart';
import 'package:maimai_ktv/features/media_library/data/baidu_pan/baidu_pan_song_source.dart';
import 'package:maimai_ktv/features/media_library/data/baidu_pan/baidu_pan_source_config_store.dart';

import '../../../../test_support/ktv_test_doubles.dart';

void main() {
  test('refresh clears cached songs when no source config exists', () async {
    final FakeMediaIndexStore mediaIndexStore = FakeMediaIndexStore();
    final BaiduPanSongSource source = BaiduPanSongSource(
      mediaLibraryRepository: createTestMediaLibraryRepository(
        mediaIndexStore: mediaIndexStore,
      ),
      sourceConfigStore: _FakeBaiduPanSourceConfigStore(),
      remoteDataSource: _FakeBaiduPanRemoteDataSource(),
    );

    await source.refresh();

    expect(
      mediaIndexStore.clearedSources,
      contains((sourceType: 'baidu_pan', sourceRootId: null)),
    );
  });

  test(
    'refresh imports only playable video files from the configured root',
    () async {
      final FakeMediaIndexStore mediaIndexStore = FakeMediaIndexStore();
      final BaiduPanSongSource source = BaiduPanSongSource(
        mediaLibraryRepository: createTestMediaLibraryRepository(
          mediaIndexStore: mediaIndexStore,
        ),
        sourceConfigStore: _FakeBaiduPanSourceConfigStore(
          config: const BaiduPanSourceConfig(
            sourceRootId: 'baidu_pan:/KTV',
            rootPath: '/KTV',
            displayName: '百度网盘',
          ),
        ),
        remoteDataSource: _FakeBaiduPanRemoteDataSource(
          files: <BaiduPanRemoteFile>[
            const BaiduPanRemoteFile(
              fsid: 'video-1',
              path: '/KTV/周杰伦-青花瓷-国语.mp4',
              serverFilename: '周杰伦-青花瓷-国语.mp4',
              isDirectory: false,
              size: 1,
              modifiedAtMillis: 1,
            ),
            const BaiduPanRemoteFile(
              fsid: 'doc-1',
              path: '/KTV/readme.txt',
              serverFilename: 'readme.txt',
              isDirectory: false,
              size: 1,
              modifiedAtMillis: 1,
            ),
            const BaiduPanRemoteFile(
              fsid: 'dir-1',
              path: '/KTV/子目录',
              serverFilename: '子目录',
              isDirectory: true,
              size: 0,
              modifiedAtMillis: 1,
            ),
          ],
        ),
      );

      await source.refresh();

      expect(mediaIndexStore.replacedSourceSongs, hasLength(1));
      expect(mediaIndexStore.replacedSourceSongs.single.title, '青花瓷');
    },
  );

  test('refresh keeps the previous index when the remote scan fails', () async {
    final FakeMediaIndexStore mediaIndexStore = FakeMediaIndexStore();
    final BaiduPanSongSource source = BaiduPanSongSource(
      mediaLibraryRepository: createTestMediaLibraryRepository(
        mediaIndexStore: mediaIndexStore,
      ),
      sourceConfigStore: _FakeBaiduPanSourceConfigStore(
        config: const BaiduPanSourceConfig(
          sourceRootId: 'baidu_pan:/KTV',
          rootPath: '/KTV',
          displayName: '百度网盘',
        ),
      ),
      remoteDataSource: _FailingBaiduPanRemoteDataSource(),
    );

    await expectLater(source.refresh(), throwsA(isA<StateError>()));

    expect(mediaIndexStore.clearedSources, isEmpty);
    expect(mediaIndexStore.replacedSourceSongs, isEmpty);
  });
}

class _FakeBaiduPanSourceConfigStore extends BaiduPanSourceConfigStore {
  _FakeBaiduPanSourceConfigStore({this.config});

  BaiduPanSourceConfig? config;

  @override
  Future<BaiduPanSourceConfig?> loadConfig() async => config;

  @override
  Future<void> saveConfig(BaiduPanSourceConfig config) async {
    this.config = config;
  }

  @override
  Future<void> clearConfig() async {
    config = null;
  }
}

class _FakeBaiduPanRemoteDataSource extends BaiduPanRemoteDataSource {
  _FakeBaiduPanRemoteDataSource({this.files = const <BaiduPanRemoteFile>[]});

  final List<BaiduPanRemoteFile> files;

  @override
  Future<List<BaiduPanRemoteFile>> scanRoot(String rootPath) async => files;

  @override
  Future<List<BaiduPanRemoteFile>> searchFiles({
    required String keyword,
    String? rootPath,
  }) async {
    return files;
  }

  @override
  Future<BaiduPanRemoteFile> getPlayableFileMeta(String fileId) async {
    return files.firstWhere((file) => file.fsid == fileId);
  }
}

class _FailingBaiduPanRemoteDataSource extends BaiduPanRemoteDataSource {
  @override
  Future<BaiduPanRemoteFile> getPlayableFileMeta(String fileId) {
    throw UnimplementedError();
  }

  @override
  Future<List<BaiduPanRemoteFile>> scanRoot(String rootPath) {
    throw StateError('network unavailable');
  }

  @override
  Future<List<BaiduPanRemoteFile>> searchFiles({
    required String keyword,
    String? rootPath,
  }) {
    throw UnimplementedError();
  }
}
