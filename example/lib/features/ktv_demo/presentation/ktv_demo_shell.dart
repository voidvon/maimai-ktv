import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:ktv2/ktv2.dart';

import '../../../core/models/demo_song.dart';
import '../../settings/presentation/settings_page.dart';
import '../application/ktv_demo_controller.dart';

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

class _KtvDemoShellState extends State<KtvDemoShell> {
  final KtvDemoController _demoController = KtvDemoController();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearchChanged);
    unawaited(_demoController.initialize());
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_handleSearchChanged)
      ..dispose();
    _demoController.dispose();
    super.dispose();
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

class _HomePage extends StatelessWidget {
  const _HomePage({
    super.key,
    required this.controller,
    required this.queueCount,
    required this.currentTitle,
    required this.currentSubtitle,
    required this.onEnterSongBook,
    required this.onSettingsPressed,
    required this.onToggleAudioMode,
    required this.onTogglePlayback,
  });

  final PlayerController controller;
  final int queueCount;
  final String currentTitle;
  final String currentSubtitle;
  final VoidCallback onEnterSongBook;
  final VoidCallback onSettingsPressed;
  final VoidCallback onToggleAudioMode;
  final VoidCallback onTogglePlayback;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool compact = constraints.maxWidth < 860;
        final Widget content = _GradientShell(
          padding: compact
              ? const EdgeInsets.all(16)
              : const EdgeInsets.fromLTRB(18, 12, 18, 16),
          compact: compact,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _HomeToolbar(
                controller: controller,
                queueCount: queueCount,
                compact: compact,
                onQueuePressed: onEnterSongBook,
                onSettingsPressed: onSettingsPressed,
                onToggleAudioMode: onToggleAudioMode,
                onTogglePlayback: onTogglePlayback,
              ),
              SizedBox(height: compact ? 16 : 18),
              if (compact) ...<Widget>[
                _HomePreviewCard(
                  controller: controller,
                  title: currentTitle,
                  subtitle: currentSubtitle,
                  compact: true,
                ),
                const SizedBox(height: 16),
                _HomeShortcutGrid(
                  onEnterSongBook: onEnterSongBook,
                  compact: true,
                ),
              ] else
                Expanded(
                  child: Row(
                    children: <Widget>[
                      const SizedBox(width: 48),
                      Expanded(
                        flex: 384,
                        child: _HomePreviewCard(
                          controller: controller,
                          title: currentTitle,
                          subtitle: currentSubtitle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 324,
                        child: _HomeShortcutGrid(
                          onEnterSongBook: onEnterSongBook,
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
            ],
          ),
        );

        if (compact) {
          return content;
        }

        return AspectRatio(aspectRatio: 852 / 393, child: content);
      },
    );
  }
}

class _SongBookPage extends StatelessWidget {
  const _SongBookPage({
    super.key,
    required this.controller,
    required this.searchController,
    required this.selectedLanguage,
    required this.songs,
    required this.hasConfiguredDirectory,
    required this.isScanningLibrary,
    required this.libraryScanErrorMessage,
    required this.queuedSongs,
    required this.onBackPressed,
    required this.onLanguageSelected,
    required this.onAppendSearchToken,
    required this.onRemoveSearchCharacter,
    required this.onClearSearch,
    required this.onPlaySong,
    required this.onSettingsPressed,
    required this.onToggleAudioMode,
    required this.onTogglePlayback,
    required this.onRestartPlayback,
  });

