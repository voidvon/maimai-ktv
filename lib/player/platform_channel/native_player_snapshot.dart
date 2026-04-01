class NativePlayerSnapshot {
  const NativePlayerSnapshot({
    required this.isPlaying,
    required this.isPlaybackCompleted,
    required this.hasVideoOutput,
    required this.playbackPosition,
    required this.playbackDuration,
    required this.videoTrackCount,
    required this.audioTrackCount,
    required this.selectedAudioTrackTitle,
    required this.selectedAudioChannelCount,
    required this.playbackError,
  });

  factory NativePlayerSnapshot.fromMap(Map<Object?, Object?> snapshot) {
    return NativePlayerSnapshot(
      isPlaying: snapshot['isPlaying'] == true,
      isPlaybackCompleted: snapshot['isPlaybackCompleted'] == true,
      hasVideoOutput: snapshot['hasVideoOutput'] == true,
      playbackPosition: Duration(
        milliseconds: (snapshot['playbackPositionMs'] as num?)?.round() ?? 0,
      ),
      playbackDuration: Duration(
        milliseconds: (snapshot['playbackDurationMs'] as num?)?.round() ?? 0,
      ),
      videoTrackCount: (snapshot['videoTrackCount'] as num?)?.round() ?? 0,
      audioTrackCount: (snapshot['audioTrackCount'] as num?)?.round() ?? 0,
      selectedAudioTrackTitle: snapshot['selectedAudioTrackTitle'] as String?,
      selectedAudioChannelCount: (snapshot['selectedAudioChannelCount'] as num?)
          ?.round(),
      playbackError: snapshot['playbackError'] as String?,
    );
  }

  final bool isPlaying;
  final bool isPlaybackCompleted;
  final bool hasVideoOutput;
  final Duration playbackPosition;
  final Duration playbackDuration;
  final int videoTrackCount;
  final int audioTrackCount;
  final String? selectedAudioTrackTitle;
  final int? selectedAudioChannelCount;
  final String? playbackError;
}
