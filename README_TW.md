<div align="center">

<img src="docs/public/app-icon.png" alt="麥麥KTV" width="112">

# 麥麥KTV

[![Flutter](https://img.shields.io/badge/Flutter-3-02569B.svg?logo=flutter)](https://flutter.dev/)
[![版本](https://img.shields.io/badge/版本-v1.0.0--alpha.9-orange.svg)](https://github.com/voidvon/maimai-ktv/releases/tag/v1.0.0-alpha.9)
[![平台](https://img.shields.io/badge/平台-Android%20%7C%20macOS%20%7C%20Windows%20%7C%20iOS-555.svg)](#下載與安裝)

**適合家庭娛樂、大螢幕播放和 KTV 包廂的影片點歌應用程式。**

[English](README.md) | [简体中文](README_CN.md) | 繁體中文

<p>
  <a href="https://github.com/voidvon/maimai-ktv/releases/tag/v1.0.0-alpha.9">下載應用程式</a> ·
  <a href="https://maimai.0122.vip/guide/">使用指南</a> ·
  <a href="CHANGELOG.md">更新記錄</a>
</p>

<img src="docs/images/desktop-screen.png" alt="麥麥KTV 點歌介面" width="900">

</div>

## 應用程式簡介

麥麥KTV將找歌、已點佇列、影片播放、原唱/伴唱切換、雲端下載和歌庫管理
集中在同一套橫向介面中，適合電視、投影、大螢幕電腦、平板和手機。

接上自己的 KTV 影片歌庫後，可以依歌名或歌手瀏覽，使用中文或拼音首字母
快速搜尋，並在點歌介面內完成整場歡唱的播放和佇列管理。

> 麥麥KTV不內建歌曲，也不提供媒體內容服務。請自行準備歌庫，並確保你有權
> 存取和使用其中的媒體檔案。

## 主要功能

- **多種點歌入口**：依歌名、歌手、本機歌曲、收藏或常唱歌曲瀏覽。
- **快速搜尋**：支援歌名、歌手、中文、拼音首字母和本機檔名搜尋。
- **播放控制**：播放、暫停、切歌、重唱、進度跳轉、全螢幕播放，以及原唱/
  伴唱切換。
- **已點管理**：查看目前播放和後續歌曲，將歌曲置頂，或從佇列移除。
- **多種歌庫來源**：掃描本機資料夾，並可連接 WebDAV 或百度網盤歌庫。
- **雲端下載管理**：歌曲下載時仍保留在已點佇列，支援查看進度、重試工作和
  管理已下載檔案。
- **個人歌庫**：收藏常唱曲目，並自動彙整經常播放的歌曲。
- **三語介面**：支援繁體中文、简体中文和 English，也可以跟隨系統語言。

## 下載與安裝

麥麥KTV目前是用於測試的 **Alpha 預發佈版本**。請從
[GitHub Releases](https://github.com/voidvon/maimai-ktv/releases/tag/v1.0.0-alpha.9)
下載目前的安裝套件。

| 平台 | 安裝套件 | 說明 |
|---|---|---|
| Android | APK（`arm64-v8a`、`armeabi-v7a`、`x86_64` 和通用版） | 建議使用，目前功能最完整 |
| macOS | ZIP 壓縮檔 | 解壓縮後開啟應用程式 |
| Windows x64 | ZIP 壓縮檔 | 完整解壓縮後再啟動應用程式 |
| iOS | unsigned IPA | 用於側載和實機測試，不是 App Store 版本 |

已發佈檔案的 SHA-256 校驗值可以在
[更新清單](docs/public/latest.json)中查看。

## 快速開始

1. 下載並安裝適合目前裝置的套件。
2. 開啟**設定**，選擇本機資料夾、WebDAV 或百度網盤作為歌庫來源。
3. 選擇或匯入 KTV 影片資料夾，等待掃描完成。
4. 回到首頁，找到歌曲並加入已點佇列。
5. 播放時視需要使用**原唱**、**伴唱**、**切歌**和**重唱**。

雲端歌曲會先下載再播放，歌曲清單和已點佇列都會顯示下載進度。

### 整理本機歌庫

一致的檔名可以讓搜尋和分類更準確，建議格式為：

```text
歌手-歌名-語言-標籤.副檔名
```

例如：

```text
周杰倫-七里香-國語-流行.mp4
```

多位歌手之間使用 `&`。不符合此格式的檔案仍會使用備用標題匯入。詳細規則見
[SQLite 歌曲入庫命名規則](docs/sqlite_song_import_rules.md)。

## 平台說明

- Android 是目前的主要平台，功能涵蓋最完整。
- 只有 Android 支援將原唱和伴唱分別儲存在同一條音軌左右聲道中的單音軌
  KTV 影片，其他平台暫不支援這類資源。
- iOS 安裝套件未簽署，需要使用自己的簽署或側載方式安裝。
- 所有安裝套件均為預發佈測試版本。請備份重要的歌庫資訊，並另外保留原始
  媒體檔案。
- 雲端歌庫的可用性和下載速度取決於對應服務、網路環境和帳號權限。

## 介面截圖

| 桌面與大螢幕 | 手機與平板 |
|---|---|
| ![桌面端點歌介面](docs/images/desktop-screen.png) | ![行動端點歌介面](docs/images/mobile-screen.jpg) |

## 使用與協助

| 文件 | 內容 |
|---|---|
| [使用指南](https://maimai.0122.vip/guide/) | 安裝、首次啟動和日常使用 |
| [版本發佈記錄](https://maimai.0122.vip/release-history) | 已發佈版本和安裝套件 |
| [更新記錄](CHANGELOG.md) | 各版本中使用者可感受到的變化 |
| [Android 建置說明](docs/android_build.md) | Android 建置與封裝 |
| [Windows 建置說明](docs/windows_build.md) | Windows 建置與封裝 |

## 開發

```bash
flutter pub get
flutter analyze
flutter test
```

使用 `flutter run -d android` 或 `flutter run -d macos` 執行應用程式。單獨檢查
倉庫內的播放器 package：

```bash
cd packages/ktv_player
flutter analyze
flutter test
```

歡迎提交 Issue 和 Pull Request。回報播放問題時，請附上受影響的平台、重現
步驟和相關日誌。
