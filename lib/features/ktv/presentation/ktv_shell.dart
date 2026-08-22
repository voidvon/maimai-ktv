import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;

import '../../../core/localization/locale_controller.dart';
import '../../../core/localization/localization_extensions.dart';
import '../../../core/models/song.dart';
import '../../../core/presentation/center_overlay_toast.dart';
import '../../media_library/data/baidu_pan/baidu_pan_app_config.dart';
import '../../media_library/data/baidu_pan/baidu_pan_http_api_client.dart';
import '../../media_library/data/baidu_pan/baidu_pan_oauth_repository.dart';
import '../../media_library/data/baidu_pan/file_baidu_pan_auth_store.dart';
import '../../media_library/data/baidu_pan/file_baidu_pan_source_config_store.dart';
import '../../media_library/data/cloud/cloud_playback_cache.dart';
import '../../media_library/data/cloud/cloud_song_download_service.dart';
import '../../media_library/data/smb/file_smb_store.dart';
import '../../media_library/data/smb/smb_client.dart';
import '../../media_library/data/smb/smb_credential_store.dart';
import '../../media_library/data/webdav/file_webdav_store.dart';
import '../../media_library/data/webdav/webdav_client.dart';
import '../../media_library/data/webdav/webdav_credential_store.dart';
import '../../settings/application/baidu_pan_settings_controller.dart';
import '../../settings/application/settings_controller.dart';
import '../../settings/application/smb_settings_controller.dart';
import '../../settings/application/webdav_settings_controller.dart';
import '../../settings/presentation/settings_page.dart';
import '../../update/application/update_controller.dart';
import '../application/download_manager_models.dart';
import '../application/ktv_controller.dart';
import 'home_page.dart';
import 'ktv_preview_coordinator.dart';
import 'ktv_search_coordinator.dart';
import 'shared_widgets.dart';
import 'songbook_contracts.dart';
import 'songbook_page.dart';

class KtvShell extends StatefulWidget {
  const KtvShell({
    super.key,
    required this.controller,
    required this.updateController,
    required this.localeController,
  });

  final KtvController controller;
  final UpdateController updateController;
  final LocaleController localeController;

  @override
  State<KtvShell> createState() => _KtvShellState();
}

class _KtvShellState extends State<KtvShell> with WidgetsBindingObserver {
  static const Duration _backgroundErrorSuppressDuration = Duration(seconds: 2);
  static const double _wideShellMaxWidth = 980;
  static const double _landscapeSongBookShellMaxWidth = 1120;

  late final KtvController _controller;
  late final KtvSearchCoordinator _searchCoordinator;
  late final KtvPreviewCoordinator _previewCoordinator;
  AppLifecycleState _appLifecycleState = AppLifecycleState.resumed;
  bool _shouldRestorePlaybackAfterBackground = false;
  final Set<String> _backgroundInterruptedDownloadKeys = <String>{};
  final Map<String, DateTime> _suppressedDownloadErrorsUntil =
      <String, DateTime>{};

  @override
  void initState() {
    super.initState();
    _controller = widget.controller;
    WidgetsBinding.instance.addObserver(this);
    _searchCoordinator = KtvSearchCoordinator(
      onQueryChanged: _controller.setSearchQuery,
    );
    _previewCoordinator = KtvPreviewCoordinator(
      controller: _controller.playerController,
      routeResolver: () => _controller.route,
    );
    unawaited(_controller.initialize());
  }

