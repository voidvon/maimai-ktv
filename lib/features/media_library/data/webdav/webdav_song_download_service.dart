import 'dart:io';

import '../cloud/cloud_song_download_service.dart';
import 'file_webdav_store.dart';

class WebDavSongDownloadService extends CloudSongDownloadService {
  WebDavSongDownloadService({
    required super.playbackCache,
    super.androidStorageDataSource,
    Future<Directory> Function()? fallbackDirectoryProvider,
    Future<File> Function()? downloadIndexFileProvider,
  }) : super(
         sourceId: 'webdav',
         fallbackDirectoryProvider:
             fallbackDirectoryProvider ?? resolveWebDavDownloadsDirectory,
         downloadIndexFileProvider:
             downloadIndexFileProvider ??
             (() => resolveWebDavStoreFile('downloaded_songs.json')),
         jsonMapReader: readWebDavJsonMap,
         jsonMapWriter: writeWebDavJsonMap,
         defaultFileStem: 'webdav_song',
       );
}
