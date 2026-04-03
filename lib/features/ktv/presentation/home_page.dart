import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:ktv2/ktv2.dart';

import 'ktv_presentation_helpers.dart';
import 'shared_widgets.dart';

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
  ),
  _HomeShortcut(
    label: '歌星',
    icon: Icons.person_rounded,
    colors: <Color>[Color(0xFF9CC9FF), Color(0xFF89B2FF), Color(0xFF9571FF)],
    enabled: true,
    action: _HomeShortcutAction.artists,
  ),
  _HomeShortcut(
    label: '本地',
    icon: Icons.library_music_rounded,
    colors: <Color>[Color(0xFF65D8FF), Color(0xFF2E9DFF)],
    enabled: true,
    action: _HomeShortcutAction.local,
  ),
  _HomeShortcut(
    label: '收藏',
    icon: Icons.favorite_border_rounded,
    colors: <Color>[Color(0xFFF2AAFF), Color(0xFFC46BFF)],
    enabled: true,
    action: _HomeShortcutAction.favorites,
  ),
  _HomeShortcut(
    label: '常唱',
    icon: Icons.mic_external_on_rounded,
    colors: <Color>[Color(0xFFFFB8A8), Color(0xFFFF8B78)],
    enabled: true,
    action: _HomeShortcutAction.frequent,
  ),
];

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.controller,
    required this.queueCount,
    required this.onEnterSongBook,
    required this.onEnterFavoritesBook,
    required this.onEnterFrequentBook,
    required this.onEnterArtistBook,
    required this.onQueuePressed,
    required this.onSettingsPressed,
    required this.onToggleAudioMode,
    required this.onTogglePlayback,
    required this.onSkipSong,
    this.compact = false,
  });

  final PlayerController controller;
  final int queueCount;
  final VoidCallback onEnterSongBook;
  final VoidCallback onEnterFavoritesBook;
  final VoidCallback onEnterFrequentBook;
  final VoidCallback onEnterArtistBook;
  final VoidCallback onQueuePressed;
  final VoidCallback onSettingsPressed;
  final VoidCallback onToggleAudioMode;
  final VoidCallback onTogglePlayback;
  final VoidCallback onSkipSong;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool shouldUseCompactLayout =
            compact ||
            constraints.maxWidth < 560 ||
            constraints.maxHeight < 340;
        final bool shouldScroll =
            constraints.maxHeight < (shouldUseCompactLayout ? 360 : 300);
        final Widget shortcutGrid = _HomeShortcutGrid(
          onEnterSongBook: onEnterSongBook,
          onEnterFavoritesBook: onEnterFavoritesBook,
          onEnterFrequentBook: onEnterFrequentBook,
          onEnterArtistBook: onEnterArtistBook,
          compact: shouldUseCompactLayout,
        );

        final List<Widget> children = <Widget>[
          _HomeToolbar(
            controller: controller,
            queueCount: queueCount,
            compact: shouldUseCompactLayout,
            onQueuePressed: onQueuePressed,
            onSettingsPressed: onSettingsPressed,
            onToggleAudioMode: onToggleAudioMode,
            onTogglePlayback: onTogglePlayback,
            onSkipSong: onSkipSong,
          ),
          SizedBox(height: shouldUseCompactLayout ? 16 : 18),
          if (shouldUseCompactLayout || shouldScroll)
            Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 324),
                child: shortcutGrid,
              ),
            )
          else
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 324),
                  child: shortcutGrid,
                ),
              ),
            ),
        ];

        final Widget content = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        );

        if (!shouldScroll) {
          return content;
        }

        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: content,
          ),
        );
      },
    );
  }
}

class LandscapeHomePage extends StatelessWidget {
  const LandscapeHomePage({
    super.key,
    required this.controller,
    required this.queueCount,
    required this.previewAnchorKey,
    required this.onEnterSongBook,
    required this.onEnterFavoritesBook,
    required this.onEnterFrequentBook,
    required this.onEnterArtistBook,
    required this.onQueuePressed,
    required this.onSettingsPressed,
    required this.onToggleAudioMode,
    required this.onTogglePlayback,
    required this.onSkipSong,
  });

  final PlayerController controller;
  final int queueCount;
  final GlobalKey previewAnchorKey;
  final VoidCallback onEnterSongBook;
  final VoidCallback onEnterFavoritesBook;
  final VoidCallback onEnterFrequentBook;
  final VoidCallback onEnterArtistBook;
  final VoidCallback onQueuePressed;
  final VoidCallback onSettingsPressed;
  final VoidCallback onToggleAudioMode;
  final VoidCallback onTogglePlayback;
  final VoidCallback onSkipSong;

