import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:ktv2/ktv2.dart';

import '../../../core/models/demo_artist.dart';
import '../../../core/models/demo_song.dart';
import '../application/ktv_demo_controller.dart';
import 'queue_page.dart';

const List<String> _languageTabs = <String>[
  '全部',
  '国语',
  '粤语',
  '闽南语',
  '英语',
  '日语',
  '韩语',
  '其它',
];

const String _numberKeyboardToggleLabel = '123';
const String _letterKeyboardToggleLabel = 'ABC';
const String _keyboardSpacerLabel = '_spacer_';

const List<List<String>> _letterKeyboardRows = <List<String>>[
  <String>['A', 'B', 'C', 'D', 'E', 'F', 'G'],
  <String>['H', 'I', 'J', 'K', 'L', 'M', 'N'],
  <String>['O', 'P', 'Q', 'R', 'S', 'T', 'U'],
  <String>['V', 'W', 'X', 'Y', 'Z', _numberKeyboardToggleLabel],
];

const List<List<String>> _numberKeyboardRows = <List<String>>[
  <String>['1', '2', '3'],
  <String>['4', '5', '6'],
  <String>['7', '8', '9'],
  <String>[_keyboardSpacerLabel, '0', _letterKeyboardToggleLabel],
];

class SongBookViewModel {
  const SongBookViewModel({
    required this.navigation,
    required this.library,
    required this.playback,
  });

  final SongBookNavigationViewModel navigation;
  final SongBookLibraryViewModel library;
  final SongBookPlaybackViewModel playback;
}

class SongBookNavigationViewModel {
  const SongBookNavigationViewModel({
    required this.route,
    required this.songBookMode,
    required this.selectedArtist,
    required this.breadcrumbLabel,
  });

  final DemoRoute route;
  final DemoSongBookMode songBookMode;
  final String? selectedArtist;
  final String breadcrumbLabel;
}

class SongBookLibraryViewModel {
  const SongBookLibraryViewModel({
    required this.searchQuery,
    required this.selectedLanguage,
    required this.songs,
    required this.artists,
    required this.totalCount,
    required this.pageIndex,
    required this.totalPages,
    required this.pageSize,
    required this.hasConfiguredDirectory,
    required this.isScanning,
    required this.isLoadingPage,
    required this.scanErrorMessage,
  });

  final String searchQuery;
  final String selectedLanguage;
  final List<DemoSong> songs;
  final List<DemoArtist> artists;
  final int totalCount;
  final int pageIndex;
  final int totalPages;
  final int pageSize;
  final bool hasConfiguredDirectory;
  final bool isScanning;
  final bool isLoadingPage;
  final String? scanErrorMessage;
}

class SongBookPlaybackViewModel {
  const SongBookPlaybackViewModel({required this.queuedSongs});

  final List<DemoSong> queuedSongs;
}

class SongBookCallbacks {
  const SongBookCallbacks({
    required this.navigation,
    required this.library,
    required this.playback,
  });

  final SongBookNavigationCallbacks navigation;
  final SongBookLibraryCallbacks library;
  final SongBookPlaybackCallbacks playback;
}

class SongBookNavigationCallbacks {
  const SongBookNavigationCallbacks({
    required this.onBackPressed,
    required this.onQueuePressed,
    required this.onSelectArtist,
    required this.onSettingsPressed,
  });

  final VoidCallback onBackPressed;
  final VoidCallback onQueuePressed;
  final ValueChanged<String> onSelectArtist;
  final VoidCallback onSettingsPressed;
}

class SongBookLibraryCallbacks {
  const SongBookLibraryCallbacks({
    required this.onLanguageSelected,
    required this.onAppendSearchToken,
    required this.onRemoveSearchCharacter,
    required this.onClearSearch,
    required this.onRequestLibraryPage,
    required this.onRequestSong,
  });

  final ValueChanged<String> onLanguageSelected;
  final ValueChanged<String> onAppendSearchToken;
  final VoidCallback onRemoveSearchCharacter;
  final VoidCallback onClearSearch;
  final void Function(int pageIndex, int pageSize) onRequestLibraryPage;
  final ValueChanged<DemoSong> onRequestSong;
}

class SongBookPlaybackCallbacks {
  const SongBookPlaybackCallbacks({
    required this.onPrioritizeQueuedSong,
    required this.onRemoveQueuedSong,
    required this.onToggleAudioMode,
    required this.onTogglePlayback,
    required this.onRestartPlayback,
    required this.onSkipSong,
  });

  final ValueChanged<DemoSong> onPrioritizeQueuedSong;
  final ValueChanged<DemoSong> onRemoveQueuedSong;
  final VoidCallback onToggleAudioMode;
  final VoidCallback onTogglePlayback;
  final VoidCallback onRestartPlayback;
  final VoidCallback onSkipSong;
}

class SongBookPage extends StatelessWidget {
  const SongBookPage({
    super.key,
    required this.controller,
    required this.searchController,
    required this.viewModel,
    required this.callbacks,
    this.compact = false,
  });

