import 'package:flutter/material.dart';
import 'package:ktv2/ktv2.dart';

import 'ktv_demo_presentation_helpers.dart';
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
    enabled: true,
    action: _HomeShortcutAction.songs,
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

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.controller,
    required this.queueCount,
    required this.onEnterSongBook,
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
  final VoidCallback onEnterArtistBook;
  final VoidCallback onQueuePressed;
  final VoidCallback onSettingsPressed;
  final VoidCallback onToggleAudioMode;
  final VoidCallback onTogglePlayback;
  final VoidCallback onSkipSong;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _HomeToolbar(
          controller: controller,
          queueCount: queueCount,
          compact: compact,
          onQueuePressed: onQueuePressed,
          onSettingsPressed: onSettingsPressed,
          onToggleAudioMode: onToggleAudioMode,
          onTogglePlayback: onTogglePlayback,
          onSkipSong: onSkipSong,
        ),
        SizedBox(height: compact ? 16 : 18),
        if (compact)
          _HomeShortcutGrid(
            onEnterSongBook: onEnterSongBook,
            onEnterArtistBook: onEnterArtistBook,
            compact: true,
          )
        else
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 324),
                child: _HomeShortcutGrid(
                  onEnterSongBook: onEnterSongBook,
                  onEnterArtistBook: onEnterArtistBook,
                ),
              ),
            ),
          ),
      ],
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
    required this.onEnterArtistBook,
    this.compact = false,
  });

  final VoidCallback onEnterSongBook;
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
                  _HomeShortcutAction.artists => onEnterArtistBook,
                  null => onEnterSongBook,
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

enum _HomeShortcutAction { songs, artists }