  final PlayerController controller;
  final TextEditingController searchController;
  final String selectedLanguage;
  final List<DemoSong> songs;
  final bool hasConfiguredDirectory;
  final bool isScanningLibrary;
  final String? libraryScanErrorMessage;
  final List<DemoSong> queuedSongs;
  final VoidCallback onBackPressed;
  final ValueChanged<String> onLanguageSelected;
  final ValueChanged<String> onAppendSearchToken;
  final VoidCallback onRemoveSearchCharacter;
  final VoidCallback onClearSearch;
  final ValueChanged<DemoSong> onPlaySong;
  final VoidCallback onSettingsPressed;
  final VoidCallback onToggleAudioMode;
  final VoidCallback onTogglePlayback;
  final VoidCallback onRestartPlayback;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool compact = constraints.maxWidth < 860;
        final Widget content = _GradientShell(
          padding: compact
              ? const EdgeInsets.all(18)
              : const EdgeInsets.fromLTRB(56, 22, 28, 18),
          compact: compact,
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _SongBookLeftColumn(
                      controller: controller,
                      searchController: searchController,
                      compact: true,
                      onAppendSearchToken: onAppendSearchToken,
                      onRemoveSearchCharacter: onRemoveSearchCharacter,
                      onClearSearch: onClearSearch,
                    ),
                    const SizedBox(height: 20),
                    _SongBookRightColumn(
                      controller: controller,
                      compact: true,
                      selectedLanguage: selectedLanguage,
                      songs: songs,
                      hasConfiguredDirectory: hasConfiguredDirectory,
                      isScanningLibrary: isScanningLibrary,
                      libraryScanErrorMessage: libraryScanErrorMessage,
                      queuedSongs: queuedSongs,
                      onBackPressed: onBackPressed,
                      onLanguageSelected: onLanguageSelected,
                      onPlaySong: onPlaySong,
                      onSettingsPressed: onSettingsPressed,
                      onToggleAudioMode: onToggleAudioMode,
                      onTogglePlayback: onTogglePlayback,
                      onRestartPlayback: onRestartPlayback,
                    ),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    SizedBox(
                      width: 304,
                      child: _SongBookLeftColumn(
                        controller: controller,
                        searchController: searchController,
                        onAppendSearchToken: onAppendSearchToken,
                        onRemoveSearchCharacter: onRemoveSearchCharacter,
                        onClearSearch: onClearSearch,
                      ),
                    ),
                    const SizedBox(width: 28),
                    Expanded(
                      child: _SongBookRightColumn(
                        controller: controller,
                        selectedLanguage: selectedLanguage,
                        songs: songs,
                        hasConfiguredDirectory: hasConfiguredDirectory,
                        isScanningLibrary: isScanningLibrary,
                        libraryScanErrorMessage: libraryScanErrorMessage,
                        queuedSongs: queuedSongs,
                        onBackPressed: onBackPressed,
                        onLanguageSelected: onLanguageSelected,
                        onPlaySong: onPlaySong,
                        onSettingsPressed: onSettingsPressed,
                        onToggleAudioMode: onToggleAudioMode,
                        onTogglePlayback: onTogglePlayback,
                        onRestartPlayback: onRestartPlayback,
                      ),
                    ),
                  ],
                ),
        );

        if (compact) {
          return content;
        }

        return AspectRatio(aspectRatio: 852 / 393, child: content);
      },
    );
  }
}

class _GradientShell extends StatelessWidget {
  const _GradientShell({
    required this.child,
    required this.padding,
    required this.compact,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFF23004F),
            Color(0xFF4A0A99),
            Color(0xFF2B005A),
            Color(0xFF30006B),
            Color(0xFF6820D9),
            Color(0xFF461094),
            Color(0xFF16012D),
            Color(0xFF3B1177),
            Color(0xFF25024A),
          ],
          stops: <double>[0.0, 0.12, 0.24, 0.36, 0.48, 0.6, 0.74, 0.86, 1.0],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(
              0xFF090012,
            ).withValues(alpha: compact ? 0.25 : 0.28),
            blurRadius: compact ? 28 : 32,
            offset: Offset(0, compact ? 18 : 20),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class _HomeToolbar extends StatelessWidget {
  const _HomeToolbar({
    required this.controller,
    required this.queueCount,
    required this.compact,
    required this.onQueuePressed,
    required this.onSettingsPressed,
    required this.onToggleAudioMode,
    required this.onTogglePlayback,
  });

  final PlayerController controller;
  final int queueCount;
  final bool compact;
  final VoidCallback onQueuePressed;
  final VoidCallback onSettingsPressed;
  final VoidCallback onToggleAudioMode;
  final VoidCallback onTogglePlayback;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, Widget? child) {
        final List<Widget> actions = <Widget>[
          const _ToolbarPill(label: '搜索', enabled: false),
          _ToolbarPill(label: '已点$queueCount', onPressed: onQueuePressed),
          _ToolbarPill(
            label: controller.audioOutputMode == AudioOutputMode.accompaniment
                ? '原唱'
                : '伴唱',
            onPressed: controller.hasMedia ? onToggleAudioMode : null,
          ),
          const _ToolbarPill(label: '切歌', enabled: false),
          _ToolbarPill(
            label: controller.isPlaying ? '暂停' : '播放',
            onPressed: controller.hasMedia ? onTogglePlayback : null,
          ),
          _ToolbarPill(label: '设置', onPressed: onSettingsPressed),
        ];

        return Container(
          constraints: BoxConstraints(minHeight: compact ? 0 : 40),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0x14FFFFFF),
            borderRadius: BorderRadius.circular(20),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x66120023),
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      '金调KTV',
                      style: TextStyle(
                        color: Color(0xFFFFD85E),
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        alignment: WrapAlignment.end,
                        children: actions,
                      ),
                    ),
                  ],
                )
              : Row(
                  children: <Widget>[
                    const Text(
                      '金调KTV',
                      style: TextStyle(
                        color: Color(0xFFFFD85E),
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Wrap(spacing: 6, children: actions),
                  ],
                ),
        );
      },
    );
  }
}

