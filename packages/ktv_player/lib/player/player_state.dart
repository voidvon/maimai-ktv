import 'audio_output_mode.dart';

class PlayerState {
  const PlayerState({
    this.audioOutputMode = AudioOutputMode.original,
    this.isPreparingPlayback = false,
    this.isPlaying = false,
    this.isPlaybackCompleted = false,
    this.hasVideoOutput = false,
    this.playbackPosition = Duration.zero,
    this.playbackDuration = Duration.zero,
    this.playbackError,
    this.playbackDiagnostics,
    this.videoTrackCount = 0,
    this.audioTrackCount = 0,
    this.audioModeDescription = '开始播放后可切换',
    this.currentMediaPath,
  });

  final AudioOutputMode audioOutputMode;
  final bool isPreparingPlayback;
  final bool isPlaying;
  final bool isPlaybackCompleted;
  final bool hasVideoOutput;
  final Duration playbackPosition;
  final Duration playbackDuration;
  final String? playbackError;
  final String? playbackDiagnostics;
  final int videoTrackCount;
  final int audioTrackCount;
  final String audioModeDescription;
  final String? currentMediaPath;

  double get playbackProgress {
    final durationMs = playbackDuration.inMilliseconds;
    if (durationMs <= 0) {
      return 0;
    }
    return (playbackPosition.inMilliseconds / durationMs).clamp(0.0, 1.0);
  }
}
