import '../../../core/models/demo_song.dart';
import '../../../src/demo_media_library_service.dart';
import '../../../src/demo_scan_directory_service.dart';

class DemoMediaLibraryRepository {
  DemoMediaLibraryRepository({
    DemoMediaLibraryService? mediaLibraryService,
    DemoScanDirectoryService? scanDirectoryService,
  }) : _mediaLibraryService = mediaLibraryService ?? DemoMediaLibraryService(),
       _scanDirectoryService =
           scanDirectoryService ?? DemoScanDirectoryService();

  final DemoMediaLibraryService _mediaLibraryService;
  final DemoScanDirectoryService _scanDirectoryService;

  Future<String?> pickDirectory({String? initialDirectory}) {
    return _scanDirectoryService.pickDirectory(
      initialDirectory: initialDirectory,
    );
  }

  Future<bool> ensureDirectoryAccess(String path) {
    return _scanDirectoryService.ensureDirectoryAccess(path);
  }

  Future<void> clearDirectoryAccess({String? path}) {
    return _scanDirectoryService.clearDirectoryAccess(path: path);
  }

  Future<void> saveSelectedDirectory(String path) {
    return _scanDirectoryService.saveSelectedDirectory(path);
  }

  Future<String?> loadSelectedDirectory() {
    return _scanDirectoryService.loadSelectedDirectory();
  }

  Future<List<DemoSong>> scanLibrary(String directory) async {
    final List<DemoLibrarySong> songs = await _mediaLibraryService.scanLibrary(
      directory,
    );
    return songs
        .map(
          (DemoLibrarySong song) => DemoSong(
            title: song.title,
            artist: song.artist,
            language: song.language,
            searchIndex: song.searchIndex,
            mediaPath: song.mediaPath,
          ),
        )
        .toList(growable: false);
  }
}
