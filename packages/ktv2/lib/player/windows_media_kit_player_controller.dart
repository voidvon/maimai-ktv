import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:media_kit/media_kit.dart' as media_kit;
import 'package:media_kit_video/media_kit_video.dart';

import '../models/media_source.dart';
import 'audio_output_mode.dart';
import 'player_controller.dart';
import 'player_state.dart';

class WindowsMediaKitPlayerController extends PlayerController {
  WindowsMediaKitPlayerController() {
    _ensureMediaKitInitialized();
    _player = media_kit.Player();
    _videoController = VideoController(_player);
    _subscriptions.addAll(<StreamSubscription<dynamic>>[
      _player.stream.playing.listen((bool value) {
        _isPlaying = value;
        _updatePlaybackDiagnostics();
        notifyListeners();
      }),
      _player.stream.completed.listen((bool value) {
        _isPlaybackCompleted = value;
        notifyListeners();
      }),
      _player.stream.position.listen((Duration value) {
        _playbackPosition = value;
        notifyListeners();
      }),
      _player.stream.duration.listen((Duration value) {
        _playbackDuration = value;
        notifyListeners();
      }),
      _player.stream.tracks.listen((media_kit.Tracks value) {
        _availableTracks = value;
        _refreshTrackMetadata();
        unawaited(_syncAudioOutputMode(reportUnsupported: false));
      }),
      _player.stream.track.listen((media_kit.Track value) {
        _selectedTrack = value;
        _refreshTrackMetadata();
      }),
      _player.stream.width.listen((int? value) {
        _videoWidth = value;
        _refreshTrackMetadata();
      }),
      _player.stream.height.listen((int? value) {
        _videoHeight = value;
        _refreshTrackMetadata();
      }),
      _player.stream.error.listen((String value) {
        _playbackError = value.trim().isEmpty ? null : value;
        notifyListeners();
      }),
    ]);
  }

  static bool _didInitializeMediaKit = false;

  static void _ensureMediaKitInitialized() {
    if (_didInitializeMediaKit) {
      return;
    }
    media_kit.MediaKit.ensureInitialized();
    _didInitializeMediaKit = true;
  }

  late final media_kit.Player _player;
  late final VideoController _videoController;
  final List<StreamSubscription<dynamic>> _subscriptions =
      <StreamSubscription<dynamic>>[];

  String? _currentMediaPath;
  AudioOutputMode _audioOutputMode = AudioOutputMode.original;
  bool _isPreparingPlayback = false;
  bool _isPlaying = false;
  bool _isPlaybackCompleted = false;
  Duration _playbackPosition = Duration.zero;
  Duration _playbackDuration = Duration.zero;
  String? _playbackError;
  String? _playbackDiagnostics;
  media_kit.Tracks _availableTracks = const media_kit.Tracks();
  media_kit.Track _selectedTrack = const media_kit.Track();
  int? _videoWidth;
  int? _videoHeight;

  List<media_kit.VideoTrack> get _actualVideoTracks => _availableTracks.video
      .where((media_kit.VideoTrack track) => !_isSyntheticTrack(track.id))
      .toList(growable: false);

  List<media_kit.AudioTrack> get _actualAudioTracks => _availableTracks.audio
      .where((media_kit.AudioTrack track) => !_isSyntheticTrack(track.id))
      .toList(growable: false);

  bool get _hasVideoOutput =>
      _actualVideoTracks.isNotEmpty ||
      ((_videoWidth ?? 0) > 0 && (_videoHeight ?? 0) > 0);

  String _buildAudioModeDescription() {
    if (_currentMediaPath == null) {
      return '开始播放后可切换';
    }
    if (_actualAudioTracks.length > 1) {
      final String? title = _selectedTrack.audio.title?.trim();
      if (title != null && title.isNotEmpty) {
        return '${_actualAudioTracks.length} 条音轨，当前轨道：$title';
      }
      return '${_actualAudioTracks.length} 条音轨，按原唱/伴唱切换';
    }
    if (_actualAudioTracks.length == 1) {
      return 'Windows 当前仅支持多音轨切换，单音轨文件暂不支持左右声道分离。';
    }
    if (_isPreparingPlayback) {
      return '正在解析当前文件的音轨信息';
    }
    return '当前文件未识别到可切换音轨';
  }

  void _updatePlaybackDiagnostics() {
    if (_currentMediaPath == null) {
      _playbackDiagnostics = null;
      return;
    }
    if (_actualVideoTracks.isEmpty && _actualAudioTracks.isNotEmpty) {
      _playbackDiagnostics = '当前文件只识别到音频轨，预览区不会出画面。';
      return;
    }
    if (_actualVideoTracks.isNotEmpty) {
      _playbackDiagnostics =
          '已识别到 ${_actualVideoTracks.length} 条视频轨，当前使用 Windows Media Kit 播放。';
      return;
    }
    if (_isPreparingPlayback) {
      _playbackDiagnostics = '正在初始化 Windows 播放器并解析媒体轨道。';
      return;
    }
    _playbackDiagnostics = '播放器尚未解析出可用媒体轨道。';
  }

  void _refreshTrackMetadata() {
    _updatePlaybackDiagnostics();
    notifyListeners();
  }

