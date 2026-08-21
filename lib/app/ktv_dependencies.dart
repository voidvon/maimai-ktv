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
import '../features/media_library/data/cloud/cloud_playback_cache.dart';
import '../features/media_library/data/cloud/cloud_song_download_service.dart';
import '../features/media_library/data/local_song_source_adapter.dart';
import '../features/media_library/data/media_library_repository.dart';
import '../features/media_library/data/smb/file_smb_playback_cache.dart';
import '../features/media_library/data/smb/file_smb_store.dart';
import '../features/media_library/data/smb/smb_client.dart';
import '../features/media_library/data/smb/smb_credential_store.dart';
import '../features/media_library/data/smb/smb_remote_data_source.dart';
import '../features/media_library/data/smb/smb_song_download_service.dart';
import '../features/media_library/data/smb/smb_song_source.dart';
import '../features/media_library/data/webdav/file_webdav_playback_cache.dart';
import '../features/media_library/data/webdav/file_webdav_store.dart';
import '../features/media_library/data/webdav/webdav_client.dart';
import '../features/media_library/data/webdav/webdav_credential_store.dart';
import '../features/media_library/data/webdav/webdav_remote_data_source.dart';
import '../features/media_library/data/webdav/webdav_song_download_service.dart';
import '../features/media_library/data/webdav/webdav_song_source.dart';
import '../features/update/application/app_version_source.dart';
import '../features/update/application/update_controller.dart';
import '../features/update/application/update_package_downloader.dart';
import '../features/update/application/update_package_installer.dart';
import '../features/update/application/update_platform_adapter.dart';
import '../features/update/application/update_platform_info_source.dart';
import '../features/update/application/update_service.dart';
import '../features/update/data/update_manifest_client.dart';
import '../features/update/data/update_manifest_config.dart';
import '../features/update/domain/app_update_info.dart';

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
  final FileWebDavSourceConfigStore webDavConfigStore =
      FileWebDavSourceConfigStore();
  final SecureWebDavCredentialStore webDavCredentialStore =
      SecureWebDavCredentialStore();
  final WebDavClient webDavClient = WebDavClient(
    configStore: webDavConfigStore,
    credentialStore: webDavCredentialStore,
  );
  final DefaultWebDavRemoteDataSource webDavRemoteDataSource =
      DefaultWebDavRemoteDataSource(client: webDavClient);
  final FileWebDavPlaybackCache webDavPlaybackCache = FileWebDavPlaybackCache(
    client: webDavClient,
    remoteDataSource: webDavRemoteDataSource,
  );
  final WebDavSongSource webDavSongSource = WebDavSongSource(
    mediaLibraryRepository: repository,
    sourceConfigStore: webDavConfigStore,
    remoteDataSource: webDavRemoteDataSource,
  );
  final FileSmbSourceConfigStore smbConfigStore = FileSmbSourceConfigStore();
  final SecureSmbCredentialStore smbCredentialStore =
      SecureSmbCredentialStore();
  final SmbClient smbClient = SmbClient(
    configStore: smbConfigStore,
    credentialStore: smbCredentialStore,
  );
  final DefaultSmbRemoteDataSource smbRemoteDataSource =
      DefaultSmbRemoteDataSource(client: smbClient);
  final FileSmbPlaybackCache smbPlaybackCache = FileSmbPlaybackCache(
    client: smbClient,
    remoteDataSource: smbRemoteDataSource,
  );
  final SmbSongSource smbSongSource = SmbSongSource(
    mediaLibraryRepository: repository,
    sourceConfigStore: smbConfigStore,
    remoteDataSource: smbRemoteDataSource,
  );
  return KtvController(
    mediaLibraryRepository: repository,
    aggregatedLibraryRepository: DefaultAggregatedLibraryRepository(
      mediaLibraryRepository: repository,
      localSource: localSongSource,
      sources: <AggregatedSongSource>[
        localSongSource,
        baiduPanSongSource,
        webDavSongSource,
        smbSongSource,
      ],
    ),
    playerController: playerController ?? createPlayerController(),
    baiduPanSongDownloadService: BaiduPanSongDownloadService(
      playbackCache: baiduPanPlaybackCache,
    ),
    songDownloadServices: <String, CloudSongDownloadService>{
      'webdav': WebDavSongDownloadService(playbackCache: webDavPlaybackCache),
      'smb': SmbSongDownloadService(playbackCache: smbPlaybackCache),
    },
    playableSongResolver:
        playableSongResolver ??
        DefaultPlayableSongResolver(
          baiduPanPlaybackCache: baiduPanPlaybackCache,
          cloudPlaybackCaches: <String, CloudPlaybackCache>{
            'baidu_pan': baiduPanPlaybackCache,
            'webdav': webDavPlaybackCache,
            'smb': smbPlaybackCache,
          },
        ),
  );
}

UpdateController createUpdateController() {
  final AppUpdatePlatform platform = AppUpdateInfo.currentPlatform();
  final MethodChannelUpdatePlatformInfoSource platformInfoSource =
      MethodChannelUpdatePlatformInfoSource();
  return UpdateController(
    updateService: UpdateService(
      versionSource: PackageInfoAppVersionSource(),
      manifestClient: UpdateManifestClient(manifestUri: kAppUpdateManifestUri),
      platform: platform,
      platformInfoSource: platformInfoSource,
    ),
    platformAdapter: ExternalUpdatePlatformAdapter(
      platform: platform,
      releasePageUri: kAppReleasePageUri,
      platformInfoSource: platformInfoSource,
      packageDownloader: HttpUpdatePackageDownloader(),
      packageInstaller: MethodChannelUpdatePackageInstaller(),
    ),
  );
}
