import '../../../core/models/artist.dart';
import '../../../core/models/artist_page.dart';
import '../../../core/models/song.dart';
import '../../../core/models/song_page.dart';
import '../../ktv/application/ktv_state.dart';
import 'local_song_source_adapter.dart';
import 'media_library_repository.dart';

abstract class AggregatedSongSource {
  String get sourceId;

  bool isAvailable({String? localDirectory});

  bool supportsScope(LibraryScope scope);

  Future<void> refresh({String? localDirectory});

  Future<List<Song>> loadAllSongs({String? localDirectory});

  Future<List<Song>> getSongsByIds({
    required List<String> songIds,
    String? localDirectory,
  });

  Future<Song?> getSongById({required String songId, String? localDirectory});

  int compareSongs(Song left, Song right);
}

abstract class AggregatedLibraryRepository {
  Future<void> refreshSources({String? localDirectory});

  Future<SongPage> querySongs({
    required LibraryScope scope,
    required int pageIndex,
    required int pageSize,
    String? localDirectory,
    String? language,
    String? artist,
    String searchQuery = '',
  });

  Future<ArtistPage> queryArtists({
    required LibraryScope scope,
    required int pageIndex,
    required int pageSize,
    String? localDirectory,
    String? language,
    String searchQuery = '',
  });

  Future<List<Song>> getSongsByIds({
    required List<String> songIds,
    String? localDirectory,
  });

  Future<Song?> getSongById({required String songId, String? localDirectory});

  Future<String?> resolvePlayableMediaPath({
    required String songId,
    String? localDirectory,
  });
}

class DefaultAggregatedLibraryRepository
    implements AggregatedLibraryRepository {
  DefaultAggregatedLibraryRepository({
    MediaLibraryRepository? mediaLibraryRepository,
    LocalSongSourceAdapter? localSource,
    List<AggregatedSongSource>? sources,
  }) : this._(
         mediaLibraryRepository:
             mediaLibraryRepository ?? MediaLibraryRepository(),
         localSource: localSource ?? LocalSongSourceAdapter(),
         sources: sources,
       );

  DefaultAggregatedLibraryRepository._({
    required MediaLibraryRepository mediaLibraryRepository,
    required LocalSongSourceAdapter localSource,
    List<AggregatedSongSource>? sources,
  }) : _mediaLibraryRepository = mediaLibraryRepository,
       _localSource = localSource,
       _sources = sources ?? <AggregatedSongSource>[localSource] {
    assert(
      _sources.any((AggregatedSongSource source) => source.sourceId == 'local'),
      'DefaultAggregatedLibraryRepository requires a local source.',
    );
  }

  final MediaLibraryRepository _mediaLibraryRepository;
  final LocalSongSourceAdapter _localSource;
  final List<AggregatedSongSource> _sources;

  @override
  Future<void> refreshSources({String? localDirectory}) async {
    for (final AggregatedSongSource source in _sources) {
      if (!source.isAvailable(localDirectory: localDirectory)) {
        continue;
      }
      await source.refresh(localDirectory: localDirectory);
    }
  }

  @override
  Future<SongPage> querySongs({
    required LibraryScope scope,
    required int pageIndex,
    required int pageSize,
    String? localDirectory,
    String? language,
    String? artist,
    String searchQuery = '',
  }) async {
    if (scope == LibraryScope.localOnly) {
      return _queryLocalSongs(
        localDirectory: localDirectory,
        pageIndex: pageIndex,
        pageSize: pageSize,
        language: language,
        artist: artist,
        searchQuery: searchQuery,
      );
    }
    return _mediaLibraryRepository.queryAggregatedSongs(
      pageIndex: pageIndex,
      pageSize: pageSize,
      localDirectory: localDirectory,
      language: language,
      artist: artist,
      searchQuery: searchQuery,
    );
  }

  @override
  Future<ArtistPage> queryArtists({
    required LibraryScope scope,
    required int pageIndex,
    required int pageSize,
    String? localDirectory,
    String? language,
    String searchQuery = '',
  }) async {
    if (scope == LibraryScope.localOnly) {
      return _queryLocalArtists(
        localDirectory: localDirectory,
        pageIndex: pageIndex,
        pageSize: pageSize,
        language: language,
        searchQuery: searchQuery,
      );
    }
    return _mediaLibraryRepository.queryAggregatedArtists(
      pageIndex: pageIndex,
      pageSize: pageSize,
      localDirectory: localDirectory,
      language: language,
      searchQuery: searchQuery,
    );
  }

  @override
  Future<List<Song>> getSongsByIds({
    required List<String> songIds,
    String? localDirectory,
  }) async {
    if (songIds.isEmpty) {
      return const <Song>[];
    }
    return _mediaLibraryRepository.getAggregatedSongsByIds(
      songIds: songIds,
      localDirectory: localDirectory,
    );
  }

  @override
  Future<Song?> getSongById({
    required String songId,
    String? localDirectory,
  }) async {
    return _mediaLibraryRepository.getAggregatedSongById(
      songId: songId,
      localDirectory: localDirectory,
    );
  }

  @override
  Future<String?> resolvePlayableMediaPath({
    required String songId,
    String? localDirectory,
  }) async {
    final Song? song = await getSongById(
      songId: songId,
      localDirectory: localDirectory,
    );
    return song?.mediaPath;
  }

  Future<SongPage> _queryLocalSongs({
    required String? localDirectory,
    required int pageIndex,
    required int pageSize,
    String? language,
    String? artist,
    required String searchQuery,
  }) {
    if (!_localSource.isAvailable(localDirectory: localDirectory)) {
      return Future<SongPage>.value(
        SongPage(
          songs: const <Song>[],
          totalCount: 0,
          pageIndex: pageIndex,
          pageSize: pageSize,
        ),
      );
    }
    return _localSource.querySongs(
      directory: localDirectory!,
      pageIndex: pageIndex,
      pageSize: pageSize,
      language: language,
      artist: artist,
      searchQuery: searchQuery,
    );
  }

  Future<ArtistPage> _queryLocalArtists({
    required String? localDirectory,
    required int pageIndex,
    required int pageSize,
    String? language,
    required String searchQuery,
  }) {
    if (!_localSource.isAvailable(localDirectory: localDirectory)) {
      return Future<ArtistPage>.value(
        ArtistPage(
          artists: const <Artist>[],
          totalCount: 0,
          pageIndex: pageIndex,
          pageSize: pageSize,
        ),
      );
    }
    return _localSource.queryArtists(
      directory: localDirectory!,
      pageIndex: pageIndex,
      pageSize: pageSize,
      language: language,
      searchQuery: searchQuery,
    );
  }
}
