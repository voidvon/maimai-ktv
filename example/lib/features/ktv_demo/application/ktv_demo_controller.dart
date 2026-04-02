import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:ktv2/ktv2.dart';

import '../../../core/models/demo_artist.dart';
import '../../../core/models/demo_artist_page.dart';
import '../../../core/models/demo_song.dart';
import '../../../core/models/demo_song_page.dart';
import '../../media_library/data/demo_media_library_repository.dart';
import 'ktv_demo_state.dart';

export 'ktv_demo_state.dart' show DemoRoute, DemoSongBookMode, KtvDemoState;

class KtvDemoController extends ChangeNotifier {
  KtvDemoController({
    DemoMediaLibraryRepository? mediaLibraryRepository,
    PlayerController? playerController,
  }) : _mediaLibraryRepository =
           mediaLibraryRepository ?? DemoMediaLibraryRepository(),
       playerController = playerController ?? createPlayerController();

  static const String allLanguagesLabel = '全部';
  static const Duration _searchRefreshDebounce = Duration(milliseconds: 180);

  final DemoMediaLibraryRepository _mediaLibraryRepository;
  final PlayerController playerController;

  KtvDemoState _state = const KtvDemoState();
  bool _didInitialize = false;
  Timer? _pendingSearchRefresh;
  int _libraryQueryGeneration = 0;

  DemoMediaLibraryRepository get mediaLibraryRepository =>
      _mediaLibraryRepository;
  KtvDemoState get state => _state;

  DemoRoute get route => _state.route;
  DemoSongBookMode get songBookMode => _state.songBookMode;
  String get selectedLanguage => _state.selectedLanguage;
  String? get selectedArtist => _state.selectedArtist;
  String get searchQuery => _state.searchQuery;
  String? get libraryScanErrorMessage => _state.libraryScanErrorMessage;
  String? get scanDirectoryPath => _state.scanDirectoryPath;
  bool get isScanningLibrary => _state.isScanningLibrary;
  bool get isLoadingLibraryPage => _state.isLoadingLibraryPage;
  bool get hasConfiguredDirectory => _state.hasConfiguredDirectory;
  List<DemoSong> get queuedSongs =>
      List<DemoSong>.unmodifiable(_state.queuedSongs);
  List<DemoSong> get librarySongs =>
      List<DemoSong>.unmodifiable(_state.libraryPageSongs);
  List<DemoArtist> get libraryArtists =>
      List<DemoArtist>.unmodifiable(_state.libraryPageArtists);
  List<DemoSong> get filteredSongs => librarySongs;
  int get libraryTotalCount => _state.libraryTotalCount;
  int get libraryPageIndex => _state.libraryPageIndex;
  int get libraryPageSize => _state.libraryPageSize;
  int get libraryTotalPages => _state.libraryTotalPages;
  List<DemoSong> get filteredQueuedSongs => _state.filteredQueuedSongs();

  String get currentTitle => _state.currentTitle;

  String get currentSubtitle => _state.currentSubtitle;

  Future<void> initialize() async {
    if (_didInitialize) {
      return;
    }
    _didInitialize = true;
    await _restoreSavedDirectory();
  }

  void setSearchQuery(String query) {
    if (_state.searchQuery == query) {
      return;
    }
    _setState(_state.copyWith(searchQuery: query));
    _scheduleLibraryRefresh(resetPage: true);
  }

  void enterSongBook({DemoSongBookMode mode = DemoSongBookMode.songs}) {
    if (_state.route == DemoRoute.songBook &&
        _state.songBookMode == mode &&
        (mode == DemoSongBookMode.artists || _state.selectedArtist == null)) {
      return;
    }
    final bool shouldClearSelectedArtist = mode == DemoSongBookMode.artists;
    _setState(
      _state.copyWith(
        route: DemoRoute.songBook,
        songBookMode: mode,
        selectedArtist: shouldClearSelectedArtist
            ? null
            : _state.selectedArtist,
        searchQuery: '',
        libraryPageIndex: 0,
      ),
    );
    unawaited(_reloadLibraryPage(pageIndex: 0));
  }

