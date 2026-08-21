import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:ktv2/ktv2.dart';
import 'package:maimai_ktv/core/models/artist.dart';
import 'package:maimai_ktv/core/models/song.dart';
import 'package:maimai_ktv/core/models/song_page.dart';
import 'package:maimai_ktv/core/models/artist_page.dart';
import 'package:maimai_ktv/core/models/song_identity.dart';
import 'package:maimai_ktv/features/ktv/application/download_manager_models.dart';
import 'package:maimai_ktv/features/ktv/application/download_task_store.dart';
import 'package:maimai_ktv/features/ktv/application/ktv_state.dart';
import 'package:maimai_ktv/features/ktv/application/playback_session_store.dart';
import 'package:maimai_ktv/features/media_library/data/aggregated_library_repository.dart';
import 'package:maimai_ktv/features/media_library/data/cloud/cloud_playback_cache.dart';
import 'package:maimai_ktv/features/media_library/data/cloud/cloud_song_download_service.dart';
import 'package:maimai_ktv/features/media_library/data/media_index_store.dart';
import 'package:maimai_ktv/features/media_library/data/media_library_repository.dart';
import 'package:maimai_ktv/features/media_library/data/scan_directory_data_source.dart';

Song buildLocalSong({
  required String title,
  required String artist,
  String language = '国语',
  String? mediaPath,
  String? searchIndex,
}) {
  return Song(
    songId: buildAggregateSongId(title: title, artist: artist),
    sourceId: 'local',
    sourceSongId: buildLocalSourceSongId(
      fingerprint: buildLocalMetadataFingerprint(
        locator: mediaPath ?? '/library/$artist-$title.mp4',
      ),
    ),
    title: title,
    artist: artist,
    languages: <String>[language],
    searchIndex: (searchIndex ?? '$title $artist $language').toLowerCase(),
    mediaPath: mediaPath ?? '/library/$artist-$title.mp4',
  );
}

Song buildRemoteSong({
  required String title,
  required String artist,
  required String sourceId,
  required String sourceSongId,
  String language = '国语',
  String? mediaPath,
  String? searchIndex,
}) {
  return Song(
    songId: buildAggregateSongId(title: title, artist: artist),
    sourceId: sourceId,
    sourceSongId: sourceSongId,
    title: title,
    artist: artist,
    languages: <String>[language],
    searchIndex: (searchIndex ?? '$title $artist $language').toLowerCase(),
    mediaPath: mediaPath ?? '$sourceId://$sourceSongId',
  );
}

MediaLibraryRepository createTestMediaLibraryRepository({
  String? savedDirectory,
  Set<String> accessibleDirectories = const <String>{},
  bool hasConfiguredAggregatedSources = false,
  FakeMediaIndexStore? mediaIndexStore,
}) {
  final FakeMediaIndexStore store =
      mediaIndexStore ??
      FakeMediaIndexStore(
        savedDirectory: savedDirectory,
        hasConfiguredAggregatedSources: hasConfiguredAggregatedSources,
      );
  return MediaLibraryRepository(
    scanDirectoryDataSource: FakeScanDirectoryDataSource(
      mediaIndexStore: store,
      accessibleDirectories: accessibleDirectories,
    ),
    mediaIndexStore: store,
  );
}

class FakeMediaIndexStore extends MediaIndexStore {
  FakeMediaIndexStore({
    this.savedDirectory,
    this.hasConfiguredAggregatedSources = false,
  });

  String? savedDirectory;
  bool hasConfiguredAggregatedSources;
  final List<({String sourceType, String sourceRootId})> configuredSources =
      <({String sourceType, String sourceRootId})>[];
  final List<({String sourceType, String? sourceRootId})> clearedSources =
      <({String sourceType, String? sourceRootId})>[];
  final List<SourceSongRecord> replacedSourceSongs = <SourceSongRecord>[];

  @override
  Future<void> upsertSourceSyncState({
    required String sourceType,
    required String sourceRootId,
    String? syncToken,
    int? lastSyncedAt,
    String syncStatus = 'configured',
    String? lastError,
  }) async {
    configuredSources.add((sourceType: sourceType, sourceRootId: sourceRootId));
  }

  @override
  Future<bool> hasConfiguredAggregateSources({
    String? activeLocalRootId,
  }) async {
    return hasConfiguredAggregatedSources;
  }

