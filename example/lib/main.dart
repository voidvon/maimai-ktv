import 'package:flutter/material.dart';
import 'package:ktv2/ktv2.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const KtvPlayerExampleApp());
}

class KtvPlayerExampleApp extends StatelessWidget {
  const KtvPlayerExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'KTV Player Example',
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
    return Scaffold(
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            KtvPlayerView(
              controller: _controller,
              placeholder: const _EmptyState(),
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
                      KtvPlayerProgressBar(controller: _controller),
                      const SizedBox(height: 12),
                      KtvPlayerControlBar(
                        controller: _controller,
                        onOpenPressed: _pickAndPlay,
                        isOpening: _isPicking,
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
