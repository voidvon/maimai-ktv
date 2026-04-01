import '../../../core/models/demo_song.dart';

enum DemoRoute { home, songBook, queueList }

class KtvDemoState {
  const KtvDemoState({
    this.route = DemoRoute.home,
    this.selectedLanguage = '全部',
    this.libraryScanErrorMessage,
    this.scanDirectoryPath,
    this.searchQuery = '',
    this.isScanningLibrary = false,
    this.isLoadingLibraryPage = false,
    this.queuedSongs = const <DemoSong>[],
    this.libraryPageSongs = const <DemoSong>[],
    this.libraryTotalCount = 0,
    this.libraryPageIndex = 0,
    this.libraryPageSize = 8,
  });

  static const Object _unset = Object();

  final DemoRoute route;
  final String selectedLanguage;
  final String? libraryScanErrorMessage;
  final String? scanDirectoryPath;
  final String searchQuery;
  final bool isScanningLibrary;
  final bool isLoadingLibraryPage;
  final List<DemoSong> queuedSongs;
  final List<DemoSong> libraryPageSongs;
  final int libraryTotalCount;
  final int libraryPageIndex;
  final int libraryPageSize;

  bool get hasConfiguredDirectory => scanDirectoryPath != null;

  String get normalizedSearchQuery => searchQuery.trim().toLowerCase();

  int get libraryTotalPages {
    if (libraryPageSize <= 0 || libraryTotalCount <= 0) {
      return 1;
    }
    return ((libraryTotalCount + libraryPageSize - 1) / libraryPageSize).ceil();
  }

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
    String? selectedLanguage,
    Object? libraryScanErrorMessage = _unset,
    Object? scanDirectoryPath = _unset,
    String? searchQuery,
    bool? isScanningLibrary,
    bool? isLoadingLibraryPage,
    List<DemoSong>? queuedSongs,
    List<DemoSong>? libraryPageSongs,
    int? libraryTotalCount,
    int? libraryPageIndex,
    int? libraryPageSize,
  }) {
    return KtvDemoState(
      route: route ?? this.route,
      selectedLanguage: selectedLanguage ?? this.selectedLanguage,
      libraryScanErrorMessage: identical(libraryScanErrorMessage, _unset)
          ? this.libraryScanErrorMessage
          : libraryScanErrorMessage as String?,
      scanDirectoryPath: identical(scanDirectoryPath, _unset)
          ? this.scanDirectoryPath
          : scanDirectoryPath as String?,
      searchQuery: searchQuery ?? this.searchQuery,
      isScanningLibrary: isScanningLibrary ?? this.isScanningLibrary,
      isLoadingLibraryPage:
          isLoadingLibraryPage ?? this.isLoadingLibraryPage,
      queuedSongs: queuedSongs ?? this.queuedSongs,
      libraryPageSongs: libraryPageSongs ?? this.libraryPageSongs,
      libraryTotalCount: libraryTotalCount ?? this.libraryTotalCount,
      libraryPageIndex: libraryPageIndex ?? this.libraryPageIndex,
      libraryPageSize: libraryPageSize ?? this.libraryPageSize,
    );
  }
}
