import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:ktv2/ktv2.dart';

import '../../../core/localization/localization_extensions.dart';
import '../../../core/models/artist.dart';
import '../../../core/models/song.dart';
import '../application/download_manager_models.dart';
import '../application/ktv_controller.dart';
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
  static const double _songTileMinHeight = 36;
  static const double _artistTileHeight = 104;
  static const double _artistTileMinHeight = 72;
  static const double _artistTargetTileWidth = 64;
  static const double _queueTileHeight = _songTileHeight;
  static const double _queueTileMinHeight = _songTileMinHeight;
  static const double _paginationSectionHeight = 28;
  static const double _paginationSectionGap = 6;
  static const int _maxVisiblePages = 20;

  int _currentPage = 0;
  int? _pendingLibraryPageSizeSync;

  SongBookViewModel get _viewModel => widget.viewModel;
  SongBookCallbacks get _callbacks => widget.callbacks;
  SongBookNavigationViewModel get _navigation => _viewModel.navigation;
  SongBookLibraryViewModel get _library => _viewModel.library;
  SongBookPlaybackViewModel get _playback => _viewModel.playback;
  SongBookNavigationCallbacks get _navigationCallbacks => _callbacks.navigation;
  SongBookLibraryCallbacks get _libraryCallbacks => _callbacks.library;
  SongBookPlaybackCallbacks get _playbackCallbacks => _callbacks.playback;

  int _resolveCrossAxisCountForWidth(double availableWidth) {
    if (availableWidth < 760) {
      return 2;
    }
    if (availableWidth < 1080) {
      return 3;
    }
    return 4;
  }

  int _resolveArtistCrossAxisCountForWidth(double availableWidth) {
    if (!availableWidth.isFinite || availableWidth <= 0) {
      return 3;
    }
    final int fittedColumns =
        ((availableWidth + _gridSpacing) /
                (_artistTargetTileWidth + _gridSpacing))
            .floor();
    return fittedColumns.clamp(3, 8);
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
    required int fallbackRowsPerPage,
    required double minTileHeight,
  }) {
    if (!availableHeight.isFinite || availableHeight <= 0) {
      return fallbackRowsPerPage;
    }
    final double listHeight = math.max(
      0,
      availableHeight - _paginationSectionHeight - _paginationSectionGap,
    );
    final int fittedRows =
        ((listHeight + _gridSpacing) / (minTileHeight + _gridSpacing)).floor();
    return math.max(1, fittedRows);
  }

  double _resolveTileHeightForAvailableHeight({
    required double availableHeight,
    required int rowsPerPage,
    required double minTileHeight,
    required double fallbackTileHeight,
  }) {
    if (rowsPerPage <= 0 || !availableHeight.isFinite || availableHeight <= 0) {
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
    return computedTileHeight
        .clamp(minTileHeight, fallbackTileHeight)
        .toDouble();
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
    return normalizedPage;
  }

  void _scheduleLibraryPageSizeSync(int pageSize) {
    if (_navigation.route == KtvRoute.queueList ||
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

  void _animateToPage(int page) {
    if (page == _currentPage) {
      return;
    }
    setState(() => _currentPage = page);
  }

  @override
  Widget build(BuildContext context) {
    final MediaQueryData media = MediaQuery.of(context);
    final bool isLandscape = media.orientation == Orientation.landscape;
    final bool isQueueRoute = _navigation.route == KtvRoute.queueList;
    final bool isFavoritesMode =
        _navigation.songBookMode == SongBookMode.favorites;
    final bool isFrequentMode =
        _navigation.songBookMode == SongBookMode.frequent;
    final bool isArtistOverview =
        !isQueueRoute &&
        _navigation.songBookMode == SongBookMode.artists &&
        _navigation.selectedArtist == null;
    final Set<String> favoriteSongIds = _library.favoriteSongIds.toSet();
    final int fallbackCrossAxisCount = isArtistOverview
        ? _resolveArtistCrossAxisCountForWidth(media.size.width)
        : _resolveCrossAxisCountForWidth(media.size.width);
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
    final double minTileHeight = isQueueRoute
        ? _queueTileMinHeight
        : isArtistOverview
        ? _artistTileMinHeight
        : _songTileMinHeight;
    final List<QueuedSongEntry> filteredQueueEntries = isQueueRoute
        ? _resolveFilteredQueueEntries()
        : const <QueuedSongEntry>[];

    Widget buildLibraryGrid(
      List<Song> visibleSongs,
      int rowsPerPage, {
      required int crossAxisCount,
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
            final Song song = visibleSongs[index];
            final DownloadTaskStatus? downloadTaskStatus = _library
                .downloadTaskStatusForSong(song);
            final bool isCurrent =
                widget.controller.hasMedia &&
                _playback.queuedSongs.isNotEmpty &&
                _playback.queuedSongs.first == song;
            final bool isQueued = _playback.queuedSongs.contains(song);
            final bool isFavorite = favoriteSongIds.contains(song.songId);
            final bool isDownloaded = _library.isSongDownloaded(song);
            final bool showCloudStatus =
                _library.supportsDownload(song) && !isDownloaded;
            final bool hasDownloadTask =
                downloadTaskStatus == DownloadTaskStatus.downloading ||
                downloadTaskStatus == DownloadTaskStatus.paused ||
                downloadTaskStatus == DownloadTaskStatus.failed;
            final double? downloadProgress = _library.downloadProgressForSong(
              song,
            );
            final Widget trailing = Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (showCloudStatus && !hasDownloadTask) ...<Widget>[
                  const SongTileIconButton(
                    icon: Icons.cloud_rounded,
                    preserveColorWhenDisabled: true,
                  ),
                  const SizedBox(width: 4),
                ],
                SongTileIconButton(
                  icon: isFavorite
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: isFavorite
                      ? const Color(0xFFFF7AA2)
                      : const Color(0xB8F3DAFF),
                  onPressed: () => _libraryCallbacks.onToggleFavorite(song),
                ),
              ],
            );
            return SongTile(
              title: song.title,
              subtitle: isCurrent
                  ? '${song.artist} · ${song.language} · ${context.l10n.currentPlayback}'
                  : isQueued
                  ? '${song.artist} · ${song.language} · ${context.l10n.queued}'
                  : '${song.artist} · ${song.language}',
              highlighted: isCurrent,
              downloadProgress: hasDownloadTask ? downloadProgress : null,
              progressKey: ValueKey<String>(
                'song-download-progress-${song.songId}',
              ),
              trailing: trailing,
              onTap: !isQueued || showCloudStatus
                  ? () => _libraryCallbacks.onRequestSong(song)
                  : null,
            );
          },
        ),
      );
    }

    Widget buildArtistGrid(
      List<Artist> visibleArtists,
      int rowsPerPage, {
      required int crossAxisCount,
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
            final Artist artist = visibleArtists[index];
            return ArtistTile(
              artist: artist,
              onTap: () => _navigationCallbacks.onSelectArtist(artist.name),
            );
          },
        ),
      );
    }

    Widget buildLibraryContent(
      int rowsPerPage, {
      required int crossAxisCount,
      required double tileHeight,
    }) {
      final int itemsPerPage = crossAxisCount * rowsPerPage;
      final bool needsAggregatedSourceConfiguration =
          _navigation.libraryScope == LibraryScope.aggregated &&
          !_library.hasConfiguredAggregatedSources &&
          _navigation.songBookMode != SongBookMode.favorites &&
          _navigation.songBookMode != SongBookMode.frequent;
      if (!_library.hasConfiguredDirectory &&
          _navigation.libraryScope == LibraryScope.localOnly) {
        return EmptyContentCard(message: context.l10n.noLocalDirectory);
      }
      if (needsAggregatedSourceConfiguration &&
          _library.songs.isEmpty &&
          _library.artists.isEmpty &&
          _library.scanErrorMessage == null) {
        return EmptyContentCard(message: context.l10n.noDataSource);
      }
      _scheduleLibraryPageSizeSync(itemsPerPage);
      if (_library.isScanning &&
          _library.totalCount == 0 &&
          _library.songs.isEmpty) {
        return EmptyContentCard(message: context.l10n.scanningLocalSongs);
      }
      if (_library.isLoadingPage &&
          _library.totalCount == 0 &&
          _library.songs.isEmpty &&
          _library.artists.isEmpty) {
        return EmptyContentCard(
          message: isArtistOverview
              ? context.l10n.loadingArtists
              : context.l10n.loadingSongs,
        );
      }
      if (_library.scanErrorMessage != null) {
        return EmptyContentCard(message: _library.scanErrorMessage!);
      }
      if (isArtistOverview) {
        if (_library.artists.isEmpty) {
          return EmptyContentCard(message: context.l10n.noMatchingArtists);
        }
        return buildArtistGrid(
          _library.artists,
          rowsPerPage,
          crossAxisCount: crossAxisCount,
          tileHeight: tileHeight,
        );
      }
      if (_library.songs.isEmpty) {
        return EmptyContentCard(
          message: isFavoritesMode
              ? context.l10n.noFavorites
              : isFrequentMode
              ? context.l10n.noFrequentSongs
              : _navigation.selectedArtist == null
              ? context.l10n.noPlayableVideos
              : context.l10n.noArtistSongs,
        );
      }
      return buildLibraryGrid(
        _library.songs,
        rowsPerPage,
        crossAxisCount: crossAxisCount,
        tileHeight: tileHeight,
      );
    }

    Widget buildQueueGrid(
      List<QueuedSongEntry> visibleEntries,
      int rowsPerPage, {
      required int crossAxisCount,
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
            final Song song = entry.song;
            final double? downloadProgress = _library.downloadProgressForSong(
              song,
            );
            final Widget? trailing = entry.isCurrent
                ? null
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      if (entry.showPinAction) ...<Widget>[
                        SongTileIconButton(
                          icon: Icons.vertical_align_top_rounded,
                          onPressed: entry.canPinToTop
                              ? () => _playbackCallbacks.onPrioritizeQueuedSong(
                                  song,
                                )
                              : null,
                        ),
                        const SizedBox(width: 4),
                      ],
                      SongTileIconButton(
                        icon: Icons.delete_outline_rounded,
                        onPressed: () =>
                            _playbackCallbacks.onRemoveQueuedSong(song),
                      ),
                    ],
                  );
            return SongTile(
              title: song.title,
              subtitle: '${song.artist} · ${song.language} · ${entry.subtitle}',
              highlighted: entry.isCurrent,
              downloadProgress: downloadProgress,
              progressKey: ValueKey<String>(
                'song-download-progress-${song.songId}',
              ),
              trailing: trailing,
              onTap: entry.isPendingDownload
                  ? () => _libraryCallbacks.onRequestSong(song)
                  : null,
            );
          },
        ),
      );
    }

    Widget buildQueueContent(
      int rowsPerPage, {
      required int crossAxisCount,
      required double tileHeight,
    }) {
      if (_playback.queuedSongs.isEmpty) {
        return EmptyContentCard(message: context.l10n.emptyQueue);
      }
      if (filteredQueueEntries.isEmpty) {
        return EmptyContentCard(message: context.l10n.noQueueMatches);
      }
      final List<List<QueuedSongEntry>> pages = _paginateItems<QueuedSongEntry>(
        filteredQueueEntries,
        itemsPerPage: crossAxisCount * rowsPerPage,
      );
      final int currentPage = _normalizeCurrentPage(pages.length);
      return buildQueueGrid(
        pages[currentPage],
        rowsPerPage,
        crossAxisCount: crossAxisCount,
        tileHeight: tileHeight,
      );
    }

    ({int currentPage, int totalPages}) resolvePageData<T>(
      List<T> items, {
      required int crossAxisCount,
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
              label: context.l10n.back,
              icon: Icons.arrow_back_ios_new_rounded,
              onPressed: _navigationCallbacks.onBackPressed,
              padding: const EdgeInsets.fromLTRB(8, 5, 14, 5),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _localizedBreadcrumb(context, _navigation.breadcrumbLabel),
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
                              _localizedLanguageLabel(context, language),
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
                      crossAxisCount: fallbackCrossAxisCount,
                      tileHeight: tileHeight,
                    )
                  : buildLibraryContent(
                      fallbackRowsPerPage,
                      crossAxisCount: fallbackCrossAxisCount,
                      tileHeight: tileHeight,
                    );
            },
          ),
          const SizedBox(height: _paginationSectionGap),
          Builder(
            builder: (BuildContext context) {
              final int libraryItemsPerPage =
                  fallbackCrossAxisCount * fallbackRowsPerPage;
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
                      crossAxisCount: fallbackCrossAxisCount,
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
                  fallbackRowsPerPage: fallbackRowsPerPage,
                  minTileHeight: minTileHeight,
                );
                final int crossAxisCount = isArtistOverview
                    ? _resolveArtistCrossAxisCountForWidth(constraints.maxWidth)
                    : _resolveCrossAxisCountForWidth(constraints.maxWidth);
                final double resolvedTileHeight =
                    _resolveTileHeightForAvailableHeight(
                      availableHeight: constraints.maxHeight,
                      rowsPerPage: rowsPerPage,
                      minTileHeight: minTileHeight,
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
                        crossAxisCount: crossAxisCount,
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
                                crossAxisCount: crossAxisCount,
                                tileHeight: resolvedTileHeight,
                              )
                            : buildLibraryContent(
                                rowsPerPage,
                                crossAxisCount: crossAxisCount,
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
    final bool hasCurrentPlayback =
        widget.controller.hasMedia && _playback.queuedSongs.isNotEmpty;
    final Iterable<QueuedSongEntry> allEntries = _playback.queuedSongs
        .asMap()
        .entries
        .map((MapEntry<int, Song> entry) {
          final Song song = entry.value;
          final DownloadTaskStatus? downloadTaskStatus = _library
              .downloadTaskStatusForSong(song);
          final bool isPendingDownload =
              _library.supportsDownload(song) &&
              !_library.isSongDownloaded(song);
          final bool isDownloading =
              downloadTaskStatus == DownloadTaskStatus.downloading;
          final bool isPausedDownload =
              downloadTaskStatus == DownloadTaskStatus.paused;
          final bool isFailedDownload =
              downloadTaskStatus == DownloadTaskStatus.failed;
          return QueuedSongEntry(
            song: song,
            queueIndex: entry.key,
            isCurrent: hasCurrentPlayback && entry.key == 0,
            isPendingDownload: isPendingDownload,
            canPinToTop:
                !isPendingDownload && entry.key > (hasCurrentPlayback ? 1 : 0),
            showPinAction: !isPendingDownload,
            subtitle: hasCurrentPlayback && entry.key == 0
                ? context.l10n.currentPlayback
                : isPendingDownload
                ? (isDownloading
                      ? context.l10n.downloading
                      : isPausedDownload
                      ? context.l10n.downloadPaused
                      : isFailedDownload
                      ? context.l10n.downloadError
                      : context.l10n.waitingForDownload)
                : context.l10n.queuePosition(
                    entry.key + (hasCurrentPlayback ? 0 : 1),
                  ),
          );
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

String _localizedLanguageLabel(BuildContext context, String language) {
  return switch (language) {
    '全部' => context.l10n.allLanguages,
    '国语' => context.l10n.mandarin,
    '粤语' => context.l10n.cantonese,
    '闽南语' => context.l10n.minNan,
    '英语' => context.l10n.englishLanguage,
    '日语' => context.l10n.japanese,
    '韩语' => context.l10n.korean,
    '其它' => context.l10n.otherLanguage,
    _ => language,
  };
}

String _localizedBreadcrumb(BuildContext context, String breadcrumb) {
  return breadcrumb
      .split(' / ')
      .map((String segment) {
        return switch (segment) {
          '主页' => context.l10n.home,
          '歌名' => context.l10n.songTitle,
          '歌星' => context.l10n.artist,
          '本地' => context.l10n.local,
          '收藏' => context.l10n.favorites,
          '常唱' => context.l10n.frequent,
          '已点' => context.l10n.queued,
          _ => segment,
        };
      })
      .join(' / ');
}
