# Repository Guidelines

## 项目结构与模块组织
本仓库是 Flutter KTV 主应用，播放器 package 已迁移到 `https://github.com/voidvon/ktv-player`，本地协作目录约定为 `../ktv-player/`。  
根目录的 `lib/` 负责页面、文件选择、媒体库与交互逻辑，`android/` 与 `macos/` 是宿主平台工程；播放器 API、跨平台播放控制、平台视图与声道切换能力由外部 `ktv2` package 提供。排错资料在 `docs/`。

## 构建、测试与开发命令
- `flutter pub get`：安装主应用依赖。  
- `flutter analyze`：检查主应用与集成层。  
- `flutter test`：运行主应用测试。  
- `flutter run -d macos`：验证 macOS 播放链路。  
- `flutter run -d android`：验证 Android 平台视图、文件选择与播放。  
- `flutter build apk --release`：构建 Android Release，检查混淆与播放器可用性。  
- `cd ../ktv-player && flutter analyze && flutter test`：检查播放器 package。

## 代码风格与命名规范
各 Flutter 子项目都遵循各自 `analysis_options.yaml` 中的 `flutter_lints`，统一 2 空格缩进。  
Dart 文件名使用 `snake_case.dart`，类名使用 `UpperCamelCase`，字段与方法使用 `lowerCamelCase`。  
提交前在对应子项目执行 `dart format lib test`。平台通道/JNI 相关类需语义清晰，例如 `NativeKtvPlayerHost`、`platform_channel_player_controller.dart`。

## 测试指南
主应用改动优先补根目录 `test/`；播放器 package 改动优先补 `../ktv-player/test/`。测试文件命名使用 `*_test.dart`。  
涉及 Android 播放链路时，除测试外，至少在根目录手动验证一次：选文件、播放、原唱/伴唱切换、Release 安装后可播放。背景说明见 `docs/android_playback_notes.md`。

## 提交与 Pull Request 规范
提交信息遵循 Conventional Commits：`type(scope): summary` 或 `type: summary`，例如：`fix(android): stabilize playback pipeline`。  
PR 需包含：变更目的、影响平台（Android/macOS）、验证命令与结果。若影响界面或播放行为，请附截图、关键日志或复现步骤。

## 平台与稳定性注意事项
不要删除 Android 的 `content://` 缓存复制、URI 持久权限、`proguard-rules.pro` 或 JNI 声道路由相关逻辑；这些是当前播放器稳定性的关键约束。  
请勿提交 `build/`、`.dart_tool/`、`android/.gradle/`、`macos/Pods/` 等构建产物。
