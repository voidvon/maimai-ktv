import '../../../core/models/artist_page.dart';
import '../../../core/models/song.dart';
import '../../../core/models/song_page.dart';
import '../../ktv/application/ktv_state.dart';
import 'aggregated_library_repository.dart';
import 'media_library_repository.dart';

class LocalSongSourceAdapter implements AggregatedSongSource {
  LocalSongSourceAdapter({MediaLibraryRepository? repository})
    : _repository = repository ?? MediaLibraryRepository();

  @override
  String get sourceId => 'local';

  final MediaLibraryRepository _repository;

  @override
  bool isAvailable({String? localDirectory}) {
    return localDirectory != null && localDirectory.trim().isNotEmpty;
  }

  @override
  Future<void> refresh({String? localDirectory}) {
    if (!isAvailable(localDirectory: localDirectory)) {
      return Future<void>.value();
    }
    return _repository.scanLibrary(localDirectory!);
  }

  Future<SongPage> querySongs({
    required String directory,
    required int pageIndex,
    required int pageSize,
    String? language,
    String? artist,
    String searchQuery = '',
  }) {
    return _repository.querySongs(
      directory: directory,
      pageIndex: pageIndex,
      pageSize: pageSize,
      language: language,
      artist: artist,
      searchQuery: searchQuery,
    );
  }

  Future<ArtistPage> queryArtists({
    required String directory,
    required int pageIndex,
    required int pageSize,
    String? language,
    String searchQuery = '',
  }) {
    return _repository.queryArtists(
      directory: directory,
      pageIndex: pageIndex,
      pageSize: pageSize,
      language: language,
      searchQuery: searchQuery,
    );
  }

  @override
  Future<List<Song>> loadAllSongs({String? localDirectory}) {
    if (!isAvailable(localDirectory: localDirectory)) {
      return Future<List<Song>>.value(const <Song>[]);
    }
    return _repository.loadAllSongs(directory: localDirectory!);
  }

  @override
  Future<List<Song>> getSongsByIds({
    required List<String> songIds,
    String? localDirectory,
  }) {
    if (!isAvailable(localDirectory: localDirectory)) {
      return Future<List<Song>>.value(const <Song>[]);
    }
    return _repository.getSongsByIds(
      directory: localDirectory!,
      songIds: songIds,
    );
  }

  @override
  Future<Song?> getSongById({required String songId, String? localDirectory}) {
    if (!isAvailable(localDirectory: localDirectory)) {
      return Future<Song?>.value(null);
    }
    return _repository.getSongById(directory: localDirectory!, songId: songId);
  }

  @override
  bool supportsScope(LibraryScope scope) => true;

  @override
  int compareSongs(Song left, Song right) {
    final int titleCompare = left.title.compareTo(right.title);
    if (titleCompare != 0) {
      return titleCompare;
    }
    return left.artist.compareTo(right.artist);
  }
}