  final PlayerController controller;
  final TextEditingController searchController;
  final SongBookViewModel viewModel;
  final SongBookCallbacks callbacks;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final bool showLetterKeyboard =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final double sectionGap = showLetterKeyboard
        ? (compact ? 20 : 12)
        : (compact ? 20 : 10);
    final Widget rightColumn = SongBookRightColumn(
      controller: controller,
      compact: compact,
      viewModel: viewModel,
      callbacks: callbacks,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SongBookLeftColumn(
          controller: controller,
          searchController: searchController,
          route: viewModel.navigation.route,
          songBookMode: viewModel.navigation.songBookMode,
          selectedArtist: viewModel.navigation.selectedArtist,
          compact: compact,
          showLetterKeyboard: showLetterKeyboard,
          onAppendSearchToken: callbacks.library.onAppendSearchToken,
          onRemoveSearchCharacter: callbacks.library.onRemoveSearchCharacter,
          onClearSearch: callbacks.library.onClearSearch,
        ),
        SizedBox(height: sectionGap),
        if (compact) rightColumn else Expanded(child: rightColumn),
      ],
    );
  }
}

class SongBookLeftColumn extends StatefulWidget {
  const SongBookLeftColumn({
    super.key,
    required this.controller,
    required this.searchController,
    required this.route,
    required this.songBookMode,
    required this.selectedArtist,
    required this.showLetterKeyboard,
    required this.onAppendSearchToken,
    required this.onRemoveSearchCharacter,
    required this.onClearSearch,
    this.compact = false,
  });

  final PlayerController controller;
  final TextEditingController searchController;
  final DemoRoute route;
  final DemoSongBookMode songBookMode;
  final String? selectedArtist;
  final bool showLetterKeyboard;
  final ValueChanged<String> onAppendSearchToken;
  final VoidCallback onRemoveSearchCharacter;
  final VoidCallback onClearSearch;
  final bool compact;

  @override
  State<SongBookLeftColumn> createState() => _SongBookLeftColumnState();
}

class _SongBookLeftColumnState extends State<SongBookLeftColumn> {
  bool _showNumberKeyboard = false;

  void _handleKeyboardKeyPressed(String key) {
    if (key == _numberKeyboardToggleLabel) {
      setState(() => _showNumberKeyboard = true);
      return;
    }
    if (key == _letterKeyboardToggleLabel) {
      setState(() => _showNumberKeyboard = false);
      return;
    }
    widget.onAppendSearchToken(key.toLowerCase());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _SongBookSearchField(
          controller: widget.searchController,
          placeholder: widget.route == DemoRoute.queueList
              ? '搜索已点歌曲 / 歌手'
              : widget.songBookMode == DemoSongBookMode.artists &&
                    widget.selectedArtist == null
              ? '输入歌手名称'
              : '输入歌名 / 中文 / 拼音首字母',
          enableSystemKeyboard: !widget.showLetterKeyboard,
          onBackspacePressed: widget.onRemoveSearchCharacter,
          onClearPressed: widget.onClearSearch,
        ),
        if (widget.showLetterKeyboard) ...<Widget>[
          SizedBox(height: widget.compact ? 6 : 8),
          _SearchKeyboard(
            showNumberKeyboard: _showNumberKeyboard,
            onKeyPressed: _handleKeyboardKeyPressed,
          ),
        ],
      ],
    );
  }
}

class SongPreviewPlaceholder extends StatelessWidget {
  const SongPreviewPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFF1C0634), Color(0xFF120520)],
        ),
      ),
    );
  }
}

class _SongBookSearchField extends StatelessWidget {
  const _SongBookSearchField({
    required this.controller,
    required this.placeholder,
    required this.enableSystemKeyboard,
    required this.onBackspacePressed,
    required this.onClearPressed,
  });

  final TextEditingController controller;
  final String placeholder;
  final bool enableSystemKeyboard;
  final VoidCallback onBackspacePressed;
  final VoidCallback onClearPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: const Color(0x24FFFFFF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          const SizedBox(width: 10),
          const Icon(Icons.search_rounded, size: 14, color: Color(0xCCFFF2FF)),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: controller,
              readOnly: !enableSystemKeyboard,
              showCursor: enableSystemKeyboard,
              enableInteractiveSelection: enableSystemKeyboard,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFFFFF7FF),
              ),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: placeholder,
                hintStyle: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Color(0x99F2DFFF),
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: onBackspacePressed,
            splashRadius: 14,
            iconSize: 14,
            color: const Color(0xCCFFF2FF),
            icon: const Icon(Icons.backspace_outlined),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Material(
              color: const Color(0x24FFFFFF),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onClearPressed,
                child: const SizedBox(
                  width: 16,
                  height: 16,
                  child: Icon(
                    Icons.close_rounded,
                    size: 10,
                    color: Color(0xCCFFF2FF),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchKeyboard extends StatelessWidget {
  const _SearchKeyboard({
    required this.showNumberKeyboard,
    required this.onKeyPressed,
  });

  final bool showNumberKeyboard;
  final ValueChanged<String> onKeyPressed;

  @override
  Widget build(BuildContext context) {
    final List<List<String>> keyboardRows = showNumberKeyboard
        ? _numberKeyboardRows
        : _letterKeyboardRows;
    return Column(
      children: keyboardRows
          .map((List<String> row) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: row == keyboardRows.last ? 0 : 6,
              ),
              child: Row(
                children: row
                    .map((String key) {
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            right: key == row.last ? 0 : 6,
                          ),
                          child: _KeyboardKey(
                            label: key,
                            onPressed: () => onKeyPressed(key),
                          ),
                        ),
                      );
                    })
                    .toList(growable: false),
              ),
            );
          })
          .toList(growable: false),
    );
  }
}

