# ktv2

从原项目中抽离出来的最小 KTV 播放器/组件，只保留：

- 本地视频播放
- 完整原唱 / 伴唱切换
- Android libVLC 播放链路
- macOS 原生播放器桥接

现在仓库提供更纯粹的 Flutter package API，外部项目可直接通过 `path` 或 `git` 依赖引入。文件选择和示例控制 UI 已移到 `example/`。

## 作为组件引入

`pubspec.yaml`

```yaml
dependencies:
  ktv2:
    path: ../ktv2
```

页面中接入：

```dart
import 'package:flutter/material.dart';
import 'package:ktv2/ktv2.dart';

class DemoPage extends StatefulWidget {
  const DemoPage({super.key});

  @override
  State<DemoPage> createState() => _DemoPageState();
}

class _DemoPageState extends State<DemoPage> {
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
  [docs/android_playback_notes.md](docs/android_playback_notes.md)

## 常用命令

```bash
flutter analyze
flutter test
cd example && flutter run -d macos
cd example && flutter run -d android
```
