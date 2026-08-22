import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import '../../../core/models/artist.dart';
import '../../../core/models/artist_page.dart';
import '../../../core/models/song.dart';
import '../../../core/models/song_page.dart';
import '../../media_library/data/aggregated_library_repository.dart';
import '../../media_library/data/media_library_repository.dart';
import '../../song_profile/data/song_profile_repository.dart';
import 'ktv_state.dart';

typedef KtvStateReader = KtvState Function();
typedef KtvStateWriter = void Function(KtvState nextState);

class LibrarySession {
  LibrarySession({
    required MediaLibraryRepository directoryRepository,
    required AggregatedLibraryRepository libraryRepository,
    required SongProfileRepository songProfileRepository,
    required KtvStateReader readState,
    required KtvStateWriter writeState,
    required this.allLanguagesLabel,
  }) : _directoryRepository = directoryRepository,
       _libraryRepository = libraryRepository,
       _songProfileRepository = songProfileRepository,
       _readState = readState,
       _writeState = writeState;

  final MediaLibraryRepository _directoryRepository;
  final AggregatedLibraryRepository _libraryRepository;
  final SongProfileRepository _songProfileRepository;
  final KtvStateReader _readState;
  final KtvStateWriter _writeState;
  final String allLanguagesLabel;

  int _libraryQueryGeneration = 0;

  Future<void> restoreSavedDirectory() async {
    final String? savedDirectory = await _directoryRepository
        .loadSelectedDirectory();
    if (savedDirectory == null) {
      await _syncConfiguredSourceFlags(localDirectory: null);
      return;
    }

    final bool hasAccess = await _directoryRepository.ensureDirectoryAccess(
      savedDirectory,
    );
    if (!hasAccess) {
      await _directoryRepository.clearDirectoryAccess(path: savedDirectory);
      await _syncConfiguredSourceFlags(localDirectory: null);
      return;
    }

    await _directoryRepository.markSourceConfigured(
      sourceType: 'local',
      sourceRootId: savedDirectory,
    );
    _writeState(
      _readState().copyWith(
        scanDirectoryPath: savedDirectory,
        hasConfiguredAggregatedSources: true,
      ),
    );
    await scanLibrary(savedDirectory);
  }

  Future<void> handleSelectedDirectory(String directory) async {
    await _directoryRepository.markSourceConfigured(
      sourceType: 'local',
      sourceRootId: directory,
    );
    _writeState(
      _readState().copyWith(
        scanDirectoryPath: directory,
        hasConfiguredAggregatedSources: true,
      ),
    );
    await _directoryRepository.saveSelectedDirectory(directory);
    await scanLibrary(directory);
  }

  Future<bool> scanLibrary(String directory) async {
    _writeState(
      _readState().copyWith(
        scanDirectoryPath: directory,
        hasConfiguredAggregatedSources: true,
        isScanningLibrary: true,
        libraryScanErrorMessage: null,
        selectedLanguage: allLanguagesLabel,
        searchQuery: '',
        libraryPageIndex: 0,
      ),
    );

    try {
      await _libraryRepository.refreshSources(localDirectory: directory);
      await reloadLibraryPage(pageIndex: 0, clearErrorMessage: true);
      return true;
    } catch (error) {
      _writeState(
        _readState().copyWith(
          libraryPageSongs: const <Song>[],
          libraryPageArtists: const <Artist>[],
          libraryFavoriteSongIds: const <String>{},
          libraryTotalCount: 0,
          libraryPageIndex: 0,
          libraryScanErrorMessage: '扫描本地目录失败：$error',
        ),
      );
      return false;
    } finally {
      _writeState(_readState().copyWith(isScanningLibrary: false));
    }
  }

  Future<void> loadNextLibraryPage() {
    final KtvState state = _readState();
    if (state.route != KtvRoute.songBook ||
        state.isLoadingLibraryPage ||
        !state.hasMoreLibraryItems) {
      return Future<void>.value();
    }
    return reloadLibraryPage(
      pageIndex: state.libraryPageIndex + 1,
      pageSize: state.libraryPageSize,
      append: true,
    );
  }

