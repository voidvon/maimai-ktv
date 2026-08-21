import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ktv2/ktv2.dart';

class _FakePlayerController extends PlayerController {
  _FakePlayerController({
    required AudioOutputMode audioOutputMode,
    this.mediaPath,
  }) : _audioOutputMode = audioOutputMode;

  AudioOutputMode _audioOutputMode;
  final String? mediaPath;

  @override
  PlayerState get state => PlayerState(
    audioOutputMode: _audioOutputMode,
    currentMediaPath: mediaPath,
  );

  @override
  Future<void> applyAudioOutputMode(AudioOutputMode mode) async {
    _audioOutputMode = mode;
  }

  @override
  Widget? buildVideoView() => null;

  @override
  Future<void> openMedia(MediaSource source) async {}

  @override
  Future<void> seekToProgress(double progress) async {}

  @override
  Future<void> togglePlayback() async {}
}

void main() {
  test('toggleAudioOutputMode switches to accompaniment', () async {
    final controller = _FakePlayerController(
      audioOutputMode: AudioOutputMode.original,
      mediaPath: '/tmp/demo.mp4',
    );

    await controller.toggleAudioOutputMode();

    expect(controller.audioOutputMode, AudioOutputMode.accompaniment);
    expect(controller.hasMedia, isTrue);
  });

  test('toggleAudioOutputMode switches back to original', () async {
    final controller = _FakePlayerController(
      audioOutputMode: AudioOutputMode.accompaniment,
    );

    await controller.toggleAudioOutputMode();

    expect(controller.audioOutputMode, AudioOutputMode.original);
    expect(controller.hasMedia, isFalse);
  });
}