  void enterQueueList() {
    if (_state.route == DemoRoute.queueList) {
      return;
    }
    _setState(_state.copyWith(route: DemoRoute.queueList));
  }

  void returnHome() {
    if (_state.route == DemoRoute.home) {
      return;
    }
    _setState(_state.copyWith(route: DemoRoute.home));
  }

  Future<void> selectArtist(String artist) async {
    final String normalizedArtist = artist.trim();
    if (normalizedArtist.isEmpty) {
      return;
    }
    _setState(
      _state.copyWith(
        route: DemoRoute.songBook,
        songBookMode: DemoSongBookMode.songs,
        selectedArtist: normalizedArtist,
        searchQuery: '',
        libraryPageIndex: 0,
      ),
    );
    await _reloadLibraryPage(pageIndex: 0);
  }

  Future<bool> returnFromSelectedArtist() async {
    if (_state.selectedArtist == null) {
      return false;
    }
    _setState(
      _state.copyWith(
        songBookMode: DemoSongBookMode.artists,
        selectedArtist: null,
        searchQuery: '',
        libraryPageIndex: 0,
      ),
    );
    await _reloadLibraryPage(pageIndex: 0);
    return true;
  }

  void selectLanguage(String language) {
    if (_state.selectedLanguage == language) {
      return;
    }
    _setState(_state.copyWith(selectedLanguage: language));
    unawaited(_reloadLibraryPage(pageIndex: 0));
  }

  Future<void> handleSelectedDirectory(String directory) async {
    _setState(_state.copyWith(scanDirectoryPath: directory));
    await _mediaLibraryRepository.saveSelectedDirectory(directory);
    await scanLibrary(directory);
  }

  Future<bool> scanLibrary(String directory) async {
    _pendingSearchRefresh?.cancel();
    _setState(
      _state.copyWith(
        scanDirectoryPath: directory,
        isScanningLibrary: true,
        libraryScanErrorMessage: null,
        selectedLanguage: allLanguagesLabel,
        songBookMode: DemoSongBookMode.songs,
        selectedArtist: null,
        route: DemoRoute.songBook,
        searchQuery: '',
        libraryPageIndex: 0,
      ),
    );

    try {
      await _mediaLibraryRepository.scanLibrary(directory);
      await _reloadLibraryPage(pageIndex: 0, clearErrorMessage: true);
      return true;
    } catch (error) {
      _setState(
        _state.copyWith(
          libraryPageSongs: const <DemoSong>[],
          libraryPageArtists: const <DemoArtist>[],
          libraryTotalCount: 0,
          libraryPageIndex: 0,
          libraryScanErrorMessage: '扫描目录失败：$error',
        ),
      );
      return false;
    } finally {
      _setState(_state.copyWith(isScanningLibrary: false));
    }
  }

  Future<void> requestLibraryPage({
    required int pageIndex,
    required int pageSize,
  }) {
    final int normalizedPageSize = math.max(1, pageSize);
    final int previousOffset = _state.libraryPageIndex * _state.libraryPageSize;
    final int nextPageIndex = normalizedPageSize == _state.libraryPageSize
        ? pageIndex
        : previousOffset ~/ normalizedPageSize;
    return _reloadLibraryPage(
      pageIndex: nextPageIndex,
      pageSize: normalizedPageSize,
    );
  }

  Future<void> requestSong(DemoSong song) async {
    final List<DemoSong> queuedSongs = List<DemoSong>.of(_state.queuedSongs);
    final bool hasCurrentSong =
        queuedSongs.isNotEmpty && playerController.hasMedia;

    if (hasCurrentSong) {
      if (queuedSongs.contains(song)) {
        return;
      }
      queuedSongs.add(song);
      _setState(_state.copyWith(queuedSongs: queuedSongs));
      return;
    }

    queuedSongs
      ..remove(song)
      ..insert(0, song);
    await playerController.openMedia(
      MediaSource(path: song.mediaPath, displayName: song.title),
    );
    _setState(_state.copyWith(queuedSongs: queuedSongs));
  }

