import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
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
  static const double _artistTileHeight = 104;
  static const double _artistTargetTileWidth = 64;
  static const double _queueTileHeight = _songTileHeight;
  static const double _loadMoreThreshold = 360;
  static const double _loadMoreFooterHeight = 44;

  late final ScrollController _scrollController;
  bool _isLoadMoreRequestPending = false;
  bool _isFillViewportCheckScheduled = false;
  bool _isScrollResetScheduled = false;

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
    _scrollController = ScrollController(keepScrollOffset: false)
      ..addListener(_handleScroll);
  }

  @override
  void didUpdateWidget(covariant SongBookRightColumn oldWidget) {
    super.didUpdateWidget(oldWidget);
    final SongBookLibraryViewModel oldLibrary = oldWidget.viewModel.library;
    final SongBookLibraryViewModel nextLibrary = widget.viewModel.library;
    final bool contentChanged =
        _contentIdentity(oldWidget.viewModel) !=
        _contentIdentity(widget.viewModel);
    final bool accumulatedItemsWereReset =
        oldLibrary.pageIndex > 0 && nextLibrary.pageIndex == 0;
    if (contentChanged || accumulatedItemsWereReset) {
      _scheduleScrollReset();
    }
    if (oldLibrary.isLoadingPage != nextLibrary.isLoadingPage ||
        oldLibrary.pageIndex != nextLibrary.pageIndex ||
        oldLibrary.loadMoreErrorMessage != nextLibrary.loadMoreErrorMessage) {
      _isLoadMoreRequestPending = false;
    }
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  Object _contentIdentity(SongBookViewModel viewModel) {
    return (
      viewModel.navigation.route,
      viewModel.navigation.songBookMode,
      viewModel.navigation.libraryScope,
      viewModel.navigation.selectedArtist,
      viewModel.library.selectedLanguage,
      viewModel.library.searchQuery,
    );
  }

  void _scheduleScrollReset() {
    if (_isScrollResetScheduled) {
      return;
    }
    _isScrollResetScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _isScrollResetScheduled = false;
      if (!mounted || !_scrollController.hasClients) {
        return;
      }
      _scrollController.jumpTo(0);
    });
  }

  void _handleScroll() {
    if (!_scrollController.hasClients ||
        _scrollController.position.extentAfter > _loadMoreThreshold) {
      return;
    }
    _requestLoadMore();
  }

  void _scheduleFillViewportCheck() {
    if (_isFillViewportCheckScheduled ||
        _navigation.route == KtvRoute.queueList ||
        !_library.hasMore ||
        _library.isLoadingPage ||
        _library.loadMoreErrorMessage != null) {
      return;
    }
    _isFillViewportCheckScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _isFillViewportCheckScheduled = false;
      if (!mounted || !_scrollController.hasClients) {
        return;
      }
      if (_scrollController.position.extentAfter <= _loadMoreThreshold) {
        _requestLoadMore();
      }
    });
  }

  void _requestLoadMore({bool retry = false}) {
    if (_isLoadMoreRequestPending ||
        _navigation.route == KtvRoute.queueList ||
        !_library.hasMore ||
        _library.isLoadingPage ||
        (!retry && _library.loadMoreErrorMessage != null)) {
      return;
    }
    _isLoadMoreRequestPending = true;
    _libraryCallbacks.onLoadMore();
  }

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

  int _resolveCompactViewportRows(
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

  double _computeGridHeight({
    required int rowsPerPage,
    required double tileHeight,
  }) {
    return (tileHeight * rowsPerPage) + (_gridSpacing * (rowsPerPage - 1));
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
    final Set<String> favoriteSongIds = _library.favoriteSongIds;
    final int compactViewportRows = _resolveCompactViewportRows(
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
        if (widget.compact)
          SizedBox(
            height: _computeGridHeight(
              rowsPerPage: compactViewportRows,
              tileHeight: tileHeight,
            ),
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                return _buildScrollableContent(
                  context,
                  availableWidth: constraints.maxWidth,
                  isQueueRoute: isQueueRoute,
                  isArtistOverview: isArtistOverview,
                  isFavoritesMode: isFavoritesMode,
                  isFrequentMode: isFrequentMode,
                  favoriteSongIds: favoriteSongIds,
                  filteredQueueEntries: filteredQueueEntries,
                  tileHeight: tileHeight,
                );
              },
            ),
          )
        else
          Expanded(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                return _buildScrollableContent(
                  context,
                  availableWidth: constraints.maxWidth,
                  isQueueRoute: isQueueRoute,
                  isArtistOverview: isArtistOverview,
                  isFavoritesMode: isFavoritesMode,
                  isFrequentMode: isFrequentMode,
                  favoriteSongIds: favoriteSongIds,
                  filteredQueueEntries: filteredQueueEntries,
                  tileHeight: tileHeight,
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildScrollableContent(
    BuildContext context, {
    required double availableWidth,
    required bool isQueueRoute,
    required bool isArtistOverview,
    required bool isFavoritesMode,
    required bool isFrequentMode,
    required Set<String> favoriteSongIds,
    required List<QueuedSongEntry> filteredQueueEntries,
    required double tileHeight,
  }) {
    final int crossAxisCount = isArtistOverview
        ? _resolveArtistCrossAxisCountForWidth(availableWidth)
        : _resolveCrossAxisCountForWidth(availableWidth);
    if (isQueueRoute) {
      if (_playback.queuedSongs.isEmpty) {
        return EmptyContentCard(message: context.l10n.emptyQueue);
      }
      if (filteredQueueEntries.isEmpty) {
        return EmptyContentCard(message: context.l10n.noQueueMatches);
      }
      return _buildLazyGrid(
        crossAxisCount: crossAxisCount,
        tileHeight: tileHeight,
        itemCount: filteredQueueEntries.length,
        itemBuilder: (BuildContext context, int index) {
          return _buildQueueTile(context, filteredQueueEntries[index]);
        },
      );
    }

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
    if (_library.isScanning &&
        _library.totalCount == 0 &&
        _library.songs.isEmpty &&
        _library.artists.isEmpty) {
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
    if (_library.scanErrorMessage != null &&
        _library.songs.isEmpty &&
        _library.artists.isEmpty) {
      return EmptyContentCard(message: _library.scanErrorMessage!);
    }
    if (isArtistOverview) {
      if (_library.artists.isEmpty) {
        return EmptyContentCard(message: context.l10n.noMatchingArtists);
      }
      _scheduleFillViewportCheck();
      return _buildLazyGrid(
        crossAxisCount: crossAxisCount,
        tileHeight: tileHeight,
        itemCount: _library.artists.length,
        showLoadMoreFooter: true,
        itemBuilder: (BuildContext context, int index) {
          final Artist artist = _library.artists[index];
          return ArtistTile(
            key: ValueKey<String>('library-artist-${artist.name}'),
            artist: artist,
            onTap: () => _navigationCallbacks.onSelectArtist(artist.name),
          );
        },
      );
    }
    if (_library.songs.isEmpty) {
      if (_library.hasMore) {
        _scheduleFillViewportCheck();
        return _buildLazyGrid(
          crossAxisCount: crossAxisCount,
          tileHeight: tileHeight,
          itemCount: 0,
          showLoadMoreFooter: true,
          itemBuilder: (BuildContext context, int index) =>
              const SizedBox.shrink(),
        );
      }
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
    _scheduleFillViewportCheck();
    return _buildLazyGrid(
      crossAxisCount: crossAxisCount,
      tileHeight: tileHeight,
      itemCount: _library.songs.length,
      showLoadMoreFooter: true,
      itemBuilder: (BuildContext context, int index) {
        return _buildLibrarySongTile(
          context,
          _library.songs[index],
          favoriteSongIds: favoriteSongIds,
        );
      },
    );
  }

  Widget _buildLazyGrid({
    required int crossAxisCount,
    required double tileHeight,
    required int itemCount,
    required Widget Function(BuildContext context, int index) itemBuilder,
    bool showLoadMoreFooter = false,
  }) {
    return CustomScrollView(
      controller: _scrollController,
      scrollCacheExtent: ScrollCacheExtent.pixels(tileHeight * 3),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: <Widget>[
        SliverGrid(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: _gridSpacing,
            crossAxisSpacing: _gridSpacing,
            mainAxisExtent: tileHeight,
          ),
          delegate: SliverChildBuilderDelegate(
            itemBuilder,
            childCount: itemCount,
            addAutomaticKeepAlives: false,
          ),
        ),
        SliverToBoxAdapter(
          child: showLoadMoreFooter
              ? _buildLoadMoreFooter()
              : const SizedBox(height: 12),
        ),
      ],
    );
  }

  Widget _buildLoadMoreFooter() {
    if (_library.isLoadingPage) {
      return const SizedBox(
        height: _loadMoreFooterHeight,
        child: Center(
          child: SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (_library.loadMoreErrorMessage != null) {
      return SizedBox(
        height: _loadMoreFooterHeight,
        child: Center(
          child: IconButton(
            tooltip: context.l10n.retry,
            onPressed: () => _requestLoadMore(retry: true),
            icon: const Icon(Icons.refresh_rounded),
            color: const Color(0xFFFF8A8A),
          ),
        ),
      );
    }
    return const SizedBox(height: 12);
  }

  Widget _buildLibrarySongTile(
    BuildContext context,
    Song song, {
    required Set<String> favoriteSongIds,
  }) {
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
    final double? downloadProgress = _library.downloadProgressForSong(song);
    return SongTile(
      key: ValueKey<String>(
        'library-song-${song.sourceId}-${song.sourceSongId}-${song.songId}',
      ),
      title: song.title,
      subtitle: isCurrent
          ? '${song.artist} · ${song.language} · ${context.l10n.currentPlayback}'
          : isQueued
          ? '${song.artist} · ${song.language} · ${context.l10n.queued}'
          : '${song.artist} · ${song.language}',
      highlighted: isCurrent,
      downloadProgress: hasDownloadTask ? downloadProgress : null,
      progressKey: ValueKey<String>('song-download-progress-${song.songId}'),
      trailing: Row(
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
      ),
      onTap: !isQueued || showCloudStatus
          ? () => _libraryCallbacks.onRequestSong(song)
          : null,
    );
  }

  Widget _buildQueueTile(BuildContext context, QueuedSongEntry entry) {
    final Song song = entry.song;
    final double? downloadProgress = _library.downloadProgressForSong(song);
    final Widget? trailing = entry.isCurrent
        ? null
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (entry.showPinAction) ...<Widget>[
                SongTileIconButton(
                  icon: Icons.vertical_align_top_rounded,
                  onPressed: entry.canPinToTop
                      ? () => _playbackCallbacks.onPrioritizeQueuedSong(song)
                      : null,
                ),
                const SizedBox(width: 4),
              ],
              SongTileIconButton(
                icon: Icons.delete_outline_rounded,
                onPressed: () => _playbackCallbacks.onRemoveQueuedSong(song),
              ),
            ],
          );
    return SongTile(
      key: ValueKey<String>(
        'queue-song-${entry.queueIndex}-${song.sourceId}-${song.sourceSongId}',
      ),
      title: song.title,
      subtitle: '${song.artist} · ${song.language} · ${entry.subtitle}',
      highlighted: entry.isCurrent,
      downloadProgress: downloadProgress,
      progressKey: ValueKey<String>('song-download-progress-${song.songId}'),
      trailing: trailing,
      onTap: entry.isPendingDownload
          ? () => _libraryCallbacks.onRequestSong(song)
          : null,
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