  VoidCallback? _resolveShortcutAction(_HomeShortcut shortcut) {
    if (!shortcut.enabled) {
      return null;
    }
    return switch (shortcut.action) {
      _HomeShortcutAction.songs => onEnterSongBook,
      _HomeShortcutAction.local => onEnterSongBook,
      _HomeShortcutAction.favorites => onEnterFavoritesBook,
      _HomeShortcutAction.frequent => onEnterFrequentBook,
      _HomeShortcutAction.artists => onEnterArtistBook,
      null => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    const List<_HomeShortcut> previewRowShortcuts = <_HomeShortcut>[
      _HomeShortcut(
        label: '常唱',
        icon: Icons.mic_external_on_rounded,
        colors: <Color>[Color(0xFFFFB8A8), Color(0xFFFF8B78)],
        enabled: true,
        action: _HomeShortcutAction.frequent,
      ),
      _HomeShortcut(
        label: '收藏',
        icon: Icons.favorite_border_rounded,
        colors: <Color>[Color(0xFFF2AAFF), Color(0xFFC46BFF)],
        enabled: true,
        action: _HomeShortcutAction.favorites,
      ),
      _HomeShortcut(
        label: '分类',
        icon: Icons.library_music_rounded,
        colors: <Color>[Color(0xFFAF9DFF), Color(0xFF8B6DFF)],
        enabled: true,
        action: _HomeShortcutAction.songs,
      ),
    ];
    const List<_HomeShortcut> sideColumnShortcuts = <_HomeShortcut>[
      _HomeShortcut(
        label: '排行榜',
        icon: Icons.star_rounded,
        colors: <Color>[
          Color(0xFFFF7C93),
          Color(0xFFFF5372),
          Color(0xFFFF9A7A),
        ],
      ),
      _HomeShortcut(
        label: '歌名',
        icon: Icons.music_note_rounded,
        colors: <Color>[
          Color(0xFFFFD36A),
          Color(0xFFFFB245),
          Color(0xFFFF9566),
        ],
      ),
      _HomeShortcut(
        label: '歌星',
        icon: Icons.person_rounded,
        colors: <Color>[
          Color(0xFF9CC9FF),
          Color(0xFF89B2FF),
          Color(0xFF9571FF),
        ],
        enabled: true,
        action: _HomeShortcutAction.artists,
      ),
      _HomeShortcut(
        label: '本地',
        icon: Icons.library_music_rounded,
        colors: <Color>[Color(0xFF65D8FF), Color(0xFF2E9DFF)],
        enabled: true,
        action: _HomeShortcutAction.local,
      ),
    ];

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double gap = constraints.maxWidth < 900 ? 14 : 18;
        final double centerColumnWidth = (constraints.maxWidth * 0.21)
            .clamp(156.0, 188.0)
            .toDouble();
        final double reservedBottomSpace = (constraints.maxHeight * 0.1)
            .clamp(20.0, 56.0)
            .toDouble();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _HomeToolbar(
              controller: controller,
              queueCount: queueCount,
              compact: false,
              onQueuePressed: onQueuePressed,
              onSettingsPressed: onSettingsPressed,
              onToggleAudioMode: onToggleAudioMode,
              onTogglePlayback: onTogglePlayback,
              onSkipSong: onSkipSong,
            ),
            SizedBox(height: gap),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: reservedBottomSpace),
                child: LayoutBuilder(
                  builder:
                      (
                        BuildContext context,
                        BoxConstraints contentConstraints,
                      ) {
                        final double usableContentHeight = math.max(
                          240,
                          contentConstraints.maxHeight - reservedBottomSpace,
                        );
                        final double maxRowHeightByHeight = math.max(
                          48,
                          (usableContentHeight - gap * 3 - 2) / 4,
                        );
                        final double maxRowHeightByWidth = math.max(
                          48,
                          (((constraints.maxWidth - centerColumnWidth - gap) *
                                      9 /
                                      16) -
                                  gap * 2) /
                              3,
                        );
                        final double rowHeight = math.max(
                          48,
                          math.min(
                            96,
                            math
                                .min(maxRowHeightByHeight, maxRowHeightByWidth)
                                .floorToDouble(),
                          ),
                        );
                        final double previewHeight = rowHeight * 3 + gap * 2;
                        final double previewColumnWidth =
                            previewHeight * (16 / 9);
                        final double contentHeight = rowHeight * 4 + gap * 3;

                        return Center(
                          child: SizedBox(
                            height: contentHeight,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: <Widget>[
                                SizedBox(
                                  width: previewColumnWidth,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: <Widget>[
                                      SizedBox(
                                        height: previewHeight,
                                        child: HomePreviewCard(
                                          controller: controller,
                                          previewSurface:
                                              const HomePreviewPlaceholder(),
                                          previewAnchorKey: previewAnchorKey,
                                        ),
                                      ),
                                      SizedBox(height: gap),
                                      SizedBox(
                                        height: rowHeight,
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: <Widget>[
                                            for (
                                              int index = 0;
                                              index <
                                                  previewRowShortcuts.length;
                                              index++
                                            ) ...<Widget>[
                                              Expanded(
                                                child: _ShortcutCard(
                                                  shortcut:
                                                      previewRowShortcuts[index],
                                                  onTap: _resolveShortcutAction(
                                                    previewRowShortcuts[index],
                                                  ),
                                                ),
                                              ),
                                              if (index !=
                                                  previewRowShortcuts.length -
                                                      1)
                                                SizedBox(width: gap),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(width: gap),
                                SizedBox(
                                  width: centerColumnWidth,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: sideColumnShortcuts
                                        .map(
                                          (_HomeShortcut shortcut) => Padding(
                                            padding: EdgeInsets.only(
                                              bottom:
                                                  shortcut ==
                                                      sideColumnShortcuts.last
                                                  ? 0
                                                  : gap,
                                            ),
                                            child: SizedBox(
                                              height: rowHeight,
                                              child: _ShortcutCard(
                                                shortcut: shortcut,
                                                onTap: _resolveShortcutAction(
                                                  shortcut,
                                                ),
                                              ),
                                            ),
                                          ),
                                        )
                                        .toList(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                ),
              ),
            ),
          ],
        );
      },
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
    required this.onSkipSong,
  });

  final PlayerController controller;
  final int queueCount;
  final bool compact;
  final VoidCallback onQueuePressed;
  final VoidCallback onSettingsPressed;
  final VoidCallback onToggleAudioMode;
  final VoidCallback onTogglePlayback;
  final VoidCallback onSkipSong;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, Widget? child) {
        final List<Widget> actions = <Widget>[
          const _ToolbarPill(label: '搜索', enabled: false),
          _ToolbarPill(label: '已点$queueCount', onPressed: onQueuePressed),
          _ToolbarPill(
            label: audioModeToggleLabel(controller),
            onPressed: controller.hasMedia ? onToggleAudioMode : null,
          ),
          _ToolbarPill(
            label: '切歌',
            onPressed: controller.hasMedia || queueCount > 0
                ? onSkipSong
                : null,
          ),
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
                      '我爱KTV',
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
                      '我爱KTV',
                      style: TextStyle(
                        color: Color(0xFFFFD85E),
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          alignment: WrapAlignment.end,
                          children: actions,
                        ),
                      ),
                    ),
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

class HomePreviewCard extends StatelessWidget {
  const HomePreviewCard({
    super.key,
    required this.controller,
    required this.previewSurface,
    required this.previewAnchorKey,
    this.compact = false,
  });

  final PlayerController controller;
  final Widget previewSurface;
  final GlobalKey previewAnchorKey;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final BorderRadius borderRadius = BorderRadius.all(
      Radius.circular(compact ? 12 : 14),
    );
    return Container(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        border: const Border.fromBorderSide(
          BorderSide(color: Color(0x1FFFFFFF)),
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x87090012),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              Positioned.fill(key: previewAnchorKey, child: previewSurface),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: IgnorePointer(
                  child: PlayerProgressTrack(
                    controller: controller,
                    thickness: 6,
                    barHeight: 6,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomePreviewPlaceholder extends StatelessWidget {
  const HomePreviewPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
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
    );
  }
}

class _HomeShortcutGrid extends StatelessWidget {
  const _HomeShortcutGrid({
    required this.onEnterSongBook,
    required this.onEnterFavoritesBook,
    required this.onEnterFrequentBook,
    required this.onEnterArtistBook,
    this.compact = false,
  });

  final VoidCallback onEnterSongBook;
  final VoidCallback onEnterFavoritesBook;
  final VoidCallback onEnterFrequentBook;
  final VoidCallback onEnterArtistBook;
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
          onTap: shortcut.enabled
              ? switch (shortcut.action) {
                  _HomeShortcutAction.songs => onEnterSongBook,
                  _HomeShortcutAction.local => onEnterSongBook,
                  _HomeShortcutAction.favorites => onEnterFavoritesBook,
                  _HomeShortcutAction.frequent => onEnterFrequentBook,
                  _HomeShortcutAction.artists => onEnterArtistBook,
                  null => null,
                }
              : null,
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
                ],
              ),
            ),
          ),
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
    this.action,
  });

  final String label;
  final IconData icon;
  final List<Color> colors;
  final bool enabled;
  final _HomeShortcutAction? action;
}

enum _HomeShortcutAction { songs, local, favorites, frequent, artists }
