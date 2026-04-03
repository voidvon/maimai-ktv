import 'ktv_state.dart';

class NavigationDestination {
  const NavigationDestination.home()
    : route = KtvRoute.home,
      songBookMode = SongBookMode.songs,
      libraryScope = LibraryScope.localOnly,
      selectedArtist = null;

  const NavigationDestination.songBook({
    required SongBookMode mode,
    required this.libraryScope,
    this.selectedArtist,
  }) : route = KtvRoute.songBook,
       songBookMode = mode;

  const NavigationDestination.queueList({
    required this.songBookMode,
    required this.libraryScope,
    required this.selectedArtist,
  }) : route = KtvRoute.queueList;

  final KtvRoute route;
  final SongBookMode songBookMode;
  final LibraryScope libraryScope;
  final String? selectedArtist;

  String get breadcrumbSegment {
    switch (route) {
      case KtvRoute.home:
        return '主页';
      case KtvRoute.songBook:
        if (selectedArtist != null) {
          return selectedArtist!;
        }
        return switch (songBookMode) {
          SongBookMode.artists => '歌星',
          SongBookMode.favorites => '收藏',
          SongBookMode.frequent => '常唱',
          SongBookMode.songs =>
            libraryScope == LibraryScope.aggregated ? '歌名' : '本地',
        };
      case KtvRoute.queueList:
        return '已点';
    }
  }

  @override
  bool operator ==(Object other) {
    return other is NavigationDestination &&
        other.route == route &&
        other.songBookMode == songBookMode &&
        other.libraryScope == libraryScope &&
        other.selectedArtist == selectedArtist;
  }

  @override
  int get hashCode =>
      Object.hash(route, songBookMode, libraryScope, selectedArtist);
}

class NavigationHistory {
  final List<NavigationDestination> _stack = <NavigationDestination>[
    const NavigationDestination.home(),
  ];

  NavigationDestination get current => _stack.last;

  bool get canNavigateBack => _stack.length > 1;

  String get breadcrumbLabel =>
      '‹ ${_stack.map((entry) => entry.breadcrumbSegment).join(' / ')}';

  bool enterSongBook({
    SongBookMode mode = SongBookMode.songs,
    LibraryScope? scope,
  }) {
    final NavigationDestination target = NavigationDestination.songBook(
      mode: mode,
      libraryScope: scope ?? _defaultScopeForMode(mode),
    );
    if (current == target) {
      return false;
    }
    _stack.add(target);
    return true;
  }

  bool enterQueueList({
    required SongBookMode songBookMode,
    required LibraryScope libraryScope,
    required String? selectedArtist,
  }) {
    final NavigationDestination target = NavigationDestination.queueList(
      songBookMode: songBookMode,
      libraryScope: libraryScope,
      selectedArtist: selectedArtist,
    );
    if (current == target) {
      return false;
    }
    _stack.add(target);
    return true;
  }

  bool selectArtist(String artist) {
    final String normalizedArtist = artist.trim();
    if (normalizedArtist.isEmpty) {
      return false;
    }
    final LibraryScope scope = current.route == KtvRoute.songBook
        ? current.libraryScope
        : LibraryScope.aggregated;
    final NavigationDestination target = NavigationDestination.songBook(
      mode: SongBookMode.songs,
      libraryScope: scope,
      selectedArtist: normalizedArtist,
    );
    if (current == target) {
      return false;
    }
    _stack.add(target);
    return true;
  }

  bool returnHome() {
    if (_stack.length == 1 &&
        _stack.first == const NavigationDestination.home()) {
      return false;
    }
    _stack
      ..clear()
      ..add(const NavigationDestination.home());
    return true;
  }

  NavigationDestination? navigateBack() {
    if (!canNavigateBack) {
      return null;
    }
    _stack.removeLast();
    return current;
  }

  LibraryScope _defaultScopeForMode(SongBookMode mode) {
    return switch (mode) {
      SongBookMode.songs => LibraryScope.aggregated,
      SongBookMode.artists ||
      SongBookMode.favorites ||
      SongBookMode.frequent => LibraryScope.aggregated,
    };
  }
}
