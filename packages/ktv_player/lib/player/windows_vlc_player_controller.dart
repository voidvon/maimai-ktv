import 'dart:async';

import 'package:flutter/widgets.dart';

import 'platform_channel/native_player_channels.dart';
import 'platform_channel_player_controller.dart';

class WindowsVlcPlayerController extends PlatformChannelPlayerController {
  WindowsVlcPlayerController({
    super.channels = const NativePlayerChannels(),
  });

  @override
  String get eventErrorPrefix => 'Windows 原生 VLC 播放器事件异常';

  @override
  String get initializingDiagnostics => '正在初始化 Windows 原生 VLC 播放器。';

  @override
  String get backendDisplayName => 'Windows 原生 libVLC';

  @override
  bool get showsSelectedTrackTitle => true;

  @override
  String describeSingleTrackAudioMode(int? channelCount) {
    if ((channelCount ?? 2) >= 2) {
      return '单音轨文件，原唱播右声道，伴唱播左声道';
    }
    return '当前文件为单声道，无法拆分原唱/伴唱';
  }

  @override
  Widget buildPlatformVideoView() {
    return _WindowsVlcVideoView(channels: channels);
  }
}

class _WindowsVlcVideoView extends StatefulWidget {
  const _WindowsVlcVideoView({required this.channels});

  final NativePlayerChannels channels;

  @override
  State<_WindowsVlcVideoView> createState() => _WindowsVlcVideoViewState();
}

class _WindowsVlcVideoViewState extends State<_WindowsVlcVideoView> {
  final GlobalKey _key = GlobalKey();
  Size? _lastLogicalSize;
  Offset? _lastLogicalOffset;
  double? _lastDevicePixelRatio;
  bool _updateScheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scheduleBoundsPush());
  }

  @override
  void dispose() {
    unawaited(widget.channels.invoke('detachVideoView'));
    super.dispose();
  }

  void _scheduleBoundsPush() {
    if (_updateScheduled || !mounted) {
      return;
    }
    _updateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateScheduled = false;
      _pushBounds();
    });
  }

  Future<void> _pushBounds() async {
    if (!mounted) {
      return;
    }
    final context = _key.currentContext;
    if (context == null) {
      return;
    }
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) {
      return;
    }

    final logicalOffset = renderObject.localToGlobal(Offset.zero);
    final logicalSize = renderObject.size;
    final devicePixelRatio = View.of(context).devicePixelRatio;

    if (_lastLogicalOffset == logicalOffset &&
        _lastLogicalSize == logicalSize &&
        _lastDevicePixelRatio == devicePixelRatio) {
      return;
    }

    _lastLogicalOffset = logicalOffset;
    _lastLogicalSize = logicalSize;
    _lastDevicePixelRatio = devicePixelRatio;

    await widget.channels.invoke('attachVideoView', {
      'left': (logicalOffset.dx * devicePixelRatio).round(),
      'top': (logicalOffset.dy * devicePixelRatio).round(),
      'width': (logicalSize.width * devicePixelRatio).round(),
      'height': (logicalSize.height * devicePixelRatio).round(),
    });
  }

  @override
  Widget build(BuildContext context) {
    _scheduleBoundsPush();
    return LayoutBuilder(
      builder: (context, constraints) {
        _scheduleBoundsPush();
        return ColoredBox(
          key: _key,
          color: const Color(0xFF000000),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}
