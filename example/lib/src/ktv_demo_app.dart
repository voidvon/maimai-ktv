import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ktv2/ktv2.dart';

import 'demo_scan_directory_service.dart';
import 'demo_video_picker_service.dart';

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

const List<_DemoSong> _demoSongs = <_DemoSong>[
  _DemoSong('夜曲', '周杰伦', '国语', 'yequ zhoujielun'),
  _DemoSong('后来', '刘若英', '国语', 'houlai liuruoying'),
  _DemoSong('光辉岁月', 'Beyond', '粤语', 'guanghuisuiyue beyond'),
  _DemoSong('海阔天空', 'Beyond', '粤语', 'haikuotiankong beyond'),
  _DemoSong('爱拼才会赢', '叶启田', '闽南语', 'aipinca huiying yeqitian'),
  _DemoSong(
    'Yesterday Once More',
    'Carpenters',
    '英语',
    'yesterday once more carpenters',
  ),
  _DemoSong('Lemon', '米津玄师', '日语', 'lemon mizuxuanshi yonezu'),
  _DemoSong('Spring Day', 'BTS', '韩语', 'spring day bts'),
  _DemoSong('演员', '薛之谦', '国语', 'yanyuan xuezhiqian'),
  _DemoSong('小幸运', '田馥甄', '国语', 'xiaoxingyun hebe'),
  _DemoSong('红色高跟鞋', '蔡健雅', '国语', 'hongsegaogenxie caijianya'),
  _DemoSong('Sugar', 'Maroon 5', '英语', 'sugar maroon5'),
];

class KtvDemoApp extends StatelessWidget {
  const KtvDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFFFFD85E),
        secondary: Color(0xFFFF4D8D),
        surface: Color(0xFF16012D),
      ),
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '金调KTV Demo',
      theme: base.copyWith(
        scaffoldBackgroundColor: const Color(0xFF070012),
        textTheme: base.textTheme.apply(
          bodyColor: const Color(0xFFFFF7FF),
          displayColor: const Color(0xFFFFF7FF),
        ),
      ),
      home: const _KtvDemoShell(),
    );
  }
}

enum _DemoRoute { home, songBook }

class _KtvDemoShell extends StatefulWidget {
  const _KtvDemoShell();

  @override
  State<_KtvDemoShell> createState() => _KtvDemoShellState();
}

class _KtvDemoShellState extends State<_KtvDemoShell> {
  final PlayerController _controller = createPlayerController();
  final DemoVideoPickerService _videoPickerService = DemoVideoPickerService();
  final DemoScanDirectoryService _scanDirectoryService =
      DemoScanDirectoryService();
  final TextEditingController _searchController = TextEditingController();

  final List<_DemoSong> _queuedSongs = <_DemoSong>[];

