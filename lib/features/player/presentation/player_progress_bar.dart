import 'package:flutter/material.dart';
import 'package:ktv2/ktv2.dart';

class PlayerProgressBar extends StatefulWidget {
  const PlayerProgressBar({super.key, required this.controller});

  final PlayerController controller;

  @override
  State<PlayerProgressBar> createState() => _PlayerProgressBarState();
}

class _PlayerProgressBarState extends State<PlayerProgressBar> {
  double? _previewProgress;
  bool _isDragging = false;
  int _interactionId = 0;

  void _handlePreviewStart(double progress) {
    _interactionId += 1;
    setState(() {
      _isDragging = true;
      _previewProgress = progress;
    });
  }

  void _handlePreviewChanged(double progress) {
    setState(() {
      _previewProgress = progress;
    });
  }

  Future<void> _handlePreviewEnd(double progress) async {
    final int interactionId = _interactionId;
    setState(() {
      _isDragging = false;
      _previewProgress = progress;
    });
    await widget.controller.seekToProgress(progress);
    if (!mounted || _isDragging || interactionId != _interactionId) {
      return;
    }
    setState(() {
      _previewProgress = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final bool hasMedia =
            widget.controller.hasMedia &&
            widget.controller.playbackDuration > Duration.zero;
        final double displayedProgress = hasMedia
            ? (_previewProgress ?? widget.controller.playbackProgress)
            : 0;
        final Duration displayedPosition = hasMedia && _previewProgress != null
            ? _positionForProgress(
                widget.controller.playbackDuration,
                displayedProgress,
              )
            : widget.controller.playbackPosition;
        final ThemeData theme = Theme.of(context);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(
                  _formatDuration(displayedPosition),
                  style: theme.textTheme.bodySmall,
                ),
                const Spacer(),
                Text(
                  _formatDuration(widget.controller.playbackDuration),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
            Slider(
              value: displayedProgress,
              onChangeStart: hasMedia ? _handlePreviewStart : null,
              onChanged: hasMedia ? _handlePreviewChanged : null,
              onChangeEnd: hasMedia ? _handlePreviewEnd : null,
            ),
          ],
        );
      },
    );
  }
}

Duration _positionForProgress(Duration duration, double progress) {
  final int durationMs = duration.inMilliseconds;
  if (durationMs <= 0) {
    return Duration.zero;
  }
  return Duration(
    milliseconds: (durationMs * progress.clamp(0.0, 1.0)).round(),
  );
}

String _formatDuration(Duration duration) {
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
