import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:ktv2/ktv2.dart';

import '../../../core/models/artist.dart';
import '../../../core/models/song.dart';
import '../../media_library/data/aggregated_library_repository.dart';
import '../../media_library/data/baidu_pan/baidu_pan_song_download_service.dart';
import '../../media_library/data/cloud/cloud_playback_cache.dart';
import '../../media_library/data/cloud/cloud_song_download_service.dart';
import '../../media_library/data/local_song_source_adapter.dart';
import '../../media_library/data/media_library_repository.dart';
import '../../song_profile/data/song_profile_repository.dart';
import 'download_manager_models.dart';
import 'library_session.dart';
import 'navigation_history.dart';
import 'playback_queue_manager.dart';
import 'playable_song_resolver.dart';
import 'ktv_state.dart';

export 'ktv_state.dart' show KtvRoute, SongBookMode, LibraryScope, KtvState;

class KtvController extends ChangeNotifier {
  KtvController({
    MediaLibraryRepository? mediaLibraryRepository,
    AggregatedLibraryRepository? aggregatedLibraryRepository,
    SongProfileRepository? songProfileRepository,
    PlayerController? playerController,
    PlayableSongResolver? playableSongResolver,
    BaiduPanSongDownloadService? baiduPanSongDownloadService,
    Map<String, CloudSongDownloadService>? songDownloadServices,
  }) : _mediaLibraryRepository =
           mediaLibraryRepository ?? MediaLibraryRepository(),
       _songProfileRepository =
           songProfileRepository ?? SongProfileRepository(),
       playerController = playerController ?? createPlayerController(),
       _playableSongResolver =
           playableSongResolver ?? const DefaultPlayableSongResolver(),
       _songDownloadServices = _resolveSongDownloadServices(
         playableSongResolver: playableSongResolver,
         baiduPanSongDownloadService: baiduPanSongDownloadService,
         songDownloadServices: songDownloadServices,
       ) {
    _aggregatedLibraryRepository =
        aggregatedLibraryRepository ??
        DefaultAggregatedLibraryRepository(
          mediaLibraryRepository: _mediaLibraryRepository,
          localSource: LocalSongSourceAdapter(
            repository: _mediaLibraryRepository,
          ),
        );
  }

  static const String allLanguagesLabel = '全部';
  static const Duration _searchRefreshDebounce = Duration(milliseconds: 180);

  static BaiduPanSongDownloadService? _createDefaultDownloadService(
    PlayableSongResolver? resolver,
  ) {
    if (resolver is! DefaultPlayableSongResolver) {
      return null;
    }
    final playbackCache = resolver.baiduPanPlaybackCache;
    if (playbackCache == null) {
      return null;
    }
    return BaiduPanSongDownloadService(playbackCache: playbackCache);
  }

  static Map<String, CloudSongDownloadService> _resolveSongDownloadServices({
    required PlayableSongResolver? playableSongResolver,
    required BaiduPanSongDownloadService? baiduPanSongDownloadService,
    required Map<String, CloudSongDownloadService>? songDownloadServices,
  }) {
    final Map<String, CloudSongDownloadService> resolvedServices =
        <String, CloudSongDownloadService>{...?songDownloadServices};
    final BaiduPanSongDownloadService? baiduService =
        baiduPanSongDownloadService ??
        _createDefaultDownloadService(playableSongResolver);
    if (baiduService != null) {
      resolvedServices[baiduService.sourceId] = baiduService;
    }
    return Map<String, CloudSongDownloadService>.unmodifiable(resolvedServices);
  }