class _KeyboardKey extends StatelessWidget {
  const _KeyboardKey({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (label == _keyboardSpacerLabel) {
      return const SizedBox(height: 22);
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onPressed,
        child: Ink(
          height: 22,
          decoration: BoxDecoration(
            color: const Color(0x24FFFFFF),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: label.length > 1 ? 10 : 12,
                fontWeight: label.length > 1
                    ? FontWeight.w700
                    : FontWeight.w600,
                color: const Color(0xD9FFF6FF),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SongBookRightColumn extends StatefulWidget {
  const SongBookRightColumn({
    super.key,
    required this.controller,
    required this.viewModel,
    required this.callbacks,
    this.compact = false,
  });

  final PlayerController controller;
  final SongBookViewModel viewModel;
  final SongBookCallbacks callbacks;
  final bool compact;

  @override
  State<SongBookRightColumn> createState() => _SongBookRightColumnState();
}

class _SongBookRightColumnState extends State<SongBookRightColumn> {
  static const double _gridSpacing = 8;
  static const double _songTileHeight = 44;
  static const double _artistTileHeight = 104;
  static const double _queueTileHeight = 48;
  static const double _paginationSectionHeight = 42;
  static const double _paginationSectionGap = 12;
  static const double _pageViewportFraction = 0.92;
  static const double _pageGap = 12;
  static const int _maxVisiblePages = 20;

  int _currentPage = 0;
  late final PageController _pageController;
  int? _pendingPageJump;
  int? _pendingLibraryPageSizeSync;

  SongBookViewModel get _viewModel => widget.viewModel;
  SongBookCallbacks get _callbacks => widget.callbacks;
  SongBookNavigationViewModel get _navigation => _viewModel.navigation;
  SongBookLibraryViewModel get _library => _viewModel.library;
  SongBookPlaybackViewModel get _playback => _viewModel.playback;
  SongBookNavigationCallbacks get _navigationCallbacks => _callbacks.navigation;
  SongBookLibraryCallbacks get _libraryCallbacks => _callbacks.library;
  SongBookPlaybackCallbacks get _playbackCallbacks => _callbacks.playback;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: _pageViewportFraction);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  int _resolveCrossAxisCount(MediaQueryData media) {
    return media.size.width < 340 ? 1 : 2;
  }

  int _resolveArtistCrossAxisCount(
    MediaQueryData media, {
    required bool isLandscape,
  }) {
    if (isLandscape) {
      return 4;
    }
    return media.size.width < 360 ? 2 : 3;
  }

  int _resolveRowsPerPage(
    MediaQueryData media, {
    required bool isLandscape,
    required bool isArtistOverview,
  }) {
    if (isLandscape) {
      if (isArtistOverview) {
        return 2;
      }
      return 4;
    }
    final double height = media.size.height;
    if (height >= 760) {
      return 6;
    }
    if (height >= 640) {
      return 5;
    }
    return 4;
  }

  int _resolveRowsPerPageForAvailableHeight({
    required double availableHeight,
    required bool isLandscape,
    required int fallbackRowsPerPage,
    required double tileHeight,
  }) {
    if (isLandscape) {
      return fallbackRowsPerPage;
    }
    final double listHeight = math.max(
      0,
      availableHeight - _paginationSectionHeight - _paginationSectionGap,
    );
    final int fittedRows =
        ((listHeight + _gridSpacing) / (tileHeight + _gridSpacing)).floor();
    return math.max(1, fittedRows);
  }

  double _resolveTileHeightForAvailableHeight({
    required double availableHeight,
    required bool isLandscape,
    required int rowsPerPage,
    required double fallbackTileHeight,
  }) {
    if (!isLandscape || rowsPerPage <= 0) {
      return fallbackTileHeight;
    }
    final double gridHeight = math.max(
      0,
      availableHeight - _paginationSectionHeight - _paginationSectionGap,
    );
    final double computedTileHeight =
        (gridHeight - (_gridSpacing * (rowsPerPage - 1))) / rowsPerPage;
    if (!computedTileHeight.isFinite || computedTileHeight <= 0) {
      return fallbackTileHeight;
    }
    return math.min(fallbackTileHeight, computedTileHeight);
  }

  int _computeMaxPage(int totalSongs, int songsPerPage) {
    if (totalSongs <= 0) {
      return 0;
    }
    return (totalSongs / songsPerPage).ceil() - 1;
  }

  double _computeGridHeight({
    required int rowsPerPage,
    required double tileHeight,
  }) {
    return (tileHeight * rowsPerPage) + (_gridSpacing * (rowsPerPage - 1));
  }

  List<List<T>> _paginateItems<T>(List<T> items, {required int itemsPerPage}) {
    if (items.isEmpty) {
      return <List<T>>[<T>[]];
    }
    final List<List<T>> pages = <List<T>>[];
    for (int start = 0; start < items.length; start += itemsPerPage) {
      if (pages.length >= _maxVisiblePages) {
        break;
      }
      final int end = math.min(start + itemsPerPage, items.length);
      pages.add(items.sublist(start, end));
    }
    return pages;
  }

  int _computeVisibleTotalPages(int totalItems, int itemsPerPage) {
    if (totalItems <= 0) {
      return 1;
    }
    final int totalPages = _computeMaxPage(totalItems, itemsPerPage) + 1;
    return math.min(totalPages, _maxVisiblePages);
  }

  int _normalizeCurrentPage(int totalPages) {
    final int normalizedPage = _currentPage.clamp(0, totalPages - 1);
    if (_currentPage != normalizedPage) {
      _currentPage = normalizedPage;
    }
    _schedulePageJump(normalizedPage);
    return normalizedPage;
  }

  void _schedulePageJump(int targetPage) {
    if (_pageController.hasClients) {
      final double fallbackPage = _currentPage.toDouble();
      final int controllerPage = (_pageController.page ?? fallbackPage).round();
      if (controllerPage == targetPage) {
        _pendingPageJump = null;
        return;
      }
    }
    if (_pendingPageJump == targetPage) {
      return;
    }
    _pendingPageJump = targetPage;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final int? pendingPage = _pendingPageJump;
      if (pendingPage == null) {
        return;
      }
      _pendingPageJump = null;
      if (!_pageController.hasClients) {
        return;
      }
      final double fallbackPage = _currentPage.toDouble();
      final int controllerPage = (_pageController.page ?? fallbackPage).round();
      if (controllerPage != pendingPage) {
        _pageController.jumpToPage(pendingPage);
      }
    });
  }

  void _scheduleLibraryPageSizeSync(int pageSize) {
    if (_navigation.route == DemoRoute.queueList ||
        _library.pageSize == pageSize ||
        _pendingLibraryPageSizeSync == pageSize) {
      return;
    }
    _pendingLibraryPageSizeSync = pageSize;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _pendingLibraryPageSizeSync != pageSize) {
        return;
      }
      _pendingLibraryPageSizeSync = null;
      _libraryCallbacks.onRequestLibraryPage(_library.pageIndex, pageSize);
    });
  }

