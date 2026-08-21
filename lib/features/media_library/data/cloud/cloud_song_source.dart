import '../../../../core/media/supported_video_formats.dart';
import '../../../../core/models/song.dart';
import '../../../ktv/application/ktv_state.dart';
import '../aggregated_library_repository.dart';
import '../media_index_store.dart';
import '../media_library_repository.dart';
import 'cloud_models.dart';
import 'cloud_remote_data_source.dart';
import 'cloud_source_config_store.dart';

typedef CloudSourceSongRecordMapper<
  TConfig extends CloudSourceConfig,
  TFile extends CloudRemoteFile
> = SourceSongRecord Function({required TFile file, required TConfig config});

class CloudSongSource<
  TConfig extends CloudSourceConfig,
  TFile extends CloudRemoteFile
>
    implements AggregatedSongSource {
  CloudSongSource({
    required this.sourceId,
    required MediaLibraryRepository mediaLibraryRepository,
    required CloudSourceConfigStore<TConfig> sourceConfigStore,
    required CloudRemoteDataSource<TFile> remoteDataSource,
    required CloudSourceSongRecordMapper<TConfig, TFile> sourceRecordMapper,
  }) : _mediaLibraryRepository = mediaLibraryRepository,
       _sourceConfigStore = sourceConfigStore,
       _remoteDataSource = remoteDataSource,
       _sourceRecordMapper = sourceRecordMapper;

  @override
  final String sourceId;

  final MediaLibraryRepository _mediaLibraryRepository;
  final CloudSourceConfigStore<TConfig> _sourceConfigStore;
  final CloudRemoteDataSource<TFile> _remoteDataSource;
  final CloudSourceSongRecordMapper<TConfig, TFile> _sourceRecordMapper;

  @override
  bool isAvailable({String? localDirectory}) => true;

  @override
  bool supportsScope(LibraryScope scope) => scope == LibraryScope.aggregated;

  @override
  Future<void> refresh({String? localDirectory}) async {
    final TConfig? config = await _sourceConfigStore.loadConfig();
    final String rootPath = config?.rootPath.trim() ?? '';
    if (rootPath.isEmpty) {
      await _mediaLibraryRepository.mediaIndexStore.clearSourceSongs(
        sourceType: sourceId,
      );
      return;
    }

    final TConfig currentConfig = config!;
    final List<TFile> files = await _remoteDataSource.scanRoot(rootPath);
    final List<SourceSongRecord> songs = files
        .where((TFile file) => !file.isDirectory)
        .where((TFile file) {
          return supportedVideoExtensionSet.contains(
            extractVideoExtension(file.serverFilename),
          );
        })
        .map(
          (TFile file) =>
              _sourceRecordMapper(file: file, config: currentConfig),
        )
        .toList(growable: false);

    // Keep the last successful index when a remote scan fails.
    await _mediaLibraryRepository.mediaIndexStore.clearSourceSongs(
      sourceType: sourceId,
    );
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
