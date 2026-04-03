import 'dart:async';
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
    await reloadLibraryPage(pageIndex: 0, clearErrorMessage: true);
    if (_readState().libraryTotalCount == 0) {
      await scanLibrary(savedDirectory);
      return;
    }
    unawaited(refreshLibraryIndexInBackground(savedDirectory));
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
          libraryFavoriteSongIds: const <String>[],
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

  Future<void> requestLibraryPage({
    required int pageIndex,
    required int pageSize,
  }) {
    final KtvState state = _readState();
    final int normalizedPageSize = math.max(1, pageSize);
    final int previousOffset = state.libraryPageIndex * state.libraryPageSize;
    final int nextPageIndex = normalizedPageSize == state.libraryPageSize
        ? pageIndex
        : previousOffset ~/ normalizedPageSize;
    return reloadLibraryPage(
      pageIndex: nextPageIndex,
      pageSize: normalizedPageSize,
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
        pageIndex: _readState().libraryPageIndex,
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

  Future<void> reloadLibraryPage({
    int? pageIndex,
    int? pageSize,
    bool clearErrorMessage = false,
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
          libraryFavoriteSongIds: const <String>[],
          libraryTotalCount: 0,
          libraryPageIndex: 0,
          isLoadingLibraryPage: false,
        ),
      );
      return;
    }

    final int targetPageSize = math.max(1, pageSize ?? state.libraryPageSize);
    final int targetPageIndex = math.max(
      0,
      pageIndex ?? state.libraryPageIndex,
    );
    final int generation = ++_libraryQueryGeneration;

    _writeState(
      state.copyWith(
        isLoadingLibraryPage: true,
        libraryPageIndex: targetPageIndex,
        libraryPageSize: targetPageSize,
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
      );
    } catch (error) {
      if (generation != _libraryQueryGeneration) {
        return;
      }
      _writeState(
        _readState().copyWith(
          libraryPageSongs: const <Song>[],
          libraryPageArtists: const <Artist>[],
          libraryFavoriteSongIds: const <String>[],
          libraryTotalCount: 0,
          isLoadingLibraryPage: false,
          libraryScanErrorMessage: '加载歌曲列表失败：$error',
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
        libraryPageArtists: page.artists,
        libraryFavoriteSongIds: const <String>[],
        hasConfiguredAggregatedSources:
            _readState().hasConfiguredAggregatedSources || page.totalCount > 0,
        libraryTotalCount: page.totalCount,
        libraryPageIndex: page.pageIndex,
        libraryPageSize: page.pageSize,
        isLoadingLibraryPage: false,
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
        libraryPageSongs: page.songs,
        libraryPageArtists: const <Artist>[],
        libraryFavoriteSongIds: favoriteSongIds.toList(growable: false),
        hasConfiguredAggregatedSources:
            _readState().hasConfiguredAggregatedSources || page.totalCount > 0,
        libraryTotalCount: page.totalCount,
        libraryPageIndex: page.pageIndex,
        libraryPageSize: page.pageSize,
        isLoadingLibraryPage: false,
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
        libraryPageSongs: songs,
        libraryPageArtists: const <Artist>[],
        libraryFavoriteSongIds: favoriteSongIds,
        hasConfiguredAggregatedSources:
            _readState().hasConfiguredAggregatedSources || songs.isNotEmpty,
        libraryTotalCount: totalCount,
        libraryPageIndex: pageIndex,
        libraryPageSize: pageSize,
        isLoadingLibraryPage: false,
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
        libraryPageSongs: songs,
        libraryPageArtists: const <Artist>[],
        libraryFavoriteSongIds: favoriteSongIds.toList(growable: false),
        hasConfiguredAggregatedSources:
            _readState().hasConfiguredAggregatedSources || songs.isNotEmpty,
        libraryTotalCount: totalCount,
        libraryPageIndex: pageIndex,
        libraryPageSize: pageSize,
        isLoadingLibraryPage: false,
        libraryScanErrorMessage: clearErrorMessage
            ? null
            : _readState().libraryScanErrorMessage,
      ),
    );
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
