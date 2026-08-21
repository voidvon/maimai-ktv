# 开发文档

这里收口的是当前仓库最常用的开发资料。

## 仓库定位

- 当前仓库维护 Flutter KTV 主应用。
- 页面、歌库、文件选择和业务交互都在这里。
- 播放器 package 位于仓库内的 `packages/ktv_player/`。

## 本地检查

```bash
flutter pub get
flutter analyze
flutter test
flutter run -d android
flutter run -d macos
```

播放器 package 联动检查：

```bash
cd packages/ktv_player
flutter analyze
flutter test
```

## 先看哪类文档

- 构建与运行： [Android 构建说明](/android_build)、[Windows 构建说明](/windows_build)
- 播放与数据： [Android 播放链路说明](/android_playback_notes)、[SQLite 歌曲入库命名规则](/sqlite_song_import_rules)
- 发布维护： [发版与 latest.json 维护说明](/release_publish)

## 数据源与云盘扩展

- [云盘数据源可复用流程](/cloud_drive_source_reusable_flow)
- [百度网盘接入准备文档](/baidu_pan_data_source_guide)
- [百度网盘数据源类设计草案](/baidu_pan_data_source_design)
- [115 开放平台开发文档整理](/115_open_platform_guide)

## UI 与交互规范

如果你改的是大屏点歌界面、搜索工作区或播放层交互，直接进入 [UI 设计入口](/design/)。