  Future<void> refreshLoadedLibraryItems() {
    final KtvState state = _readState();
    final int retainedPageIndex = state.libraryPageIndex;
    final int retainedPageSize = state.libraryPageSize;
    return reloadLibraryPage(
      pageIndex: 0,
      pageSize: retainedPageSize * (retainedPageIndex + 1),
      retainedPageIndex: retainedPageIndex,
      retainedPageSize: retainedPageSize,
    );
  }

  Future<void> refreshLibraryIndexInBackground(String directory) async {
    if (_readState().scanDirectoryPath != directory) {
      return;
    }
    _writeState(
      _readState().copyWith(
        isScanningLibrary: true,
        libraryScanErrorMessage: null,
      ),
    );
    try {
      await _libraryRepository.refreshSources(localDirectory: directory);
      if (_readState().scanDirectoryPath != directory) {
        return;
      }
      await reloadLibraryPage(
        pageIndex: 0,
        pageSize: _readState().libraryPageSize,
        clearErrorMessage: true,
      );
    } catch (error) {
      if (_readState().scanDirectoryPath != directory) {
        return;
      }
      _writeState(
        _readState().copyWith(libraryScanErrorMessage: '后台刷新本地目录失败：$error'),
      );
    } finally {
      if (_readState().scanDirectoryPath == directory) {
        _writeState(_readState().copyWith(isScanningLibrary: false));
      }
    }
  }

  Future<void> refreshConfiguredSources() async {
    final KtvState state = _readState();
    final String? directory = state.scanDirectoryPath;
    _writeState(
      state.copyWith(isScanningLibrary: true, libraryScanErrorMessage: null),
    );
    try {
      await _libraryRepository.refreshSources(localDirectory: directory);
      await _syncConfiguredSourceFlags(localDirectory: directory);
      await reloadLibraryPage(
        pageIndex: 0,
        pageSize: state.libraryPageSize,
        clearErrorMessage: true,
      );
    } catch (error) {
      _writeState(
        _readState().copyWith(libraryScanErrorMessage: '刷新数据源失败：$error'),
      );
    } finally {
      _writeState(_readState().copyWith(isScanningLibrary: false));
    }
  }

