part of 'ktv_demo_shell.dart';

class _GradientShell extends StatelessWidget {
  const _GradientShell({required this.child, required this.padding});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(padding: padding, child: child);
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

class _PersistentPreviewSurface extends StatelessWidget {
  const _PersistentPreviewSurface({
    super.key,
    required this.controller,
    required this.routeResolver,
  });

  final PlayerController controller;
  final DemoRoute Function() routeResolver;

  @override
  Widget build(BuildContext context) {
    final bool isHome = routeResolver() == DemoRoute.home;
    return KtvPlayerView(
      controller: controller,
      backgroundColor: isHome
          ? const Color(0xFF0A0018)
          : const Color(0xFF090013),
      placeholder: isHome
          ? const _HomePreviewPlaceholder()
          : const _SongPreviewPlaceholder(),
    );
  }
}

class _PreviewViewportHost extends StatefulWidget {
  const _PreviewViewportHost({
    required this.controller,
    required this.previewSurface,
    required this.rect,
    required this.isFullscreen,
    required this.onEnterFullscreen,
    required this.onBackToSongBook,
    required this.onTogglePlayback,
    required this.onRestartPlayback,
    required this.onSkipSong,
  });

  final PlayerController controller;
  final Widget previewSurface;
  final Rect rect;
  final bool isFullscreen;
  final VoidCallback onEnterFullscreen;
  final VoidCallback onBackToSongBook;
  final VoidCallback onTogglePlayback;
  final VoidCallback onRestartPlayback;
  final VoidCallback onSkipSong;

  @override
  State<_PreviewViewportHost> createState() => _PreviewViewportHostState();
}

class _PreviewViewportHostState extends State<_PreviewViewportHost> {
  bool _showControls = false;
  bool _canToggleControls = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _canToggleControls = true;
    });
  }

  @override
  void didUpdateWidget(covariant _PreviewViewportHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isFullscreen && _showControls) {
      setState(() => _showControls = false);
    }
  }

  void _toggleControlsVisibility() {
    if (!_canToggleControls) {
      return;
    }
    setState(() => _showControls = !_showControls);
  }

  void _handleBackToSongBook() {
    widget.onBackToSongBook();
  }

  String _formatDuration(Duration value) {
    final int totalSeconds = value.inSeconds.clamp(0, 86399);
    final int minutes = (totalSeconds ~/ 60) % 60;
    final int seconds = totalSeconds % 60;
    final int hours = totalSeconds ~/ 3600;
    if (hours > 0) {
      final String paddedMinutes = minutes.toString().padLeft(2, '0');
      final String paddedSeconds = seconds.toString().padLeft(2, '0');
      return '$hours:$paddedMinutes:$paddedSeconds';
    }
    final String paddedSeconds = seconds.toString().padLeft(2, '0');
    return '$minutes:$paddedSeconds';
  }

  @override
  Widget build(BuildContext context) {
    final BorderRadius borderRadius = widget.isFullscreen
        ? BorderRadius.zero
        : const BorderRadius.all(Radius.circular(14));

    return Positioned(
      left: widget.rect.left,
      top: widget.rect.top,
      width: widget.rect.width,
      height: widget.rect.height,
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            widget.previewSurface,
            if (!widget.isFullscreen) ...<Widget>[
              Positioned.fill(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    key: const ValueKey<String>('preview-tap-target'),
                    onTap: widget.onEnterFullscreen,
                    splashColor: const Color(0x22FFFFFF),
                    highlightColor: Colors.transparent,
                  ),
                ),
              ),
              Positioned(
                right: 10,
                top: 10,
                child: IgnorePointer(
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0x52000000),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.fullscreen_rounded,
                      size: 14,
                      color: Color(0xE8FFFFFF),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _PlayerProgressTrack(
                  controller: widget.controller,
                  thickness: 6,
                  barHeight: 6,
                ),
              ),
            ] else ...<Widget>[
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _toggleControlsVisibility,
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: !_showControls,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 160),
                    transitionBuilder:
                        (Widget child, Animation<double> animation) =>
                            FadeTransition(opacity: animation, child: child),
                    child: _showControls
                        ? SafeArea(
                            child: AnimatedBuilder(
                              key: const ValueKey<String>(
                                'fullscreen-preview-controls',
                              ),
                              animation: widget.controller,
                              builder: (BuildContext context, Widget? child) {
                                final bool hasMedia =
                                    widget.controller.hasMedia &&
                                    widget.controller.playbackDuration >
                                        Duration.zero;
                                return Column(
                                  children: <Widget>[
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        14,
                                        10,
                                        14,
                                        0,
                                      ),
                                      child: SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        child: Row(
                                          children: <Widget>[
                                            _FullscreenToolbarButton(
                                              label: '返回点歌',
                                              icon: Icons.arrow_back_rounded,
                                              onPressed: _handleBackToSongBook,
                                            ),
                                            const SizedBox(width: 8),
                                            _FullscreenToolbarButton(
                                              label: widget.controller.isPlaying
                                                  ? '暂停'
                                                  : '播放',
                                              icon: widget.controller.isPlaying
                                                  ? Icons.pause_rounded
                                                  : Icons.play_arrow_rounded,
                                              onPressed: hasMedia
                                                  ? widget.onTogglePlayback
                                                  : null,
                                            ),
                                            const SizedBox(width: 8),
                                            _FullscreenToolbarButton(
                                              label: '重唱',
                                              icon: Icons.replay_rounded,
                                              onPressed: hasMedia
                                                  ? widget.onRestartPlayback
                                                  : null,
                                            ),
                                            const SizedBox(width: 8),
                                            _FullscreenToolbarButton(
                                              label: '切歌',
                                              icon: Icons.skip_next_rounded,
                                              onPressed: hasMedia
                                                  ? widget.onSkipSong
                                                  : null,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    Container(
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                      ),
                                      padding: const EdgeInsets.fromLTRB(
                                        8,
                                        8,
                                        8,
                                        10,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: <Color>[
                                            Color(0x30000000),
                                            Color(0xA0000000),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: <Widget>[
                                          _PlayerProgressTrack(
                                            controller: widget.controller,
                                            thickness: 4,
                                            barHeight: 18,
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 2,
                                            ),
                                            child: Row(
                                              children: <Widget>[
                                                Text(
                                                  _formatDuration(
                                                    widget
                                                        .controller
                                                        .playbackPosition,
                                                  ),
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w500,
                                                    color: Color(0xD6FFFFFF),
                                                  ),
                                                ),
                                                const Spacer(),
                                                Text(
                                                  _formatDuration(
                                                    widget
                                                        .controller
                                                        .playbackDuration,
                                                  ),
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w500,
                                                    color: Color(0xB8FFFFFF),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FullscreenToolbarButton extends StatelessWidget {
  const _FullscreenToolbarButton({
    required this.label,
    required this.icon,
    this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final bool isEnabled = onPressed != null;
    return Material(
      color: isEnabled ? const Color(0x2BFFFFFF) : const Color(0x1AFFFFFF),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                icon,
                size: 16,
                color: isEnabled
                    ? const Color(0xEAFFFFFF)
                    : const Color(0x80FFFFFF),
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isEnabled
                      ? const Color(0xEAFFFFFF)
                      : const Color(0x80FFFFFF),
                ),
              ),
            ],
          ),
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