  final MediaLibraryRepository _mediaLibraryRepository;
  late final AggregatedLibraryRepository _aggregatedLibraryRepository;
  final SongProfileRepository _songProfileRepository;
  final PlayerController playerController;
  final PlayableSongResolver _playableSongResolver;
  final Map<String, CloudSongDownloadService> _songDownloadServices;
  late final PlaybackQueueManager _playbackQueueManager = PlaybackQueueManager(
    playerController: playerController,
    playableSongResolver: _playableSongResolver,
  );
  late final LibrarySession _librarySession = LibrarySession(
    directoryRepository: _mediaLibraryRepository,
    libraryRepository: _aggregatedLibraryRepository,
    songProfileRepository: _songProfileRepository,
    readState: () => _state,
    writeState: _setState,
    allLanguagesLabel: allLanguagesLabel,
  );
  final NavigationHistory _navigationHistory = NavigationHistory();

  KtvState _state = const KtvState();
  bool _didInitialize = false;
  Timer? _pendingSearchRefresh;
  final Set<String> _downloadingSongIds = <String>{};
  final Set<String> _downloadedSongKeys = <String>{};
  final Map<String, DownloadingSongItem> _downloadingSongsByKey =
      <String, DownloadingSongItem>{};
  final Map<String, DownloadedSongItem> _downloadedSongsByKey =
      <String, DownloadedSongItem>{};
  final Map<String, CloudDownloadCancellationToken>
  _downloadCancellationTokens = <String, CloudDownloadCancellationToken>{};

  MediaLibraryRepository get mediaLibraryRepository => _mediaLibraryRepository;
  KtvState get state => _state;

  KtvRoute get route => _state.route;
  SongBookMode get songBookMode => _state.songBookMode;
  LibraryScope get libraryScope => _state.libraryScope;
  String get selectedLanguage => _state.selectedLanguage;
  String? get selectedArtist => _state.selectedArtist;
  String get searchQuery => _state.searchQuery;
  String? get libraryScanErrorMessage => _state.libraryScanErrorMessage;
  String? get scanDirectoryPath => _state.scanDirectoryPath;
  bool get isScanningLibrary => _state.isScanningLibrary;
  bool get isLoadingLibraryPage => _state.isLoadingLibraryPage;
  bool get hasConfiguredDirectory => _state.hasConfiguredDirectory;
  bool get hasConfiguredAggregatedSources =>
      _state.hasConfiguredAggregatedSources;
  bool get canNavigateBack => _navigationHistory.canNavigateBack;
  List<Song> get queuedSongs => List<Song>.unmodifiable(_state.queuedSongs);
  List<Song> get librarySongs =>
      List<Song>.unmodifiable(_state.libraryPageSongs);
  List<Artist> get libraryArtists =>
      List<Artist>.unmodifiable(_state.libraryPageArtists);
  List<String> get favoriteSongIds =>
      List<String>.unmodifiable(_state.libraryFavoriteSongIds);
  Set<String> get downloadingSongIds =>
      Set<String>.unmodifiable(_downloadingSongIds);
  Set<String> get downloadedSongKeys =>
      Set<String>.unmodifiable(_downloadedSongKeys);
  Set<String> get downloadableSourceIds =>
      Set<String>.unmodifiable(_songDownloadServices.keys.toSet());
  List<DownloadingSongItem> get downloadingSongs {
    final List<DownloadingSongItem> items = _downloadingSongsByKey.values
        .toList(growable: false);
    items.sort(
      (DownloadingSongItem a, DownloadingSongItem b) =>
          b.startedAtMillis.compareTo(a.startedAtMillis),
    );
    return items;
  }

  List<DownloadedSongItem> get downloadedSongs {
    final List<DownloadedSongItem> items = _downloadedSongsByKey.values.toList(
      growable: false,
    );
    items.sort(
      (DownloadedSongItem a, DownloadedSongItem b) =>
          b.savedAtMillis.compareTo(a.savedAtMillis),
    );
    return items;
  }

  List<Song> get filteredSongs => librarySongs;
  int get libraryTotalCount => _state.libraryTotalCount;
  int get libraryPageIndex => _state.libraryPageIndex;
  int get libraryPageSize => _state.libraryPageSize;
  int get libraryTotalPages => _state.libraryTotalPages;
  List<Song> get filteredQueuedSongs => _state.filteredQueuedSongs();

