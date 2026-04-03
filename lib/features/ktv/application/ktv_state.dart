import '../../../core/models/song.dart';
import '../../../core/models/artist.dart';

enum KtvRoute { home, songBook, queueList }

enum SongBookMode { songs, artists, favorites, frequent }

enum LibraryScope { localOnly, aggregated }

class LibraryState {
  const LibraryState({
    this.scanDirectoryPath,
    this.scope = LibraryScope.localOnly,
    this.hasConfiguredAggregatedSources = false,
    this.searchQuery = '',
    this.isScanningLibrary = false,
    this.isLoadingLibraryPage = false,
    this.pageSongs = const <Song>[],
    this.pageArtists = const <Artist>[],
    this.favoriteSongIds = const <String>[],
    this.totalCount = 0,
    this.pageIndex = 0,
    this.pageSize = 8,
    this.scanErrorMessage,
  });

  static const Object _unset = Object();

  final String? scanDirectoryPath;
  final LibraryScope scope;
  final bool hasConfiguredAggregatedSources;
  final String searchQuery;
  final bool isScanningLibrary;
  final bool isLoadingLibraryPage;
  final List<Song> pageSongs;
  final List<Artist> pageArtists;
  final List<String> favoriteSongIds;
  final int totalCount;
  final int pageIndex;
  final int pageSize;
  final String? scanErrorMessage;

  bool get hasConfiguredDirectory => scanDirectoryPath != null;

  int get totalPages {
    if (pageSize <= 0 || totalCount <= 0) {
      return 1;
    }
    return ((totalCount + pageSize - 1) / pageSize).ceil();
  }

  LibraryState copyWith({
    Object? scanDirectoryPath = _unset,
    LibraryScope? scope,
    bool? hasConfiguredAggregatedSources,
    String? searchQuery,
    bool? isScanningLibrary,
    bool? isLoadingLibraryPage,
    List<Song>? pageSongs,
    List<Artist>? pageArtists,
    List<String>? favoriteSongIds,
    int? totalCount,
    int? pageIndex,
    int? pageSize,
    Object? scanErrorMessage = _unset,
  }) {
    return LibraryState(
      scanDirectoryPath: identical(scanDirectoryPath, _unset)
          ? this.scanDirectoryPath
          : scanDirectoryPath as String?,
      scope: scope ?? this.scope,
      hasConfiguredAggregatedSources:
          hasConfiguredAggregatedSources ?? this.hasConfiguredAggregatedSources,
      searchQuery: searchQuery ?? this.searchQuery,
      isScanningLibrary: isScanningLibrary ?? this.isScanningLibrary,
      isLoadingLibraryPage: isLoadingLibraryPage ?? this.isLoadingLibraryPage,
      pageSongs: pageSongs ?? this.pageSongs,
      pageArtists: pageArtists ?? this.pageArtists,
      favoriteSongIds: favoriteSongIds ?? this.favoriteSongIds,
      totalCount: totalCount ?? this.totalCount,
      pageIndex: pageIndex ?? this.pageIndex,
      pageSize: pageSize ?? this.pageSize,
      scanErrorMessage: identical(scanErrorMessage, _unset)
          ? this.scanErrorMessage
          : scanErrorMessage as String?,
    );
  }
}

class PlaybackState {
  const PlaybackState({this.queuedSongs = const <Song>[]});

  final List<Song> queuedSongs;

  PlaybackState copyWith({List<Song>? queuedSongs}) {
    return PlaybackState(queuedSongs: queuedSongs ?? this.queuedSongs);
  }
}

class KtvState {
  const KtvState({
    this.route = KtvRoute.home,
    this.songBookMode = SongBookMode.songs,
    this.selectedLanguage = '全部',
    this.selectedArtist,
    this.library = const LibraryState(),
    this.playback = const PlaybackState(),
  });

  static const Object _unset = Object();

  final KtvRoute route;
  final SongBookMode songBookMode;
  final String selectedLanguage;
  final String? selectedArtist;
  final LibraryState library;
  final PlaybackState playback;

