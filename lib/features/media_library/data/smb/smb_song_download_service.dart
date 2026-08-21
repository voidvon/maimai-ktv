import 'dart:io';

import '../cloud/cloud_song_download_service.dart';
import 'file_smb_store.dart';

class SmbSongDownloadService extends CloudSongDownloadService {
  SmbSongDownloadService({
    required super.playbackCache,
    super.androidStorageDataSource,
    Future<Directory> Function()? fallbackDirectoryProvider,
    Future<File> Function()? downloadIndexFileProvider,
  }) : super(
         sourceId: 'smb',
         fallbackDirectoryProvider:
             fallbackDirectoryProvider ?? resolveSmbDownloadsDirectory,
         downloadIndexFileProvider:
             downloadIndexFileProvider ??
             (() => resolveSmbStoreFile('downloaded_songs.json')),
         jsonMapReader: readSmbJsonMap,
         jsonMapWriter: writeSmbJsonMap,
         defaultFileStem: 'smb_song',
       );
}
