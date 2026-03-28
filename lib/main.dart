import 'package:flutter/material.dart';

import 'models/media_source.dart';
import 'player/audio_output_mode.dart';
import 'player/player_controller.dart';
import 'player/player_factory.dart';
import 'services/video_picker_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const KtvPlayerApp());
}

class KtvPlayerApp extends StatelessWidget {
  const KtvPlayerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'KTV Player',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1D6B57),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF11161B),
        useMaterial3: true,
      ),
      home: const PlayerHomePage(),
    );
  }
}

class PlayerHomePage extends StatefulWidget {
  const PlayerHomePage({super.key});

  @override
  State<PlayerHomePage> createState() => _PlayerHomePageState();
}

class _PlayerHomePageState extends State<PlayerHomePage> {
  final PlayerController _controller = createPlayerController();
  final VideoPickerService _videoPickerService = VideoPickerService();

  MediaSource? _currentSource;
  bool _isPicking = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickAndPlay() async {
    if (_isPicking) {
      return;
    }

    setState(() {
      _isPicking = true;
    });

    try {
      final source = await _videoPickerService.pickVideo();
      if (!mounted || source == null) {
        return;
      }

      setState(() {
        _currentSource = source;
      });
      await _controller.openMedia(source);
    } finally {
      if (mounted) {
        setState(() {
          _isPicking = false;
        });
      }
    }
  }

  Future<void> _toggleAudioOutputMode() async {
    if (_controller.currentMediaPath == null) {
      return;
    }

    final nextMode = _controller.audioOutputMode == AudioOutputMode.original
        ? AudioOutputMode.accompaniment
        : AudioOutputMode.original;
    await _controller.applyAudioOutputMode(nextMode);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final videoView = _controller.buildVideoView();
        final hasSelection = _currentSource != null;
        return Scaffold(
          body: SafeArea(
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(
                  color: Colors.black,
                  child: hasSelection && videoView != null
                      ? SizedBox.expand(child: videoView)
                      : const _EmptyState(),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 960),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _ProgressSection(controller: _controller),
                          const SizedBox(height: 12),
                          _ControlSection(
                            controller: _controller,
                            onPickVideo: _pickAndPlay,
                            onToggleAudioMode: _toggleAudioOutputMode,
                            isPicking: _isPicking,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

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

class _ProgressSection extends StatelessWidget {
  const _ProgressSection({required this.controller});

  final PlayerController controller;

  @override
  Widget build(BuildContext context) {
    final hasMedia =
        controller.currentMediaPath != null &&
        controller.playbackDuration > Duration.zero;
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Text(
              _formatDuration(controller.playbackPosition),
              style: theme.textTheme.bodySmall,
            ),
            const Spacer(),
            Text(
              _formatDuration(controller.playbackDuration),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        Slider(
          value: hasMedia ? controller.playbackProgress : 0,
          onChanged: hasMedia ? controller.seekToProgress : null,
        ),
      ],
    );
  }
}

class _ControlSection extends StatelessWidget {
  const _ControlSection({
    required this.controller,
    required this.onPickVideo,
    required this.onToggleAudioMode,
    required this.isPicking,
  });

  final PlayerController controller;
  final Future<void> Function() onPickVideo;
  final Future<void> Function() onToggleAudioMode;
  final bool isPicking;

  @override
  Widget build(BuildContext context) {
    final hasMedia = controller.currentMediaPath != null;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        FilledButton.icon(
          onPressed: isPicking ? null : onPickVideo,
          icon: const Icon(Icons.folder_open),
          label: Text(isPicking ? '选择中' : '选择视频'),
        ),
        const SizedBox(width: 12),
        FilledButton.tonalIcon(
          onPressed: hasMedia ? onToggleAudioMode : null,
          icon: const Icon(Icons.mic_rounded),
          label: Text(
            controller.audioOutputMode == AudioOutputMode.accompaniment
                ? '原唱'
                : '伴唱',
          ),
        ),
        const SizedBox(width: 12),
        IconButton.filled(
          onPressed: hasMedia ? controller.togglePlayback : null,
          icon: Icon(
            controller.isPlaying ? Icons.pause_rounded : Icons.play_arrow,
          ),
        ),
      ],
    );
  }
}

String _formatDuration(Duration duration) {
  final totalSeconds = duration.inSeconds;
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  if (hours > 0) {
    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }
  return '${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')}';
}