  String get currentTitle => _state.currentTitle;

  String get currentSubtitle => _state.currentSubtitle;

  String get breadcrumbLabel => _navigationHistory.breadcrumbLabel;

  Future<void> initialize() async {
    if (_didInitialize) {
      return;
    }
    _didInitialize = true;
    await _librarySession.restoreSavedDirectory();
    if (_songDownloadServices.isNotEmpty) {
      _downloadedSongKeys.clear();
      _downloadedSongsByKey.clear();
      for (final CloudSongDownloadService service
          in _songDownloadServices.values) {
        final List<CloudDownloadedSongRecord> records = await service
            .loadDownloadedSongs();
        for (final CloudDownloadedSongRecord record in records) {
          final String key = _buildDownloadKey(
            sourceId: record.sourceId,
            sourceSongId: record.sourceSongId,
          );
          _downloadedSongKeys.add(key);
          _downloadedSongsByKey[key] = DownloadedSongItem.fromRecord(record);
        }
      }
      notifyListeners();
    }
  }

  void setSearchQuery(String query) {
    if (_state.searchQuery == query) {
      return;
    }
    _setState(_state.copyWith(searchQuery: query));
    _scheduleLibraryRefresh(resetPage: true);
  }

  void enterSongBook({
    SongBookMode mode = SongBookMode.songs,
    LibraryScope? scope,
  }) {
    if (!_navigationHistory.enterSongBook(mode: mode, scope: scope)) {
      return;
    }
    _applyNavigationState(_navigationHistory.current);
    unawaited(_librarySession.reloadLibraryPage(pageIndex: 0));
  }

  void enterFavoritesBook() {
    enterSongBook(mode: SongBookMode.favorites);
  }

  void enterFrequentBook() {
    enterSongBook(mode: SongBookMode.frequent);
  }

  void enterQueueList() {
    if (!_navigationHistory.enterQueueList(
      songBookMode: _state.songBookMode,
      libraryScope: _state.libraryScope,
      selectedArtist: _state.selectedArtist,
    )) {
      return;
    }
    _applyNavigationState(_navigationHistory.current);
  }

  void returnHome() {
    if (!_navigationHistory.returnHome()) {
      return;
    }
    _applyNavigationState(_navigationHistory.current);
  }

  Future<void> selectArtist(String artist) async {
    if (!_navigationHistory.selectArtist(artist)) {
      return;
    }
    _applyNavigationState(_navigationHistory.current);
    await _librarySession.reloadLibraryPage(pageIndex: 0);
  }

  Future<bool> returnFromSelectedArtist() async {
    if (!canNavigateBack) {
      return false;
    }
    return navigateBack();
  }

  Future<bool> navigateBack() async {
    final NavigationDestination? target = _navigationHistory.navigateBack();
    if (target == null) {
      return false;
    }
    _applyNavigationState(target);
    if (target.route == KtvRoute.home) {
      return true;
    }
    await _librarySession.reloadLibraryPage(pageIndex: 0);
    return true;
  }

  void selectLanguage(String language) {
    if (_state.selectedLanguage == language) {
      return;
    }
    _setState(_state.copyWith(selectedLanguage: language));
    unawaited(_librarySession.reloadLibraryPage(pageIndex: 0));
  }

  Future<void> handleSelectedDirectory(String directory) async {
    await _librarySession.handleSelectedDirectory(directory);
  }

  Future<bool> scanLibrary(String directory) async {
    _pendingSearchRefresh?.cancel();
    return _librarySession.scanLibrary(directory);
  }

  Future<void> refreshConfiguredSources() {
    _pendingSearchRefresh?.cancel();
    return _librarySession.refreshConfiguredSources();
  }

  Future<void> requestLibraryPage({
    required int pageIndex,
    required int pageSize,
  }) {
    return _librarySession.requestLibraryPage(
      pageIndex: pageIndex,
      pageSize: pageSize,
    );
  }

