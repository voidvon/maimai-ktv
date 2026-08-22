<div align="center">

<img src="docs/public/app-icon.png" alt="麦麦KTV" width="112">

# 麦麦KTV

[![Flutter](https://img.shields.io/badge/Flutter-3-02569B.svg?logo=flutter)](https://flutter.dev/)
[![版本](https://img.shields.io/badge/版本-v1.0.0--alpha.9-orange.svg)](https://github.com/voidvon/maimai-ktv/releases/tag/v1.0.0-alpha.9)
[![平台](https://img.shields.io/badge/平台-Android%20%7C%20macOS%20%7C%20Windows%20%7C%20iOS-555.svg)](#下载安装)

**面向家庭娱乐、大屏播放和 KTV 包厢的视频点歌应用。**

[English](README.md) | 简体中文 | [繁體中文](README_TW.md)

<p>
  <a href="https://github.com/voidvon/maimai-ktv/releases/tag/v1.0.0-alpha.9">下载应用</a> ·
  <a href="https://maimai.0122.vip/guide/">使用指南</a> ·
  <a href="CHANGELOG.md">更新记录</a>
</p>

<img src="docs/images/desktop-screen.png" alt="麦麦KTV 点歌界面" width="900">

</div>

## 应用简介

麦麦KTV把找歌、已点队列、视频播放、原唱/伴唱切换、云端下载和歌库管理
集中在同一套横屏界面中，适合电视、投影、大屏电脑、平板和手机。

接入自己的 KTV 视频歌库后，可以按歌名或歌手浏览，使用中文或拼音首字母
快速搜索，并在点歌界面内完成整场演唱的播放和队列管理。

> 麦麦KTV不内置歌曲，也不提供媒体内容服务。请自行准备歌库，并确保你有权
> 访问和使用其中的媒体文件。

## 主要功能

- **多入口点歌**：按歌名、歌手、本地歌曲、收藏或常唱歌曲浏览。
- **快速搜索**：支持歌名、歌手、中文、拼音首字母和本地文件名检索。
- **播放控制**：播放、暂停、切歌、重唱、进度跳转、全屏播放，以及原唱/
  伴唱切换。
- **已点管理**：查看当前播放和后续歌曲，将歌曲置顶，或从队列移除。
- **多种歌库来源**：扫描本地目录，并可接入 WebDAV 或百度网盘歌库。
- **云端下载管理**：歌曲下载时仍保留在已点队列，支持查看进度、重试任务和
  管理已下载文件。
- **个人歌库**：收藏常唱曲目，并自动聚合经常播放的歌曲。
- **三语界面**：支持简体中文、繁体中文和 English，也可以跟随系统语言。

## 下载安装

麦麦KTV目前是用于测试的 **Alpha 预发布版本**。请从
[GitHub Releases](https://github.com/voidvon/maimai-ktv/releases/tag/v1.0.0-alpha.9)
下载当前安装包。

| 平台 | 安装包 | 说明 |
|---|---|---|
| Android | APK（`arm64-v8a`、`armeabi-v7a`、`x86_64` 和通用版） | 推荐使用，当前功能最完整 |
| macOS | ZIP 压缩包 | 解压后打开应用 |
| Windows x64 | ZIP 压缩包 | 完整解压后再启动应用 |
| iOS | unsigned IPA | 用于侧载和真机测试，不是 App Store 版本 |

已发布文件的 SHA-256 校验值可以在
[更新清单](docs/public/latest.json)中查看。

## 快速开始

1. 下载并安装适合当前设备的软件包。
2. 打开**设置**，选择本地目录、WebDAV 或百度网盘作为歌库来源。
3. 选择或导入 KTV 视频目录，等待扫描完成。
4. 回到首页，找到歌曲并加入已点队列。
5. 播放时按需使用**原唱**、**伴唱**、**切歌**和**重唱**。

云端歌曲会先下载再播放，歌曲列表和已点队列都会显示下载进度。

### 整理本地歌库

规范的文件名可以让搜索和分类更准确，推荐格式为：

```text
歌手-歌名-语言-标签.扩展名
```

例如：

```text
周杰伦-七里香-国语-流行.mp4
```

多位歌手之间使用 `&`。不符合该格式的文件仍会使用降级标题导入。详细规则见
[SQLite 歌曲入库命名规则](docs/sqlite_song_import_rules.md)。

## 平台说明

- Android 是当前主力平台，功能覆盖最完整。
- 只有 Android 支持把原唱和伴唱分别保存在同一条音轨左右声道中的单音轨
  KTV 视频，其他平台暂不支持这类资源。
- iOS 安装包未签名，需要使用自己的签名或侧载方式安装。
- 所有安装包均为预发布测试版本。请备份重要的歌库信息，并单独保留原始媒体
  文件。
- 云端歌库的可用性和下载速度取决于对应服务、网络环境和账号权限。

## 界面截图

| 桌面与大屏 | 手机与平板 |
|---|---|
| ![桌面端点歌界面](docs/images/desktop-screen.png) | ![移动端点歌界面](docs/images/mobile-screen.jpg) |

## 使用与帮助

| 文档 | 内容 |
|---|---|
| [使用指南](https://maimai.0122.vip/guide/) | 安装、首次启动和日常使用 |
| [版本发布记录](https://maimai.0122.vip/release-history) | 已发布版本和安装包 |
| [更新记录](CHANGELOG.md) | 各版本中用户可感知的变化 |
| [Android 构建说明](docs/android_build.md) | Android 构建与打包 |
| [Windows 构建说明](docs/windows_build.md) | Windows 构建与打包 |

## 开发

```bash
flutter pub get
flutter analyze
flutter test
```

使用 `flutter run -d android` 或 `flutter run -d macos` 运行应用。单独检查仓库内
的播放器 package：

```bash
cd packages/ktv_player
flutter analyze
flutter test
```

欢迎提交 Issue 和 Pull Request。报告播放问题时，请附上受影响的平台、复现步骤
和相关日志。
