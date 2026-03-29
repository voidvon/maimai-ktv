import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
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

const List<List<String>> _letterKeyboardRows = <List<String>>[
  <String>['A', 'B', 'C', 'D', 'E', 'F', 'G'],
  <String>['H', 'I', 'J', 'K', 'L', 'M', 'N'],
  <String>['O', 'P', 'Q', 'R', 'S', 'T', 'U'],
  <String>['V', 'W', 'X', 'Y', 'Z', '123'],
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _searchController.addListener(_handleSearchChanged);
    unawaited(_demoController.initialize());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController
      ..removeListener(_handleSearchChanged)
      ..dispose();
    _demoController.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _demoController,
      builder: (BuildContext context, Widget? child) {
        return Scaffold(
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
              fit: StackFit.expand,
              children: <Widget>[
                const _KtvAtmosphereBackground(),
                SafeArea(
                  minimum: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  child: LayoutBuilder(
                    builder: (BuildContext context, BoxConstraints constraints) {
                      final double minContentHeight = math.max(
                        0,
                        constraints.maxHeight - 158,
                      );
                      return Column(
                        children: <Widget>[
                          Expanded(
                            child: SingleChildScrollView(
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minHeight: minContentHeight,
                                ),
                                child: Center(
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 980,
                                    ),
                                    child: AnimatedSwitcher(
                                      duration: const Duration(
                                        milliseconds: 320,
                                      ),
                                      switchInCurve: Curves.easeOutCubic,
                                      switchOutCurve: Curves.easeInCubic,
                                      child:
                                          _demoController.route ==
                                              DemoRoute.home
                                          ? _HomePage(
                                              key: const ValueKey<String>(
                                                'home',
                                              ),
                                              controller: _demoController
                                                  .playerController,
                                              queueCount: _demoController
                                                  .queuedSongs
                                                  .length,
                                              currentTitle:
                                                  _demoController.currentTitle,
                                              currentSubtitle: _demoController
                                                  .currentSubtitle,
                                              onEnterSongBook: _enterSongBook,
                                              onSettingsPressed:
                                                  _openSettingsPage,
                                              onToggleAudioMode:
                                                  _toggleAudioMode,
                                              onTogglePlayback: _togglePlayback,
                                            )
                                          : _SongBookPage(
                                              key: const ValueKey<String>(
                                                'song_book',
                                              ),
                                              controller: _demoController
                                                  .playerController,
                                              searchController:
                                                  _searchController,
                                              selectedLanguage: _demoController
                                                  .selectedLanguage,
                                              songs:
                                                  _demoController.filteredSongs,
                                              hasConfiguredDirectory:
                                                  _demoController
                                                      .hasConfiguredDirectory,
                                              isScanningLibrary: _demoController
                                                  .isScanningLibrary,
                                              libraryScanErrorMessage:
                                                  _demoController
                                                      .libraryScanErrorMessage,
                                              queuedSongs:
                                                  _demoController.queuedSongs,
                                              onBackPressed: _returnHome,
                                              onLanguageSelected:
                                                  _selectLanguage,
                                              onAppendSearchToken:
                                                  _appendSearchToken,
                                              onRemoveSearchCharacter:
                                                  _removeSearchCharacter,
                                              onClearSearch: _clearSearch,
                                              onPlaySong: _playSong,
                                              onSettingsPressed:
                                                  _openSettingsPage,
                                              onToggleAudioMode:
                                                  _toggleAudioMode,
                                              onTogglePlayback: _togglePlayback,
                                              onRestartPlayback:
                                                  _restartPlayback,
                                            ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