  Future<void> requestSong(Song song) async {
    final bool startsPlaybackImmediately =
        !(_state.queuedSongs.isNotEmpty && playerController.hasMedia);
    await _recordSongRequested(song);
    final List<Song> nextQueue = await _playbackQueueManager.requestSong(
      _state.queuedSongs,
      song,
    );
    if (startsPlaybackImmediately) {
      await _recordSongStarted(song);
    }
    _setState(_state.copyWith(queuedSongs: nextQueue));
    await _reloadSongProfileDrivenPageIfNeeded();
  }

  Future<CloudSongDownloadResult> downloadSongToLocal(Song song) async {
    final CloudSongDownloadService? downloader =
        _songDownloadServices[song.sourceId];
    if (downloader == null) {
      throw StateError('${song.sourceId} 下载服务未启用');
    }
    if (_downloadingSongIds.contains(song.songId)) {
      throw StateError('这首歌曲正在下载中');
    }

    _downloadingSongIds.add(song.songId);
    final String downloadKey = _buildDownloadKey(
      sourceId: song.sourceId,
      sourceSongId: song.sourceSongId,
    );
    final CloudDownloadCancellationToken cancellationToken =
        CloudDownloadCancellationToken();
    _downloadCancellationTokens[downloadKey] = cancellationToken;
    _downloadingSongsByKey[downloadKey] = DownloadingSongItem(
      songId: song.songId,
      sourceId: song.sourceId,
      sourceSongId: song.sourceSongId,
      title: song.title,
      artist: song.artist,
      startedAtMillis: DateTime.now().millisecondsSinceEpoch,
    );
    notifyListeners();
    try {
      final String? preferredDirectory = _state.scanDirectoryPath;
      final CloudSongDownloadResult result = await downloader.downloadSong(
        song: song,
        preferredDirectory: preferredDirectory,
        cancellationToken: cancellationToken,
        onProgress: (CloudDownloadProgress progress) {
          final DownloadingSongItem? current =
              _downloadingSongsByKey[downloadKey];
          if (current == null) {
            return;
          }
          _downloadingSongsByKey[downloadKey] = current.copyWith(
            progress: progress.value,
            phaseLabel: progress.phaseLabel,
          );
          notifyListeners();
        },
      );
      if (result.usedPreferredDirectory &&
          preferredDirectory != null &&
          preferredDirectory.trim().isNotEmpty) {
        unawaited(
          _librarySession.refreshLibraryIndexInBackground(preferredDirectory),
        );
      }
      _downloadedSongKeys.add(downloadKey);
      _downloadedSongsByKey[downloadKey] = DownloadedSongItem(
        sourceId: song.sourceId,
        sourceSongId: song.sourceSongId,
        title: song.title,
        artist: song.artist,
        savedPath: result.savedPath,
        savedAtMillis: DateTime.now().millisecondsSinceEpoch,
      );
      notifyListeners();
      return result;
    } finally {
      _downloadingSongIds.remove(song.songId);
      _downloadingSongsByKey.remove(downloadKey);
      _downloadCancellationTokens.remove(downloadKey);
      notifyListeners();
    }
  }

  void cancelDownload({
    required String sourceId,
    required String sourceSongId,
  }) {
    final String downloadKey = _buildDownloadKey(
      sourceId: sourceId,
      sourceSongId: sourceSongId,
    );
    _downloadCancellationTokens[downloadKey]?.cancel();
  }

  Future<void> deleteDownloadedSong({
    required String sourceId,
    required String sourceSongId,
  }) async {
    final CloudSongDownloadService? downloader =
        _songDownloadServices[sourceId];
    if (downloader == null) {
      throw StateError('$sourceId 下载服务未启用');
    }
    await downloader.deleteDownloadedSong(sourceSongId: sourceSongId);
    final String downloadKey = _buildDownloadKey(
      sourceId: sourceId,
      sourceSongId: sourceSongId,
    );
    _downloadedSongKeys.remove(downloadKey);
    _downloadedSongsByKey.remove(downloadKey);
    notifyListeners();
  }

