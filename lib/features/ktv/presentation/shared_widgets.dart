import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:ktv2/ktv2.dart';

import '../application/ktv_controller.dart';
import 'home_page.dart';
import 'ktv_presentation_helpers.dart';
import 'songbook_page.dart';

class GradientShell extends StatelessWidget {
  const GradientShell({super.key, required this.child, required this.padding});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(padding: padding, child: child);
  }
}

class PlayerProgressTrack extends StatelessWidget {
  const PlayerProgressTrack({
    super.key,
    required this.controller,
    required this.thickness,
    required this.barHeight,
    this.trackShape,
    this.activeTrackColor = const Color(0xFFFF4D8D),
    this.inactiveTrackColor = const Color(0x33FFFFFF),
    this.disabledInactiveTrackColor = const Color(0x33FFFFFF),
    this.overlayColor = const Color(0x29FF4D8D),
  });

  final PlayerController controller;
  final double thickness;
  final double barHeight;
  final SliderTrackShape? trackShape;
  final Color activeTrackColor;
  final Color inactiveTrackColor;
  final Color disabledInactiveTrackColor;
  final Color overlayColor;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, Widget? child) {
        final bool hasMedia =
            controller.hasMedia && controller.playbackDuration > Duration.zero;
        return SizedBox(
          height: barHeight,
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              if (!constraints.hasBoundedWidth || constraints.maxWidth <= 0) {
                return const SizedBox.shrink();
              }
              return SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: thickness,
                  trackShape: trackShape,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 0,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 12,
                  ),
                  activeTrackColor: activeTrackColor,
                  inactiveTrackColor: inactiveTrackColor,
                  disabledInactiveTrackColor: disabledInactiveTrackColor,
                  overlayColor: overlayColor,
                ),
                child: Slider(
                  value: hasMedia ? controller.playbackProgress : 0,
                  onChanged: hasMedia ? controller.seekToProgress : null,
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class PersistentPreviewSurface extends StatelessWidget {
  const PersistentPreviewSurface({
    super.key,
    required this.controller,
    required this.routeResolver,
  });

  final PlayerController controller;
  final KtvRoute Function() routeResolver;

  @override
  Widget build(BuildContext context) {
    final bool isHome = routeResolver() == KtvRoute.home;
    return KtvPlayerView(
      controller: controller,
      backgroundColor: isHome
          ? const Color(0xFF0A0018)
          : const Color(0xFF090013),
      placeholder: isHome
          ? const HomePreviewPlaceholder()
          : const SongPreviewPlaceholder(),
    );
  }
}

class PreviewViewportHost extends StatefulWidget {
  const PreviewViewportHost({
    super.key,
    required this.controller,
    required this.previewSurface,
    required this.rect,
    required this.isFullscreen,
    required this.onEnterFullscreen,
    required this.onBackToSongBook,
    required this.onToggleAudioMode,
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
  final VoidCallback onToggleAudioMode;
  final VoidCallback onTogglePlayback;
  final VoidCallback onRestartPlayback;
  final VoidCallback onSkipSong;

  @override
  State<PreviewViewportHost> createState() => _PreviewViewportHostState();
}

class _PreviewViewportHostState extends State<PreviewViewportHost> {
  static const double _nonFullscreenProgressControlHeight = 28;

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
  void didUpdateWidget(covariant PreviewViewportHost oldWidget) {
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
                bottom: _nonFullscreenProgressControlHeight,
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
                left: 0,
                right: 0,
                bottom: 0,
                child: PlayerProgressTrack(
                  controller: widget.controller,
                  thickness: 2,
                  barHeight: _nonFullscreenProgressControlHeight,
                  trackShape: const _BottomAlignedSliderTrackShape(),
                  activeTrackColor: const Color(0x73FF9DBD),
                  inactiveTrackColor: Colors.transparent,
                  disabledInactiveTrackColor: Colors.transparent,
                  overlayColor: const Color(0x0DFF9DBD),
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
                                            FullscreenToolbarButton(
                                              label: '返回点歌',
                                              icon: Icons.arrow_back_rounded,
                                              onPressed: _handleBackToSongBook,
                                            ),
                                            const SizedBox(width: 8),
                                            FullscreenToolbarButton(
                                              label: audioModeToggleLabel(
                                                widget.controller,
                                              ),
                                              icon: Icons.mic_rounded,
                                              onPressed:
                                                  widget.controller.hasMedia
                                                  ? widget.onToggleAudioMode
                                                  : null,
                                            ),
                                            const SizedBox(width: 8),
                                            FullscreenToolbarButton(
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
                                            FullscreenToolbarButton(
                                              label: '重唱',
                                              icon: Icons.replay_rounded,
                                              onPressed: hasMedia
                                                  ? widget.onRestartPlayback
                                                  : null,
                                            ),
                                            const SizedBox(width: 8),
                                            FullscreenToolbarButton(
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
                                          PlayerProgressTrack(
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
                                                  formatPlaybackDuration(
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
                                                  formatPlaybackDuration(
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

class FullscreenToolbarButton extends StatelessWidget {
  const FullscreenToolbarButton({
    super.key,
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
    final BorderRadius borderRadius = BorderRadius.circular(14);
    final Color foregroundColor = isEnabled
        ? const Color(0xFFF6F7FF)
        : const Color(0xA6FFFFFF);
    const List<Shadow> foregroundShadows = <Shadow>[
      Shadow(color: Color(0xCC000000), blurRadius: 10, offset: Offset(0, 1)),
    ];
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isEnabled ? const Color(0xC21A0E2E) : const Color(0x991A0E2E),
        borderRadius: borderRadius,
        border: Border.all(
          color: isEnabled ? const Color(0x52FFFFFF) : const Color(0x2EFFFFFF),
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x73000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: borderRadius,
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  icon,
                  size: 16,
                  color: foregroundColor,
                  shadows: foregroundShadows,
                ),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: foregroundColor,
                    shadows: foregroundShadows,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class KtvAtmosphereBackground extends StatelessWidget {
  const KtvAtmosphereBackground({super.key});

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

class _BottomAlignedSliderTrackShape extends RoundedRectSliderTrackShape {
  const _BottomAlignedSliderTrackShape();

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final double trackHeight = sliderTheme.trackHeight ?? 0;
    final double trackLeft = offset.dx;
    final double trackWidth = math.max(0, parentBox.size.width);
    final double trackTop = offset.dy + parentBox.size.height - trackHeight;
    return Rect.fromLTWH(trackLeft, trackTop, trackWidth, trackHeight);
  }
}
