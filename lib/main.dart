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

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final colorScheme = Theme.of(context).colorScheme;
        final videoView = _controller.buildVideoView();
        return Scaffold(
          appBar: AppBar(
            title: const Text('KTV Player'),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: FilledButton.tonalIcon(
                  onPressed: _isPicking ? null : _pickAndPlay,
                  icon: const Icon(Icons.video_library_outlined),
                  label: Text(_isPicking ? '选择中' : '选择视频'),
                ),
              ),
            ],
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: colorScheme.outlineVariant),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ?videoView,
                            if (_controller.currentMediaPath == null)
                              const _EmptyState(),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _InfoCard(
                    currentSource: _currentSource,
                    controller: _controller,
                  ),
                  const SizedBox(height: 12),
                  _ProgressCard(controller: _controller),
                  const SizedBox(height: 12),
                  _ControlCard(
                    controller: _controller,
                    onPickVideo: _pickAndPlay,
                    isPicking: _isPicking,
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
          SizedBox(height: 4),
          Text('已保留播放器与完整原唱/伴唱切换逻辑', style: TextStyle(color: Colors.white38)),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.currentSource, required this.controller});

  final MediaSource? currentSource;
  final PlayerController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              currentSource?.displayName ?? '未选择视频',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              controller.audioModeDescription,
              style: theme.textTheme.bodyMedium,
            ),
            if (controller.playbackDiagnostics case final diagnostics?)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  diagnostics,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            if (controller.playbackError case final error?)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  error,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.controller});

  final PlayerController controller;

  @override
  Widget build(BuildContext context) {
    final hasMedia =
        controller.currentMediaPath != null &&
        controller.playbackDuration > Duration.zero;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          children: [
            Row(
              children: [
                Text(_formatDuration(controller.playbackPosition)),
                const Spacer(),
                Text(_formatDuration(controller.playbackDuration)),
              ],
            ),
            Slider(
              value: hasMedia ? controller.playbackProgress : 0,
              onChanged: hasMedia ? controller.seekToProgress : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _ControlCard extends StatelessWidget {
  const _ControlCard({
    required this.controller,
    required this.onPickVideo,
    required this.isPicking,
  });

  final PlayerController controller;
  final Future<void> Function() onPickVideo;
  final bool isPicking;

  @override
  Widget build(BuildContext context) {
    final hasMedia = controller.currentMediaPath != null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilledButton.tonalIcon(
              onPressed: isPicking ? null : onPickVideo,
              icon: const Icon(Icons.folder_open),
              label: const Text('选择视频'),
            ),
            FilledButton.icon(
              onPressed: hasMedia ? controller.togglePlayback : null,
              icon: Icon(
                controller.isPlaying ? Icons.pause_rounded : Icons.play_arrow,
              ),
              label: Text(controller.isPlaying ? '暂停' : '播放'),
            ),
            SegmentedButton<AudioOutputMode>(
              segments: const [
                ButtonSegment(
                  value: AudioOutputMode.original,
                  label: Text('原唱'),
                  icon: Icon(Icons.mic),
                ),
                ButtonSegment(
                  value: AudioOutputMode.accompaniment,
                  label: Text('伴唱'),
                  icon: Icon(Icons.music_note),
                ),
              ],
              selected: {controller.audioOutputMode},
              onSelectionChanged: hasMedia
                  ? (selection) =>
                        controller.applyAudioOutputMode(selection.first)
                  : null,
            ),
          ],
        ),
      ),
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