class _ToolbarPill extends StatelessWidget {
  const _ToolbarPill({
    required this.label,
    this.onPressed,
    this.enabled = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final bool isEnabled = enabled && onPressed != null;
    return Material(
      color: isEnabled ? const Color(0x1AFFFFFF) : const Color(0x0DFFFFFF),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: isEnabled ? onPressed : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isEnabled
                  ? const Color(0xFFFFF7FF)
                  : const Color(0xFFA99ABF),
            ),
          ),
        ),
      ),
    );
  }
}

class _HomePreviewCard extends StatelessWidget {
  const _HomePreviewCard({
    required this.controller,
    required this.title,
    required this.subtitle,
    this.compact = false,
  });

  final PlayerController controller;
  final String title;
  final String subtitle;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, Widget? child) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                DecoratedBox(
                  decoration: const BoxDecoration(
                    border: Border.fromBorderSide(
                      BorderSide(color: Color(0x1FFFFFFF)),
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: Color(0x87090012),
                        blurRadius: 24,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: KtvPlayerView(
                    controller: controller,
                    placeholder: const _HomePreviewPlaceholder(),
                    backgroundColor: const Color(0xFF0A0018),
                  ),
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[
                        Color(0x0D000000),
                        Color(0x24000000),
                        Color(0x47000000),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: compact ? 12 : 16,
                  top: compact ? 12 : 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: const BoxDecoration(
                      color: Color(0x1FFFFFFF),
                      borderRadius: BorderRadius.all(Radius.circular(999)),
                    ),
                    child: const Text(
                      '等待点唱',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFFFF7FF),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: compact ? 12 : 16,
                  right: compact ? 12 : 16,
                  bottom: compact ? 12 : 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xCCF3DAFF),
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _PlayerProgressTrack(
                        controller: controller,
                        thickness: 6,
                        barHeight: compact ? 30 : 34,
                      ),
                    ],
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

class _HomePreviewPlaceholder extends StatelessWidget {
  const _HomePreviewPlaceholder();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFF18052C),
            Color(0xFF320B58),
            Color(0xFF0D0D2C),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const <Widget>[
            Icon(Icons.music_video_rounded, size: 54, color: Color(0xB3FFFFFF)),
            SizedBox(height: 12),
            Text(
              '首页预览区',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 6),
            Text('常驻播放器会复用同一套控制器。', style: TextStyle(color: Color(0xCCF3DAFF))),
          ],
        ),
      ),
    );
  }
}

class _HomeShortcutGrid extends StatelessWidget {
  const _HomeShortcutGrid({
    required this.onEnterSongBook,
    this.compact = false,
  });

  final VoidCallback onEnterSongBook;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: _homeShortcuts.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: compact ? 2.25 : 156 / 54,
      ),
      itemBuilder: (BuildContext context, int index) {
        final _HomeShortcut shortcut = _homeShortcuts[index];
        return _ShortcutCard(
          shortcut: shortcut,
          onTap: shortcut.enabled ? onEnterSongBook : null,
        );
      },
    );
  }
}

class _ShortcutCard extends StatelessWidget {
  const _ShortcutCard({required this.shortcut, this.onTap});