  Future<void> reloadLibraryPage({
    int? pageIndex,
    int? pageSize,
    bool clearErrorMessage = false,
    bool append = false,
    int? retainedPageIndex,
    int? retainedPageSize,
  }) async {
    final KtvState state = _readState();
    final String? directory = state.scanDirectoryPath;
    final bool requiresLocalDirectory =
        state.libraryScope == LibraryScope.localOnly;
    if (requiresLocalDirectory && directory == null) {
      _writeState(
        state.copyWith(
          libraryPageSongs: const <Song>[],
          libraryPageArtists: const <Artist>[],
          libraryFavoriteSongIds: const <String>{},
          libraryTotalCount: 0,
          libraryPageIndex: 0,
          isLoadingLibraryPage: false,
          libraryLoadMoreErrorMessage: null,
        ),
      );
      return;
    }

    final int targetPageSize = math.max(1, pageSize ?? state.libraryPageSize);
    final int targetPageIndex = math.max(
      0,
      pageIndex ?? state.libraryPageIndex,
    );
    final int loadingPageIndex = math.max(
      0,
      retainedPageIndex ?? (append ? state.libraryPageIndex : targetPageIndex),
    );
    final int resultPageIndex = math.max(
      0,
      retainedPageIndex ?? targetPageIndex,
    );
    final int resultPageSize = math.max(1, retainedPageSize ?? targetPageSize);
    final int generation = ++_libraryQueryGeneration;

    _writeState(
      state.copyWith(
        isLoadingLibraryPage: true,
        libraryPageIndex: loadingPageIndex,
        libraryPageSize: resultPageSize,
        libraryLoadMoreErrorMessage: null,
        libraryScanErrorMessage: clearErrorMessage
            ? null
            : state.libraryScanErrorMessage,
      ),
    );

    try {
      final KtvState currentState = _readState();
      final String? language =
          currentState.selectedLanguage == allLanguagesLabel
          ? null
          : currentState.selectedLanguage;
      final String searchQuery = currentState.searchQuery;
      if (currentState.songBookMode == SongBookMode.artists &&
          currentState.selectedArtist == null) {
        await _loadArtistPage(
          generation: generation,
          directory: directory,
          scope: currentState.libraryScope,
          language: language,
          searchQuery: searchQuery,
          pageIndex: targetPageIndex,
          pageSize: targetPageSize,
          clearErrorMessage: clearErrorMessage,
          append: append,
          resultPageIndex: resultPageIndex,
          resultPageSize: resultPageSize,
        );
        return;
      }

      if (currentState.songBookMode == SongBookMode.favorites) {
        await _loadFavoritePage(
          generation: generation,
          directory: directory,
          language: language,
          artist: currentState.selectedArtist,
          searchQuery: searchQuery,
          pageIndex: targetPageIndex,
          pageSize: targetPageSize,
          clearErrorMessage: clearErrorMessage,
          append: append,
          resultPageIndex: resultPageIndex,
          resultPageSize: resultPageSize,
        );
        return;
      }

      if (currentState.songBookMode == SongBookMode.frequent) {
        await _loadFrequentPage(
          generation: generation,
          directory: directory,
          language: language,
          artist: currentState.selectedArtist,
          searchQuery: searchQuery,
          pageIndex: targetPageIndex,
          pageSize: targetPageSize,
          clearErrorMessage: clearErrorMessage,
          append: append,
          resultPageIndex: resultPageIndex,
          resultPageSize: resultPageSize,
        );
        return;
      }

      await _loadSongPage(
        generation: generation,
        directory: directory,
        scope: currentState.libraryScope,
        language: language,
        artist: currentState.selectedArtist,
        searchQuery: searchQuery,
        pageIndex: targetPageIndex,
        pageSize: targetPageSize,
        clearErrorMessage: clearErrorMessage,
        append: append,
        resultPageIndex: resultPageIndex,
        resultPageSize: resultPageSize,
      );
    } catch (error) {
      if (generation != _libraryQueryGeneration) {
        return;
      }
      final KtvState currentState = _readState();
      _writeState(
        append
            ? currentState.copyWith(
                isLoadingLibraryPage: false,
                libraryLoadMoreErrorMessage: '加载更多歌曲失败：$error',
              )
            : currentState.copyWith(
                libraryPageSongs: const <Song>[],
                libraryPageArtists: const <Artist>[],
                libraryFavoriteSongIds: const <String>{},
                libraryTotalCount: 0,
                isLoadingLibraryPage: false,
                libraryScanErrorMessage: '加载歌曲列表失败：$error',
                libraryLoadMoreErrorMessage: null,
              ),
      );
    }
  }

  Future<void> _loadArtistPage({
    required int generation,
    required String? directory,
    required LibraryScope scope,
    required String? language,
    required String searchQuery,
    required int pageIndex,
    required int pageSize,
    required bool clearErrorMessage,
    required bool append,
    required int resultPageIndex,
    required int resultPageSize,
  }) async {
    final ArtistPage page = await _libraryRepository.queryArtists(
      scope: scope,
      pageIndex: pageIndex,
      pageSize: pageSize,
      localDirectory: directory,
      language: language,
      searchQuery: searchQuery,
    );
    if (generation != _libraryQueryGeneration) {
      return;
    }

    final int totalPages = page.totalPages;
    if (page.totalCount > 0 && pageIndex >= totalPages) {
      if (append) {
        _writeState(
          _readState().copyWith(
            libraryTotalCount: page.totalCount,
            isLoadingLibraryPage: false,
            libraryLoadMoreErrorMessage: null,
          ),
        );
        return;
      }
      await reloadLibraryPage(
        pageIndex: totalPages - 1,
        pageSize: pageSize,
        clearErrorMessage: clearErrorMessage,
      );
      return;
    }

    _writeState(
      _readState().copyWith(
        libraryPageSongs: const <Song>[],
        libraryPageArtists: append
            ? _mergeArtists(_readState().libraryPageArtists, page.artists)
            : page.artists,
        libraryFavoriteSongIds: const <String>{},
        hasConfiguredAggregatedSources:
            _readState().hasConfiguredAggregatedSources || page.totalCount > 0,
        libraryTotalCount: page.totalCount,
        libraryPageIndex: resultPageIndex,
        libraryPageSize: resultPageSize,
        isLoadingLibraryPage: false,
        libraryLoadMoreErrorMessage: null,
        libraryScanErrorMessage: clearErrorMessage
            ? null
            : _readState().libraryScanErrorMessage,
      ),
    );
  }

