import 'package:flutter/widgets.dart';

import '../models/media_source.dart';
import 'audio_output_mode.dart';
import 'player_state.dart';

abstract class PlayerController extends ChangeNotifier {
  static const int minPitchShiftSemitones = -6;
  static const int maxPitchShiftSemitones = 6;

  PlayerState get state;
  Listenable get videoViewListenable => this;

  AudioOutputMode get audioOutputMode => state.audioOutputMode;
  bool get hasMedia => currentMediaPath != null;
  bool get isPreparingPlayback => state.isPreparingPlayback;
  bool get isPlaying => state.isPlaying;
  bool get isPlaybackCompleted => state.isPlaybackCompleted;
  bool get hasVideoOutput => state.hasVideoOutput;
  Duration get playbackPosition => state.playbackPosition;
  Duration get playbackDuration => state.playbackDuration;
  double get playbackProgress => state.playbackProgress;
  String? get playbackError => state.playbackError;
  String? get playbackDiagnostics => state.playbackDiagnostics;
  int get videoTrackCount => state.videoTrackCount;
  int get audioTrackCount => state.audioTrackCount;
  int get pitchShiftSemitones => state.pitchShiftSemitones;
  String get audioModeDescription => state.audioModeDescription;
  String? get currentMediaPath => state.currentMediaPath;

  Future<void> openMedia(MediaSource source);
  Future<void> togglePlayback();
  Future<void> stopPlayback() async {
    if (currentMediaPath == null) {
      return;
    }
    if (isPlaying) {
      await togglePlayback();
    }
    await seekToProgress(0);
  }

  Future<void> clearMedia() async {
    await stopPlayback();
  }

  Future<void> seekToProgress(double progress);
  Future<void> applyAudioOutputMode(AudioOutputMode mode);
  Future<void> setPitchShiftSemitones(int semitones);
  Widget? buildVideoView();

  Future<void> shiftPitchBy(int semitones) {
    return setPitchShiftSemitones(pitchShiftSemitones + semitones);
  }

  Future<void> resetPitchShift() => setPitchShiftSemitones(0);

  Future<void> toggleAudioOutputMode() {
    final nextMode = audioOutputMode == AudioOutputMode.original
        ? AudioOutputMode.accompaniment
        : AudioOutputMode.original;
    return applyAudioOutputMode(nextMode);
  }
}
