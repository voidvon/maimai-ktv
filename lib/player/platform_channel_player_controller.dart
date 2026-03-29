import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../models/media_source.dart';
import 'audio_output_mode.dart';
import 'player_controller.dart';
import 'player_state.dart';

abstract class PlatformChannelPlayerController extends PlayerController {
  PlatformChannelPlayerController() {
    _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
      _handleEvent,
      onError: (Object error) {
        _playbackError = '$eventErrorPrefix：$error';
        notifyListeners();
      },
    );
  }

  static const MethodChannel _methodChannel = MethodChannel(
    'ktv/native_player',
  );
  static const EventChannel _eventChannel = EventChannel(
    'ktv/native_player_events',
  );

  late final StreamSubscription<dynamic> _eventSubscription;
  late final Widget _videoView = buildPlatformVideoView();

  String? _currentMediaPath;
  AudioOutputMode _audioOutputMode = AudioOutputMode.original;
  bool _isPreparingPlayback = false;
  bool _isPlaying = false;
  bool _isPlaybackCompleted = false;
  bool _hasVideoOutput = false;
  Duration _playbackPosition = Duration.zero;
  Duration _playbackDuration = Duration.zero;
  String? _playbackError;
  String? _playbackDiagnostics;
  int _videoTrackCount = 0;
  int _audioTrackCount = 0;
  String? _selectedAudioTrackTitle;
  int? _selectedAudioChannelCount;

  String get eventErrorPrefix;
  String get initializingDiagnostics;
  String get backendDisplayName;

  Widget buildPlatformVideoView();

  Future<void> validateMediaPath(String path) async {
    if (path.startsWith('content://')) {
      return;
    }

    final file = File(path);
    if (!await file.exists()) {
      throw FileSystemException('本地视频文件不存在', path);
    }
  }

  bool get showsSelectedTrackTitle => false;

  String describeSingleTrackAudioMode(int? channelCount) {
    return '单音轨文件，原唱播右声道，伴唱播左声道';
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
    videoTrackCount: _videoTrackCount,
    audioTrackCount: _audioTrackCount,
    audioModeDescription: _buildAudioModeDescription(),
    currentMediaPath: _currentMediaPath,
  );

  String _buildAudioModeDescription() {
    if (_currentMediaPath == null) {
      return '开始播放后可切换';
    }

    if (_audioTrackCount > 1) {
      final selectedTrackTitle = _selectedAudioTrackTitle;
      if (showsSelectedTrackTitle &&
          selectedTrackTitle != null &&
          selectedTrackTitle.trim().isNotEmpty) {
        return '$_audioTrackCount 条音轨，当前轨道：$selectedTrackTitle';
      }
      return '$_audioTrackCount 条音轨，按原唱/伴唱切换';
    }

    if (_audioTrackCount == 1) {
      return describeSingleTrackAudioMode(_selectedAudioChannelCount);
    }

    if (_isPreparingPlayback) {
      return '正在解析当前文件的音轨信息';
    }

    return '当前文件未识别到可切换音轨';
  }

  void _handleEvent(dynamic event) {
    if (event is! Map) {
      return;
    }
    _applySnapshot(Map<Object?, Object?>.from(event));
  }

  void _applySnapshot(Map<Object?, Object?> snapshot) {
    _isPlaying = snapshot['isPlaying'] == true;
    _isPlaybackCompleted = snapshot['isPlaybackCompleted'] == true;
    _hasVideoOutput = snapshot['hasVideoOutput'] == true;
    _playbackPosition = Duration(
      milliseconds: (snapshot['playbackPositionMs'] as num?)?.round() ?? 0,
    );
    _playbackDuration = Duration(
      milliseconds: (snapshot['playbackDurationMs'] as num?)?.round() ?? 0,
    );
    _videoTrackCount = (snapshot['videoTrackCount'] as num?)?.round() ?? 0;
    _audioTrackCount = (snapshot['audioTrackCount'] as num?)?.round() ?? 0;
    _selectedAudioTrackTitle = snapshot['selectedAudioTrackTitle'] as String?;
    _selectedAudioChannelCount = (snapshot['selectedAudioChannelCount'] as num?)
        ?.round();
    _playbackError = snapshot['playbackError'] as String?;
    _playbackDiagnostics = _buildDiagnostics();
    notifyListeners();
  }

  String? _buildDiagnostics() {
    if (_videoTrackCount == 0 && _audioTrackCount > 0) {
      return '当前文件只识别到音频轨，预览区不会出画面。';
    }

    if (_videoTrackCount > 0) {
      return '已识别到 $_videoTrackCount 条视频轨，当前使用 $backendDisplayName 播放。';
    }

    if (_isPreparingPlayback) {
      return initializingDiagnostics;
    }

    return '播放器尚未解析出可用媒体轨道。';
  }

  Future<Map<Object?, Object?>?> _invoke(
    String method, [
    Map<String, Object?>? arguments,
  ]) async {
    final result = await _methodChannel.invokeMethod<dynamic>(
      method,
      arguments,
    );
    if (result is Map) {
      return Map<Object?, Object?>.from(result);
    }
    return null;
  }

  @override
  Future<void> openMedia(MediaSource source) async {
    _currentMediaPath = source.path;
    _audioOutputMode = AudioOutputMode.original;
    _isPreparingPlayback = true;
    _isPlaybackCompleted = false;
    _isPlaying = false;
    _hasVideoOutput = false;
    _playbackPosition = Duration.zero;
    _playbackDuration = Duration.zero;
    _playbackError = null;
    _playbackDiagnostics = initializingDiagnostics;
    _videoTrackCount = 0;
    _audioTrackCount = 0;
    _selectedAudioTrackTitle = null;
    _selectedAudioChannelCount = null;
    notifyListeners();

    try {
      await validateMediaPath(source.path);

      final snapshot = await _invoke('open', {
        'path': source.path,
        'audioOutputMode': _audioOutputMode.name,
      });
      _isPreparingPlayback = false;
      if (snapshot != null) {
        _applySnapshot(snapshot);
        await _ensurePlayingAfterOpen();
      } else {
        _playbackDiagnostics = _buildDiagnostics();
        notifyListeners();
      }
    } catch (error) {
      _isPreparingPlayback = false;
      _isPlaying = false;
      _playbackError = '播放失败：$error';
      _playbackDiagnostics = _buildDiagnostics();
      notifyListeners();
    }
  }

  Future<void> _ensurePlayingAfterOpen() async {
    if (_currentMediaPath == null || _isPlaying || _playbackError != null) {
      return;
    }

    final snapshot = await _invoke('play');
    if (snapshot != null) {
      _applySnapshot(snapshot);
    }
  }

  @override
  Future<void> togglePlayback() async {
    if (_currentMediaPath == null) {
      return;
    }

    try {
      final snapshot = await _invoke(_isPlaying ? 'pause' : 'play');
      if (snapshot != null) {
        _applySnapshot(snapshot);
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

    final normalizedProgress = progress.clamp(0.0, 1.0);
    _isPlaybackCompleted = false;
    _playbackPosition = Duration(
      milliseconds: (_playbackDuration.inMilliseconds * normalizedProgress)
          .round(),
    );
    _playbackError = null;
    notifyListeners();

    try {
      final snapshot = await _invoke('seekToProgress', {
        'progress': normalizedProgress,
      });
      if (snapshot != null) {
        _applySnapshot(snapshot);
      }
    } catch (error) {
      _playbackError = '拖动进度失败：$error';
      notifyListeners();
    }
  }

  @override
  Future<void> applyAudioOutputMode(AudioOutputMode mode) async {
    _audioOutputMode = mode;
    notifyListeners();

    try {
      final snapshot = await _invoke('setAudioOutputMode', {'mode': mode.name});
      if (snapshot != null) {
        _applySnapshot(snapshot);
      }
    } catch (error) {
      _playbackError = '原唱/伴唱切换失败：$error';
      notifyListeners();
    }
  }

  @override
  Widget? buildVideoView() => _videoView;

  @override
  void dispose() {
    unawaited(_eventSubscription.cancel());
    unawaited(_methodChannel.invokeMethod<void>('dispose'));
    super.dispose();
  }
}