  void prioritizeQueuedSong(DemoSong song) {
    final List<DemoSong> queuedSongs = List<DemoSong>.of(_state.queuedSongs);
    final int currentIndex = queuedSongs.indexOf(song);
    if (currentIndex <= 1) {
      return;
    }
    queuedSongs
      ..removeAt(currentIndex)
      ..insert(1, song);
    _setState(_state.copyWith(queuedSongs: queuedSongs));
  }

  void removeQueuedSong(DemoSong song) {
    final List<DemoSong> queuedSongs = List<DemoSong>.of(_state.queuedSongs);
    final int currentIndex = queuedSongs.indexOf(song);
    if (currentIndex <= 0) {
      return;
    }
    queuedSongs.removeAt(currentIndex);
    _setState(_state.copyWith(queuedSongs: queuedSongs));
  }

  void togglePlayback() {
    if (!playerController.hasMedia) {
      return;
    }
    unawaited(playerController.togglePlayback());
  }

  void toggleAudioMode() {
    if (!playerController.hasMedia) {
      return;
    }
    unawaited(playerController.toggleAudioOutputMode());
  }

  void restartPlayback() {
    if (!playerController.hasMedia) {
      return;
    }
    unawaited(playerController.seekToProgress(0));
  }

  Future<void> skipCurrentSong() async {
    if (!playerController.hasMedia && _state.queuedSongs.isEmpty) {
      return;
    }

    final List<DemoSong> remainingQueue = List<DemoSong>.of(_state.queuedSongs);
    if (remainingQueue.isNotEmpty) {
      remainingQueue.removeAt(0);
    }

    if (remainingQueue.isEmpty) {
      await playerController.stopPlayback();
      _setState(_state.copyWith(queuedSongs: const <DemoSong>[]));
      return;
    }

    final DemoSong nextSong = remainingQueue.first;
    await playerController.openMedia(
      MediaSource(path: nextSong.mediaPath, displayName: nextSong.title),
    );
    _setState(_state.copyWith(queuedSongs: remainingQueue));
  }

  Future<void> stopPlayback() {
    return playerController.stopPlayback();
  }

  Future<void> _restoreSavedDirectory() async {
    final String? savedDirectory = await _mediaLibraryRepository
        .loadSelectedDirectory();
    if (savedDirectory == null) {
      return;
    }

    final bool hasAccess = await _mediaLibraryRepository.ensureDirectoryAccess(
      savedDirectory,
    );
    if (!hasAccess) {
      await _mediaLibraryRepository.clearDirectoryAccess(path: savedDirectory);
      return;
    }

    _setState(
      _state.copyWith(
        scanDirectoryPath: savedDirectory,
        route: DemoRoute.songBook,
        songBookMode: DemoSongBookMode.songs,
        selectedArtist: null,
      ),
    );
    await _reloadLibraryPage(pageIndex: 0, clearErrorMessage: true);
    if (_state.libraryTotalCount == 0) {
      await scanLibrary(savedDirectory);
    }
  }

  void _scheduleLibraryRefresh({required bool resetPage}) {
    _pendingSearchRefresh?.cancel();
    _pendingSearchRefresh = Timer(_searchRefreshDebounce, () {
      unawaited(_reloadLibraryPage(pageIndex: resetPage ? 0 : null));
    });
  }