  @override
  void dispose() {
    unawaited(_previewCoordinator.disposeCoordinator());
    WidgetsBinding.instance.removeObserver(this);
    _searchCoordinator.dispose();
    _previewCoordinator.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    _previewCoordinator.schedulePreviewViewportSync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final AppLifecycleState previousState = _appLifecycleState;
    _appLifecycleState = state;
    _pruneExpiredSuppressedDownloadErrors();
    if (_isBackgroundLifecycle(state) &&
        !_isBackgroundLifecycle(previousState)) {
      final bool shouldStopPlayback = _controller.playerController.isPlaying;
      _shouldRestorePlaybackAfterBackground = shouldStopPlayback;
      final Set<String> downloadKeys = _controller.downloadingSongs
          .where((DownloadingSongItem item) => item.isDownloading)
          .map((DownloadingSongItem item) {
            return _buildDownloadKeyForTask(item);
          })
          .toSet();
      _backgroundInterruptedDownloadKeys.addAll(downloadKeys);
      _markSuppressedDownloadErrors(downloadKeys);
      unawaited(_handleAppMovedToBackground());
      return;
    }
    if (state == AppLifecycleState.resumed &&
        _isBackgroundLifecycle(previousState) &&
        _backgroundInterruptedDownloadKeys.isNotEmpty) {
      final List<String> pendingKeys = _backgroundInterruptedDownloadKeys
          .toList(growable: false);
      for (final String key in pendingKeys) {
        final DownloadingSongItem? task = _findDownloadTaskByKey(key);
        if (task == null || task.isDownloading || task.canResume) {
          _clearBackgroundRetryState(key);
        }
      }
    }
    if (state == AppLifecycleState.resumed &&
        _isBackgroundLifecycle(previousState)) {
      final bool shouldRestorePlayback = _shouldRestorePlaybackAfterBackground;
      _shouldRestorePlaybackAfterBackground = false;
      if (shouldRestorePlayback) {
        unawaited(_controller.restorePlaybackSessionIfNeeded(force: true));
      }
    }
  }

  Future<void> _openSettingsPage() async {
    final SettingsController settingsController = SettingsController(
      mediaLibraryRepository: _controller.mediaLibraryRepository,
      initialDirectoryPath: _controller.scanDirectoryPath,
    );
    final BaiduPanOAuthRepository baiduPanAuthRepository =
        BaiduPanOAuthRepository(
          appCredentials: kBaiduPanAppCredentials,
          authStore: FileBaiduPanAuthStore(),
        );
    final BaiduPanSettingsController baiduPanController =
        BaiduPanSettingsController(
          appCredentials: kBaiduPanAppCredentials,
          apiClient: BaiduPanHttpApiClient(
            authRepository: baiduPanAuthRepository,
          ),
          authRepository: baiduPanAuthRepository,
          sourceConfigStore: FileBaiduPanSourceConfigStore(),
        );
    unawaited(baiduPanController.load());
    final FileWebDavSourceConfigStore webDavConfigStore =
        FileWebDavSourceConfigStore();
    final SecureWebDavCredentialStore webDavCredentialStore =
        SecureWebDavCredentialStore();
    final WebDavSettingsController webDavController = WebDavSettingsController(
      configStore: webDavConfigStore,
      credentialStore: webDavCredentialStore,
      client: WebDavClient(
        configStore: webDavConfigStore,
        credentialStore: webDavCredentialStore,
      ),
    );
    unawaited(webDavController.load());
    final FileSmbSourceConfigStore smbConfigStore = FileSmbSourceConfigStore();
    final SecureSmbCredentialStore smbCredentialStore =
        SecureSmbCredentialStore();
    final SmbSettingsController smbController = SmbSettingsController(
      configStore: smbConfigStore,
      credentialStore: smbCredentialStore,
      client: SmbClient(
        configStore: smbConfigStore,
        credentialStore: smbCredentialStore,
      ),
    );
    unawaited(smbController.load());
    final SettingsPageResult? result = await Navigator.of(context)
        .push<SettingsPageResult>(
          MaterialPageRoute<SettingsPageResult>(
            builder: (BuildContext context) {
              return SettingsPage(
                controller: settingsController,
                baiduPanController: baiduPanController,
                webDavController: webDavController,
                smbController: smbController,
                ktvController: _controller,
                updateController: widget.updateController,
                localeController: widget.localeController,
              );
            },
            fullscreenDialog: true,
          ),
        );
    settingsController.dispose();
    baiduPanController.dispose();
    webDavController.dispose();
    smbController.dispose();

    if (!mounted || result == null) {
      return;
    }

    if (result.localDirectory != null) {
      await _controller.handleSelectedDirectory(result.localDirectory!);
      _searchCoordinator.clear();
      return;
    }
    if (result.refreshAggregatedSources) {
      await _controller.refreshConfiguredSources();
      _searchCoordinator.clear();
    }
  }

