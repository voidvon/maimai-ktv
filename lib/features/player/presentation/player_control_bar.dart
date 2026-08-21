import 'package:flutter/material.dart';
import 'package:ktv2/ktv2.dart';

import '../../../core/localization/localization_extensions.dart';

class PlayerControlBar extends StatelessWidget {
  const PlayerControlBar({
    super.key,
    required this.controller,
    this.onOpenPressed,
    this.isOpening = false,
    this.openButtonLabel,
    this.openingButtonLabel,
  });

  final PlayerController controller;
  final Future<void> Function()? onOpenPressed;
  final bool isOpening;
  final String? openButtonLabel;
  final String? openingButtonLabel;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (onOpenPressed != null) ...[
                FilledButton.icon(
                  onPressed: isOpening ? null : onOpenPressed,
                  icon: const Icon(Icons.folder_open),
                  label: Text(
                    isOpening
                        ? openingButtonLabel ?? context.l10n.selecting
                        : openButtonLabel ?? context.l10n.selectVideo,
                  ),
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
                      ? context.l10n.originalVocal
                      : context.l10n.accompaniment,
                ),
              ),
              const SizedBox(width: 12),
              IconButton.filled(
                onPressed: controller.hasMedia
                    ? controller.togglePlayback
                    : null,
                icon: Icon(
                  controller.isPlaying ? Icons.pause_rounded : Icons.play_arrow,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
