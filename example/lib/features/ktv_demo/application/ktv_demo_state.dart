import '../../../core/models/demo_song.dart';
import '../../../core/models/demo_artist.dart';

enum DemoRoute { home, songBook, queueList }

enum DemoSongBookMode { songs, artists }

class DemoLibraryState {
  const DemoLibraryState({
    this.scanDirectoryPath,
    this.searchQuery = '',
    this.isScanningLibrary = false,
    this.isLoadingLibraryPage = false,
    this.pageSongs = const <DemoSong>[],
    this.pageArtists = const <DemoArtist>[],
    this.totalCount = 0,
    this.pageIndex = 0,
    this.pageSize = 8,
    this.scanErrorMessage,
  });

  static const Object _unset = Object();

  final String? scanDirectoryPath;
  final String searchQuery;
  final bool isScanningLibrary;
  final bool isLoadingLibraryPage;
  final List<DemoSong> pageSongs;
  final List<DemoArtist> pageArtists;
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

  DemoLibraryState copyWith({
    Object? scanDirectoryPath = _unset,
    String? searchQuery,
    bool? isScanningLibrary,
    bool? isLoadingLibraryPage,
    List<DemoSong>? pageSongs,
    List<DemoArtist>? pageArtists,
    int? totalCount,
    int? pageIndex,
    int? pageSize,
    Object? scanErrorMessage = _unset,
  }) {
    return DemoLibraryState(
      scanDirectoryPath: identical(scanDirectoryPath, _unset)
          ? this.scanDirectoryPath
          : scanDirectoryPath as String?,
      searchQuery: searchQuery ?? this.searchQuery,
      isScanningLibrary: isScanningLibrary ?? this.isScanningLibrary,
      isLoadingLibraryPage: isLoadingLibraryPage ?? this.isLoadingLibraryPage,
      pageSongs: pageSongs ?? this.pageSongs,
      pageArtists: pageArtists ?? this.pageArtists,
      totalCount: totalCount ?? this.totalCount,
      pageIndex: pageIndex ?? this.pageIndex,
      pageSize: pageSize ?? this.pageSize,
      scanErrorMessage: identical(scanErrorMessage, _unset)
          ? this.scanErrorMessage
          : scanErrorMessage as String?,
    );
  }
}

class DemoPlaybackState {
  const DemoPlaybackState({this.queuedSongs = const <DemoSong>[]});

  final List<DemoSong> queuedSongs;

  DemoPlaybackState copyWith({List<DemoSong>? queuedSongs}) {
    return DemoPlaybackState(queuedSongs: queuedSongs ?? this.queuedSongs);
  }
}

class KtvDemoState {
  const KtvDemoState({
    this.route = DemoRoute.home,
    this.songBookMode = DemoSongBookMode.songs,
    this.selectedLanguage = '全部',
    this.selectedArtist,
    this.library = const DemoLibraryState(),
    this.playback = const DemoPlaybackState(),
  });

  static const Object _unset = Object();

  final DemoRoute route;
  final DemoSongBookMode songBookMode;
  final String selectedLanguage;
  final String? selectedArtist;
  final DemoLibraryState library;
  final DemoPlaybackState playback;

  String? get libraryScanErrorMessage => library.scanErrorMessage;
  String? get scanDirectoryPath => library.scanDirectoryPath;
  String get searchQuery => library.searchQuery;
  bool get isScanningLibrary => library.isScanningLibrary;
  bool get isLoadingLibraryPage => library.isLoadingLibraryPage;
  List<DemoSong> get queuedSongs => playback.queuedSongs;
  List<DemoSong> get libraryPageSongs => library.pageSongs;
  List<DemoArtist> get libraryPageArtists => library.pageArtists;
  int get libraryTotalCount => library.totalCount;
  int get libraryPageIndex => library.pageIndex;
  int get libraryPageSize => library.pageSize;

  bool get hasConfiguredDirectory => library.hasConfiguredDirectory;
  bool get isArtistMode => songBookMode == DemoSongBookMode.artists;

  String get normalizedSearchQuery => library.searchQuery.trim().toLowerCase();

  int get libraryTotalPages => library.totalPages;

  List<DemoSong> filteredQueuedSongs() {
    if (normalizedSearchQuery.isEmpty) {
      return List<DemoSong>.unmodifiable(queuedSongs);
    }
    return queuedSongs
        .where(
          (DemoSong song) => song.searchIndex.contains(normalizedSearchQuery),
        )
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
      return '${queuedSongs.first.artist} · 已从目录中加载 $libraryTotalCount 首';
    }
    if (scanDirectoryPath != null && libraryTotalCount > 0) {
      return '已从扫描目录加载 $libraryTotalCount 首歌曲。';
    }
    return '请先在设置中选择扫描目录。';
  }

  KtvDemoState copyWith({
    DemoRoute? route,
    DemoSongBookMode? songBookMode,
    String? selectedLanguage,
    DemoLibraryState? library,
    DemoPlaybackState? playback,
    Object? selectedArtist = _unset,
    Object? libraryScanErrorMessage = _unset,
    Object? scanDirectoryPath = _unset,
    String? searchQuery,
    bool? isScanningLibrary,
    bool? isLoadingLibraryPage,
    List<DemoSong>? queuedSongs,
    List<DemoSong>? libraryPageSongs,
    List<DemoArtist>? libraryPageArtists,
    int? libraryTotalCount,
    int? libraryPageIndex,
    int? libraryPageSize,
  }) {
    final DemoLibraryState nextLibrary = (library ?? this.library).copyWith(
      scanDirectoryPath: scanDirectoryPath,
      searchQuery: searchQuery,
      isScanningLibrary: isScanningLibrary,
      isLoadingLibraryPage: isLoadingLibraryPage,
      pageSongs: libraryPageSongs,
      pageArtists: libraryPageArtists,
      totalCount: libraryTotalCount,
      pageIndex: libraryPageIndex,
      pageSize: libraryPageSize,
      scanErrorMessage: libraryScanErrorMessage,
    );
    final DemoPlaybackState nextPlayback = (playback ?? this.playback).copyWith(
      queuedSongs: queuedSongs,
    );

    return KtvDemoState(
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