  Future<void> _reloadLibraryPage({
    int? pageIndex,
    int? pageSize,
    bool clearErrorMessage = false,
  }) async {
    final String? directory = _state.scanDirectoryPath;
    if (directory == null) {
      _setState(
        _state.copyWith(
          libraryPageSongs: const <DemoSong>[],
          libraryPageArtists: const <DemoArtist>[],
          libraryTotalCount: 0,
          libraryPageIndex: 0,
          isLoadingLibraryPage: false,
        ),
      );
      return;
    }

    final int targetPageSize = math.max(1, pageSize ?? _state.libraryPageSize);
    final int targetPageIndex = math.max(
      0,
      pageIndex ?? _state.libraryPageIndex,
    );
    final int generation = ++_libraryQueryGeneration;

    _setState(
      _state.copyWith(
        isLoadingLibraryPage: true,
        libraryPageIndex: targetPageIndex,
        libraryPageSize: targetPageSize,
        libraryScanErrorMessage: clearErrorMessage
            ? null
            : _state.libraryScanErrorMessage,
      ),
    );

    try {
      final String? language = _state.selectedLanguage == allLanguagesLabel
          ? null
          : _state.selectedLanguage;
      if (_state.songBookMode == DemoSongBookMode.artists &&
          _state.selectedArtist == null) {
        final DemoArtistPage page = await _mediaLibraryRepository.queryArtists(
          directory: directory,
          language: language,
          searchQuery: _state.searchQuery,
          pageIndex: targetPageIndex,
          pageSize: targetPageSize,
        );
        if (generation != _libraryQueryGeneration) {
          return;
        }

        final int totalPages = page.totalPages;
        if (page.totalCount > 0 && targetPageIndex >= totalPages) {
          await _reloadLibraryPage(
            pageIndex: totalPages - 1,
            pageSize: targetPageSize,
            clearErrorMessage: clearErrorMessage,
          );
          return;
        }

        _setState(
          _state.copyWith(
            libraryPageSongs: const <DemoSong>[],
            libraryPageArtists: page.artists,
            libraryTotalCount: page.totalCount,
            libraryPageIndex: page.pageIndex,
            libraryPageSize: page.pageSize,
            isLoadingLibraryPage: false,
            libraryScanErrorMessage: clearErrorMessage
                ? null
                : _state.libraryScanErrorMessage,
          ),
        );
        return;
      }

      final DemoSongPage page = await _mediaLibraryRepository.querySongs(
        directory: directory,
        language: language,
        artist: _state.selectedArtist,
        searchQuery: _state.searchQuery,
        pageIndex: targetPageIndex,
        pageSize: targetPageSize,
      );
      if (generation != _libraryQueryGeneration) {
        return;
      }

      final int totalPages = page.totalPages;
      if (page.totalCount > 0 && targetPageIndex >= totalPages) {
        await _reloadLibraryPage(
          pageIndex: totalPages - 1,
          pageSize: targetPageSize,
          clearErrorMessage: clearErrorMessage,
        );
        return;
      }

      _setState(
        _state.copyWith(
          libraryPageSongs: page.songs,
          libraryPageArtists: const <DemoArtist>[],
          libraryTotalCount: page.totalCount,
          libraryPageIndex: page.pageIndex,
          libraryPageSize: page.pageSize,
          isLoadingLibraryPage: false,
          libraryScanErrorMessage: clearErrorMessage
              ? null
              : _state.libraryScanErrorMessage,
        ),
      );
    } catch (error) {
      if (generation != _libraryQueryGeneration) {
        return;
      }
      _setState(
        _state.copyWith(
          libraryPageSongs: const <DemoSong>[],
          libraryPageArtists: const <DemoArtist>[],
          libraryTotalCount: 0,
          isLoadingLibraryPage: false,
          libraryScanErrorMessage: '加载歌曲列表失败：$error',
        ),
      );
    }
  }

  void _setState(KtvDemoState nextState) {
    if (identical(_state, nextState)) {
      return;
    }
    _state = nextState;
    notifyListeners();
  }

  @override
  void dispose() {
    _pendingSearchRefresh?.cancel();
    playerController.dispose();
    super.dispose();
  }
}
