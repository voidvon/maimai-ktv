# Repository Guidelines

## 项目结构与模块组织
本仓库是 Flutter KTV 播放器示例。核心代码位于 `lib/`：`main.dart` 负责入口与页面，`lib/player/` 负责播放控制与声道切换，`lib/services/` 负责文件选择流程，`lib/models/` 与 `lib/platform/` 放数据模型和平台判断。  
原生代码在 `android/` 与 `macos/`，其中 Android 关键链路集中在 `android/app/src/main/`（libVLC、JNI、平台通道）。测试代码在 `test/`，排错资料在 `docs/`。

## 构建、测试与开发命令
- `flutter pub get`：安装依赖。  
- `flutter analyze`：执行静态检查，提交前必须通过。  
- `flutter test`：运行单元/组件测试。  
- `flutter run -d macos`：本地验证 macOS 播放链路。  
- `flutter run -d android`：验证 Android 平台视图、文件选择与播放。  
- `flutter build apk --release`：构建 Release 包，检查混淆与播放可用性。
示例：调试播放问题时可先执行 `flutter analyze && flutter test`，再进入设备侧复测。

## 代码风格与命名规范
遵循 `analysis_options.yaml` 中的 `flutter_lints`，统一 2 空格缩进。  
Dart 文件名使用 `snake_case.dart`，类名使用 `UpperCamelCase`，变量/方法使用 `lowerCamelCase`。  
提交前执行 `dart format lib test`。平台通道/JNI 类命名需语义明确，例如 `NativeKtvPlayerHost`。

## 测试指南
优先覆盖 `lib/player/` 与 `lib/services/` 的变更。测试文件放在 `test/`，命名为 `*_test.dart`。  
涉及 Android 播放链路时，除 `flutter test` 外，至少手动验证一次：选文件、开始播放、原唱/伴唱切换，以及 Release 安装后可播放。可参考 `docs/android_playback_notes.md`。

## 提交与 Pull Request 规范
提交信息使用 Conventional Commits：`type(scope): summary`（如 `fix(android): stabilize playback pipeline`）。  
PR 需包含：变更目的、影响平台（Android/macOS）、验证命令与结果。若影响界面或播放行为，请附截图、关键日志或复现步骤。

## 平台稳定性与配置注意事项
不要删除 Android 的 `content://` 缓存复制、URI 持久权限、`proguard-rules.pro`、JNI 声道路由相关逻辑。  
禁止提交构建产物：`build/`、`.dart_tool/`、`android/.gradle/`。

## 架构与协作约定
优先在 Flutter 层（`lib/`）修复通用逻辑，只有在平台差异明确时再修改 `android/` 或 `macos/`。  
涉及播放稳定性的改动，请保持“文件访问 -> 缓存复制 -> 播放初始化 -> 声道切换”链路完整，避免跨层大范围重构。  
推荐提交流程：先 `flutter analyze`，再 `flutter test`，最后进行一次目标平台手测并在 PR 中记录结果与日志片段。

## 提交前检查清单
- 新增/修改 Dart 代码后，确认已执行 `dart format lib test`。  
- 涉及播放器行为的改动，至少在一个真实设备上验证“选择文件 + 播放 + 声道切换”。  
- 修改 Android 原生逻辑时，检查 `proguard-rules.pro` 与 JNI/平台通道是否仍可联通。  
- PR 描述中写明“改动范围、风险点、回滚方式”，便于快速评审与回归。  

## 问题反馈建议
提交缺陷时请附最小复现步骤、设备信息（机型/系统版本）、关键日志（如 `adb logcat` 片段）以及预期行为与实际行为对比。  
如果问题只在 Release 出现，请同时提供 Debug 与 Release 的差异说明，便于快速定位混淆或权限相关问题。
建议同步标注是否可稳定复现（如“5/5 次必现”）。
