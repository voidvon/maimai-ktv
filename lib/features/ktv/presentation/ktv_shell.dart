import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;

import '../../../core/models/song.dart';
import '../../media_library/data/baidu_pan/baidu_pan_app_config.dart';
import '../../media_library/data/baidu_pan/baidu_pan_http_api_client.dart';
import '../../media_library/data/baidu_pan/baidu_pan_oauth_repository.dart';
import '../../media_library/data/baidu_pan/baidu_pan_song_download_service.dart';
import '../../media_library/data/baidu_pan/file_baidu_pan_auth_store.dart';
import '../../media_library/data/baidu_pan/file_baidu_pan_source_config_store.dart';
import '../../settings/application/baidu_pan_settings_controller.dart';
import '../../settings/application/settings_controller.dart';
import '../../settings/presentation/settings_page.dart';
import '../application/ktv_controller.dart';
import 'home_page.dart';
import 'ktv_preview_coordinator.dart';
import 'ktv_search_coordinator.dart';
import 'shared_widgets.dart';
import 'songbook_contracts.dart';
import 'songbook_page.dart';

class KtvShell extends StatefulWidget {
  const KtvShell({super.key, required this.controller});

  final KtvController controller;

  @override
  State<KtvShell> createState() => _KtvShellState();
}

class _KtvShellState extends State<KtvShell> with WidgetsBindingObserver {
  late final KtvController _controller;
  late final KtvSearchCoordinator _searchCoordinator;
  late final KtvPreviewCoordinator _previewCoordinator;

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
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      unawaited(_controller.stopPlayback());
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
    final SettingsPageResult? result = await Navigator.of(context)
        .push<SettingsPageResult>(
          MaterialPageRoute<SettingsPageResult>(
            builder: (BuildContext context) {
              return SettingsPage(
                controller: settingsController,
                baiduPanController: baiduPanController,
              );
            },
            fullscreenDialog: true,
          ),
        );
    settingsController.dispose();
    baiduPanController.dispose();

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
    unawaited(_previewCoordinator.enterPreviewFullscreen());
  }

  void _exitPreviewFullscreen() {
    unawaited(
      _previewCoordinator.exitPreviewFullscreen(
        restoredOrientation: mounted ? MediaQuery.orientationOf(context) : null,
      ),
    );
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

  Future<void> _requestLibraryPage(int pageIndex, int pageSize) {
    return _controller.requestLibraryPage(
      pageIndex: pageIndex,
      pageSize: pageSize,
    );
  }

  Future<void> _requestSong(Song song) async {
    await _controller.requestSong(song);
  }

  Future<void> _toggleFavorite(Song song) async {
    await _controller.toggleFavorite(song);
  }

  Future<void> _downloadSong(Song song) async {
    try {
      final BaiduPanDownloadResult result = await _controller
          .downloadSongToLocal(song);
      if (!mounted) {
        return;
      }
      final String fileName = path.basename(result.savedPath);
      final String label = result.usedPreferredDirectory
          ? '已下载到本地目录：$fileName'
          : '已下载到应用目录：$fileName';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(label)));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('下载失败：$error')));
    }
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
        downloadingSongIds: _controller.downloadingSongIds,
        downloadedSourceSongIds: _controller.downloadedSourceSongIds,
        totalCount: _controller.libraryTotalCount,
        pageIndex: _controller.libraryPageIndex,
        totalPages: _controller.libraryTotalPages,
        pageSize: _controller.libraryPageSize,
        hasConfiguredDirectory: _controller.hasConfiguredDirectory,
        hasConfiguredAggregatedSources:
            _controller.hasConfiguredAggregatedSources,
        isScanning: _controller.isScanningLibrary,
        isLoadingPage: _controller.isLoadingLibraryPage,
        scanErrorMessage: _controller.libraryScanErrorMessage,
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
        onRequestLibraryPage: _requestLibraryPage,
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
                            _previewCoordinator
                                .syncSystemStatusBarForOrientation(orientation);
                            final bool useWideLayout =
                                orientation == Orientation.landscape ||
                                constraints.maxWidth >= 860;
                            final double columnGap = constraints.maxWidth < 760
                                ? 16
                                : 28;
                            final double candidateSidePanelWidth =
                                (constraints.maxWidth * 0.36)
                                    .clamp(220.0, 304.0)
                                    .toDouble();
                            final double maxAllowedSidePanelWidth = math.max(
                              180,
                              constraints.maxWidth - columnGap - 260,
                            );
                            final double sidePanelWidth = math.min(
                              candidateSidePanelWidth,
                              maxAllowedSidePanelWidth,
                            );
                            final double rightPanelWidth =
                                constraints.maxWidth -
                                sidePanelWidth -
                                columnGap;
                            final bool compactWideHomePage =
                                rightPanelWidth < 520;
                            final double minContentHeight = math.max(
                              0,
                              constraints.maxHeight - 158,
                            );
                            final Widget constrainedShell = ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 980),
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
                                              980,
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
