import '../audio_output_mode.dart';
import '../player_state.dart';
import 'native_player_snapshot.dart';

class PlatformPlayerStateStore {
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

  String? get currentMediaPath => _currentMediaPath;
  AudioOutputMode get audioOutputMode => _audioOutputMode;
  bool get isPreparingPlayback => _isPreparingPlayback;
  bool get isPlaying => _isPlaying;
  bool get hasVideoOutput => _hasVideoOutput;
  bool get isPlaybackCompleted => _isPlaybackCompleted;
  Duration get playbackPosition => _playbackPosition;
  Duration get playbackDuration => _playbackDuration;
  String? get playbackError => _playbackError;
  String? get playbackDiagnostics => _playbackDiagnostics;
  int get videoTrackCount => _videoTrackCount;
  int get audioTrackCount => _audioTrackCount;
  String? get selectedAudioTrackTitle => _selectedAudioTrackTitle;
  int? get selectedAudioChannelCount => _selectedAudioChannelCount;

  PlayerState toPlayerState({required String audioModeDescription}) {
    return PlayerState(
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
      audioModeDescription: audioModeDescription,
      currentMediaPath: _currentMediaPath,
    );
  }

  void resetForOpen({
    required String mediaPath,
    required String initializingDiagnostics,
  }) {
    _currentMediaPath = mediaPath;
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
  }

  void applySnapshot(NativePlayerSnapshot snapshot) {
    _isPlaying = snapshot.isPlaying;
    _isPlaybackCompleted = snapshot.isPlaybackCompleted;
    _hasVideoOutput = snapshot.hasVideoOutput;
    _playbackPosition = snapshot.playbackPosition;
    _playbackDuration = snapshot.playbackDuration;
    _videoTrackCount = snapshot.videoTrackCount;
    _audioTrackCount = snapshot.audioTrackCount;
    _selectedAudioTrackTitle = snapshot.selectedAudioTrackTitle;
    _selectedAudioChannelCount = snapshot.selectedAudioChannelCount;
    _playbackError = snapshot.playbackError;
  }

  bool applyProgressUpdate({
    required Duration playbackPosition,
    required Duration playbackDuration,
  }) {
    if (_playbackPosition == playbackPosition &&
        _playbackDuration == playbackDuration) {
      return false;
    }
    _playbackPosition = playbackPosition;
    _playbackDuration = playbackDuration;
    return true;
  }

  void applyLocalSeekPreview(double normalizedProgress) {
    _isPlaybackCompleted = false;
    _playbackPosition = Duration(
      milliseconds: (_playbackDuration.inMilliseconds * normalizedProgress)
          .round(),
    );
    _playbackError = null;
  }

  void setPreparingPlayback(bool value) {
    _isPreparingPlayback = value;
  }

  void setAudioOutputMode(AudioOutputMode mode) {
    _audioOutputMode = mode;
  }

  void setPlaybackError(String? error) {
    _playbackError = error;
  }

  void setPlaybackDiagnostics(String? diagnostics) {
    _playbackDiagnostics = diagnostics;
  }

  void setPlaying(bool value) {
    _isPlaying = value;
  }

  void clearMedia() {
    _currentMediaPath = null;
    _isPreparingPlayback = false;
    _isPlaying = false;
    _isPlaybackCompleted = false;
    _hasVideoOutput = false;
    _playbackPosition = Duration.zero;
    _playbackDuration = Duration.zero;
    _playbackError = null;
    _playbackDiagnostics = null;
    _videoTrackCount = 0;
    _audioTrackCount = 0;
    _selectedAudioTrackTitle = null;
    _selectedAudioChannelCount = null;
  }
}