  final _HomeShortcut shortcut;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bool enabled = shortcut.enabled && onTap != null;
    return Opacity(
      opacity: enabled ? 1 : 0.56,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: enabled ? onTap : null,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: shortcut.colors,
              ),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0x4F1B024D),
                  blurRadius: 20,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: <Widget>[
                  Icon(shortcut.icon, color: const Color(0xCCFFFFFF), size: 24),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      shortcut.label,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFFFF9FF),
                      ),
                    ),
                  ),
                  if (enabled)
                    const Icon(
                      Icons.arrow_forward_rounded,
                      color: Color(0xCCFFFFFF),
                      size: 20,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SongBookLeftColumn extends StatelessWidget {
  const _SongBookLeftColumn({
    required this.controller,
    required this.searchController,
    required this.onAppendSearchToken,
    required this.onRemoveSearchCharacter,
    required this.onClearSearch,
    this.compact = false,
  });

  final PlayerController controller;
  final TextEditingController searchController;
  final ValueChanged<String> onAppendSearchToken;
  final VoidCallback onRemoveSearchCharacter;
  final VoidCallback onClearSearch;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SizedBox(height: compact ? 6 : 10),
        _SongPreviewCard(controller: controller, compact: compact),
        SizedBox(height: compact ? 4 : 6),
        _SongBookSearchField(
          controller: searchController,
          onBackspacePressed: onRemoveSearchCharacter,
          onClearPressed: onClearSearch,
        ),
        SizedBox(height: compact ? 6 : 8),
        _LetterKeyboard(onKeyPressed: onAppendSearchToken),
      ],
    );
  }
}

class _SongPreviewCard extends StatelessWidget {
  const _SongPreviewCard({required this.controller, required this.compact});

  final PlayerController controller;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, Widget? child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(compact ? 12 : 4),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0x87111111)),
                        boxShadow: const <BoxShadow>[
                          BoxShadow(
                            color: Color(0x870A001E),
                            blurRadius: 18,
                            offset: Offset(0, 10),
                          ),
                        ],
                      ),
                      child: KtvPlayerView(
                        controller: controller,
                        backgroundColor: const Color(0xFF090013),
                        placeholder: const _SongPreviewPlaceholder(),
                      ),
                    ),
                    Positioned(
                      left: 10,
                      top: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: const BoxDecoration(
                          color: Color(0x1FFFFFFF),
                          borderRadius: BorderRadius.all(Radius.circular(999)),
                        ),
                        child: const Text(
                          '等待点唱',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 2),
            _PlayerProgressTrack(
              controller: controller,
              thickness: 6,
              barHeight: 8,
            ),
          ],
        );
      },
    );
  }
}

class _SongPreviewPlaceholder extends StatelessWidget {
  const _SongPreviewPlaceholder();

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
      child: Center(
        child: Icon(
          Icons.queue_music_rounded,
          size: 44,
          color: Color(0x99FFFFFF),
        ),
      ),
    );
  }
}

class _SongBookSearchField extends StatelessWidget {
  const _SongBookSearchField({
    required this.controller,
    required this.onBackspacePressed,
    required this.onClearPressed,
  });

