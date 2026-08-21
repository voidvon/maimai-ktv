import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'platform_channel_player_controller.dart';

class IosNativePlayerController extends PlatformChannelPlayerController {
  @override
  String get eventErrorPrefix => 'iOS 原生 VLC 播放器事件异常';

  @override
  String get initializingDiagnostics => '正在初始化 iOS 原生 VLC 播放器。';

  @override
  String get backendDisplayName => 'iOS 原生 MobileVLCKit';

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
    return const UiKitView(
      viewType: 'ktv/native_video_view',
      hitTestBehavior: PlatformViewHitTestBehavior.transparent,
    );
  }
}
