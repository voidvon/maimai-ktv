import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ktv2/ktv2.dart';
import 'package:ktv2_example/features/ktv_demo/application/ktv_demo_controller.dart';
import 'package:ktv2_example/features/ktv_demo/presentation/ktv_demo_preview_coordinator.dart';

void main() {
  testWidgets('preview coordinator exposes preview surface and inert sync', (
    WidgetTester tester,
  ) async {
    final KtvDemoPreviewCoordinator coordinator = KtvDemoPreviewCoordinator(
      controller: _TestPlayerController(),
      routeResolver: () => DemoRoute.home,
    );
    addTearDown(() async {
      await coordinator.disposeCoordinator();
      coordinator.dispose();
    });

    expect(coordinator.isPreviewFullscreen, isFalse);
    expect(coordinator.previewViewportRect, isNull);
    expect(coordinator.sharedPreviewSurface, isA<Widget>());

    coordinator.schedulePreviewViewportSync();
    await tester.pump();
    expect(coordinator.isPreviewFullscreen, isFalse);
    expect(coordinator.previewViewportRect, isNull);
  });
}

class _TestPlayerController extends PlayerController {
  @override
  PlayerState get state => const PlayerState();

  @override
  Widget? buildVideoView() => const SizedBox.shrink();

  @override
  Future<void> openMedia(MediaSource source) async {}

  @override
  Future<void> seekToProgress(double progress) async {}

  @override
  Future<void> togglePlayback() async {}

  @override
  Future<void> applyAudioOutputMode(AudioOutputMode mode) async {}
}