  final TextEditingController controller;
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
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFFFFF7FF),
              ),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: '输入歌名 / 中文 / 拼音首字母',
                hintStyle: TextStyle(
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

class _LetterKeyboard extends StatelessWidget {
  const _LetterKeyboard({required this.onKeyPressed});

  final ValueChanged<String> onKeyPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: _letterKeyboardRows
          .map((List<String> row) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: row == _letterKeyboardRows.last ? 0 : 6,
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
                            onPressed: () => onKeyPressed(key.toLowerCase()),
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
                fontSize: label == '123' ? 10 : 12,
                fontWeight: label == '123' ? FontWeight.w700 : FontWeight.w600,
                color: const Color(0xD9FFF6FF),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SongBookRightColumn extends StatelessWidget {
  const _SongBookRightColumn({
    required this.controller,
    required this.selectedLanguage,
    required this.songs,
    required this.hasConfiguredDirectory,
    required this.isScanningLibrary,
    required this.libraryScanErrorMessage,
    required this.queuedSongs,
    required this.onBackPressed,
    required this.onLanguageSelected,
    required this.onPlaySong,
    required this.onSettingsPressed,
    required this.onToggleAudioMode,
    required this.onTogglePlayback,
    required this.onRestartPlayback,
    this.compact = false,
  });

  final PlayerController controller;
  final String selectedLanguage;
  final List<DemoSong> songs;
  final bool hasConfiguredDirectory;
  final bool isScanningLibrary;
  final String? libraryScanErrorMessage;
  final List<DemoSong> queuedSongs;
  final VoidCallback onBackPressed;
  final ValueChanged<String> onLanguageSelected;
  final ValueChanged<DemoSong> onPlaySong;
  final VoidCallback onSettingsPressed;
  final VoidCallback onToggleAudioMode;
  final VoidCallback onTogglePlayback;
  final VoidCallback onRestartPlayback;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final Widget libraryContent = !hasConfiguredDirectory
        ? const _EmptyContentCard(message: '请先在设置里选择扫描目录，扫描完成后这里会展示歌曲列表。')
        : isScanningLibrary
        ? const _EmptyContentCard(message: '正在扫描目录中的歌曲，请稍候。')
        : libraryScanErrorMessage != null
        ? _EmptyContentCard(message: libraryScanErrorMessage!)
        : songs.isEmpty
        ? const _EmptyContentCard(
            message: '当前目录下没有扫描到可播放歌曲，请确认目录中包含 mp4、dat 等媒体文件。',
          )
        : GridView.builder(
            shrinkWrap: compact,
            physics: compact
                ? const NeverScrollableScrollPhysics()
                : const ClampingScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 6,
              crossAxisSpacing: 12,
              childAspectRatio: 2.86,
            ),
            itemCount: songs.length,
            itemBuilder: (BuildContext context, int index) {
              final DemoSong song = songs[index];
              final bool isCurrent =
                  queuedSongs.isNotEmpty && queuedSongs.first == song;
              return _SongTile(
                song: song,
                isCurrent: isCurrent,
                onTap: () => onPlaySong(song),
              );
            },
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _SongBookActionRow(
          controller: controller,
          queueCount: queuedSongs.length,
          compact: compact,
          onSettingsPressed: onSettingsPressed,
          onToggleAudioMode: onToggleAudioMode,
          onTogglePlayback: onTogglePlayback,
          onRestartPlayback: onRestartPlayback,
        ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            const Expanded(
              child: Text(
                '‹ 主页 / 歌名',
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
              onPressed: onBackPressed,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: _languageTabs
              .map((String language) {
                final bool selected = language == selectedLanguage;
                return Material(
                  color: selected
                      ? const Color(0x14FFFFFF)
                      : const Color(0x0AFFFFFF),
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => onLanguageSelected(language),
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
                );
              })
              .toList(growable: false),
        ),
        const SizedBox(height: 12),
        if (compact) ...<Widget>[
          libraryContent,
          const SizedBox(height: 12),
          const _PaginationBar(),
        ] else
          Expanded(
            child: Column(
              children: <Widget>[
                Expanded(child: libraryContent),
                const SizedBox(height: 12),
                const _PaginationBar(),
              ],
            ),
          ),
      ],
    );
  }
}

class _SongBookActionRow extends StatelessWidget {
  const _SongBookActionRow({
    required this.controller,
    required this.queueCount,
    required this.compact,
    required this.onSettingsPressed,
    required this.onToggleAudioMode,
    required this.onTogglePlayback,
    required this.onRestartPlayback,
  });

  final PlayerController controller;
  final int queueCount;
  final bool compact;
  final VoidCallback onSettingsPressed;
  final VoidCallback onToggleAudioMode;
  final VoidCallback onTogglePlayback;
  final VoidCallback onRestartPlayback;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, Widget? child) {
        return Align(
          alignment: compact ? Alignment.centerLeft : Alignment.centerRight,
          child: Wrap(
            spacing: 4,
            runSpacing: 4,
            alignment: WrapAlignment.end,
            children: <Widget>[
              _ActionPill(
                label: '已点$queueCount',
                icon: Icons.queue_music_rounded,
              ),
              _ActionPill(
                label:
                    controller.audioOutputMode == AudioOutputMode.accompaniment
                    ? '原唱'
                    : '伴唱',
                icon: Icons.mic_rounded,
                onPressed: controller.hasMedia ? onToggleAudioMode : null,
              ),
              const _ActionPill(
                label: '切歌',
                icon: Icons.skip_next_rounded,
                enabled: false,
              ),
              _ActionPill(
                label: controller.isPlaying ? '暂停' : '播放',
                icon: controller.isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                onPressed: controller.hasMedia ? onTogglePlayback : null,
              ),
              _ActionPill(
                label: '重唱',
                icon: Icons.replay_rounded,
                onPressed: controller.hasMedia ? onRestartPlayback : null,
              ),
              _ActionPill(
                label: '设置',
                icon: Icons.settings_rounded,
                onPressed: onSettingsPressed,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ActionPill extends StatelessWidget {
  const _ActionPill({
    required this.label,
    required this.icon,
    this.onPressed,
    this.enabled = true,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final bool isEnabled = enabled && onPressed != null;
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
  const _SongTile({required this.song, required this.isCurrent, this.onTap});

  final DemoSong song;
  final bool isCurrent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Color backgroundColor = isCurrent
        ? const Color(0x29FFFFFF)
        : const Color(0x1AFFFFFF);
    final Color subtitleColor = isCurrent
        ? const Color(0xCCF3DAFF)
        : const Color(0xB8F3DAFF);

    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 5, 8, 5),
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
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        height: 1,
                        color: Color(0xEDFFF7FF),
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '${song.artist} · ${song.language}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 7,
                        fontWeight: FontWeight.w500,
                        height: 1,
                        color: subtitleColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                isCurrent ? '当前播放' : '播放',
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  color: isCurrent
                      ? const Color(0xFFFFD85E)
                      : const Color(0xB8FFF7FF),
                ),
              ),
            ],
          ),
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
  const _PaginationBar();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        children: const <Widget>[
          _PaginationButton(label: '上一页'),
          Text(
            '1/1',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Color(0xCCFFF2FF),
            ),
          ),
          _PaginationButton(label: '下一页'),
        ],
      ),
    );
  }
}

