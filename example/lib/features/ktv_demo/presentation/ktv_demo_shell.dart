import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ktv2/ktv2.dart';

import '../../../core/models/demo_song.dart';
import '../../settings/presentation/settings_page.dart';
import '../application/ktv_demo_controller.dart';

part 'home_page.dart';
part 'songbook_page.dart';
part 'shared_widgets.dart';

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
const MethodChannel _orientationChannel = MethodChannel(
  'ktv2_example/orientation',
);

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

const List<_HomeShortcut> _homeShortcuts = <_HomeShortcut>[
  _HomeShortcut(
    label: '排行榜',
    icon: Icons.star_rounded,
    colors: <Color>[Color(0xFFFF7C93), Color(0xFFFF5372), Color(0xFFFF9A7A)],
  ),
  _HomeShortcut(
    label: '歌名',
    icon: Icons.music_note_rounded,
    colors: <Color>[Color(0xFFFFD36A), Color(0xFFFFB245), Color(0xFFFF9566)],
    enabled: true,
  ),
  _HomeShortcut(
    label: '歌星',
    icon: Icons.person_rounded,
    colors: <Color>[Color(0xFF9CC9FF), Color(0xFF89B2FF), Color(0xFF9571FF)],
  ),
  _HomeShortcut(
    label: '本地',
    icon: Icons.library_music_rounded,
    colors: <Color>[Color(0xFF65D8FF), Color(0xFF2E9DFF)],
  ),
  _HomeShortcut(
    label: '收藏',
    icon: Icons.favorite_border_rounded,
    colors: <Color>[Color(0xFFF2AAFF), Color(0xFFC46BFF)],
  ),
  _HomeShortcut(
    label: '常唱',
    icon: Icons.mic_external_on_rounded,
    colors: <Color>[Color(0xFFFFB8A8), Color(0xFFFF8B78)],
  ),
];

class KtvDemoShell extends StatefulWidget {
  const KtvDemoShell({super.key});

  @override
  State<KtvDemoShell> createState() => _KtvDemoShellState();
}

