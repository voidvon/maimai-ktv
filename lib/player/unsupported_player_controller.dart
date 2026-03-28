import 'package:flutter/widgets.dart';

import '../models/media_source.dart';
import 'audio_output_mode.dart';
import 'player_controller.dart';
import 'player_state.dart';

class UnsupportedPlayerController extends PlayerController {
  static const PlayerState _state = PlayerState(
    playbackError: '当前平台未接入原生 VLC 播放器。',
    playbackDiagnostics: '当前抽取工程仅实现 Android 播放与声道切换。',
  );

  @override
  PlayerState get state => _state;

  @override
  Future<void> applyAudioOutputMode(AudioOutputMode mode) async {}

  @override
  Widget? buildVideoView() => null;

  @override
  Future<void> openMedia(MediaSource source) async {}

  @override
  Future<void> seekToProgress(double progress) async {}

  @override
  Future<void> togglePlayback() async {}
}