class _PaginationButton extends StatelessWidget {
  const _PaginationButton({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0x0DFFFFFF),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Color(0x7AFFF2FF),
        ),
      ),
    );
  }
}

class _PlayerProgressTrack extends StatelessWidget {
  const _PlayerProgressTrack({
    required this.controller,
    required this.thickness,
    required this.barHeight,
  });

  final PlayerController controller;
  final double thickness;
  final double barHeight;

  @override
  Widget build(BuildContext context) {
    final bool hasMedia =
        controller.hasMedia && controller.playbackDuration > Duration.zero;
    return SizedBox(
      height: barHeight,
      child: SliderTheme(
        data: SliderTheme.of(context).copyWith(
          trackHeight: thickness,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 0),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
          activeTrackColor: const Color(0xFFFF4D8D),
          inactiveTrackColor: const Color(0x33FFFFFF),
          overlayColor: const Color(0x29FF4D8D),
        ),
        child: Slider(
          padding: EdgeInsets.zero,
          value: hasMedia ? controller.playbackProgress : 0,
          onChanged: hasMedia ? controller.seekToProgress : null,
        ),
      ),
    );
  }
}

class _KtvAtmosphereBackground extends StatelessWidget {
  const _KtvAtmosphereBackground();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: const <Widget>[
          Positioned(
            left: -80,
            top: -120,
            child: _GlowOrb(size: 260, color: Color(0xFFAA4DFF)),
          ),
          Positioned(
            right: -60,
            top: 80,
            child: _GlowOrb(size: 220, color: Color(0xFFFF5A7A)),
          ),
          Positioned(
            left: 120,
            bottom: -100,
            child: _GlowOrb(size: 240, color: Color(0xFF3E7BFF)),
          ),
          Positioned(
            right: 80,
            bottom: 120,
            child: _GlowOrb(size: 180, color: Color(0xFFFFB245)),
          ),
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: <Color>[
            color.withValues(alpha: 0.28),
            color.withValues(alpha: 0.12),
            color.withValues(alpha: 0),
          ],
        ),
      ),
    );
  }
}

class _HomeShortcut {
  const _HomeShortcut({
    required this.label,
    required this.icon,
    required this.colors,
    this.enabled = false,
  });

  final String label;
  final IconData icon;
  final List<Color> colors;
  final bool enabled;
}
