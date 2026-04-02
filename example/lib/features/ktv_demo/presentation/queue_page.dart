import 'package:flutter/material.dart';

import '../../../core/models/demo_song.dart';

class QueuedSongEntry {
  const QueuedSongEntry({required this.song, required this.queueIndex});

  final DemoSong song;
  final int queueIndex;

  bool get isCurrent => queueIndex == 0;
  bool get canPinToTop => queueIndex > 1;

  String get subtitle {
    if (isCurrent) {
      return '当前播放';
    }
    return '队列 $queueIndex';
  }
}

class QueuedSongTile extends StatelessWidget {
  const QueuedSongTile({
    super.key,
    required this.entry,
    required this.onPinToTop,
    required this.onRemove,
  });

  final QueuedSongEntry entry;
  final VoidCallback? onPinToTop;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final bool isCurrent = entry.isCurrent;
    return Container(
      decoration: BoxDecoration(
        color: isCurrent ? const Color(0x24FFFFFF) : const Color(0x14FFFFFF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x1AFFFFFF)),
      ),
      padding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  entry.song.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xEDFFF7FF),
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${entry.song.artist} · ${entry.song.language} · ${entry.subtitle}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 7,
                    fontWeight: FontWeight.w600,
                    color: Color(0xB8F3DAFF),
                    height: 1.15,
                  ),
                ),
              ],
            ),
          ),
          if (!isCurrent) ...<Widget>[
            const SizedBox(width: 6),
            _QueueActionButton(
              label: '置顶',
              onPressed: onPinToTop,
              enabled: entry.canPinToTop,
            ),
            const SizedBox(width: 4),
            _QueueActionButton(label: '移除', onPressed: onRemove),
          ],
        ],
      ),
    );
  }
}

class _QueueActionButton extends StatelessWidget {
  const _QueueActionButton({
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
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: isEnabled ? onPressed : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w600,
              color: isEnabled
                  ? const Color(0xCCFFF7FF)
                  : const Color(0x7AFFF7FF),
            ),
          ),
        ),
      ),
    );
  }
}
