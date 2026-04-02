import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/models/demo_song.dart';
import '../../settings/presentation/settings_page.dart';
import '../application/ktv_demo_controller.dart';
import 'home_page.dart';
import 'ktv_demo_preview_coordinator.dart';
import 'ktv_demo_search_coordinator.dart';
import 'shared_widgets.dart';
import 'songbook_contracts.dart';
import 'songbook_page.dart';

class KtvDemoShell extends StatefulWidget {
  const KtvDemoShell({super.key});

  @override
  State<KtvDemoShell> createState() => _KtvDemoShellState();
}

class _KtvDemoShellState extends State<KtvDemoShell>
    with WidgetsBindingObserver {
  final KtvDemoController _demoController = KtvDemoController();
  late final KtvDemoSearchCoordinator _searchCoordinator;
  late final KtvDemoPreviewCoordinator _previewCoordinator;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _searchCoordinator = KtvDemoSearchCoordinator(
      onQueryChanged: _demoController.setSearchQuery,
    );
    _previewCoordinator = KtvDemoPreviewCoordinator(
      controller: _demoController.playerController,
      routeResolver: () => _demoController.route,
    );
    unawaited(_demoController.initialize());
  }

  @override
  void dispose() {
    unawaited(_previewCoordinator.disposeCoordinator());
    WidgetsBinding.instance.removeObserver(this);
    _searchCoordinator.dispose();
    _previewCoordinator.dispose();
    _demoController.dispose();
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
      unawaited(_demoController.stopPlayback());
    }
  }

  Future<void> _openSettingsPage() async {
    final String? directory = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (BuildContext context) {
          return SettingsPage(
            mediaLibraryRepository: _demoController.mediaLibraryRepository,
            initialDirectoryPath: _demoController.scanDirectoryPath,
          );
        },
        fullscreenDialog: true,
      ),
    );

    if (!mounted || directory == null) {
      return;
    }

    await _demoController.handleSelectedDirectory(directory);
    _searchCoordinator.clear();
  }

  void _togglePlayback() {
    _demoController.togglePlayback();
  }

  void _toggleAudioMode() {
    _demoController.toggleAudioMode();
  }

  void _restartPlayback() {
    _demoController.restartPlayback();
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
    _demoController.enterSongBook(mode: _demoController.songBookMode);
    _exitPreviewFullscreen();
  }

  void _skipCurrentSong() {
    if (!_demoController.playerController.hasMedia &&
        _demoController.queuedSongs.isEmpty) {
      return;
    }
    unawaited(_demoController.skipCurrentSong());
  }

  void _enterSongBook() {
    _searchCoordinator.clear();
    _demoController.enterSongBook(mode: DemoSongBookMode.songs);
  }

  void _enterArtistBook() {
    _searchCoordinator.clear();
    _demoController.enterSongBook(mode: DemoSongBookMode.artists);
  }

  void _enterQueueList() {
    _searchCoordinator.clear();
    _demoController.enterQueueList();
  }

  void _returnHome() {
    unawaited(_handleNavigateBack());
  }

  Future<void> _handleNavigateBack() async {
    final bool didNavigate = await _demoController.navigateBack();
    if (didNavigate) {
      _searchCoordinator.clear();
    }
  }

  void _selectLanguage(String language) {
    _demoController.selectLanguage(language);
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
    return _demoController.requestLibraryPage(
      pageIndex: pageIndex,
      pageSize: pageSize,
    );
  }

  Future<void> _requestSong(DemoSong song) async {
    await _demoController.requestSong(song);
  }

  SongBookViewModel _buildSongBookViewModel() {
    return SongBookViewModel(
      navigation: SongBookNavigationViewModel(
        route: _demoController.route,
        songBookMode: _demoController.songBookMode,
        selectedArtist: _demoController.selectedArtist,
        breadcrumbLabel: _demoController.breadcrumbLabel,
      ),
      library: SongBookLibraryViewModel(
        searchQuery: _demoController.searchQuery,
        selectedLanguage: _demoController.selectedLanguage,
        songs: _demoController.filteredSongs,
        artists: _demoController.libraryArtists,
        totalCount: _demoController.libraryTotalCount,
        pageIndex: _demoController.libraryPageIndex,
        totalPages: _demoController.libraryTotalPages,
        pageSize: _demoController.libraryPageSize,
        hasConfiguredDirectory: _demoController.hasConfiguredDirectory,
        isScanning: _demoController.isScanningLibrary,
        isLoadingPage: _demoController.isLoadingLibraryPage,
        scanErrorMessage: _demoController.libraryScanErrorMessage,
      ),
      playback: SongBookPlaybackViewModel(
        queuedSongs: _demoController.queuedSongs,
      ),
    );
  }

  SongBookCallbacks _buildSongBookCallbacks() {
    return SongBookCallbacks(
      navigation: SongBookNavigationCallbacks(
        onBackPressed: _returnHome,
        onQueuePressed: _enterQueueList,
        onSelectArtist: _demoController.selectArtist,
        onSettingsPressed: _openSettingsPage,
      ),
      library: SongBookLibraryCallbacks(
        onLanguageSelected: _selectLanguage,
        onAppendSearchToken: _appendSearchToken,
        onRemoveSearchCharacter: _removeSearchCharacter,
        onClearSearch: _clearSearch,
        onRequestLibraryPage: _requestLibraryPage,
        onRequestSong: _requestSong,
      ),
      playback: SongBookPlaybackCallbacks(
        onPrioritizeQueuedSong: _demoController.prioritizeQueuedSong,
        onRemoveQueuedSong: _demoController.removeQueuedSong,
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
    return _demoController.route == DemoRoute.home
        ? const HomePreviewPlaceholder()
        : const SongPreviewPlaceholder();
  }

  Widget _buildWideHomeLayout({
    required double sidePanelWidth,
    required double columnGap,
    required bool compactHomePage,
  }) {
    return LandscapeHomePage(
      controller: _demoController.playerController,
      queueCount: _demoController.queuedSongs.length,
      previewAnchorKey: _previewCoordinator.previewAnchorKey,
      onEnterSongBook: _enterSongBook,
      onEnterArtistBook: _enterArtistBook,
      onQueuePressed: _enterQueueList,
      onSettingsPressed: _openSettingsPage,
      onToggleAudioMode: _toggleAudioMode,
      onTogglePlayback: _togglePlayback,
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
                controller: _demoController.playerController,
                previewSurface: _buildPreviewPlaceholder(),
                previewAnchorKey: _previewCoordinator.previewAnchorKey,
              ),
              const SizedBox(height: 6),
              SongBookLeftColumn(
                controller: _demoController.playerController,
                searchController: _searchCoordinator.controller,
                route: _demoController.route,
                songBookMode: _demoController.songBookMode,
                selectedArtist: _demoController.selectedArtist,
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
            controller: _demoController.playerController,
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
    final bool isHome = _demoController.route == DemoRoute.home;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        HomePreviewCard(
          controller: _demoController.playerController,
          previewSurface: _buildPreviewPlaceholder(),
          compact: true,
          previewAnchorKey: _previewCoordinator.previewAnchorKey,
        ),
        const SizedBox(height: 16),
        if (isHome)
          HomePage(
            controller: _demoController.playerController,
            compact: true,
            queueCount: _demoController.queuedSongs.length,
            onEnterSongBook: _enterSongBook,
            onEnterArtistBook: _enterArtistBook,
            onQueuePressed: _enterQueueList,
            onSettingsPressed: _openSettingsPage,
            onToggleAudioMode: _toggleAudioMode,
            onTogglePlayback: _togglePlayback,
            onSkipSong: _skipCurrentSong,
          )
        else
          Expanded(
            child: SongBookPage(
              controller: _demoController.playerController,
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
        _demoController,
        _previewCoordinator,
      ]),
      builder: (BuildContext context, Widget? child) {
        _searchCoordinator.syncFromQuery(_demoController.searchQuery);
        final SongBookViewModel songBookViewModel = _buildSongBookViewModel();
        final SongBookCallbacks songBookCallbacks = _buildSongBookCallbacks();
        _previewCoordinator.schedulePreviewViewportSync();
        return PopScope<void>(
          canPop:
              !_previewCoordinator.isPreviewFullscreen &&
              !_demoController.canNavigateBack,
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
                                    ? _demoController.route == DemoRoute.home
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
                                _demoController.route == DemoRoute.home;
                            final bool shouldUseCompactFillLayout =
                                !useWideLayout &&
                                _demoController.route != DemoRoute.home;
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
                      controller: _demoController.playerController,
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