  _DemoRoute _route = _DemoRoute.home;
  String _selectedLanguage = _languageTabs.first;
  String? _directoryPickerErrorMessage;
  String? _scanDirectoryPath;
  MediaSource? _selectedMedia;
  bool _isPickingVideo = false;
  bool _isPickingDirectory = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearchChanged);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_handleSearchChanged)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  List<_DemoSong> get _filteredSongs {
    final query = _searchController.text.trim().toLowerCase();
    return _demoSongs
        .where((_DemoSong song) {
          final languageMatches =
              _selectedLanguage == _languageTabs.first ||
              song.language == _selectedLanguage;
          if (!languageMatches) {
            return false;
          }
          if (query.isEmpty) {
            return true;
          }
          final haystack = '${song.title} ${song.artist} ${song.searchIndex}'
              .toLowerCase();
          return haystack.contains(query);
        })
        .toList(growable: false);
  }

  String get _currentTitle {
    if (_selectedMedia != null) {
      return _selectedMedia!.displayName;
    }
    if (_queuedSongs.isNotEmpty) {
      return _queuedSongs.first.title;
    }
    return '等待点唱';
  }

  String get _currentSubtitle {
    if (_queuedSongs.isNotEmpty) {
      return '${_queuedSongs.first.artist} · 已点 ${_queuedSongs.length} 首';
    }
    return '常驻播放器已接入，先从下方选择一个本地视频。';
  }

  void _handleSearchChanged() {
    setState(() {});
  }

  Future<void> _pickAndPlay() async {
    if (_isPickingVideo) {
      return;
    }

    setState(() {
      _isPickingVideo = true;
    });

    try {
      final MediaSource? source = await _videoPickerService.pickVideo();
      if (!mounted || source == null) {
        return;
      }

      await _controller.openMedia(source);
      if (!mounted) {
        return;
      }

      setState(() {
        _selectedMedia = source;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isPickingVideo = false;
        });
      }
    }
  }

  Future<void> _pickScanDirectory() async {
    if (_isPickingDirectory) {
      return;
    }

    setState(() {
      _isPickingDirectory = true;
      _directoryPickerErrorMessage = null;
    });

    try {
      final String? directory = await _scanDirectoryService.pickDirectory(
        initialDirectory: _scanDirectoryPath,
      );
      if (!mounted || directory == null) {
        return;
      }

      final bool hasAccess = await _scanDirectoryService.ensureDirectoryAccess(
        directory,
      );
      if (!mounted) {
        return;
      }
      if (!hasAccess) {
        setState(() {
          _directoryPickerErrorMessage = '系统没有保留这个目录的读取授权，请重新选择目录。';
        });
        return;
      }

      setState(() {
        _scanDirectoryPath = directory;
        _directoryPickerErrorMessage = null;
      });
    } on PlatformException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _directoryPickerErrorMessage = error.message ?? '系统目录选择器没有成功启动。';
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _directoryPickerErrorMessage = '系统目录选择器没有成功启动。';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isPickingDirectory = false;
        });
      }
    }
  }

  Future<void> _openSettingsDialog() async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            Future<void> handlePickDirectory() async {
              await _pickScanDirectory();

              if (context.mounted) {
                setDialogState(() {});
              }
            }

            return _ScanDirectoryDialog(
              scanDirectoryPath: _scanDirectoryPath,
              errorMessage: _directoryPickerErrorMessage,
              isPickingDirectory: _isPickingDirectory,
              onPickDirectory: handlePickDirectory,
            );
          },
        );
      },
    );
  }

  void _togglePlayback() {
    if (!_controller.hasMedia) {
      return;
    }
    unawaited(_controller.togglePlayback());
  }

  void _toggleAudioMode() {
    if (!_controller.hasMedia) {
      return;
    }
    unawaited(_controller.toggleAudioOutputMode());
  }

  void _restartPlayback() {
    if (!_controller.hasMedia) {
      return;
    }
    unawaited(_controller.seekToProgress(0));
  }

  void _enterSongBook() {
    setState(() {
      _route = _DemoRoute.songBook;
    });
  }

  void _returnHome() {
    setState(() {
      _route = _DemoRoute.home;
    });
  }

  void _selectLanguage(String language) {
    setState(() {
      _selectedLanguage = language;
    });
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

  void _queueSong(_DemoSong song) {
    if (_queuedSongs.contains(song)) {
      return;
    }
    setState(() {
      _queuedSongs.add(song);
    });
  }

  @override
  Widget build(BuildContext context) {
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
                                  duration: const Duration(milliseconds: 320),
                                  switchInCurve: Curves.easeOutCubic,
                                  switchOutCurve: Curves.easeInCubic,
                                  child: _route == _DemoRoute.home
                                      ? _HomePage(
                                          key: const ValueKey<String>('home'),
                                          controller: _controller,
                                          queueCount: _queuedSongs.length,
                                          currentTitle: _currentTitle,
                                          currentSubtitle: _currentSubtitle,
                                          onEnterSongBook: _enterSongBook,
                                          onSettingsPressed:
                                              _openSettingsDialog,
                                          onToggleAudioMode: _toggleAudioMode,
                                          onTogglePlayback: _togglePlayback,
                                        )
                                      : _SongBookPage(
                                          key: const ValueKey<String>(
                                            'song_book',
                                          ),
                                          controller: _controller,
                                          searchController: _searchController,
                                          selectedLanguage: _selectedLanguage,
                                          songs: _filteredSongs,
                                          queuedSongs: _queuedSongs,
                                          onBackPressed: _returnHome,
                                          onLanguageSelected: _selectLanguage,
                                          onAppendSearchToken:
                                              _appendSearchToken,
                                          onRemoveSearchCharacter:
                                              _removeSearchCharacter,
                                          onClearSearch: _clearSearch,
                                          onQueueSong: _queueSong,
                                          onSettingsPressed:
                                              _openSettingsDialog,
                                          onToggleAudioMode: _toggleAudioMode,
                                          onTogglePlayback: _togglePlayback,
                                          onRestartPlayback: _restartPlayback,
                                        ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1080),
                        child: _ResidentPlayerBar(
                          controller: _controller,
                          title: _currentTitle,
                          subtitle: _currentSubtitle,
                          isPickingVideo: _isPickingVideo,
                          onPickVideo: _pickAndPlay,
                          onToggleAudioMode: _toggleAudioMode,
                          onTogglePlayback: _togglePlayback,
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
    required this.queuedSongs,
    required this.onBackPressed,
    required this.onLanguageSelected,
    required this.onAppendSearchToken,
    required this.onRemoveSearchCharacter,
    required this.onClearSearch,
    required this.onQueueSong,
    required this.onSettingsPressed,
    required this.onToggleAudioMode,
    required this.onTogglePlayback,
    required this.onRestartPlayback,
  });

  final PlayerController controller;
  final TextEditingController searchController;
  final String selectedLanguage;
  final List<_DemoSong> songs;
  final List<_DemoSong> queuedSongs;
  final VoidCallback onBackPressed;
  final ValueChanged<String> onLanguageSelected;
  final ValueChanged<String> onAppendSearchToken;
  final VoidCallback onRemoveSearchCharacter;
  final VoidCallback onClearSearch;
  final ValueChanged<_DemoSong> onQueueSong;
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
                      queuedSongs: queuedSongs,
                      onBackPressed: onBackPressed,
                      onLanguageSelected: onLanguageSelected,
                      onQueueSong: onQueueSong,
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
                        queuedSongs: queuedSongs,
                        onBackPressed: onBackPressed,
                        onLanguageSelected: onLanguageSelected,
                        onQueueSong: onQueueSong,
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
    required this.queuedSongs,
    required this.onBackPressed,
    required this.onLanguageSelected,
    required this.onQueueSong,
    required this.onSettingsPressed,
    required this.onToggleAudioMode,
    required this.onTogglePlayback,
    required this.onRestartPlayback,
    this.compact = false,
  });

  final PlayerController controller;
  final String selectedLanguage;
  final List<_DemoSong> songs;
  final List<_DemoSong> queuedSongs;
  final VoidCallback onBackPressed;
  final ValueChanged<String> onLanguageSelected;
  final ValueChanged<_DemoSong> onQueueSong;
  final VoidCallback onSettingsPressed;
  final VoidCallback onToggleAudioMode;
  final VoidCallback onTogglePlayback;
  final VoidCallback onRestartPlayback;
  final bool compact;

  @override
  Widget build(BuildContext context) {
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
        Expanded(
          child: Column(
            children: <Widget>[
              Expanded(
                child: songs.isEmpty
                    ? const _EmptyContentCard(
                        message: '当前筛选条件下没有歌曲，试试切换分类或清空搜索关键字。',
                      )
                    : LayoutBuilder(
                        builder:
                            (BuildContext context, BoxConstraints constraints) {
                              return GridView.builder(
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      mainAxisSpacing: 6,
                                      crossAxisSpacing: 12,
                                      childAspectRatio: 2.86,
                                    ),
                                itemCount: songs.length,
                                itemBuilder: (BuildContext context, int index) {
                                  final _DemoSong song = songs[index];
                                  final bool inQueue = queuedSongs.contains(
                                    song,
                                  );
                                  final bool isCurrent =
                                      queuedSongs.isNotEmpty &&
                                      queuedSongs.first == song;
                                  return _SongTile(
                                    song: song,
                                    inQueue: inQueue,
                                    isCurrent: isCurrent,
                                    onTap: inQueue
                                        ? null
                                        : () => onQueueSong(song),
                                  );
                                },
                              );
                            },
                      ),
              ),
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

class _ScanDirectoryDialog extends StatelessWidget {
  const _ScanDirectoryDialog({
    required this.scanDirectoryPath,
    required this.errorMessage,
    required this.isPickingDirectory,
    required this.onPickDirectory,
  });

  final String? scanDirectoryPath;
  final String? errorMessage;
  final bool isPickingDirectory;
  final Future<void> Function() onPickDirectory;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      title: const Text('媒体库设置'),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width > 560
              ? 520
              : MediaQuery.sizeOf(context).width - 48,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                '配置扫描目录后，后续点歌页会基于这个目录建立扫描范围。Android 这里走系统文档树授权，不依赖额外存储权限。',
                style: TextStyle(height: 1.5),
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F2FF),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      '扫描目录',
                      style: TextStyle(
                        color: Color(0xFF1D1230),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      scanDirectoryPath ?? '当前还没有配置扫描目录。',
                      style: const TextStyle(
                        color: Color(0xFF6B5D7C),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: isPickingDirectory ? null : onPickDirectory,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6E67),
                ),
                icon: const Icon(Icons.folder_open_rounded),
                label: Text(isPickingDirectory ? '选择中' : '选择目录'),
              ),
              if (errorMessage != null) ...<Widget>[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1F1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    errorMessage!,
                    style: const TextStyle(
                      color: Color(0xFF9C2F2F),
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('完成'),
        ),
      ],
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
  const _SongTile({
    required this.song,
    required this.inQueue,
    required this.isCurrent,
    this.onTap,
  });

  final _DemoSong song;
  final bool inQueue;
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
                isCurrent
                    ? '当前播放'
                    : inQueue
                    ? '已点'
                    : '点唱',
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  color: inQueue
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

class _ResidentPlayerBar extends StatelessWidget {
  const _ResidentPlayerBar({
    required this.controller,
    required this.title,
    required this.subtitle,
    required this.isPickingVideo,
    required this.onPickVideo,
    required this.onToggleAudioMode,
    required this.onTogglePlayback,
  });

  final PlayerController controller;
  final String title;
  final String subtitle;
  final bool isPickingVideo;
  final Future<void> Function() onPickVideo;
  final VoidCallback onToggleAudioMode;
  final VoidCallback onTogglePlayback;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, Widget? child) {
        return Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          decoration: BoxDecoration(
            color: const Color(0xCC12041F),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0x1FFFFFFF)),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x52070012),
                blurRadius: 30,
                offset: Offset(0, 14),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool compact = constraints.maxWidth < 760;
              final Widget leading = Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: <Color>[Color(0xFFFF5D88), Color(0xFF8839F4)],
                      ),
                    ),
                    child: const Icon(
                      Icons.music_note_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: compact ? constraints.maxWidth - 120 : 280,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          maxLines: compact ? 2 : 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xCCF3DAFF),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );

              final Widget progress = Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _PlayerProgressTrack(
                    controller: controller,
                    thickness: 6,
                    barHeight: 12,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: <Widget>[
                      Text(
                        _formatDuration(controller.playbackPosition),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xB8FFF2FF),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _formatDuration(controller.playbackDuration),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xB8FFF2FF),
                        ),
                      ),
                    ],
                  ),
                ],
              );

              final Widget actions = Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.end,
                children: <Widget>[
                  FilledButton.icon(
                    onPressed: isPickingVideo ? null : onPickVideo,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6E67),
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.folder_open_rounded),
                    label: Text(isPickingVideo ? '选择中' : '选择本地视频'),
                  ),
                  _ResidentIconButton(
                    icon: Icons.mic_rounded,
                    label:
                        controller.audioOutputMode ==
                            AudioOutputMode.accompaniment
                        ? '原唱'
                        : '伴唱',
                    onPressed: controller.hasMedia ? onToggleAudioMode : null,
                  ),
                  _ResidentIconButton(
                    icon: controller.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    label: controller.isPlaying ? '暂停' : '播放',
                    onPressed: controller.hasMedia ? onTogglePlayback : null,
                  ),
                ],
              );

              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    leading,
                    const SizedBox(height: 16),
                    progress,
                    const SizedBox(height: 16),
                    actions,
                  ],
                );
              }

              return Row(
                children: <Widget>[
                  Expanded(flex: 35, child: leading),
                  const SizedBox(width: 20),
                  Expanded(flex: 38, child: progress),
                  const SizedBox(width: 20),
                  Expanded(
                    flex: 27,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: actions,
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _ResidentIconButton extends StatelessWidget {
  const _ResidentIconButton({
    required this.icon,
    required this.label,
    this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: onPressed == null
            ? const Color(0x7AFFF7FF)
            : const Color(0xEBFFF7FF),
        side: BorderSide(
          color: onPressed == null
              ? const Color(0x14FFFFFF)
              : const Color(0x33FFFFFF),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      icon: Icon(icon, size: 18),
      label: Text(label),
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

class _DemoSong {
  const _DemoSong(this.title, this.artist, this.language, this.searchIndex);

  final String title;
  final String artist;
  final String language;
  final String searchIndex;
}

String _formatDuration(Duration duration) {
  if (duration <= Duration.zero) {
    return '00:00';
  }

  final int totalSeconds = duration.inSeconds;
  final int hours = totalSeconds ~/ 3600;
  final int minutes = (totalSeconds % 3600) ~/ 60;
  final int seconds = totalSeconds % 60;
  if (hours > 0) {
    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }
  return '${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')}';
}
