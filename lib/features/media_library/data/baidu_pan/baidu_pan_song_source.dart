import '../../../../core/media/supported_video_formats.dart';
import '../../../../core/models/song.dart';
import '../../../ktv/application/ktv_state.dart';
import '../aggregated_library_repository.dart';
import '../media_index_store.dart';
import '../media_library_repository.dart';
import 'baidu_pan_models.dart';
import 'baidu_pan_remote_data_source.dart';
import 'baidu_pan_song_mapper.dart';
import 'baidu_pan_source_config_store.dart';

class BaiduPanSongSource implements AggregatedSongSource {
  BaiduPanSongSource({
    required MediaLibraryRepository mediaLibraryRepository,
    required BaiduPanSourceConfigStore sourceConfigStore,
    required BaiduPanRemoteDataSource remoteDataSource,
    BaiduPanSongMapper? songMapper,
  }) : _mediaLibraryRepository = mediaLibraryRepository,
       _sourceConfigStore = sourceConfigStore,
       _remoteDataSource = remoteDataSource,
       _songMapper = songMapper ?? BaiduPanSongMapper();

  @override
  String get sourceId => 'baidu_pan';

  final MediaLibraryRepository _mediaLibraryRepository;
  final BaiduPanSourceConfigStore _sourceConfigStore;
  final BaiduPanRemoteDataSource _remoteDataSource;
  final BaiduPanSongMapper _songMapper;

  @override
  bool isAvailable({String? localDirectory}) => true;

  @override
  bool supportsScope(LibraryScope scope) => scope == LibraryScope.aggregated;

  @override
  Future<void> refresh({String? localDirectory}) async {
    final BaiduPanSourceConfig? config = await _sourceConfigStore.loadConfig();
    final String rootPath = config?.rootPath.trim() ?? '';
    if (rootPath.isEmpty) {
      await _mediaLibraryRepository.mediaIndexStore.clearSourceSongs(
        sourceType: sourceId,
      );
      return;
    }

    final BaiduPanSourceConfig currentConfig = config!;
    await _mediaLibraryRepository.mediaIndexStore.clearSourceSongs(
      sourceType: sourceId,
    );
    final List<BaiduPanRemoteFile> files = await _remoteDataSource.scanRoot(
      rootPath,
    );
    final List<SourceSongRecord> songs = files
        .where((BaiduPanRemoteFile file) => !file.isDirectory)
        .where((BaiduPanRemoteFile file) {
          return supportedVideoExtensionSet.contains(
            extractVideoExtension(file.serverFilename),
          );
        })
        .map(
          (BaiduPanRemoteFile file) => _songMapper.mapRemoteFileToSourceRecord(
            file: file,
            sourceRootId: currentConfig.sourceRootId,
          ),
        )
        .toList(growable: false);

    await _mediaLibraryRepository.mediaIndexStore.replaceSourceSongs(
      sourceType: sourceId,
      sourceRootId: currentConfig.sourceRootId,
      songs: songs,
    );
  }

  @override
  Future<List<Song>> loadAllSongs({String? localDirectory}) {
    return _mediaLibraryRepository
        .loadAggregatedSongs(localDirectory: localDirectory)
        .then(
          (List<Song> songs) => songs
              .where((Song song) => song.sourceId == sourceId)
              .toList(growable: false),
        );
  }

  @override
  Future<List<Song>> getSongsByIds({
    required List<String> songIds,
    String? localDirectory,
  }) async {
    final List<Song> songs = await _mediaLibraryRepository
        .getAggregatedSongsByIds(
          songIds: songIds,
          localDirectory: localDirectory,
        );
    return songs
        .where((Song song) => song.sourceId == sourceId)
        .toList(growable: false);
  }

  @override
  Future<Song?> getSongById({required String songId, String? localDirectory}) {
    return getSongsByIds(
      songIds: <String>[songId],
      localDirectory: localDirectory,
    ).then((List<Song> songs) => songs.isEmpty ? null : songs.first);
  }

  @override
  int compareSongs(Song left, Song right) {
    final int titleCompare = left.title.compareTo(right.title);
    if (titleCompare != 0) {
      return titleCompare;
    }
    return left.artist.compareTo(right.artist);
  }
}