  Future<void> _loadSongPage({
    required int generation,
    required String? directory,
    required LibraryScope scope,
    required String? language,
    required String? artist,
    required String searchQuery,
    required int pageIndex,
    required int pageSize,
    required bool clearErrorMessage,
    required bool append,
    required int resultPageIndex,
    required int resultPageSize,
  }) async {
    final SongPage page = await _libraryRepository.querySongs(
      scope: scope,
      pageIndex: pageIndex,
      pageSize: pageSize,
      localDirectory: directory,
      language: language,
      artist: artist,
      searchQuery: searchQuery,
    );
    if (generation != _libraryQueryGeneration) {
      return;
    }

    final int totalPages = page.totalPages;
    if (page.totalCount > 0 && pageIndex >= totalPages) {
      if (append) {
        _writeState(
          _readState().copyWith(
            libraryTotalCount: page.totalCount,
            isLoadingLibraryPage: false,
            libraryLoadMoreErrorMessage: null,
          ),
        );
        return;
      }
      await reloadLibraryPage(
        pageIndex: totalPages - 1,
        pageSize: pageSize,
        clearErrorMessage: clearErrorMessage,
      );
      return;
    }

    final Set<String> favoriteSongIds = await _songProfileRepository
        .loadFavoriteSongIds(page.songs.map((Song song) => song.songId));
    if (generation != _libraryQueryGeneration) {
      return;
    }

    _writeState(
      _readState().copyWith(
        libraryPageSongs: append
            ? _mergeSongs(_readState().libraryPageSongs, page.songs)
            : page.songs,
        libraryPageArtists: const <Artist>[],
        libraryFavoriteSongIds: append
            ? _mergeIds(_readState().libraryFavoriteSongIds, favoriteSongIds)
            : Set<String>.unmodifiable(favoriteSongIds),
        hasConfiguredAggregatedSources:
            _readState().hasConfiguredAggregatedSources || page.totalCount > 0,
        libraryTotalCount: page.totalCount,
        libraryPageIndex: resultPageIndex,
        libraryPageSize: resultPageSize,
        isLoadingLibraryPage: false,
        libraryLoadMoreErrorMessage: null,
        libraryScanErrorMessage: clearErrorMessage
            ? null
            : _readState().libraryScanErrorMessage,
      ),
    );
  }

  Future<void> _loadFavoritePage({
    required int generation,
    required String? directory,
    required String? language,
    required String? artist,
    required String searchQuery,
    required int pageIndex,
    required int pageSize,
    required bool clearErrorMessage,
    required bool append,
    required int resultPageIndex,
    required int resultPageSize,
  }) async {
    final List<String> favoriteSongIds = await _songProfileRepository
        .queryFavoriteSongIds(
          pageIndex: pageIndex,
          pageSize: pageSize,
          language: language,
          artist: artist,
          searchQuery: searchQuery,
        );
    if (generation != _libraryQueryGeneration) {
      return;
    }

    final List<Song> songs = await _libraryRepository.getSongsByIds(
      songIds: favoriteSongIds,
      localDirectory: directory,
    );
    if (generation != _libraryQueryGeneration) {
      return;
    }

    final int totalCount = await _songProfileRepository.countFavoriteSongs(
      language: language,
      artist: artist,
      searchQuery: searchQuery,
    );
    if (generation != _libraryQueryGeneration) {
      return;
    }

    _writeState(
      _readState().copyWith(
        libraryPageSongs: append
            ? _mergeSongs(_readState().libraryPageSongs, songs)
            : songs,
        libraryPageArtists: const <Artist>[],
        libraryFavoriteSongIds: append
            ? _mergeIds(_readState().libraryFavoriteSongIds, favoriteSongIds)
            : Set<String>.unmodifiable(favoriteSongIds),
        hasConfiguredAggregatedSources:
            _readState().hasConfiguredAggregatedSources || songs.isNotEmpty,
        libraryTotalCount: totalCount,
        libraryPageIndex: resultPageIndex,
        libraryPageSize: resultPageSize,
        isLoadingLibraryPage: false,
        libraryLoadMoreErrorMessage: null,
        libraryScanErrorMessage: clearErrorMessage
            ? null
            : _readState().libraryScanErrorMessage,
      ),
    );
  }