  @override
  PlayerState get state => PlayerState(
    audioOutputMode: _audioOutputMode,
    isPreparingPlayback: _isPreparingPlayback,
    isPlaying: _isPlaying,
    isPlaybackCompleted: _isPlaybackCompleted,
    hasVideoOutput: _hasVideoOutput,
    playbackPosition: _playbackPosition,
    playbackDuration: _playbackDuration,
    playbackError: _playbackError,
    playbackDiagnostics: _playbackDiagnostics,
    videoTrackCount: _actualVideoTracks.length,
    audioTrackCount: _actualAudioTracks.length,
    audioModeDescription: _buildAudioModeDescription(),
    currentMediaPath: _currentMediaPath,
  );

  @override
  Future<void> openMedia(MediaSource source) async {
    final File file = File(source.path);
    if (!await file.exists()) {
      throw FileSystemException('本地视频文件不存在', source.path);
    }

    _currentMediaPath = source.path;
    _isPreparingPlayback = true;
    _isPlaying = false;
    _isPlaybackCompleted = false;
    _playbackPosition = Duration.zero;
    _playbackDuration = Duration.zero;
    _playbackError = null;
    _availableTracks = const media_kit.Tracks();
    _selectedTrack = const media_kit.Track();
    _videoWidth = null;
    _videoHeight = null;
    _updatePlaybackDiagnostics();
    notifyListeners();

    try {
      await _player.open(media_kit.Media(source.path), play: true);
      _isPreparingPlayback = false;
      await _syncAudioOutputMode(reportUnsupported: false);
      _updatePlaybackDiagnostics();
      notifyListeners();
    } catch (error) {
      _isPreparingPlayback = false;
      _isPlaying = false;
      _playbackError = '播放失败：$error';
      _updatePlaybackDiagnostics();
      notifyListeners();
    }
  }

  @override
  Future<void> togglePlayback() async {
    if (_currentMediaPath == null) {
      return;
    }
    try {
      if (_isPlaying) {
        await _player.pause();
      } else {
        await _player.play();
      }
    } catch (error) {
      _playbackError = '切换播放状态失败：$error';
      notifyListeners();
    }
  }

  @override
  Future<void> seekToProgress(double progress) async {
    if (_currentMediaPath == null || _playbackDuration <= Duration.zero) {
      return;
    }

    final double normalizedProgress = progress.clamp(0.0, 1.0);
    _playbackPosition = Duration(
      milliseconds: (_playbackDuration.inMilliseconds * normalizedProgress)
          .round(),
    );
    _isPlaybackCompleted = false;
    notifyListeners();

    try {
      await _player.seek(_playbackPosition);
    } catch (error) {
      _playbackError = '拖动进度失败：$error';
      notifyListeners();
    }
  }

  @override
  Future<void> applyAudioOutputMode(AudioOutputMode mode) async {
    if (_audioOutputMode == mode) {
      return;
    }
    _audioOutputMode = mode;
    await _syncAudioOutputMode(reportUnsupported: true);
    notifyListeners();
  }

  Future<void> _syncAudioOutputMode({required bool reportUnsupported}) async {
    final List<media_kit.AudioTrack> tracks = _actualAudioTracks;
    if (tracks.isEmpty) {
      return;
    }
    if (tracks.length == 1) {
      if (_audioOutputMode == AudioOutputMode.accompaniment &&
          reportUnsupported) {
        _audioOutputMode = AudioOutputMode.original;
        _playbackError = 'Windows 版当前仅支持多音轨切换，单音轨文件暂不支持原唱/伴唱分离。';
      }
      return;
    }

    final int targetIndex = _audioOutputMode == AudioOutputMode.original
        ? 0
        : 1;
    final media_kit.AudioTrack targetTrack =
        tracks[targetIndex.clamp(0, tracks.length - 1)];
    if (_selectedTrack.audio.id == targetTrack.id) {
      return;
    }

    try {
      _playbackError = null;
      await _player.setAudioTrack(targetTrack);
    } catch (error) {
      _playbackError = '原唱/伴唱切换失败：$error';
      notifyListeners();
    }
  }

  @override
  Future<void> clearMedia() async {
    if (_currentMediaPath == null) {
      return;
    }
    try {
      await _player.stop();
    } catch (error) {
      _playbackError = '清空播放器失败：$error';
      notifyListeners();
      return;
    }

    _currentMediaPath = null;
    _isPreparingPlayback = false;
    _isPlaying = false;
    _isPlaybackCompleted = false;
    _playbackPosition = Duration.zero;
    _playbackDuration = Duration.zero;
    _playbackError = null;
    _playbackDiagnostics = null;
    _availableTracks = const media_kit.Tracks();
    _selectedTrack = const media_kit.Track();
    _videoWidth = null;
    _videoHeight = null;
    notifyListeners();
  }

  @override
  Widget? buildVideoView() {
    return Video(
      controller: _videoController,
      controls: NoVideoControls,
      pauseUponEnteringBackgroundMode: false,
      resumeUponEnteringForegroundMode: false,
    );
  }

  @override
  void dispose() {
    for (final StreamSubscription<dynamic> subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    unawaited(_player.dispose());
    super.dispose();
  }

  static bool _isSyntheticTrack(String id) => id == 'auto' || id == 'no';
}
