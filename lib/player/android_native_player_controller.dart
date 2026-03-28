import 'dart:io';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'platform_channel_player_controller.dart';

class AndroidNativePlayerController extends PlatformChannelPlayerController {
  @override
  String get eventErrorPrefix => 'Android libVLC 播放器事件异常';

  @override
  String get initializingDiagnostics => '正在初始化 Android libVLC 播放器。';

  @override
  String get backendDisplayName => 'Android libVLC';

  @override
  bool get showsSelectedTrackTitle => true;

  @override
  String describeSingleTrackAudioMode(int? channelCount) {
    if ((channelCount ?? 2) >= 2) {
      return '单音轨文件，直接切换左右声道';
    }
    return '当前文件为单声道，无法拆分原唱/伴唱';
  }

  @override
  Future<void> validateMediaPath(String path) async {
    if (path.startsWith('content://')) {
      return;
    }

    final file = File(path);
    if (!await file.exists()) {
      throw FileSystemException('本地视频文件不存在', path);
    }
  }

  @override
  Widget buildPlatformVideoView() {
    return const AndroidView(
      viewType: 'ktv/native_video_view',
      hitTestBehavior: PlatformViewHitTestBehavior.transparent,
    );
  }
}