  void _togglePlayback() {
    _controller.togglePlayback();
  }

  void _toggleAudioMode() {
    _controller.toggleAudioMode();
  }

  void _restartPlayback() {
    _controller.restartPlayback();
  }

  void _enterPreviewFullscreen() {
    unawaited(
      _previewCoordinator.enterPreviewFullscreen(
        entryOrientation: mounted ? MediaQuery.orientationOf(context) : null,
      ),
    );
  }

  void _exitPreviewFullscreen() {
    unawaited(_previewCoordinator.exitPreviewFullscreen());
  }

  void _handleBackToSongBookFromFullscreen() {
    _controller.enterSongBook(
      mode: _controller.songBookMode,
      scope: _controller.libraryScope,
    );
    _exitPreviewFullscreen();
  }

  void _skipCurrentSong() {
    if (!_controller.playerController.hasMedia &&
        _controller.queuedSongs.isEmpty) {
      return;
    }
    if (!_controller.hasNextPlayableQueuedSong) {
      CenterOverlayToast.showError(context, message: context.l10n.noNextSong);
      return;
    }
    unawaited(_controller.skipCurrentSong());
  }

  void _enterAllSongsBook() {
    _searchCoordinator.clear();
    _controller.enterSongBook(
      mode: SongBookMode.songs,
      scope: LibraryScope.aggregated,
    );
  }

  void _enterLocalSongBook() {
    _searchCoordinator.clear();
    _controller.enterSongBook(
      mode: SongBookMode.songs,
      scope: LibraryScope.localOnly,
    );
  }

  void _enterFavoritesBook() {
    _searchCoordinator.clear();
    _controller.enterSongBook(
      mode: SongBookMode.favorites,
      scope: LibraryScope.aggregated,
    );
  }

  void _enterFrequentBook() {
    _searchCoordinator.clear();
    _controller.enterSongBook(
      mode: SongBookMode.frequent,
      scope: LibraryScope.aggregated,
    );
  }

  void _enterArtistBook() {
    _searchCoordinator.clear();
    _controller.enterSongBook(
      mode: SongBookMode.artists,
      scope: LibraryScope.aggregated,
    );
  }

  void _enterQueueList() {
    _searchCoordinator.clear();
    _controller.enterQueueList();
  }

  void _returnHome() {
    unawaited(_handleNavigateBack());
  }

  Future<void> _handleNavigateBack() async {
    final bool didNavigate = await _controller.navigateBack();
    if (didNavigate) {
      _searchCoordinator.clear();
    }
  }

  void _selectLanguage(String language) {
    _controller.selectLanguage(language);
  }

  void _appendSearchToken(String token) {
    _searchCoordinator.appendToken(token);
  }

  void _removeSearchCharacter() {
    _searchCoordinator.removeLastCharacter();
  }

  void _clearSearch() {
    _searchCoordinator.clear();
  }

  void _loadMoreLibraryItems() {
    unawaited(_controller.loadMoreLibraryItems());
  }

  Future<void> _requestSong(Song song) async {
    switch (_controller.resolveSongSelectionAction(song)) {
      case SongSelectionAction.queue:
        await _controller.requestSong(song);
        return;
      case SongSelectionAction.startDownload:
        await _controller.enqueuePendingSong(song);
        unawaited(_downloadSong(song));
        if (mounted) {
          CenterOverlayToast.showSuccess(
            context,
            message: context.l10n.addedToQueue,
          );
        }
        return;
      case SongSelectionAction.resumeDownload:
        await _controller.enqueuePendingSong(song);
        unawaited(_downloadSong(song));
        if (mounted) {
          CenterOverlayToast.showSuccess(
            context,
            message: context.l10n.downloadResumed,
          );
        }
        return;
      case SongSelectionAction.downloading:
        await _controller.enqueuePendingSong(song);
        if (mounted) {
          CenterOverlayToast.showSuccess(
            context,
            message: context.l10n.downloading,
          );
        }
        return;
    }
  }

  Future<void> _toggleFavorite(Song song) async {
    await _controller.toggleFavorite(song);
  }

