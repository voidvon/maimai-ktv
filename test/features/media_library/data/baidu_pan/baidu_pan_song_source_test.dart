import 'package:flutter_test/flutter_test.dart';
import 'package:ktv2_example/features/media_library/data/baidu_pan/baidu_pan_models.dart';
import 'package:ktv2_example/features/media_library/data/baidu_pan/baidu_pan_remote_data_source.dart';
import 'package:ktv2_example/features/media_library/data/baidu_pan/baidu_pan_song_source.dart';
import 'package:ktv2_example/features/media_library/data/baidu_pan/baidu_pan_source_config_store.dart';
import 'package:ktv2_example/features/media_library/data/media_library_repository.dart';

void main() {
  test(
    'refresh scans only configured baidu pan folder and indexes media',
    () async {
      final MediaLibraryRepository repository = MediaLibraryRepository();
      addTearDown(repository.mediaIndexStore.close);
      final _FakeBaiduPanSourceConfigStore sourceConfigStore =
          _FakeBaiduPanSourceConfigStore(
            config: const BaiduPanSourceConfig(
              sourceRootId: 'baidu_pan:/KTV',
              rootPath: '/KTV',
              displayName: '百度网盘',
            ),
          );
      final _FakeBaiduPanRemoteDataSource remoteDataSource =
          _FakeBaiduPanRemoteDataSource(
            files: <BaiduPanRemoteFile>[
              const BaiduPanRemoteFile(
                fsid: '1',
                path: '/KTV/周杰伦-青花瓷-国语.mp4',
                serverFilename: '周杰伦-青花瓷-国语.mp4',
                isDirectory: false,
                size: 1024,
                modifiedAtMillis: 1710000000000,
              ),
              const BaiduPanRemoteFile(
                fsid: '2',
                path: '/KTV/说明.txt',
                serverFilename: '说明.txt',
                isDirectory: false,
                size: 32,
                modifiedAtMillis: 1710000000000,
              ),
            ],
          );
      final BaiduPanSongSource source = BaiduPanSongSource(
        mediaLibraryRepository: repository,
        sourceConfigStore: sourceConfigStore,
        remoteDataSource: remoteDataSource,
      );

      await source.refresh();

      expect(remoteDataSource.lastScannedRootPath, '/KTV');
      final songs = await repository.queryAggregatedSongs(
        pageIndex: 0,
        pageSize: 20,
        localDirectory: null,
      );
      expect(songs.songs, hasLength(1));
      expect(songs.songs.single.sourceId, 'baidu_pan');
      expect(songs.songs.single.title, '青花瓷');
      expect(songs.songs.single.artist, '周杰伦');
    },
  );
}

class _FakeBaiduPanRemoteDataSource implements BaiduPanRemoteDataSource {
  _FakeBaiduPanRemoteDataSource({required this.files});

  final List<BaiduPanRemoteFile> files;
  String? lastScannedRootPath;

  @override
  Future<BaiduPanRemoteFile> getPlayableFileMeta(String fsid) async {
    throw UnimplementedError();
  }

  @override
  Future<List<BaiduPanRemoteFile>> scanRoot(String rootPath) async {
    lastScannedRootPath = rootPath;
    return files;
  }

  @override
  Future<List<BaiduPanRemoteFile>> searchFiles({
    required String keyword,
    String? rootPath,
  }) async {
    throw UnimplementedError();
  }
}

class _FakeBaiduPanSourceConfigStore implements BaiduPanSourceConfigStore {
  _FakeBaiduPanSourceConfigStore({this.config});

  BaiduPanSourceConfig? config;

  @override
  Future<void> clearConfig() async {
    config = null;
  }

  @override
  Future<BaiduPanSourceConfig?> loadConfig() async => config;

  @override
  Future<void> saveConfig(BaiduPanSourceConfig config) async {
    this.config = config;
  }
}