  void prioritizeQueuedSong(Song song) {
    _setState(
      _state.copyWith(
        queuedSongs: _playbackQueueManager.prioritizeQueuedSong(
          _state.queuedSongs,
          song,
        ),
      ),
    );
  }

  void removeQueuedSong(Song song) {
    _setState(
      _state.copyWith(
        queuedSongs: _playbackQueueManager.removeQueuedSong(
          _state.queuedSongs,
          song,
        ),
      ),
    );
  }

  void togglePlayback() {
    _playbackQueueManager.togglePlayback();
  }

  void toggleAudioMode() {
    _playbackQueueManager.toggleAudioMode();
  }

  void restartPlayback() {
    _playbackQueueManager.restartPlayback();
  }

  Future<void> skipCurrentSong() async {
    final List<Song> nextQueue = await _playbackQueueManager.skipCurrentSong(
      _state.queuedSongs,
    );
    if (nextQueue.isNotEmpty) {
      await _recordSongStarted(nextQueue.first);
    }
    _setState(_state.copyWith(queuedSongs: nextQueue));
    await _reloadSongProfileDrivenPageIfNeeded();
  }

  Future<void> toggleFavorite(Song song) async {
    final bool isFavorite = await _songProfileRepository.toggleFavorite(
      song: song,
    );
    final Set<String> nextFavoriteSongIds = _state.libraryFavoriteSongIds
        .toSet();
    if (isFavorite) {
      nextFavoriteSongIds.add(song.songId);
    } else {
      nextFavoriteSongIds.remove(song.songId);
    }
    _setState(
      _state.copyWith(
        libraryFavoriteSongIds: nextFavoriteSongIds.toList(growable: false),
      ),
    );

    if (_state.songBookMode == SongBookMode.favorites) {
      await _librarySession.reloadLibraryPage(
        pageIndex: _state.libraryPageIndex,
      );
    }
  }

  Future<void> stopPlayback() {
    return _playbackQueueManager.stopPlayback();
  }

  void _scheduleLibraryRefresh({required bool resetPage}) {
    _pendingSearchRefresh?.cancel();
    _pendingSearchRefresh = Timer(_searchRefreshDebounce, () {
      unawaited(
        _librarySession.reloadLibraryPage(pageIndex: resetPage ? 0 : null),
      );
    });
  }

  void _setState(KtvState nextState) {
    if (identical(_state, nextState)) {
      return;
    }
    _state = nextState;
    notifyListeners();
  }

  Future<void> _recordSongRequested(Song song) async {
    await _songProfileRepository.recordSongRequested(song: song);
  }

  Future<void> _recordSongStarted(Song song) async {
    await _songProfileRepository.recordSongStarted(song: song);
  }

  Future<void> _reloadSongProfileDrivenPageIfNeeded() async {
    if (_state.route != KtvRoute.songBook ||
        _state.songBookMode != SongBookMode.frequent) {
      return;
    }
    await _librarySession.reloadLibraryPage(pageIndex: _state.libraryPageIndex);
  }

  void _applyNavigationState(NavigationDestination target) {
    _setState(
      _state.copyWith(
        route: target.route,
        songBookMode: target.songBookMode,
        libraryScope: target.libraryScope,
        selectedArtist: target.selectedArtist,
        searchQuery: '',
        libraryPageIndex: 0,
        libraryFavoriteSongIds: const <String>[],
      ),
    );
  }

  String buildDownloadKeyForSong(Song song) {
    return _buildDownloadKey(
      sourceId: song.sourceId,
      sourceSongId: song.sourceSongId,
    );
  }

  String _buildDownloadKey({
    required String sourceId,
    required String sourceSongId,
  }) {
    return '$sourceId::${sourceSongId.trim()}';
  }

  @override
  void dispose() {
    _pendingSearchRefresh?.cancel();
    unawaited(_songProfileRepository.close());
    playerController.dispose();
    super.dispose();
  }
}