  Future<void> _loadFrequentPage({
    required int generation,
    required String? directory,
    required String? language,
    required String? artist,
    required String searchQuery,
    required int pageIndex,
    required int pageSize,
    required bool clearErrorMessage,
    required bool append,
    required int resultPageIndex,
    required int resultPageSize,
  }) async {
    final List<String> songIds = await _songProfileRepository
        .queryFrequentSongIds(
          pageIndex: pageIndex,
          pageSize: pageSize,
          language: language,
          artist: artist,
          searchQuery: searchQuery,
        );
    if (generation != _libraryQueryGeneration) {
      return;
    }

    final List<Song> songs = await _libraryRepository.getSongsByIds(
      songIds: songIds,
      localDirectory: directory,
    );
    if (generation != _libraryQueryGeneration) {
      return;
    }

    final Set<String> favoriteSongIds = await _songProfileRepository
        .loadFavoriteSongIds(songIds);
    if (generation != _libraryQueryGeneration) {
      return;
    }

    final int totalCount = await _songProfileRepository.countFrequentSongs(
      language: language,
      artist: artist,
      searchQuery: searchQuery,
    );
    if (generation != _libraryQueryGeneration) {
      return;
    }

    _writeState(
      _readState().copyWith(
        libraryPageSongs: append
            ? _mergeSongs(_readState().libraryPageSongs, songs)
            : songs,
        libraryPageArtists: const <Artist>[],
        libraryFavoriteSongIds: append
            ? _mergeIds(_readState().libraryFavoriteSongIds, favoriteSongIds)
            : Set<String>.unmodifiable(favoriteSongIds),
        hasConfiguredAggregatedSources:
            _readState().hasConfiguredAggregatedSources || songs.isNotEmpty,
        libraryTotalCount: totalCount,
        libraryPageIndex: resultPageIndex,
        libraryPageSize: resultPageSize,
        isLoadingLibraryPage: false,
        libraryLoadMoreErrorMessage: null,
        libraryScanErrorMessage: clearErrorMessage
            ? null
            : _readState().libraryScanErrorMessage,
      ),
    );
  }

  List<Song> _mergeSongs(List<Song> loaded, Iterable<Song> nextPage) {
    final List<Song> merged = List<Song>.of(loaded);
    final Set<Song> seen = loaded.toSet();
    for (final Song song in nextPage) {
      if (seen.add(song)) {
        merged.add(song);
      }
    }
    return UnmodifiableListView<Song>(merged);
  }

  List<Artist> _mergeArtists(List<Artist> loaded, Iterable<Artist> nextPage) {
    final List<Artist> merged = List<Artist>.of(loaded);
    final Set<String> seenNames = loaded
        .map((Artist artist) => artist.name)
        .toSet();
    for (final Artist artist in nextPage) {
      if (seenNames.add(artist.name)) {
        merged.add(artist);
      }
    }
    return UnmodifiableListView<Artist>(merged);
  }

  Set<String> _mergeIds(Iterable<String> loaded, Iterable<String> nextPage) {
    return UnmodifiableSetView<String>(<String>{...loaded, ...nextPage});
  }

  Future<void> _syncConfiguredSourceFlags({
    required String? localDirectory,
  }) async {
    final bool hasConfiguredAggregatedSources = await _directoryRepository
        .hasConfiguredAggregatedSources(localDirectory: localDirectory);
    _writeState(
      _readState().copyWith(
        hasConfiguredAggregatedSources: hasConfiguredAggregatedSources,
      ),
    );
  }
}