class _KtvDemoShellState extends State<KtvDemoShell>
    with WidgetsBindingObserver {
  final KtvDemoController _demoController = KtvDemoController();
  final TextEditingController _searchController = TextEditingController();
  final GlobalKey _shellStackKey = GlobalKey();
  final GlobalKey _previewSurfaceKey = GlobalKey();
  final GlobalKey _previewAnchorKey = GlobalKey();
  late final Widget _sharedPreviewSurface;
  bool? _statusBarHiddenInLandscape;
  bool _isPreviewFullscreen = false;
  Rect? _previewViewportRect;
  bool _didSchedulePreviewViewportSync = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _searchController.addListener(_handleSearchChanged);
    _sharedPreviewSurface = _PersistentPreviewSurface(
      key: _previewSurfaceKey,
      controller: _demoController.playerController,
      routeResolver: () => _demoController.route,
    );
    unawaited(_demoController.initialize());
  }

  @override
  void dispose() {
    if (_isPreviewFullscreen || _statusBarHiddenInLandscape == true) {
      unawaited(SystemChrome.setPreferredOrientations(<DeviceOrientation>[]));
      unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    }
    WidgetsBinding.instance.removeObserver(this);
    _searchController
      ..removeListener(_handleSearchChanged)
      ..dispose();
    _demoController.dispose();
    super.dispose();
  }

  void _syncSystemStatusBarForOrientation(Orientation orientation) {
    if (_isPreviewFullscreen) {
      return;
    }
    final bool shouldHideStatusBar = orientation == Orientation.landscape;
    if (_statusBarHiddenInLandscape == shouldHideStatusBar) {
      return;
    }
    _statusBarHiddenInLandscape = shouldHideStatusBar;
    if (shouldHideStatusBar) {
      unawaited(
        SystemChrome.setEnabledSystemUIMode(
          SystemUiMode.manual,
          overlays: <SystemUiOverlay>[SystemUiOverlay.bottom],
        ),
      );
      return;
    }
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
  }

  @override
  void didChangeMetrics() {
    _schedulePreviewViewportSync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      unawaited(_demoController.stopPlayback());
    }
  }

  void _handleSearchChanged() {
    _demoController.setSearchQuery(_searchController.text);
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
    _searchController.clear();
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

  void _schedulePreviewViewportSync() {
    if (_didSchedulePreviewViewportSync) {
      return;
    }
    _didSchedulePreviewViewportSync = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _didSchedulePreviewViewportSync = false;
      _syncPreviewViewportRect();
    });
  }

  void _syncPreviewViewportRect() {
    final BuildContext? stackContext = _shellStackKey.currentContext;
    if (!mounted || stackContext == null) {
      return;
    }
    final RenderObject? stackRenderObject = stackContext.findRenderObject();
    if (stackRenderObject is! RenderBox) {
      return;
    }

    Rect? nextRect;
    if (_isPreviewFullscreen) {
      nextRect = _resolveFullscreenPreviewRect(stackRenderObject.size);
    } else {
      final BuildContext? anchorContext = _previewAnchorKey.currentContext;
      final RenderObject? anchorRenderObject = anchorContext
          ?.findRenderObject();
      if (anchorRenderObject is! RenderBox) {
        return;
      }
      final Offset topLeft = anchorRenderObject.localToGlobal(
        Offset.zero,
        ancestor: stackRenderObject,
      );
      nextRect = topLeft & anchorRenderObject.size;
    }

    if (_previewViewportRect == nextRect) {
      return;
    }
    setState(() => _previewViewportRect = nextRect);
  }

  Rect _resolveFullscreenPreviewRect(Size containerSize) {
    const double targetAspectRatio = 16 / 9;
    final double containerAspectRatio =
        containerSize.width / containerSize.height;

    if (containerAspectRatio > targetAspectRatio) {
      final double height = containerSize.height;
      final double width = height * targetAspectRatio;
      return Rect.fromLTWH((containerSize.width - width) / 2, 0, width, height);
    }

    final double width = containerSize.width;
    final double height = width / targetAspectRatio;
    return Rect.fromLTWH(0, (containerSize.height - height) / 2, width, height);
  }

  void _enterPreviewFullscreen() {
    unawaited(_setPreviewFullscreen(enabled: true));
  }

  void _exitPreviewFullscreen() {
    unawaited(_setPreviewFullscreen(enabled: false));
  }

  Future<void> _setPreviewFullscreen({required bool enabled}) async {
    if (_isPreviewFullscreen == enabled) {
      return;
    }
    setState(() {
      _isPreviewFullscreen = enabled;
      if (!enabled) {
        _statusBarHiddenInLandscape = null;
      }
    });
    _schedulePreviewViewportSync();

    if (enabled) {
      await _setPlatformFullscreenOrientation(enabled: true);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      return;
    }

    await _setPlatformFullscreenOrientation(enabled: false);
    await SystemChrome.setPreferredOrientations(<DeviceOrientation>[]);
    if (!mounted) {
      return;
    }
    _syncSystemStatusBarForOrientation(MediaQuery.orientationOf(context));
  }

  Future<void> _setPlatformFullscreenOrientation({
    required bool enabled,
  }) async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    try {
      await _orientationChannel.invokeMethod<void>(
        enabled ? 'enterVideoFullscreen' : 'exitVideoFullscreen',
      );
    } on MissingPluginException {
      // Android-only channel; fall back to SystemChrome when unavailable.
    } on PlatformException {
      // Keep fullscreen flow alive even if the platform request fails.
    }
  }

  void _handleBackToSongBookFromFullscreen() {
    _demoController.enterSongBook();
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
    _demoController.enterSongBook();
  }

  void _returnHome() {
    _demoController.returnHome();
  }

  void _selectLanguage(String language) {
    _demoController.selectLanguage(language);
  }

  void _appendSearchToken(String token) {
    final String nextText = '${_searchController.text}$token';
    _searchController.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: nextText.length),
    );
  }

  void _removeSearchCharacter() {
    if (_searchController.text.isEmpty) {
      return;
    }
    final String nextText = _searchController.text.substring(
      0,
      _searchController.text.length - 1,
    );
    _searchController.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: nextText.length),
    );
  }

  void _clearSearch() {
    if (_searchController.text.isEmpty) {
      return;
    }
    _searchController.clear();
  }

  Future<void> _playSong(DemoSong song) async {
    await _demoController.playSong(song);
  }

  Widget _buildPreviewSurface() {
    return _sharedPreviewSurface;
  }

  Widget _buildPreviewPlaceholder() {
    return _demoController.route == DemoRoute.home
        ? const _HomePreviewPlaceholder()
        : const _SongPreviewPlaceholder();
  }

  Widget _buildWideHomeLayout({
    required double sidePanelWidth,
    required double columnGap,
    required bool compactHomePage,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SizedBox(
          width: sidePanelWidth,
          child: _HomePreviewCard(
            controller: _demoController.playerController,
            previewSurface: _buildPreviewPlaceholder(),
            previewAnchorKey: _previewAnchorKey,
          ),
        ),
        SizedBox(width: columnGap),
        Expanded(
          child: _HomePage(
            controller: _demoController.playerController,
            compact: compactHomePage,
            queueCount: _demoController.queuedSongs.length,
            onEnterSongBook: _enterSongBook,
            onSettingsPressed: _openSettingsPage,
            onToggleAudioMode: _toggleAudioMode,
            onTogglePlayback: _togglePlayback,
          ),
        ),
      ],
    );
  }

  Widget _buildWideSongBookLayout({
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
              _HomePreviewCard(
                controller: _demoController.playerController,
                previewSurface: _buildPreviewPlaceholder(),
                previewAnchorKey: _previewAnchorKey,
              ),
              const SizedBox(height: 6),
              _SongBookLeftColumn(
                controller: _demoController.playerController,
                searchController: _searchController,
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
          child: _SongBookRightColumn(
            controller: _demoController.playerController,
            selectedLanguage: _demoController.selectedLanguage,
            songs: _demoController.filteredSongs,
            hasConfiguredDirectory: _demoController.hasConfiguredDirectory,
            isScanningLibrary: _demoController.isScanningLibrary,
            libraryScanErrorMessage: _demoController.libraryScanErrorMessage,
            queuedSongs: _demoController.queuedSongs,
            onBackPressed: _returnHome,
            onLanguageSelected: _selectLanguage,
            onPlaySong: _playSong,
            onSettingsPressed: _openSettingsPage,
            onToggleAudioMode: _toggleAudioMode,
            onTogglePlayback: _togglePlayback,
            onRestartPlayback: _restartPlayback,
          ),
        ),
      ],
    );
  }

  Widget _buildCompactRouteLayout() {
    final bool isHome = _demoController.route == DemoRoute.home;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _HomePreviewCard(
          controller: _demoController.playerController,
          previewSurface: _buildPreviewPlaceholder(),
          compact: true,
          previewAnchorKey: _previewAnchorKey,
        ),
        const SizedBox(height: 16),
        if (isHome)
          _HomePage(
            controller: _demoController.playerController,
            compact: true,
            queueCount: _demoController.queuedSongs.length,
            onEnterSongBook: _enterSongBook,
            onSettingsPressed: _openSettingsPage,
            onToggleAudioMode: _toggleAudioMode,
            onTogglePlayback: _togglePlayback,
          )
        else
          Expanded(
            child: _SongBookPage(
              controller: _demoController.playerController,
              compact: false,
              searchController: _searchController,
              selectedLanguage: _demoController.selectedLanguage,
              songs: _demoController.filteredSongs,
              hasConfiguredDirectory: _demoController.hasConfiguredDirectory,
              isScanningLibrary: _demoController.isScanningLibrary,
              libraryScanErrorMessage: _demoController.libraryScanErrorMessage,
              queuedSongs: _demoController.queuedSongs,
              onBackPressed: _returnHome,
              onLanguageSelected: _selectLanguage,
              onAppendSearchToken: _appendSearchToken,
              onRemoveSearchCharacter: _removeSearchCharacter,
              onClearSearch: _clearSearch,
              onPlaySong: _playSong,
              onSettingsPressed: _openSettingsPage,
              onToggleAudioMode: _toggleAudioMode,
              onTogglePlayback: _togglePlayback,
              onRestartPlayback: _restartPlayback,
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _demoController,
      builder: (BuildContext context, Widget? child) {
        _schedulePreviewViewportSync();
        return PopScope<void>(
          canPop: !_isPreviewFullscreen,
          onPopInvokedWithResult: (bool didPop, void result) {
            if (!didPop && _isPreviewFullscreen) {
              _exitPreviewFullscreen();
            }
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
                key: _shellStackKey,
                fit: StackFit.expand,
                children: <Widget>[
                  const _KtvAtmosphereBackground(),
                  SafeArea(
                    minimum: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                    child: LayoutBuilder(
                      builder:
                          (BuildContext context, BoxConstraints constraints) {
                            final Orientation orientation =
                                MediaQuery.orientationOf(context);
                            _syncSystemStatusBarForOrientation(orientation);
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
                              child: _GradientShell(
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
                  if (_isPreviewFullscreen)
                    const Positioned.fill(
                      child: ColoredBox(color: Colors.black),
                    ),
                  if (_previewViewportRect != null)
                    _PreviewViewportHost(
                      controller: _demoController.playerController,
                      previewSurface: _buildPreviewSurface(),
                      rect: _previewViewportRect!,
                      isFullscreen: _isPreviewFullscreen,
                      onEnterFullscreen: _enterPreviewFullscreen,
                      onBackToSongBook: _handleBackToSongBookFromFullscreen,
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
