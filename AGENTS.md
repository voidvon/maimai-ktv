# Repository Guidelines

## 项目结构与模块组织
本仓库是精简版 Flutter KTV 播放器。核心代码在 `lib/`：`main.dart` 负责入口 UI，`lib/player/` 管理跨平台播放控制与声道切换，`lib/services/` 处理选文件流程，`lib/models/` 与 `lib/platform/` 放模型和平台判断。  
原生实现位于 `android/` 与 `macos/`，其中 Android 关键链路集中在 `android/app/src/main/`（libVLC、JNI、平台通道）。排错资料在 `docs/`，测试在 `test/`，示例应用在 `example/`。

## 构建、测试与开发命令
- `flutter pub get`：安装依赖。  
- `flutter analyze`：静态检查，提交前必须通过。  
- `flutter test`：运行单元/组件测试。  
- `flutter run -d macos`：验证 macOS 播放链路。  
- `flutter run -d android`：验证 Android 平台视图、文件选择与播放。  
- `flutter build apk --release`：构建 Android Release，检查混淆与播放器可用性。

## 代码风格与命名规范
遵循 `analysis_options.yaml` 中 `flutter_lints`，统一 2 空格缩进。  
Dart 文件名使用 `snake_case.dart`，类名使用 `UpperCamelCase`，字段与方法使用 `lowerCamelCase`。  
提交前执行 `dart format lib test`。平台通道/JNI 相关类需语义清晰，例如 `NativeKtvPlayerHost`、`platform_channel_player_controller.dart`。

## 测试指南
优先覆盖 `lib/player/` 与 `lib/services/` 的变更。测试文件放在 `test/`，命名使用 `*_test.dart`。  
涉及 Android 播放链路时，除 `flutter test` 外，至少手动验证一次：选文件、播放、原唱/伴唱切换、Release 安装后可播放。背景说明见 `docs/android_playback_notes.md`。

## 提交与 Pull Request 规范
提交信息遵循 Conventional Commits：`type(scope): summary` 或 `type: summary`，例如：`fix(android): stabilize playback pipeline`。  
PR 需包含：变更目的、影响平台（Android/macOS）、验证命令与结果。若影响界面或播放行为，请附截图、关键日志或复现步骤。

## 平台与稳定性注意事项
不要删除 Android 的 `content://` 缓存复制、URI 持久权限、`proguard-rules.pro` 或 JNI 声道路由相关逻辑；这些是当前播放器稳定性的关键约束。  
请勿提交 `build/`、`.dart_tool/`、`android/.gradle/` 等构建产物。
