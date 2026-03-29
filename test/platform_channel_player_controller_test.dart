import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ktv2/ktv2.dart';
import 'package:ktv2/player/platform_channel_player_controller.dart';

class _TestPlatformChannelPlayerController
    extends PlatformChannelPlayerController {
  @override
  String get eventErrorPrefix => 'test event error';

  @override
  String get initializingDiagnostics => 'initializing';

  @override
  String get backendDisplayName => 'test backend';

  @override
  Widget buildPlatformVideoView() => const SizedBox.shrink();

  @override
  Future<void> validateMediaPath(String path) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel methodChannel = MethodChannel('ktv/native_player');
  const MethodChannel eventChannel = MethodChannel('ktv/native_player_events');
  final List<MethodCall> methodCalls = <MethodCall>[];

  setUp(() {
    methodCalls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, (MethodCall call) async {
          methodCalls.add(call);
          if (call.method == 'open') {
            return <String, Object?>{
              'isPlaying': false,
              'isPlaybackCompleted': false,
              'hasVideoOutput': false,
              'playbackPositionMs': 0,
              'playbackDurationMs': 0,
              'videoTrackCount': 0,
              'audioTrackCount': 1,
              'selectedAudioChannelCount': 2,
            };
          }
          return null;
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          eventChannel,
          (MethodCall call) async => null,
        );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(eventChannel, null);
  });

  test('openMedia resets audio mode to original before opening', () async {
    final controller = _TestPlatformChannelPlayerController();

    await controller.applyAudioOutputMode(AudioOutputMode.accompaniment);
    expect(controller.audioOutputMode, AudioOutputMode.accompaniment);

    await controller.openMedia(
      const MediaSource(path: '/tmp/demo.mp4', displayName: 'demo'),
    );

    expect(controller.audioOutputMode, AudioOutputMode.original);
    expect(methodCalls, isNotEmpty);
    expect(methodCalls.last.method, 'open');
    expect(
      methodCalls.last.arguments,
      containsPair('audioOutputMode', AudioOutputMode.original.name),
    );

    controller.dispose();
  });
}
