import 'package:ktv2/ktv2.dart';

import '../features/ktv/application/ktv_controller.dart';
import '../features/ktv/application/playable_song_resolver.dart';
import '../features/media_library/data/aggregated_library_repository.dart';
import '../features/media_library/data/baidu_pan/baidu_pan_app_config.dart';
import '../features/media_library/data/baidu_pan/baidu_pan_http_api_client.dart';
import '../features/media_library/data/baidu_pan/baidu_pan_oauth_repository.dart';
import '../features/media_library/data/baidu_pan/baidu_pan_remote_data_source.dart';
import '../features/media_library/data/baidu_pan/baidu_pan_song_download_service.dart';
import '../features/media_library/data/baidu_pan/baidu_pan_song_source.dart';
import '../features/media_library/data/baidu_pan/file_baidu_pan_auth_store.dart';
import '../features/media_library/data/baidu_pan/file_baidu_pan_playback_cache.dart';
import '../features/media_library/data/baidu_pan/file_baidu_pan_source_config_store.dart';
import '../features/media_library/data/local_song_source_adapter.dart';
import '../features/media_library/data/media_library_repository.dart';

KtvController createKtvController({
  MediaLibraryRepository? mediaLibraryRepository,
  PlayerController? playerController,
  PlayableSongResolver? playableSongResolver,
}) {
  final MediaLibraryRepository repository =
      mediaLibraryRepository ?? MediaLibraryRepository();
  final LocalSongSourceAdapter localSongSource = LocalSongSourceAdapter(
    repository: repository,
  );
  final FileBaiduPanSourceConfigStore baiduPanSourceConfigStore =
      FileBaiduPanSourceConfigStore();
  final BaiduPanOAuthRepository baiduPanAuthRepository =
      BaiduPanOAuthRepository(
        appCredentials: kBaiduPanAppCredentials,
        authStore: FileBaiduPanAuthStore(),
      );
  final BaiduPanHttpApiClient baiduPanApiClient = BaiduPanHttpApiClient(
    authRepository: baiduPanAuthRepository,
  );
  final DefaultBaiduPanRemoteDataSource baiduPanRemoteDataSource =
      DefaultBaiduPanRemoteDataSource(apiClient: baiduPanApiClient);
  final FileBaiduPanPlaybackCache baiduPanPlaybackCache =
      FileBaiduPanPlaybackCache(
        authRepository: baiduPanAuthRepository,
        remoteDataSource: baiduPanRemoteDataSource,
      );
  final BaiduPanSongSource baiduPanSongSource = BaiduPanSongSource(
    mediaLibraryRepository: repository,
    sourceConfigStore: baiduPanSourceConfigStore,
    remoteDataSource: baiduPanRemoteDataSource,
  );
  return KtvController(
    mediaLibraryRepository: repository,
    aggregatedLibraryRepository: DefaultAggregatedLibraryRepository(
      mediaLibraryRepository: repository,
      localSource: localSongSource,
      sources: <AggregatedSongSource>[localSongSource, baiduPanSongSource],
    ),
    playerController: playerController ?? createPlayerController(),
    baiduPanSongDownloadService: BaiduPanSongDownloadService(
      playbackCache: baiduPanPlaybackCache,
    ),
    playableSongResolver:
        playableSongResolver ??
        DefaultPlayableSongResolver(
          baiduPanPlaybackCache: baiduPanPlaybackCache,
        ),
  );
}
