part of 'ktv_demo_shell.dart';

class _HomePage extends StatelessWidget {
  const _HomePage({
    required this.controller,
    required this.queueCount,
    required this.onEnterSongBook,
    required this.onSettingsPressed,
    required this.onToggleAudioMode,
    required this.onTogglePlayback,
    this.compact = false,
  });

  final PlayerController controller;
  final int queueCount;
  final VoidCallback onEnterSongBook;
  final VoidCallback onSettingsPressed;
  final VoidCallback onToggleAudioMode;
  final VoidCallback onTogglePlayback;
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
          onQueuePressed: onEnterSongBook,
          onSettingsPressed: onSettingsPressed,
          onToggleAudioMode: onToggleAudioMode,
          onTogglePlayback: onTogglePlayback,
        ),
        SizedBox(height: compact ? 16 : 18),
        if (compact)
          _HomeShortcutGrid(onEnterSongBook: onEnterSongBook, compact: true)
        else
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 324),
                child: _HomeShortcutGrid(onEnterSongBook: onEnterSongBook),
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
    required this.previewSurface,
    this.compact = false,
  });

  final PlayerController controller;
  final Widget previewSurface;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, Widget? child) {
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
                  previewSurface,
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _PlayerProgressTrack(
                      controller: controller,
                      thickness: 6,
                      barHeight: 6,
                    ),
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

class _HomePreviewPlaceholder extends StatelessWidget {
  const _HomePreviewPlaceholder();

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