  String? get libraryScanErrorMessage => library.scanErrorMessage;
  String? get scanDirectoryPath => library.scanDirectoryPath;
  LibraryScope get libraryScope => library.scope;
  bool get hasConfiguredAggregatedSources =>
      library.hasConfiguredAggregatedSources;
  String get searchQuery => library.searchQuery;
  bool get isScanningLibrary => library.isScanningLibrary;
  bool get isLoadingLibraryPage => library.isLoadingLibraryPage;
  List<Song> get queuedSongs => playback.queuedSongs;
  List<Song> get libraryPageSongs => library.pageSongs;
  List<Artist> get libraryPageArtists => library.pageArtists;
  List<String> get libraryFavoriteSongIds => library.favoriteSongIds;
  int get libraryTotalCount => library.totalCount;
  int get libraryPageIndex => library.pageIndex;
  int get libraryPageSize => library.pageSize;

  bool get hasConfiguredDirectory => library.hasConfiguredDirectory;
  bool get isArtistMode => songBookMode == SongBookMode.artists;

  String get normalizedSearchQuery => library.searchQuery.trim().toLowerCase();

  int get libraryTotalPages => library.totalPages;

  List<Song> filteredQueuedSongs() {
    if (normalizedSearchQuery.isEmpty) {
      return List<Song>.unmodifiable(queuedSongs);
    }
    return queuedSongs
        .where((Song song) => song.searchIndex.contains(normalizedSearchQuery))
        .toList(growable: false);
  }

  String get currentTitle {
    if (queuedSongs.isNotEmpty) {
      return queuedSongs.first.title;
    }
    return '等待点唱';
  }

  String get currentSubtitle {
    if (queuedSongs.isNotEmpty) {
      final String sourceLabel = libraryScope == LibraryScope.aggregated
          ? '聚合曲库'
          : '本地目录';
      return '${queuedSongs.first.artist} · 已从$sourceLabel加载 $libraryTotalCount 首';
    }
    if (libraryTotalCount > 0) {
      return libraryScope == LibraryScope.aggregated
          ? '已从聚合曲库加载 $libraryTotalCount 首歌曲。'
          : '已从本地目录加载 $libraryTotalCount 首歌曲。';
    }
    return '请先在设置中配置数据源。';
  }

  KtvState copyWith({
    KtvRoute? route,
    SongBookMode? songBookMode,
    String? selectedLanguage,
    LibraryState? library,
    PlaybackState? playback,
    Object? selectedArtist = _unset,
    Object? libraryScanErrorMessage = _unset,
    Object? scanDirectoryPath = _unset,
    LibraryScope? libraryScope,
    bool? hasConfiguredAggregatedSources,
    String? searchQuery,
    bool? isScanningLibrary,
    bool? isLoadingLibraryPage,
    List<Song>? queuedSongs,
    List<Song>? libraryPageSongs,
    List<Artist>? libraryPageArtists,
    List<String>? libraryFavoriteSongIds,
    int? libraryTotalCount,
    int? libraryPageIndex,
    int? libraryPageSize,
  }) {
    final LibraryState nextLibrary = (library ?? this.library).copyWith(
      scanDirectoryPath: scanDirectoryPath,
      scope: libraryScope,
      hasConfiguredAggregatedSources: hasConfiguredAggregatedSources,
      searchQuery: searchQuery,
      isScanningLibrary: isScanningLibrary,
      isLoadingLibraryPage: isLoadingLibraryPage,
      pageSongs: libraryPageSongs,
      pageArtists: libraryPageArtists,
      favoriteSongIds: libraryFavoriteSongIds,
      totalCount: libraryTotalCount,
      pageIndex: libraryPageIndex,
      pageSize: libraryPageSize,
      scanErrorMessage: libraryScanErrorMessage,
    );
    final PlaybackState nextPlayback = (playback ?? this.playback).copyWith(
      queuedSongs: queuedSongs,
    );

    return KtvState(
      route: route ?? this.route,
      songBookMode: songBookMode ?? this.songBookMode,
      selectedLanguage: selectedLanguage ?? this.selectedLanguage,
      library: nextLibrary,
      playback: nextPlayback,
      selectedArtist: identical(selectedArtist, _unset)
          ? this.selectedArtist
          : selectedArtist as String?,
    );
  }
}
