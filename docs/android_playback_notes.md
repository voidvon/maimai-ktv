# Android 播放链路说明

这份文档只针对 `/Volumes/DATA/Space/ktv2` 当前这套播放器实现，目的是避免后续再次踩到“选文件闪退”“release 能装但不能播”“有声无画”这类回归。

## 1. 当前播放器结构

- 示例 UI 入口：`example/lib/main.dart`
- Android 播放控制器：`lib/player/android_native_player_controller.dart`
- Dart 与原生通信：`lib/player/platform_channel_player_controller.dart`
- Android 示例文件选择：`example/android/app/src/main/kotlin/com/ktv/player/ktv2_example/MainActivity.kt`
- Android 原生播放器宿主：`android/src/main/kotlin/com/ktv/player/ktv2/NativeKtvPlayerHost.kt`
- 播放内核：`org.videolan.android:libvlc-all`

当前模式是：

- Flutter 负责 UI 和状态显示
- Android 原生负责视频视图创建、libVLC 播放、音轨切换、左右声道切换
- Flutter 通过 `MethodChannel/EventChannel` 控制原生播放器

## 2. 已确认的关键约束

### 2.1 不要把 `content://` 直接交给播放链路

Android 文件选择器返回的通常是 `content://...`。

直接拿这个 URI 喂播放器会引出两类问题：

- 权限生命周期不稳定
- 某些 libVLC 路径下兼容性差

当前做法是：

- 先在 example 的 `MainActivity.kt` 中申请持久化读权限
- 再在 package 的 `NativeKtvPlayerHost.kt` 里把 `content://` 拷到 `cache/playback_sources/`
- 真正播放时走缓存文件路径

后面如果你要改文件选择逻辑，这个步骤不要删。

### 2.2 release 版必须保留 libVLC 相关类

之前 release 包出现过：

- 选择文件后闪退
- `JNI_OnLoad` 失败
- `FindClass(org/videolan/libvlc/interfaces/IMedia$Slave) failed`

为了解决这个问题，当前工程已经补了：

- `android/app/proguard-rules.pro`
- `android/app/build.gradle.kts` 里的 `release` 混淆配置

后面如果改 Gradle 或混淆规则，先确认 release 版里 libVLC 相关类还在。

### 2.3 单音轨原唱/伴唱切换依赖 JNI

当前完整切换逻辑分两种：

- 多音轨文件：直接切 libVLC 音轨
- 单音轨双声道文件：通过 JNI 调 libVLC 声道路由，切左/右声道

相关文件：

- `android/src/main/c/native_vlc_bridge.c`
- `android/src/main/c/CMakeLists.txt`

如果 JNI 库加载失败，单音轨原唱/伴唱能力会退化。

## 3. 这次已经踩过的错误

### 3.1 选择文件后直接闪退

原因：

- `takePersistableUriPermission()` 传错 flag

表现：

- `IllegalArgumentException`
- 日志里会看到 `Requested flags 0x41, but only 0x3 are allowed`

修复：

- 只传 `READ/WRITE URI PERMISSION`
- 不把 `PERSISTABLE` flag 再次传入 `takePersistableUriPermission()`

### 3.2 release 版闪退

原因：

- 混淆删掉了 libVLC 运行时需要的类

修复：

- 新增 `proguard-rules.pro`
- 在 `release` 打包里显式保留 libVLC 相关类

### 3.3 只有声音，没有画面

这个问题最难，且目前仍然属于高风险区域。

已经确认过的事实：

- 文件本身能播
- 音频链路是通的
- Flutter 主区域里已经能创建出原生 `SurfaceView`
- `SurfaceFlinger` 里能看到 `SurfaceView[com.ktv.player.ktv2/...MainActivity]`

说明：

- 问题不在文件选择
- 不在音频
- 不完全是“没有创建视频层”
- 更可能在 `libVLC vout` 和 Android 平台视图合成链路

这类问题以后不要靠一次性大改去猜，必须先抓日志。