  @override
  Future<void> saveSelectedDirectory(String path) async {
    savedDirectory = path.trim().isEmpty ? null : path;
  }

  @override
  Future<String?> loadSelectedDirectory() async {
    final String normalized = savedDirectory?.trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }

  @override
  Future<void> clearSelectedDirectory() async {
    savedDirectory = null;
  }

  @override
  Future<void> clearSourceSongs({
    required String sourceType,
    String? sourceRootId,
  }) async {
    clearedSources.add((sourceType: sourceType, sourceRootId: sourceRootId));
  }

  @override
  Future<int> replaceSourceSongs({
    required String sourceType,
    required String sourceRootId,
    required List<SourceSongRecord> songs,
  }) async {
    replacedSourceSongs
      ..clear()
      ..addAll(songs);
    configuredSources.add((sourceType: sourceType, sourceRootId: sourceRootId));
    return songs.length;
  }
}

class FakeScanDirectoryDataSource extends ScanDirectoryDataSource {
  FakeScanDirectoryDataSource({
    required FakeMediaIndexStore mediaIndexStore,
    this.accessibleDirectories = const <String>{},
  }) : _mediaIndexStore = mediaIndexStore,
       super(mediaIndexStore: mediaIndexStore);

  final FakeMediaIndexStore _mediaIndexStore;
  final Set<String> accessibleDirectories;
  final List<String?> clearedPaths = <String?>[];

  @override
  Future<bool> ensureDirectoryAccess(String path) async {
    return accessibleDirectories.isEmpty ||
        accessibleDirectories.contains(path);
  }

  @override
  Future<void> clearDirectoryAccess({String? path}) async {
    clearedPaths.add(path);
    final String normalizedTarget = path?.trim() ?? '';
    final String saved = _mediaIndexStore.savedDirectory?.trim() ?? '';
    if (normalizedTarget.isEmpty || normalizedTarget == saved) {
      await _mediaIndexStore.clearSelectedDirectory();
    }
  }

  @override
  Future<void> saveSelectedDirectory(String path) {
    return _mediaIndexStore.saveSelectedDirectory(path);
  }

  @override
  Future<String?> loadSelectedDirectory() {
    return _mediaIndexStore.loadSelectedDirectory();
  }
}

class FakeAggregatedLibraryRepository implements AggregatedLibraryRepository {
  FakeAggregatedLibraryRepository({
    Map<String, List<Song>>? localSongsByDirectory,
    List<Song>? aggregatedSongs,
  }) : _localSongsByDirectory = localSongsByDirectory ?? <String, List<Song>>{},
       _aggregatedSongs = aggregatedSongs ?? <Song>[];

  final Map<String, List<Song>> _localSongsByDirectory;
  final List<Song> _aggregatedSongs;
  final List<String?> refreshCalls = <String?>[];

