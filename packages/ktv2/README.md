# ktv2

从麦麦KTV 主项目中抽离出来的最小 Flutter 播放器 package，只保留：

- 本地视频播放
- 完整原唱 / 伴唱切换
- Android libVLC 播放链路
- macOS 原生播放器桥接

仓库只包含播放器能力本身，文件选择、宿主页面和业务 UI 由接入方应用提供。

## 作为组件引入

`pubspec.yaml`

```yaml
dependencies:
  ktv2:
    git:
      url: https://github.com/voidvon/ktv-player.git
      ref: main
```

本地联调时也可以切回路径依赖：

```yaml
dependencies:
  ktv2:
    path: ../ktv-player
```

页面中接入：

```dart
import 'package:flutter/material.dart';
import 'package:ktv2/ktv2.dart';

class PlayerPage extends StatefulWidget {
  const PlayerPage({super.key});

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  final PlayerController controller = createPlayerController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        KtvPlayerView(controller: controller),
      ],
    );
  }
}
```

公开 API 入口为 `package:ktv2/ktv2.dart`，当前导出：

- `PlayerController` / `createPlayerController()`
- `MediaSource`
- `KtvPlayerView`
- `PlayerState`
- `AudioOutputMode`

## 说明文档

- Android 播放链路与排错记录：
  https://github.com/voidvon/ktv/blob/main/docs/android_playback_notes.md

## 常用命令

```bash
flutter pub get
flutter analyze
flutter test
```