  Future<void> _downloadSong(Song song) async {
    final String downloadKey = _controller.buildDownloadKeyForSong(song);
    try {
      final CloudSongDownloadResult result = await _controller
          .downloadSongToLocal(song);
      if (!mounted) {
        return;
      }
      final String fileName = path.basename(result.savedPath);
      final String label = result.usedPreferredDirectory
          ? context.l10n.downloadedToLocalDirectory(fileName)
          : context.l10n.downloadedToAppDirectory(fileName);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(label)));
    } catch (error) {
      if (!mounted) {
        return;
      }
      if (error is CloudDownloadCancelledException) {
        CenterOverlayToast.showSuccess(
          context,
          message: context.l10n.cancelled,
        );
        return;
      }
      if (error is CloudDownloadPausedException) {
        CenterOverlayToast.showSuccess(context, message: context.l10n.paused);
        return;
      }
      if (_shouldSuppressDownloadError(downloadKey)) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            buildDownloadErrorSummary(
              error.toString(),
              fallback: context.l10n.downloadFailed,
            ),
          ),
        ),
      );
    }
  }

  Future<void> _handleAppMovedToBackground() async {
    await _controller.preparePlaybackForBackground(
      shouldStopPlayback: _shouldRestorePlaybackAfterBackground,
    );
  }

  bool _isBackgroundLifecycle(AppLifecycleState state) {
    return state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached;
  }

  String _buildDownloadKeyForTask(DownloadingSongItem item) {
    return _controller.buildDownloadKeyForSong(item.toSong());
  }

  bool _shouldSuppressDownloadError(String downloadKey) {
    _pruneExpiredSuppressedDownloadErrors();
    return _isBackgroundLifecycle(_appLifecycleState) ||
        _backgroundInterruptedDownloadKeys.contains(downloadKey) ||
        (_suppressedDownloadErrorsUntil[downloadKey]?.isAfter(DateTime.now()) ??
            false);
  }

  DownloadingSongItem? _findDownloadTaskByKey(String key) {
    for (final DownloadingSongItem item in _controller.downloadingSongs) {
      if (_buildDownloadKeyForTask(item) == key) {
        return item;
      }
    }
    return null;
  }

  void _clearBackgroundRetryState(String key) {
    _backgroundInterruptedDownloadKeys.remove(key);
  }

  void _markSuppressedDownloadErrors(Iterable<String> keys) {
    final DateTime until = DateTime.now().add(_backgroundErrorSuppressDuration);
    for (final String key in keys) {
      _suppressedDownloadErrorsUntil[key] = until;
    }
  }

  void _pruneExpiredSuppressedDownloadErrors() {
    final DateTime now = DateTime.now();
    _suppressedDownloadErrorsUntil.removeWhere(
      (_, DateTime until) => !until.isAfter(now),
    );
  }

  SongBookViewModel _buildSongBookViewModel() {
    return SongBookViewModel(
      navigation: SongBookNavigationViewModel(
        route: _controller.route,
        songBookMode: _controller.songBookMode,
        libraryScope: _controller.libraryScope,
        selectedArtist: _controller.selectedArtist,
        breadcrumbLabel: _controller.breadcrumbLabel,
      ),
      library: SongBookLibraryViewModel(
        searchQuery: _controller.searchQuery,
        selectedLanguage: _controller.selectedLanguage,
        songs: _controller.filteredSongs,
        artists: _controller.libraryArtists,
        favoriteSongIds: _controller.favoriteSongIds,
        downloadableSourceIds: _controller.downloadableSourceIds,
        downloadingSongIds: _controller.downloadingSongIds,
        downloadingSongProgressByKey: _controller.downloadingSongProgressByKey,
        downloadTaskStatusByKey: _controller.downloadTaskStatusByKey,
        downloadedSongKeys: _controller.downloadedSongKeys,
        totalCount: _controller.libraryTotalCount,
        pageIndex: _controller.libraryPageIndex,
        hasMore: _controller.hasMoreLibraryItems,
        hasConfiguredDirectory: _controller.hasConfiguredDirectory,
        hasConfiguredAggregatedSources:
            _controller.hasConfiguredAggregatedSources,
        isScanning: _controller.isScanningLibrary,
        isLoadingPage: _controller.isLoadingLibraryPage,
        scanErrorMessage: _controller.libraryScanErrorMessage,
        loadMoreErrorMessage: _controller.libraryLoadMoreErrorMessage,
      ),
      playback: SongBookPlaybackViewModel(queuedSongs: _controller.queuedSongs),
    );
  }

  SongBookCallbacks _buildSongBookCallbacks() {
    return SongBookCallbacks(
      navigation: SongBookNavigationCallbacks(
        onBackPressed: _returnHome,
        onQueuePressed: _enterQueueList,
        onSelectArtist: _controller.selectArtist,
        onSettingsPressed: _openSettingsPage,
      ),
      library: SongBookLibraryCallbacks(
        onLanguageSelected: _selectLanguage,
        onAppendSearchToken: _appendSearchToken,
        onRemoveSearchCharacter: _removeSearchCharacter,
        onClearSearch: _clearSearch,
        onLoadMore: _loadMoreLibraryItems,
        onRequestSong: _requestSong,
        onToggleFavorite: _toggleFavorite,
        onDownloadSong: _downloadSong,
      ),
      playback: SongBookPlaybackCallbacks(
        onPrioritizeQueuedSong: _controller.prioritizeQueuedSong,
        onRemoveQueuedSong: _controller.removeQueuedSong,
        onToggleAudioMode: _toggleAudioMode,
        onTogglePlayback: _togglePlayback,
        onRestartPlayback: _restartPlayback,
        onSkipSong: _skipCurrentSong,
      ),
    );
  }

  Widget _buildPreviewSurface() {
    return _previewCoordinator.sharedPreviewSurface;
  }

  Widget _buildPreviewPlaceholder() {
    return _controller.route == KtvRoute.home
        ? const HomePreviewPlaceholder()
        : const SongPreviewPlaceholder();
  }

  Widget _buildWideHomeLayout({
    required double sidePanelWidth,
    required double columnGap,
    required bool compactHomePage,
  }) {
    return LandscapeHomePage(
      controller: _controller.playerController,
      queueCount: _controller.queuedSongs.length,
      previewAnchorKey: _previewCoordinator.previewAnchorKey,
      onEnterAllSongsBook: _enterAllSongsBook,
      onEnterLocalSongBook: _enterLocalSongBook,
      onEnterFavoritesBook: _enterFavoritesBook,
      onEnterFrequentBook: _enterFrequentBook,
      onEnterArtistBook: _enterArtistBook,
      onQueuePressed: _enterQueueList,
      onSettingsPressed: _openSettingsPage,
      onToggleAudioMode: _toggleAudioMode,
      onTogglePlayback: _togglePlayback,
      onRestartPlayback: _restartPlayback,
      onSkipSong: _skipCurrentSong,
    );
  }

  Widget _buildWideSongBookLayout({
    required SongBookViewModel viewModel,
    required SongBookCallbacks callbacks,
    required double sidePanelWidth,
    required double columnGap,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SizedBox(
          width: sidePanelWidth,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              HomePreviewCard(
                controller: _controller.playerController,
                previewSurface: _buildPreviewPlaceholder(),
                previewAnchorKey: _previewCoordinator.previewAnchorKey,
              ),
              const SizedBox(height: 6),
              SongBookLeftColumn(
                controller: _controller.playerController,
                searchController: _searchCoordinator.controller,
                route: _controller.route,
                songBookMode: _controller.songBookMode,
                selectedArtist: _controller.selectedArtist,
                showLetterKeyboard: true,
                onAppendSearchToken: _appendSearchToken,
                onRemoveSearchCharacter: _removeSearchCharacter,
                onClearSearch: _clearSearch,
              ),
            ],
          ),
        ),
        SizedBox(width: columnGap),
        Expanded(
          child: SongBookRightColumn(
            controller: _controller.playerController,
            viewModel: viewModel,
            callbacks: callbacks,
          ),
        ),
      ],
    );
  }

  Widget _buildCompactRouteLayout() {
    final SongBookViewModel viewModel = _buildSongBookViewModel();
    final SongBookCallbacks callbacks = _buildSongBookCallbacks();
    final bool isHome = _controller.route == KtvRoute.home;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        HomePreviewCard(
          controller: _controller.playerController,
          previewSurface: _buildPreviewPlaceholder(),
          compact: true,
          previewAnchorKey: _previewCoordinator.previewAnchorKey,
        ),
        const SizedBox(height: 16),
        if (isHome)
          HomePage(
            controller: _controller.playerController,
            compact: true,
            queueCount: _controller.queuedSongs.length,
            onEnterAllSongsBook: _enterAllSongsBook,
            onEnterLocalSongBook: _enterLocalSongBook,
            onEnterFavoritesBook: _enterFavoritesBook,
            onEnterFrequentBook: _enterFrequentBook,
            onEnterArtistBook: _enterArtistBook,
            onQueuePressed: _enterQueueList,
            onSettingsPressed: _openSettingsPage,
            onToggleAudioMode: _toggleAudioMode,
            onTogglePlayback: _togglePlayback,
            onRestartPlayback: _restartPlayback,
            onSkipSong: _skipCurrentSong,
          )
        else
          Expanded(
            child: SongBookPage(
              controller: _controller.playerController,
              compact: false,
              searchController: _searchCoordinator.controller,
              viewModel: viewModel,
              callbacks: callbacks,
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[
        _controller,
        _previewCoordinator,
      ]),
      builder: (BuildContext context, Widget? child) {
        _searchCoordinator.syncFromQuery(_controller.searchQuery);
        final SongBookViewModel songBookViewModel = _buildSongBookViewModel();
        final SongBookCallbacks songBookCallbacks = _buildSongBookCallbacks();
        _previewCoordinator.schedulePreviewViewportSync();
        return PopScope<void>(
          canPop:
              !_previewCoordinator.isPreviewFullscreen &&
              !_controller.canNavigateBack,
          onPopInvokedWithResult: (bool didPop, void result) {
            if (didPop) {
              return;
            }
            if (_previewCoordinator.isPreviewFullscreen) {
              _exitPreviewFullscreen();
              return;
            }
            unawaited(_handleNavigateBack());
          },
          child: Scaffold(
            body: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Color(0xFF150028),
                    Color(0xFF090014),
                    Color(0xFF05000C),
                  ],
                ),
              ),
              child: Stack(
                key: _previewCoordinator.shellStackKey,
                fit: StackFit.expand,
                children: <Widget>[
                  const KtvAtmosphereBackground(),
                  SafeArea(
                    minimum: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                    child: LayoutBuilder(
                      builder:
                          (BuildContext context, BoxConstraints constraints) {
                            final Orientation orientation =
                                MediaQuery.orientationOf(context);
                            final bool isLandscape =
                                orientation == Orientation.landscape;
                            _previewCoordinator
                                .syncSystemStatusBarForOrientation(orientation);
                            final bool useWideLayout =
                                isLandscape || constraints.maxWidth >= 860;
                            final bool useLandscapeSongBookLayout =
                                isLandscape &&
                                _controller.route != KtvRoute.home;
                            final double columnGap = constraints.maxWidth < 760
                                ? 16
                                : 28;
                            final double shellMaxWidth =
                                useLandscapeSongBookLayout
                                ? _landscapeSongBookShellMaxWidth
                                : _wideShellMaxWidth;
                            final double effectiveShellWidth = math.min(
                              constraints.maxWidth,
                              shellMaxWidth,
                            );
                            final double candidateSidePanelWidth =
                                (effectiveShellWidth * 0.36)
                                    .clamp(220.0, 304.0)
                                    .toDouble();
                            final double maxAllowedSidePanelWidth = math.max(
                              180,
                              effectiveShellWidth - columnGap - 260,
                            );
                            final _WidePanelLayout wideSongBookPanelLayout =
                                _resolveWideSongBookPanelLayout(
                                  availableWidth: effectiveShellWidth,
                                  columnGap: columnGap,
                                );
                            final double sidePanelWidth =
                                useLandscapeSongBookLayout
                                ? wideSongBookPanelLayout.leftWidth
                                : math.min(
                                    candidateSidePanelWidth,
                                    maxAllowedSidePanelWidth,
                                  );
                            final double rightPanelWidth =
                                useLandscapeSongBookLayout
                                ? wideSongBookPanelLayout.rightWidth
                                : effectiveShellWidth -
                                      sidePanelWidth -
                                      columnGap;
                            final bool compactWideHomePage =
                                rightPanelWidth < 520;
                            final double minContentHeight = math.max(
                              0,
                              constraints.maxHeight - 158,
                            );
                            final Widget constrainedShell = ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: shellMaxWidth,
                              ),
                              child: GradientShell(
                                padding: EdgeInsets.zero,
                                child: useWideLayout
                                    ? _controller.route == KtvRoute.home
                                          ? _buildWideHomeLayout(
                                              sidePanelWidth: sidePanelWidth,
                                              columnGap: columnGap,
                                              compactHomePage:
                                                  compactWideHomePage,
                                            )
                                          : _buildWideSongBookLayout(
                                              viewModel: songBookViewModel,
                                              callbacks: songBookCallbacks,
                                              sidePanelWidth: sidePanelWidth,
                                              columnGap: columnGap,
                                            )
                                    : _buildCompactRouteLayout(),
                              ),
                            );
                            final bool shouldUseCompactScroll =
                                !useWideLayout &&
                                _controller.route == KtvRoute.home;
                            final bool shouldUseCompactFillLayout =
                                !useWideLayout &&
                                _controller.route != KtvRoute.home;
                            final Widget routeShell = useWideLayout
                                ? Center(child: constrainedShell)
                                : Align(
                                    alignment: Alignment.topCenter,
                                    child: shouldUseCompactFillLayout
                                        ? SizedBox(
                                            width: math.min(
                                              constraints.maxWidth,
                                              _wideShellMaxWidth,
                                            ),
                                            height: constraints.maxHeight,
                                            child: constrainedShell,
                                          )
                                        : constrainedShell,
                                  );
                            return Column(
                              children: <Widget>[
                                Expanded(
                                  child: useWideLayout
                                      ? routeShell
                                      : shouldUseCompactScroll
                                      ? SingleChildScrollView(
                                          child: ConstrainedBox(
                                            constraints: BoxConstraints(
                                              minHeight: minContentHeight,
                                            ),
                                            child: routeShell,
                                          ),
                                        )
                                      : routeShell,
                                ),
                              ],
                            );
                          },
                    ),
                  ),
                  if (_previewCoordinator.isPreviewFullscreen)
                    const Positioned.fill(
                      child: ColoredBox(color: Colors.black),
                    ),
                  if (_previewCoordinator.previewViewportRect != null)
                    PreviewViewportHost(
                      controller: _controller.playerController,
                      previewSurface: _buildPreviewSurface(),
                      rect: _previewCoordinator.previewViewportRect!,
                      isFullscreen: _previewCoordinator.isPreviewFullscreen,
                      onEnterFullscreen: _enterPreviewFullscreen,
                      onBackToSongBook: _handleBackToSongBookFromFullscreen,
                      onToggleAudioMode: _toggleAudioMode,
                      onTogglePlayback: _togglePlayback,
                      onRestartPlayback: _restartPlayback,
                      onSkipSong: _skipCurrentSong,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

_WidePanelLayout _resolveWideSongBookPanelLayout({
  required double availableWidth,
  required double columnGap,
}) {
  final double contentWidth = math.max(0, availableWidth - columnGap);
  double leftWidth = (contentWidth * 0.34).clamp(260.0, 460.0).toDouble();
  double rightWidth = math.max(0, contentWidth - leftWidth);

  if (rightWidth > 760) {
    rightWidth = 760;
    leftWidth = math.max(0, contentWidth - rightWidth);
  }

  if (leftWidth > 460) {
    leftWidth = 460;
    rightWidth = math.max(0, contentWidth - leftWidth);
  }

  return _WidePanelLayout(leftWidth: leftWidth, rightWidth: rightWidth);
}

class _WidePanelLayout {
  const _WidePanelLayout({required this.leftWidth, required this.rightWidth});

  final double leftWidth;
  final double rightWidth;
}
