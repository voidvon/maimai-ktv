import 'package:flutter/material.dart';

import '../player/player_controller.dart';

class KtvPlayerView extends StatelessWidget {
  const KtvPlayerView({
    super.key,
    required this.controller,
    this.placeholder,
    this.backgroundColor = Colors.black,
  });

  final PlayerController controller;
  final Widget? placeholder;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller.videoViewListenable,
      builder: (context, _) {
        final videoView = controller.buildVideoView();
        return ColoredBox(
          color: backgroundColor,
          child: controller.hasMedia && videoView != null
              ? SizedBox.expand(child: videoView)
              : placeholder ?? const _DefaultPlayerPlaceholder(),
        );
      },
    );
  }
}

class _DefaultPlayerPlaceholder extends StatelessWidget {
  const _DefaultPlayerPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.movie_outlined, size: 64, color: Colors.white54),
          SizedBox(height: 12),
          Text(
            '选择一个本地视频开始播放',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ],
      ),
    );
  }
}