## 4. 修改播放器时的禁止项

下面这些改动，如果没有抓日志和真机验证，不要随便做：

- 删除 `resolvePlaybackPath()` 的缓存复制逻辑
- 删除 `proguard-rules.pro`
- 改掉 example `MainActivity.kt` 里的 URI 持久权限处理
- 把 Android 平台视图从当前实现随意切成别的承载方式
- 把 libVLC 的 `attachViews()`、`detachViews()` 顺序大改
- 在视频区域外层重新叠很多 Flutter 裁剪、圆角、透明背景容器

## 5. 出问题时先看什么

### 5.1 先判断是哪一类问题

- 选文件就闪退：优先看 URI 权限和 crash log
- debug 能播、release 不能播：优先看混淆和 libVLC 类保留
- 有声音没画面：优先看 libVLC video output 和 Surface 层
- 完全没声音没画面：优先看播放请求是否真正发到原生层

### 5.2 必看的日志关键字

抓日志时优先看这些关键词：

- `KtvNative`
- `VLC`
- `libvlc`
- `video output`
- `vout`
- `android_window`
- `SurfaceView[com.ktv.player.ktv2`
- `EncounteredError`

## 6. 推荐排查命令

### 6.1 清日志

```bash
~/Library/Android/sdk/platform-tools/adb logcat -c
```

### 6.2 实时抓播放器相关日志

```bash
~/Library/Android/sdk/platform-tools/adb logcat -v threadtime KtvNative:D VLC:D AndroidRuntime:E flutter:D Flutter:D ActivityManager:I '*:S'
```

### 6.3 只看当前进程日志

先拿 pid：

```bash
~/Library/Android/sdk/platform-tools/adb shell pidof com.ktv.player.ktv2
```

再抓：

```bash
~/Library/Android/sdk/platform-tools/adb logcat -d -v threadtime --pid=<PID>
```

### 6.4 看系统里有没有真的生成视频层

```bash
~/Library/Android/sdk/platform-tools/adb shell dumpsys SurfaceFlinger --list | rg "com.ktv.player.ktv2|SurfaceView|FlutterView|flutter"
```

如果这里根本没有 app 的 `SurfaceView`，说明原生视频层都没创建出来。

### 6.5 看退出信息

```bash
~/Library/Android/sdk/platform-tools/adb shell dumpsys activity exit-info com.ktv.player.ktv2
```

## 7. 处理“有声无画”的推荐顺序

以后再遇到“有声无画”，不要先改一堆 UI。

正确顺序：

1. 先确认 `videoTrackCount > 0`
2. 再确认 `SurfaceFlinger` 里有没有 app 的 `SurfaceView`
3. 再确认日志里有没有 `video output creation failed`
4. 再确认 `Vout` 事件是不是一直是 `0`
5. 最后才去改 Flutter 容器、平台视图承载方式或 libVLC attach 时序

## 8. 当前状态记录

截至 2026-03-29：

- 文件选择权限问题已修
- release 混淆问题已修
- `content://` 缓存复制已加
- 原唱/伴唱完整切换链路已保留
- Android `SurfaceView` 已能在系统层被创建出来
- 但“有声无画”问题仍未彻底根治

所以后面继续修这个问题时，优先从下面两个方向入手：

- `libVLC vout` 是否真正把视频帧送到了当前 surface
- 当前 `SurfaceView` 是否被 Flutter / Window 合成顺序压住

## 9. 建议的开发习惯

- 每次改 Android 播放链路，都先保留一个可回退提交
- 先打 debug 验证，再打 release 验证
- 任何“我觉得可能是 UI 遮挡”的判断，都先用 `SurfaceFlinger` 验证
- 任何“我觉得可能是权限”的判断，都先看 crash log
- 任何“我觉得可能是 libVLC 不支持”的判断，都先看 `VLC/libvlc` 原生日志

这份文档的目的不是解释 Flutter，而是避免下次再花几个回合把同一个坑重新踩一遍。
