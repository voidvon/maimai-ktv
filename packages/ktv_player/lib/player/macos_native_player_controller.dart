import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'platform_channel_player_controller.dart';

class MacOSNativePlayerController extends PlatformChannelPlayerController {
  @override
  String get eventErrorPrefix => '原生播放器事件异常';

  @override
  String get initializingDiagnostics => '正在初始化 macOS 原生播放器。';

  @override
  String get backendDisplayName => 'macOS 原生 VLCKit';

  @override
  Widget buildPlatformVideoView() {
    return const AppKitView(
      viewType: 'ktv/native_video_view',
      hitTestBehavior: PlatformViewHitTestBehavior.transparent,
    );
  }
}
