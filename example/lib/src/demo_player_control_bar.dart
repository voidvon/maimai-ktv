import 'package:flutter/material.dart';
import 'package:ktv2/ktv2.dart';

class DemoPlayerControlBar extends StatelessWidget {
  const DemoPlayerControlBar({
    super.key,
    required this.controller,
    this.onOpenPressed,
    this.isOpening = false,
    this.openButtonLabel = '选择视频',
    this.openingButtonLabel = '选择中',
  });

  final PlayerController controller;
  final Future<void> Function()? onOpenPressed;
  final bool isOpening;
  final String openButtonLabel;
  final String openingButtonLabel;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (onOpenPressed != null) ...[
              FilledButton.icon(
                onPressed: isOpening ? null : onOpenPressed,
                icon: const Icon(Icons.folder_open),
                label: Text(isOpening ? openingButtonLabel : openButtonLabel),
              ),
              const SizedBox(width: 12),
            ],
            FilledButton.tonalIcon(
              onPressed: controller.hasMedia
                  ? controller.toggleAudioOutputMode
                  : null,
              icon: const Icon(Icons.mic_rounded),
              label: Text(
                controller.audioOutputMode == AudioOutputMode.accompaniment
                    ? '原唱'
                    : '伴唱',
              ),
            ),
            const SizedBox(width: 12),
            IconButton.filled(
              onPressed: controller.hasMedia ? controller.togglePlayback : null,
              icon: Icon(
                controller.isPlaying ? Icons.pause_rounded : Icons.play_arrow,
              ),
            ),
          ],
        );
      },
    );
  }
}