  Future<void> _animateToPage(int page) async {
    if (page == _currentPage) {
      return;
    }
    if (!_pageController.hasClients) {
      setState(() => _currentPage = page);
      return;
    }
    await _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  Widget _buildAnimatedPagedContent<T>({
    required List<List<T>> pages,
    required int rowsPerPage,
    required double tileHeight,
    required Widget Function(List<T> pageItems) pageBuilder,
  }) {
    return SizedBox(
      height: _computeGridHeight(
        rowsPerPage: rowsPerPage,
        tileHeight: tileHeight,
      ),
      child: PageView.builder(
        controller: _pageController,
        physics: const BouncingScrollPhysics(parent: PageScrollPhysics()),
        itemCount: pages.length,
        onPageChanged: (int page) {
          if (page == _currentPage) {
            return;
          }
          setState(() => _currentPage = page);
        },
        itemBuilder: (BuildContext context, int index) {
          return AnimatedBuilder(
            animation: _pageController,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: _pageGap / 2),
              child: pageBuilder(pages[index]),
            ),
            builder: (BuildContext context, Widget? child) {
              double page = _currentPage.toDouble();
              if (_pageController.hasClients) {
                page = _pageController.page ?? page;
              }
              final double distance = (page - index).abs().clamp(0.0, 1.0);
              final double opacity = math.max(0.9, 1 - (distance * 0.12));
              final double scale = 1 - (distance * 0.02);
              return ClipRect(
                child: Opacity(
                  opacity: opacity,
                  child: Transform.scale(
                    scale: scale,
                    alignment: Alignment.center,
                    child: child,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final MediaQueryData media = MediaQuery.of(context);
    final bool isLandscape = media.orientation == Orientation.landscape;
    final bool isQueueRoute = _navigation.route == DemoRoute.queueList;
    final bool isArtistOverview =
        !isQueueRoute &&
        _navigation.songBookMode == DemoSongBookMode.artists &&
        _navigation.selectedArtist == null;
    final int crossAxisCount = isArtistOverview
        ? _resolveArtistCrossAxisCount(media, isLandscape: isLandscape)
        : _resolveCrossAxisCount(media);
    final int fallbackRowsPerPage = _resolveRowsPerPage(
      media,
      isLandscape: isLandscape,
      isArtistOverview: isArtistOverview,
    );
    final double tileHeight = isQueueRoute
        ? _queueTileHeight
        : isArtistOverview
        ? _artistTileHeight
        : _songTileHeight;
    final List<QueuedSongEntry> filteredQueueEntries = isQueueRoute
        ? _resolveFilteredQueueEntries()
        : const <QueuedSongEntry>[];

    Widget buildLibraryGrid(
      List<DemoSong> visibleSongs,
      int rowsPerPage, {
      required double tileHeight,
    }) {
      final double gridHeight = _computeGridHeight(
        rowsPerPage: rowsPerPage,
        tileHeight: tileHeight,
      );
      return SizedBox(
        width: double.infinity,
        height: gridHeight,
        child: GridView.builder(
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: _gridSpacing,
            crossAxisSpacing: _gridSpacing,
            mainAxisExtent: tileHeight,
          ),
          itemCount: visibleSongs.length,
          itemBuilder: (BuildContext context, int index) {
            final DemoSong song = visibleSongs[index];
            final bool isCurrent =
                _playback.queuedSongs.isNotEmpty &&
                _playback.queuedSongs.first == song;
            final bool isQueued = _playback.queuedSongs.contains(song);
            return _SongTile(
              song: song,
              isCurrent: isCurrent,
              isQueued: isQueued,
              onTap: isQueued
                  ? null
                  : () => _libraryCallbacks.onRequestSong(song),
            );
          },
        ),
      );
    }

    Widget buildArtistGrid(
      List<DemoArtist> visibleArtists,
      int rowsPerPage, {
      required double tileHeight,
    }) {
      final double gridHeight = _computeGridHeight(
        rowsPerPage: rowsPerPage,
        tileHeight: tileHeight,
      );
      return SizedBox(
        width: double.infinity,
        height: gridHeight,
        child: GridView.builder(
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: _gridSpacing,
            crossAxisSpacing: _gridSpacing,
            mainAxisExtent: tileHeight,
          ),
          itemCount: visibleArtists.length,
          itemBuilder: (BuildContext context, int index) {
            final DemoArtist artist = visibleArtists[index];
            return _ArtistTile(
              artist: artist,
              onTap: () => _navigationCallbacks.onSelectArtist(artist.name),
            );
          },
        ),
      );
    }

    Widget buildLibraryContent(int rowsPerPage, {required double tileHeight}) {
      final int itemsPerPage = crossAxisCount * rowsPerPage;
      if (!_library.hasConfiguredDirectory) {
        return const _EmptyContentCard(message: '请先在设置里选择扫描目录，扫描完成后这里会展示歌曲列表。');
      }
      _scheduleLibraryPageSizeSync(itemsPerPage);
      if (_library.isScanning &&
          _library.totalCount == 0 &&
          _library.songs.isEmpty) {
        return const _EmptyContentCard(message: '正在扫描目录中的歌曲，请稍候。');
      }
      if (_library.isLoadingPage &&
          _library.totalCount == 0 &&
          _library.songs.isEmpty &&
          _library.artists.isEmpty) {
        return _EmptyContentCard(
          message: isArtistOverview ? '正在加载歌手列表，请稍候。' : '正在加载歌曲列表，请稍候。',
        );
      }
      if (_library.scanErrorMessage != null) {
        return _EmptyContentCard(message: _library.scanErrorMessage!);
      }
      if (isArtistOverview) {
        if (_library.artists.isEmpty) {
          return const _EmptyContentCard(
            message: '当前条件下没有可显示的歌手，试试切换语言或清空搜索关键字。',
          );
        }
        return buildArtistGrid(
          _library.artists,
          rowsPerPage,
          tileHeight: tileHeight,
        );
      }
      if (_library.songs.isEmpty) {
        return _EmptyContentCard(
          message: _navigation.selectedArtist == null
              ? '当前目录下没有扫描到可播放视频文件，请确认目录中包含常见视频格式媒体文件。'
              : '当前歌手下没有匹配的歌曲，试试切换语言或清空搜索关键字。',
        );
      }
      return buildLibraryGrid(
        _library.songs,
        rowsPerPage,
        tileHeight: tileHeight,
      );
    }

    Widget buildQueueGrid(
      List<QueuedSongEntry> visibleEntries,
      int rowsPerPage, {
      required double tileHeight,
    }) {
      final double gridHeight = _computeGridHeight(
        rowsPerPage: rowsPerPage,
        tileHeight: tileHeight,
      );
      return SizedBox(
        width: double.infinity,
        height: gridHeight,
        child: GridView.builder(
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: _gridSpacing,
            crossAxisSpacing: _gridSpacing,
            mainAxisExtent: tileHeight,
          ),
          itemCount: visibleEntries.length,
          itemBuilder: (BuildContext context, int index) {
            final QueuedSongEntry entry = visibleEntries[index];
            return QueuedSongTile(
              entry: entry,
              onPinToTop: entry.canPinToTop
                  ? () => _playbackCallbacks.onPrioritizeQueuedSong(entry.song)
                  : null,
              onRemove: entry.isCurrent
                  ? null
                  : () => _playbackCallbacks.onRemoveQueuedSong(entry.song),
            );
          },
        ),
      );
    }

    Widget buildQueueContent(int rowsPerPage, {required double tileHeight}) {
      if (_playback.queuedSongs.isEmpty) {
        return const _EmptyContentCard(message: '当前还没有已点歌曲，点歌后会在这里显示。');
      }
      if (filteredQueueEntries.isEmpty) {
        return const _EmptyContentCard(message: '当前关键字下没有匹配的已点歌曲，试试清空搜索关键字。');
      }
      final List<List<QueuedSongEntry>> pages = _paginateItems<QueuedSongEntry>(
        filteredQueueEntries,
        itemsPerPage: crossAxisCount * rowsPerPage,
      );
      _normalizeCurrentPage(pages.length);
      return _buildAnimatedPagedContent<QueuedSongEntry>(
        pages: pages,
        rowsPerPage: rowsPerPage,
        tileHeight: tileHeight,
        pageBuilder: (List<QueuedSongEntry> pageItems) =>
            buildQueueGrid(pageItems, rowsPerPage, tileHeight: tileHeight),
      );
    }

    ({int currentPage, int totalPages}) resolvePageData<T>(
      List<T> items, {
      required int rowsPerPage,
    }) {
      final int itemsPerPage = crossAxisCount * rowsPerPage;
      final int totalPages = _computeVisibleTotalPages(
        items.length,
        itemsPerPage,
      );
      return (
        currentPage: _normalizeCurrentPage(totalPages),
        totalPages: totalPages,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _SongBookActionRow(
          controller: widget.controller,
          queueCount: _playback.queuedSongs.length,
          compact: widget.compact,
          onQueuePressed: isQueueRoute
              ? null
              : _navigationCallbacks.onQueuePressed,
          onSettingsPressed: _navigationCallbacks.onSettingsPressed,
          onToggleAudioMode: _playbackCallbacks.onToggleAudioMode,
          onTogglePlayback: _playbackCallbacks.onTogglePlayback,
          onRestartPlayback: _playbackCallbacks.onRestartPlayback,
          onSkipSong: _playbackCallbacks.onSkipSong,
        ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                _navigation.breadcrumbLabel,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xEBFFF7FF),
                ),
              ),
            ),
            const SizedBox(width: 10),
            _ActionPill(
              label: '返回',
              icon: Icons.chevron_right_rounded,
              onPressed: _navigationCallbacks.onBackPressed,
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (!isQueueRoute) ...<Widget>[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _languageTabs
                  .map((String language) {
                    final bool selected = language == _library.selectedLanguage;
                    return Padding(
                      padding: EdgeInsets.only(
                        right: language == _languageTabs.last ? 0 : 4,
                      ),
                      child: Material(
                        color: selected
                            ? const Color(0x14FFFFFF)
                            : const Color(0x0AFFFFFF),
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () =>
                              _libraryCallbacks.onLanguageSelected(language),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 3,
                            ),
                            child: Text(
                              language,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: selected
                                    ? const Color(0xFFFF625E)
                                    : const Color(0xB8FFF0FF),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  })
                  .toList(growable: false),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (widget.compact) ...<Widget>[
          Builder(
            builder: (BuildContext context) {
              return isQueueRoute
                  ? buildQueueContent(
                      fallbackRowsPerPage,
                      tileHeight: tileHeight,
                    )
                  : buildLibraryContent(
                      fallbackRowsPerPage,
                      tileHeight: tileHeight,
                    );
            },
          ),
          const SizedBox(height: _paginationSectionGap),
          Builder(
            builder: (BuildContext context) {
              final int libraryItemsPerPage =
                  crossAxisCount * fallbackRowsPerPage;
              final int resolvedLibraryTotalPages = _computeVisibleTotalPages(
                _library.totalCount,
                libraryItemsPerPage,
              );
              final int normalizedLibraryPage = _library.pageIndex.clamp(
                0,
                math.max(0, resolvedLibraryTotalPages - 1),
              );
              final pageData = isQueueRoute
                  ? resolvePageData<QueuedSongEntry>(
                      filteredQueueEntries,
                      rowsPerPage: fallbackRowsPerPage,
                    )
                  : (
                      currentPage: normalizedLibraryPage,
                      totalPages: resolvedLibraryTotalPages,
                    );
              return _PaginationBar(
                currentPage: pageData.currentPage + 1,
                totalPages: pageData.totalPages,
                onPrevious: pageData.currentPage > 0
                    ? () => isQueueRoute
                          ? _animateToPage(pageData.currentPage - 1)
                          : _libraryCallbacks.onRequestLibraryPage(
                              pageData.currentPage - 1,
                              libraryItemsPerPage,
                            )
                    : null,
                onNext: pageData.currentPage < pageData.totalPages - 1
                    ? () => isQueueRoute
                          ? _animateToPage(pageData.currentPage + 1)
                          : _libraryCallbacks.onRequestLibraryPage(
                              pageData.currentPage + 1,
                              libraryItemsPerPage,
                            )
                    : null,
              );
            },
          ),
        ] else
          Expanded(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final int rowsPerPage = _resolveRowsPerPageForAvailableHeight(
                  availableHeight: constraints.maxHeight,
                  isLandscape: isLandscape,
                  fallbackRowsPerPage: fallbackRowsPerPage,
                  tileHeight: tileHeight,
                );
                final double resolvedTileHeight =
                    _resolveTileHeightForAvailableHeight(
                      availableHeight: constraints.maxHeight,
                      isLandscape: isLandscape,
                      rowsPerPage: rowsPerPage,
                      fallbackTileHeight: tileHeight,
                    );
                final int libraryItemsPerPage = crossAxisCount * rowsPerPage;
                final int resolvedLibraryTotalPages = _computeVisibleTotalPages(
                  _library.totalCount,
                  libraryItemsPerPage,
                );
                final int normalizedLibraryPage = _library.pageIndex.clamp(
                  0,
                  math.max(0, resolvedLibraryTotalPages - 1),
                );
                final pageData = isQueueRoute
                    ? resolvePageData<QueuedSongEntry>(
                        filteredQueueEntries,
                        rowsPerPage: rowsPerPage,
                      )
                    : (
                        currentPage: normalizedLibraryPage,
                        totalPages: resolvedLibraryTotalPages,
                      );
                return Column(
                  children: <Widget>[
                    Expanded(
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: isQueueRoute
                            ? buildQueueContent(
                                rowsPerPage,
                                tileHeight: resolvedTileHeight,
                              )
                            : buildLibraryContent(
                                rowsPerPage,
                                tileHeight: resolvedTileHeight,
                              ),
                      ),
                    ),
                    const SizedBox(height: _paginationSectionGap),
                    _PaginationBar(
                      currentPage: pageData.currentPage + 1,
                      totalPages: pageData.totalPages,
                      onPrevious: pageData.currentPage > 0
                          ? () => isQueueRoute
                                ? _animateToPage(pageData.currentPage - 1)
                                : _libraryCallbacks.onRequestLibraryPage(
                                    pageData.currentPage - 1,
                                    libraryItemsPerPage,
                                  )
                          : null,
                      onNext: pageData.currentPage < pageData.totalPages - 1
                          ? () => isQueueRoute
                                ? _animateToPage(pageData.currentPage + 1)
                                : _libraryCallbacks.onRequestLibraryPage(
                                    pageData.currentPage + 1,
                                    libraryItemsPerPage,
                                  )
                          : null,
                    ),
                  ],
                );
              },
            ),
          ),
      ],
    );
  }

  List<QueuedSongEntry> _resolveFilteredQueueEntries() {
    final String normalizedQuery = _library.searchQuery.trim().toLowerCase();
    final Iterable<QueuedSongEntry> allEntries = _playback.queuedSongs
        .asMap()
        .entries
        .map((MapEntry<int, DemoSong> entry) {
          return QueuedSongEntry(song: entry.value, queueIndex: entry.key);
        });
    if (normalizedQuery.isEmpty) {
      return allEntries.toList(growable: false);
    }
    return allEntries
        .where(
          (QueuedSongEntry entry) =>
              entry.song.searchIndex.contains(normalizedQuery),
        )
        .toList(growable: false);
  }
}

class _SongBookActionRow extends StatelessWidget {
  const _SongBookActionRow({
    required this.controller,
    required this.queueCount,
    required this.compact,
    required this.onQueuePressed,
    required this.onSettingsPressed,
    required this.onToggleAudioMode,
    required this.onTogglePlayback,
    required this.onRestartPlayback,
    required this.onSkipSong,
  });

  final PlayerController controller;
  final int queueCount;
  final bool compact;
  final VoidCallback? onQueuePressed;
  final VoidCallback onSettingsPressed;
  final VoidCallback onToggleAudioMode;
  final VoidCallback onTogglePlayback;
  final VoidCallback onRestartPlayback;
  final VoidCallback onSkipSong;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, Widget? child) {
        return Align(
          alignment: compact ? Alignment.centerLeft : Alignment.centerRight,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _ActionPill(
                  label: '已点$queueCount',
                  icon: Icons.queue_music_rounded,
                  onPressed: onQueuePressed,
                ),
                const SizedBox(width: 4),
                _ActionPill(
                  label:
                      controller.audioOutputMode ==
                          AudioOutputMode.accompaniment
                      ? '原唱'
                      : '伴唱',
                  icon: Icons.mic_rounded,
                  onPressed: controller.hasMedia ? onToggleAudioMode : null,
                ),
                const SizedBox(width: 4),
                _ActionPill(
                  label: '切歌',
                  icon: Icons.skip_next_rounded,
                  onPressed: controller.hasMedia || queueCount > 0
                      ? onSkipSong
                      : null,
                ),
                const SizedBox(width: 4),
                _ActionPill(
                  label: controller.isPlaying ? '暂停' : '播放',
                  icon: controller.isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  onPressed: controller.hasMedia ? onTogglePlayback : null,
                ),
                const SizedBox(width: 4),
                _ActionPill(
                  label: '重唱',
                  icon: Icons.replay_rounded,
                  onPressed: controller.hasMedia ? onRestartPlayback : null,
                ),
                const SizedBox(width: 4),
                _ActionPill(
                  label: '设置',
                  icon: Icons.settings_rounded,
                  onPressed: onSettingsPressed,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ActionPill extends StatelessWidget {
  const _ActionPill({required this.label, required this.icon, this.onPressed});

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final bool isEnabled = onPressed != null;
    return Material(
      color: isEnabled ? const Color(0x1AFFFFFF) : const Color(0x0DFFFFFF),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: isEnabled ? onPressed : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                icon,
                size: 12,
                color: isEnabled
                    ? const Color(0xCCFFF7FF)
                    : const Color(0x7AFFF7FF),
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isEnabled
                      ? const Color(0xCCFFF7FF)
                      : const Color(0x7AFFF7FF),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SongTile extends StatelessWidget {
  const _SongTile({
    required this.song,
    required this.isCurrent,
    required this.isQueued,
    this.onTap,
  });

  final DemoSong song;
  final bool isCurrent;
  final bool isQueued;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Color backgroundColor = isCurrent
        ? const Color(0x29FFFFFF)
        : isQueued
        ? const Color(0x12FFFFFF)
        : const Color(0x1AFFFFFF);
    final Color subtitleColor = isCurrent
        ? const Color(0xCCF3DAFF)
        : isQueued
        ? const Color(0x80F3DAFF)
        : const Color(0xB8F3DAFF);

    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 6, 10, 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0x1AFFFFFF)),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text(
                      song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        height: 1.15,
                        color: isQueued
                            ? const Color(0xA6FFF7FF)
                            : const Color(0xEDFFF7FF),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isCurrent
                          ? '${song.artist} · ${song.language} · 当前播放'
                          : isQueued
                          ? '${song.artist} · ${song.language} · 已点'
                          : '${song.artist} · ${song.language}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                        height: 1.2,
                        color: subtitleColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArtistTile extends StatelessWidget {
  const _ArtistTile({required this.artist, this.onTap});

  final DemoArtist artist;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final String badgeLabel = artist.songCount.toString();
    return Material(
      color: const Color(0x1AFFFFFF),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool useCompactLayout = constraints.maxHeight < 72;
            final double avatarSize = useCompactLayout ? 24 : 42;
            final Widget avatar = Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                Container(
                  width: avatarSize,
                  height: avatarSize,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[Color(0xFF8BC4FF), Color(0xFF7562FF)],
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    artist.avatarLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: useCompactLayout ? 8 : 11,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                Positioned(
                  right: useCompactLayout ? -6 : -4,
                  bottom: useCompactLayout ? -4 : -2,
                  child: Container(
                    constraints: BoxConstraints(
                      minWidth: useCompactLayout ? 14 : 18,
                    ),
                    padding: EdgeInsets.symmetric(
                      horizontal: useCompactLayout ? 4 : 5,
                      vertical: useCompactLayout ? 1.5 : 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF8A63),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: const Color(0xCCFFF7FF),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      badgeLabel,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: useCompactLayout ? 7 : 8,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ],
            );

            return Container(
              padding: EdgeInsets.symmetric(
                horizontal: useCompactLayout ? 10 : 12,
                vertical: useCompactLayout ? 6 : 10,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0x1AFFFFFF)),
              ),
              child: useCompactLayout
                  ? Row(
                      children: <Widget>[
                        avatar,
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            artist.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xEDFFF7FF),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        avatar,
                        const SizedBox(height: 8),
                        Text(
                          artist.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xEDFFF7FF),
                          ),
                        ),
                      ],
                    ),
            );
          },
        ),
      ),
    );
  }
}

class _EmptyContentCard extends StatelessWidget {
  const _EmptyContentCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 18),
      decoration: BoxDecoration(
        color: const Color(0x14FFFFFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x14FFFFFF)),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Color(0xCCF3DAFF), height: 1.5),
      ),
    );
  }
}

class _PaginationBar extends StatelessWidget {
  const _PaginationBar({
    required this.currentPage,
    required this.totalPages,
    this.onPrevious,
    this.onNext,
  });

  final int currentPage;
  final int totalPages;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        children: <Widget>[
          _PaginationButton(label: '上一页', onPressed: onPrevious),
          Text(
            '$currentPage/$totalPages',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Color(0xCCFFF2FF),
            ),
          ),
          _PaginationButton(label: '下一页', onPressed: onNext),
        ],
      ),
    );
  }
}

class _PaginationButton extends StatelessWidget {
  const _PaginationButton({required this.label, this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null;
    return Material(
      color: enabled ? const Color(0x16FFFFFF) : const Color(0x0DFFFFFF),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: enabled
                  ? const Color(0xCCFFF2FF)
                  : const Color(0x7AFFF2FF),
            ),
          ),
        ),
      ),
    );
  }
}