  @override
  Future<void> refreshSources({String? localDirectory}) async {
    refreshCalls.add(localDirectory);
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
    final List<Song> songs = _filterSongs(
      _songsForScope(scope: scope, localDirectory: localDirectory),
      language: language,
      artist: artist,
      searchQuery: searchQuery,
    );
    return SongPage(
      songs: _sliceSongs(songs, pageIndex: pageIndex, pageSize: pageSize),
      totalCount: songs.length,
      pageIndex: pageIndex,
      pageSize: pageSize,
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
    final List<Song> songs = _filterSongs(
      _songsForScope(scope: scope, localDirectory: localDirectory),
      language: language,
      searchQuery: '',
    );
    final String normalizedQuery = searchQuery.trim().toLowerCase();
    final Map<String, List<Song>> songsByArtist = <String, List<Song>>{};
    for (final Song song in songs) {
      songsByArtist.putIfAbsent(song.artist, () => <Song>[]).add(song);
    }
    final List<Artist> artists =
        songsByArtist.entries
            .map(
              (MapEntry<String, List<Song>> entry) => Artist(
                name: entry.key,
                songCount: entry.value.length,
                searchIndex: entry.key.toLowerCase(),
              ),
            )
            .where(
              (Artist artist) =>
                  normalizedQuery.isEmpty ||
                  artist.searchIndex.contains(normalizedQuery),
            )
            .toList(growable: false)
          ..sort(
            (Artist left, Artist right) => left.name.compareTo(right.name),
          );
    return ArtistPage(
      artists: _sliceArtists(artists, pageIndex: pageIndex, pageSize: pageSize),
      totalCount: artists.length,
      pageIndex: pageIndex,
      pageSize: pageSize,
    );
  }

  @override
  Future<List<Song>> getSongsByIds({
    required List<String> songIds,
    String? localDirectory,
  }) async {
    final Map<String, Song> songsById = <String, Song>{
      for (final Song song in <Song>[
        ..._aggregatedSongs,
        ...?_localSongsByDirectory[localDirectory],
      ])
        song.songId: song,
    };
    return songIds
        .map((String songId) => songsById[songId])
        .whereType<Song>()
        .toList(growable: false);
  }

  @override
  Future<Song?> getSongById({
    required String songId,
    String? localDirectory,
  }) async {
    final List<Song> songs = await getSongsByIds(
      songIds: <String>[songId],
      localDirectory: localDirectory,
    );
    return songs.isEmpty ? null : songs.first;
  }

  @override
  Future<String?> resolvePlayableMediaPath({
    required String songId,
    String? localDirectory,
  }) async {
    return (await getSongById(
      songId: songId,
      localDirectory: localDirectory,
    ))?.mediaPath;
  }

  List<Song> _songsForScope({
    required LibraryScope scope,
    required String? localDirectory,
  }) {
    return switch (scope) {
      LibraryScope.localOnly => List<Song>.of(
        _localSongsByDirectory[localDirectory] ?? const <Song>[],
      ),
      LibraryScope.aggregated => List<Song>.of(_aggregatedSongs),
    };
  }

  List<Song> _filterSongs(
    List<Song> songs, {
    String? language,
    String? artist,
    required String searchQuery,
  }) {
    final String normalizedLanguage = language?.trim() ?? '';
    final String normalizedArtist = artist?.trim() ?? '';
    final String normalizedQuery = searchQuery.trim().toLowerCase();
    return songs
        .where((Song song) {
          final bool matchesLanguage =
              normalizedLanguage.isEmpty ||
              song.languages.contains(normalizedLanguage);
          final bool matchesArtist =
              normalizedArtist.isEmpty || song.artist == normalizedArtist;
          final bool matchesQuery =
              normalizedQuery.isEmpty ||
              song.searchIndex.contains(normalizedQuery);
          return matchesLanguage && matchesArtist && matchesQuery;
        })
        .toList(growable: false)
      ..sort((Song left, Song right) => left.title.compareTo(right.title));
  }

  List<Song> _sliceSongs(
    List<Song> songs, {
    required int pageIndex,
    required int pageSize,
  }) {
    final int normalizedPageIndex = pageIndex < 0 ? 0 : pageIndex;
    final int normalizedPageSize = pageSize <= 0 ? 1 : pageSize;
    final int start = normalizedPageIndex * normalizedPageSize;
    final int end = (start + normalizedPageSize).clamp(0, songs.length);
    return start >= songs.length ? const <Song>[] : songs.sublist(start, end);
  }

  List<Artist> _sliceArtists(
    List<Artist> artists, {
    required int pageIndex,
    required int pageSize,
  }) {
    final int normalizedPageIndex = pageIndex < 0 ? 0 : pageIndex;
    final int normalizedPageSize = pageSize <= 0 ? 1 : pageSize;
    final int start = normalizedPageIndex * normalizedPageSize;
    final int end = (start + normalizedPageSize).clamp(0, artists.length);
    return start >= artists.length
        ? const <Artist>[]
        : artists.sublist(start, end);
  }
}

class FakePlayerController extends PlayerController {
  PlayerState _state = const PlayerState();

  @override
  PlayerState get state => _state;

  void setState(PlayerState nextState) {
    _state = nextState;
    notifyListeners();
  }

  @override
  Future<void> openMedia(MediaSource source) async {
    setState(
      PlayerState(
        currentMediaPath: source.path,
        isPlaying: true,
        playbackDuration: const Duration(minutes: 4),
      ),
    );
  }

  @override
  Future<void> togglePlayback() async {
    setState(
      PlayerState(
        currentMediaPath: _state.currentMediaPath,
        isPlaying: !_state.isPlaying,
        playbackDuration: _state.playbackDuration,
        playbackPosition: _state.playbackPosition,
        audioOutputMode: _state.audioOutputMode,
        pitchShiftSemitones: _state.pitchShiftSemitones,
      ),
    );
  }

