import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ktv2/ktv2.dart';

import '../application/ktv_demo_controller.dart';
import 'shared_widgets.dart';

class KtvDemoPreviewCoordinator extends ChangeNotifier {
  KtvDemoPreviewCoordinator({
    required PlayerController controller,
    required DemoRoute Function() routeResolver,
    MethodChannel orientationChannel = const MethodChannel(
      'ktv2_example/orientation',
    ),
  }) : _orientationChannel = orientationChannel {
    sharedPreviewSurface = PersistentPreviewSurface(
      key: previewSurfaceKey,
      controller: controller,
      routeResolver: routeResolver,
    );
  }

  final MethodChannel _orientationChannel;

  final GlobalKey shellStackKey = GlobalKey();
  final GlobalKey previewSurfaceKey = GlobalKey();
  final GlobalKey previewAnchorKey = GlobalKey();

  late final Widget sharedPreviewSurface;

  bool? _statusBarHiddenInLandscape;
  bool _isPreviewFullscreen = false;
  Rect? _previewViewportRect;
  bool _didSchedulePreviewViewportSync = false;

  bool get isPreviewFullscreen => _isPreviewFullscreen;
  Rect? get previewViewportRect => _previewViewportRect;

  Future<void> disposeCoordinator() async {
    if (_isPreviewFullscreen || _statusBarHiddenInLandscape == true) {
      await SystemChrome.setPreferredOrientations(<DeviceOrientation>[]);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  void syncSystemStatusBarForOrientation(Orientation orientation) {
    if (_isPreviewFullscreen) {
      return;
    }
    final bool shouldHideStatusBar = orientation == Orientation.landscape;
    if (_statusBarHiddenInLandscape == shouldHideStatusBar) {
      return;
    }
    _statusBarHiddenInLandscape = shouldHideStatusBar;
    if (shouldHideStatusBar) {
      unawaited(
        SystemChrome.setEnabledSystemUIMode(
          SystemUiMode.manual,
          overlays: <SystemUiOverlay>[SystemUiOverlay.bottom],
        ),
      );
      return;
    }
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
  }

  void schedulePreviewViewportSync() {
    if (_didSchedulePreviewViewportSync) {
      return;
    }
    _didSchedulePreviewViewportSync = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _didSchedulePreviewViewportSync = false;
      _syncPreviewViewportRect();
    });
  }

  Future<void> enterPreviewFullscreen() {
    return _setPreviewFullscreen(enabled: true);
  }

  Future<void> exitPreviewFullscreen({Orientation? restoredOrientation}) {
    return _setPreviewFullscreen(
      enabled: false,
      restoredOrientation: restoredOrientation,
    );
  }

  Future<void> _setPreviewFullscreen({
    required bool enabled,
    Orientation? restoredOrientation,
  }) async {
    if (_isPreviewFullscreen == enabled) {
      return;
    }
    _isPreviewFullscreen = enabled;
    if (!enabled) {
      _statusBarHiddenInLandscape = null;
    }
    notifyListeners();
    schedulePreviewViewportSync();

    if (enabled) {
      await _setPlatformFullscreenOrientation(enabled: true);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      return;
    }

    await _setPlatformFullscreenOrientation(enabled: false);
    await SystemChrome.setPreferredOrientations(<DeviceOrientation>[]);
    if (restoredOrientation != null) {
      syncSystemStatusBarForOrientation(restoredOrientation);
    }
  }

  Future<void> _setPlatformFullscreenOrientation({
    required bool enabled,
  }) async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    try {
      await _orientationChannel.invokeMethod<void>(
        enabled ? 'enterVideoFullscreen' : 'exitVideoFullscreen',
      );
    } on MissingPluginException {
      // Android-only channel; fall back to SystemChrome when unavailable.
    } on PlatformException {
      // Keep fullscreen flow alive even if the platform request fails.
    }
  }

  void _syncPreviewViewportRect() {
    final BuildContext? stackContext = shellStackKey.currentContext;
    if (stackContext == null) {
      return;
    }
    final RenderObject? stackRenderObject = stackContext.findRenderObject();
    if (stackRenderObject is! RenderBox) {
      return;
    }

    Rect? nextRect;
    if (_isPreviewFullscreen) {
      nextRect = _resolveFullscreenPreviewRect(stackRenderObject.size);
    } else {
      final BuildContext? anchorContext = previewAnchorKey.currentContext;
      final RenderObject? anchorRenderObject = anchorContext
          ?.findRenderObject();
      if (anchorRenderObject is! RenderBox) {
        return;
      }
      final Offset topLeft = anchorRenderObject.localToGlobal(
        Offset.zero,
        ancestor: stackRenderObject,
      );
      nextRect = topLeft & anchorRenderObject.size;
    }

    if (_previewViewportRect == nextRect) {
      return;
    }
    _previewViewportRect = nextRect;
    notifyListeners();
  }

  Rect _resolveFullscreenPreviewRect(Size containerSize) {
    const double targetAspectRatio = 16 / 9;
    final double containerAspectRatio =
        containerSize.width / containerSize.height;

    if (containerAspectRatio > targetAspectRatio) {
      final double height = containerSize.height;
      final double width = height * targetAspectRatio;
      return Rect.fromLTWH((containerSize.width - width) / 2, 0, width, height);
    }

    final double width = containerSize.width;
    final double height = width / targetAspectRatio;
    return Rect.fromLTWH(0, (containerSize.height - height) / 2, width, height);
  }
}
