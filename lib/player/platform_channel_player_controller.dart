import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';

import '../models/media_source.dart';
import 'audio_output_mode.dart';
import 'platform_channel/native_player_channels.dart';
import 'platform_channel/native_player_snapshot.dart';
import 'platform_channel/platform_player_state_store.dart';
import 'player_controller.dart';
import 'player_state.dart';

abstract class PlatformChannelPlayerController extends PlayerController {
  PlatformChannelPlayerController({
    NativePlayerChannels channels = const NativePlayerChannels(),
  }) : _channels = channels {
    _eventSubscription = _channels.receiveEvents().listen(
      _handleEvent,
      onError: (Object error) {
        _stateStore.setPlaybackError('$eventErrorPrefix：$error');
        notifyListeners();
      },
    );
  }

  final NativePlayerChannels _channels;
  final PlatformPlayerStateStore _stateStore = PlatformPlayerStateStore();
  late final StreamSubscription<dynamic> _eventSubscription;
  late final Widget _videoView = buildPlatformVideoView();

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
  PlayerState get state => _stateStore.toPlayerState(
    audioModeDescription: _buildAudioModeDescription(),
  );

  String _buildAudioModeDescription() {
    if (_stateStore.currentMediaPath == null) {
      return '开始播放后可切换';
    }

    if (_stateStore.audioTrackCount > 1) {
      final selectedTrackTitle = _stateStore.selectedAudioTrackTitle;
      if (showsSelectedTrackTitle &&
          selectedTrackTitle != null &&
          selectedTrackTitle.trim().isNotEmpty) {
        return '${_stateStore.audioTrackCount} 条音轨，当前轨道：$selectedTrackTitle';
      }
      return '${_stateStore.audioTrackCount} 条音轨，按原唱/伴唱切换';
    }

    if (_stateStore.audioTrackCount == 1) {
      return describeSingleTrackAudioMode(
        _stateStore.selectedAudioChannelCount,
      );
    }

    if (_stateStore.isPreparingPlayback) {
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
    _stateStore.applySnapshot(NativePlayerSnapshot.fromMap(snapshot));
    _stateStore.setPlaybackDiagnostics(_buildDiagnostics());
    notifyListeners();
  }

  String? _buildDiagnostics() {
    if (_stateStore.videoTrackCount == 0 && _stateStore.audioTrackCount > 0) {
      return '当前文件只识别到音频轨，预览区不会出画面。';
    }

    if (_stateStore.videoTrackCount > 0) {
      return '已识别到 ${_stateStore.videoTrackCount} 条视频轨，当前使用 $backendDisplayName 播放。';
    }

    if (_stateStore.isPreparingPlayback) {
      return initializingDiagnostics;
    }

    return '播放器尚未解析出可用媒体轨道。';
  }

  @override
  Future<void> openMedia(MediaSource source) async {
    _stateStore.resetForOpen(
      mediaPath: source.path,
      initializingDiagnostics: initializingDiagnostics,
    );
    notifyListeners();

    try {
      await validateMediaPath(source.path);

      final snapshot = await _channels.invoke('open', {
        'path': source.path,
        'audioOutputMode': _stateStore.audioOutputMode.name,
      });
      _stateStore.setPreparingPlayback(false);
      if (snapshot != null) {
        _applySnapshot(snapshot);
        await _ensurePlayingAfterOpen();
      } else {
        _stateStore.setPlaybackDiagnostics(_buildDiagnostics());
        notifyListeners();
      }
    } catch (error) {
      _stateStore.setPreparingPlayback(false);
      _stateStore.setPlaying(false);
      _stateStore.setPlaybackError('播放失败：$error');
      _stateStore.setPlaybackDiagnostics(_buildDiagnostics());
      notifyListeners();
    }
  }

  Future<void> _ensurePlayingAfterOpen() async {
    if (_stateStore.currentMediaPath == null ||
        _stateStore.isPlaying ||
        _stateStore.playbackError != null) {
      return;
    }

    final snapshot = await _channels.invoke('play');
    if (snapshot != null) {
      _applySnapshot(snapshot);
    }
  }

  @override
  Future<void> togglePlayback() async {
    if (_stateStore.currentMediaPath == null) {
      return;
    }

    try {
      final snapshot = await _channels.invoke(
        _stateStore.isPlaying ? 'pause' : 'play',
      );
      if (snapshot != null) {
        _applySnapshot(snapshot);
      }
    } catch (error) {
      _stateStore.setPlaybackError('切换播放状态失败：$error');
      notifyListeners();
    }
  }

  @override
  Future<void> seekToProgress(double progress) async {
    if (_stateStore.currentMediaPath == null ||
        _stateStore.playbackDuration <= Duration.zero) {
      return;
    }

    final normalizedProgress = progress.clamp(0.0, 1.0);
    _stateStore.applyLocalSeekPreview(normalizedProgress);
    notifyListeners();

    try {
      final snapshot = await _channels.invoke('seekToProgress', {
        'progress': normalizedProgress,
      });
      if (snapshot != null) {
        _applySnapshot(snapshot);
      }
    } catch (error) {
      _stateStore.setPlaybackError('拖动进度失败：$error');
      notifyListeners();
    }
  }

  @override
  Future<void> applyAudioOutputMode(AudioOutputMode mode) async {
    _stateStore.setAudioOutputMode(mode);
    notifyListeners();

    try {
      final snapshot = await _channels.invoke('setAudioOutputMode', {
        'mode': mode.name,
      });
      if (snapshot != null) {
        _applySnapshot(snapshot);
      }
    } catch (error) {
      _stateStore.setPlaybackError('原唱/伴唱切换失败：$error');
      notifyListeners();
    }
  }

  @override
  Widget? buildVideoView() => _videoView;

  @override
  void dispose() {
    unawaited(_eventSubscription.cancel());
    unawaited(_channels.disposePlayer());
    super.dispose();
  }
}