  @override
  Future<void> seekToProgress(double progress) async {
    final Duration duration = _state.playbackDuration;
    setState(
      PlayerState(
        currentMediaPath: _state.currentMediaPath,
        isPlaying: _state.isPlaying,
        playbackDuration: duration,
        playbackPosition: Duration(
          milliseconds: (duration.inMilliseconds * progress.clamp(0.0, 1.0))
              .round(),
        ),
        audioOutputMode: _state.audioOutputMode,
        pitchShiftSemitones: _state.pitchShiftSemitones,
      ),
    );
  }

  @override
  Future<void> applyAudioOutputMode(AudioOutputMode mode) async {
    setState(
      PlayerState(
        currentMediaPath: _state.currentMediaPath,
        isPlaying: _state.isPlaying,
        playbackDuration: _state.playbackDuration,
        playbackPosition: _state.playbackPosition,
        audioOutputMode: mode,
        pitchShiftSemitones: _state.pitchShiftSemitones,
      ),
    );
  }

  @override
  Future<void> setPitchShiftSemitones(int semitones) async {
    setState(
      PlayerState(
        currentMediaPath: _state.currentMediaPath,
        isPlaying: _state.isPlaying,
        playbackDuration: _state.playbackDuration,
        playbackPosition: _state.playbackPosition,
        audioOutputMode: _state.audioOutputMode,
        pitchShiftSemitones: semitones.clamp(
          PlayerController.minPitchShiftSemitones,
          PlayerController.maxPitchShiftSemitones,
        ),
      ),
    );
  }

  @override
  Widget? buildVideoView() => null;
}

class MemoryDownloadTaskStore extends DownloadTaskStore {
  MemoryDownloadTaskStore([List<DownloadingSongItem>? initialTasks])
    : _tasks = List<DownloadingSongItem>.of(
        initialTasks ?? const <DownloadingSongItem>[],
      ),
      super(fileProvider: _unusedFileProvider);

  List<DownloadingSongItem> _tasks;

  @override
  Future<List<DownloadingSongItem>> loadTasks() async {
    return List<DownloadingSongItem>.of(_tasks);
  }

  @override
  Future<void> saveTasks(List<DownloadingSongItem> tasks) async {
    _tasks = List<DownloadingSongItem>.of(tasks);
  }
}

class MemoryPlaybackSessionStore extends PlaybackSessionStore {
  MemoryPlaybackSessionStore({PersistedPlaybackSession? initialSession})
    : _session = initialSession,
      super(fileProvider: _unusedFileProvider);

  PersistedPlaybackSession? _session;

  @override
  Future<PersistedPlaybackSession?> loadSession() async {
    return _session;
  }

  @override
  Future<void> saveSession(PersistedPlaybackSession session) async {
    _session = session;
  }

  @override
  Future<void> clearSession() async {
    _session = null;
  }
}

class FakeCloudSongDownloadService extends CloudSongDownloadService {
  FakeCloudSongDownloadService({
    required super.sourceId,
    List<CloudDownloadedSongRecord>? downloadedSongs,
  }) : _downloadedSongs = List<CloudDownloadedSongRecord>.of(
         downloadedSongs ?? const <CloudDownloadedSongRecord>[],
       ),
       super(
         playbackCache: const _FakeCloudPlaybackCache(),
         fallbackDirectoryProvider: _tempDirectoryProvider,
         downloadIndexFileProvider: _unusedFileProvider,
       );

  final List<CloudDownloadedSongRecord> _downloadedSongs;

  @override
  Future<List<CloudDownloadedSongRecord>> loadDownloadedSongs() async {
    return List<CloudDownloadedSongRecord>.of(_downloadedSongs);
  }
}

class _FakeCloudPlaybackCache implements CloudPlaybackCache {
  const _FakeCloudPlaybackCache();

  @override
  Future<CloudCachedMedia> resolve({
    required Song song,
    required String sourceSongId,
    void Function(double progress)? onProgress,
    CloudDownloadCancellationToken? cancellationToken,
  }) async {
    return const CloudCachedMedia(
      localPath: '/tmp/fake-media.mp4',
      displayName: 'fake-media.mp4',
    );
  }

  @override
  Future<void> clearExpiredCache() async {}
}

Future<File> _unusedFileProvider() async {
  return File('${Directory.systemTemp.path}/ktv-test-unused.json');
}

Future<Directory> _tempDirectoryProvider() async {
  return Directory.systemTemp;
}
