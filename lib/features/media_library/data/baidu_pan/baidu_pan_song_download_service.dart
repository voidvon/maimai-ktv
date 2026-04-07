import 'dart:io';

import '../../../../core/models/song.dart';
import '../cloud/cloud_playback_cache.dart';
import '../cloud/cloud_song_download_service.dart';
import '_baidu_pan_file_store_support.dart';
import 'baidu_pan_playback_cache.dart';

class BaiduPanDownloadResult extends CloudSongDownloadResult {
  const BaiduPanDownloadResult({
    required super.savedPath,
    required super.usedPreferredDirectory,
  });
}

class BaiduPanSongDownloadService extends CloudSongDownloadService {
  BaiduPanSongDownloadService({
    required BaiduPanPlaybackCache playbackCache,
    super.androidStorageDataSource,
    Future<Directory> Function()? fallbackDirectoryProvider,
    Future<File> Function()? downloadIndexFileProvider,
  }) : super(
         sourceId: 'baidu_pan',
         playbackCache: playbackCache,
         fallbackDirectoryProvider:
             fallbackDirectoryProvider ?? resolveBaiduPanDownloadsDirectory,
         downloadIndexFileProvider:
             downloadIndexFileProvider ??
             (() => resolveBaiduPanStoreFile('downloaded_songs.json')),
         jsonMapReader: readJsonMapFile,
         jsonMapWriter: writeJsonMapFile,
         defaultFileStem: 'baidu_pan_song',
       );

  @override
  Future<BaiduPanDownloadResult> downloadSong({
    required Song song,
    String? preferredDirectory,
    void Function(CloudDownloadProgress progress)? onProgress,
    CloudDownloadCancellationToken? cancellationToken,
  }) async {
    final CloudSongDownloadResult result = await super.downloadSong(
      song: song,
      preferredDirectory: preferredDirectory,
      onProgress: onProgress,
      cancellationToken: cancellationToken,
    );
    return BaiduPanDownloadResult(
      savedPath: result.savedPath,
      usedPreferredDirectory: result.usedPreferredDirectory,
    );
  }
}
