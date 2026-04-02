import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:ktv2/ktv2.dart';

import '../../../core/models/demo_artist.dart';
import '../../../core/models/demo_song.dart';
import '../application/ktv_demo_controller.dart';
import 'queue_page.dart';
import 'songbook_contracts.dart';
import 'songbook_right_column_widgets.dart';

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
            return SongTile(
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
            return ArtistTile(
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
        return const EmptyContentCard(message: '请先在设置里选择扫描目录，扫描完成后这里会展示歌曲列表。');
      }
      _scheduleLibraryPageSizeSync(itemsPerPage);
      if (_library.isScanning &&
          _library.totalCount == 0 &&
          _library.songs.isEmpty) {
        return const EmptyContentCard(message: '正在扫描目录中的歌曲，请稍候。');
      }
      if (_library.isLoadingPage &&
          _library.totalCount == 0 &&
          _library.songs.isEmpty &&
          _library.artists.isEmpty) {
        return EmptyContentCard(
          message: isArtistOverview ? '正在加载歌手列表，请稍候。' : '正在加载歌曲列表，请稍候。',
        );
      }
      if (_library.scanErrorMessage != null) {
        return EmptyContentCard(message: _library.scanErrorMessage!);
      }
      if (isArtistOverview) {
        if (_library.artists.isEmpty) {
          return const EmptyContentCard(
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
        return EmptyContentCard(
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
        return const EmptyContentCard(message: '当前还没有已点歌曲，点歌后会在这里显示。');
      }
      if (filteredQueueEntries.isEmpty) {
        return const EmptyContentCard(message: '当前关键字下没有匹配的已点歌曲，试试清空搜索关键字。');
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
        SongBookActionRow(
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
            ActionPill(
              label: '返回',
              onPressed: _navigationCallbacks.onBackPressed,
              padding: const EdgeInsets.fromLTRB(8, 5, 14, 5),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _navigation.breadcrumbLabel,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xEBFFF7FF),
                ),
              ),
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
              return PaginationBar(
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
                    PaginationBar(
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
