import 'ktv_demo_state.dart';

class DemoNavigationDestination {
  const DemoNavigationDestination.home()
    : route = DemoRoute.home,
      songBookMode = DemoSongBookMode.songs,
      selectedArtist = null;

  const DemoNavigationDestination.songBook({
    required DemoSongBookMode mode,
    this.selectedArtist,
  }) : route = DemoRoute.songBook,
       songBookMode = mode;

  const DemoNavigationDestination.queueList({
    required this.songBookMode,
    required this.selectedArtist,
  }) : route = DemoRoute.queueList;

  final DemoRoute route;
  final DemoSongBookMode songBookMode;
  final String? selectedArtist;

  String get breadcrumbSegment {
    switch (route) {
      case DemoRoute.home:
        return '主页';
      case DemoRoute.songBook:
        if (selectedArtist != null) {
          return selectedArtist!;
        }
        return songBookMode == DemoSongBookMode.artists ? '歌星' : '歌名';
      case DemoRoute.queueList:
        return '已点';
    }
  }

  @override
  bool operator ==(Object other) {
    return other is DemoNavigationDestination &&
        other.route == route &&
        other.songBookMode == songBookMode &&
        other.selectedArtist == selectedArtist;
  }

  @override
  int get hashCode => Object.hash(route, songBookMode, selectedArtist);
}

class DemoNavigationHistory {
  final List<DemoNavigationDestination> _stack = <DemoNavigationDestination>[
    const DemoNavigationDestination.home(),
  ];

  DemoNavigationDestination get current => _stack.last;

  bool get canNavigateBack => _stack.length > 1;

  String get breadcrumbLabel =>
      '‹ ${_stack.map((entry) => entry.breadcrumbSegment).join(' / ')}';

  bool enterSongBook({DemoSongBookMode mode = DemoSongBookMode.songs}) {
    final DemoNavigationDestination target = DemoNavigationDestination.songBook(
      mode: mode,
    );
    if (current == target) {
      return false;
    }
    _stack.add(target);
    return true;
  }

  bool enterQueueList({
    required DemoSongBookMode songBookMode,
    required String? selectedArtist,
  }) {
    final DemoNavigationDestination target =
        DemoNavigationDestination.queueList(
          songBookMode: songBookMode,
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
    final DemoNavigationDestination target = DemoNavigationDestination.songBook(
      mode: DemoSongBookMode.songs,
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
        _stack.first == const DemoNavigationDestination.home()) {
      return false;
    }
    _stack
      ..clear()
      ..add(const DemoNavigationDestination.home());
    return true;
  }

  DemoNavigationDestination? navigateBack() {
    if (!canNavigateBack) {
      return null;
    }
    _stack.removeLast();
    return current;
  }
}
