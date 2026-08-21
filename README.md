<div align="center">

<img src="docs/public/app-icon.png" alt="Maimai KTV" width="112">

# Maimai KTV

[![Flutter](https://img.shields.io/badge/Flutter-3-02569B.svg?logo=flutter)](https://flutter.dev/)
[![Release](https://img.shields.io/badge/release-v1.0.0--alpha.7-orange.svg)](https://github.com/voidvon/maimai-ktv/releases/tag/v1.0.0-alpha.7)
[![Platforms](https://img.shields.io/badge/platforms-Android%20%7C%20macOS%20%7C%20Windows%20%7C%20iOS-555.svg)](#downloads)

**A video-first karaoke songbook for home entertainment, big screens, and KTV rooms.**

English | [简体中文](README_CN.md) | [繁體中文](README_TW.md)

<p>
  <a href="https://github.com/voidvon/maimai-ktv/releases/tag/v1.0.0-alpha.7">Download</a> ·
  <a href="https://maimai.0122.vip/guide/">User Guide</a> ·
  <a href="CHANGELOG.md">Changelog</a>
</p>

<img src="docs/images/desktop-screen.png" alt="Maimai KTV song selection screen" width="900">

</div>

## Overview

Maimai KTV brings song search, the play queue, video playback, vocal switching,
cloud downloads, and library management into one landscape interface. It is
designed for TVs, projected displays, desktop computers, tablets, and phones.

Bring your own karaoke video library, then browse by song or artist, search by
Chinese text or Pinyin initials, and manage the whole singing session without
leaving the songbook.

> Maimai KTV does not include songs or provide a media service. You are
> responsible for supplying and using media that you are authorized to access.

## Features

- **Fast song selection** - browse by song, artist, local library, favorites,
  or frequently played tracks.
- **Karaoke-friendly search** - search by song title, artist, Chinese text,
  Pinyin initials, or local filename.
- **Session controls** - play, pause, skip, restart, seek, enter fullscreen,
  and switch between original vocals and accompaniment.
- **Queue management** - see what is playing and what is next, move a song to
  the top, or remove it from the queue.
- **Multiple library sources** - scan local folders and connect WebDAV or
  Baidu Netdisk libraries.
- **Cloud download manager** - keep cloud songs in the queue while they
  download, view progress, retry interrupted tasks, and manage downloaded
  files.
- **Personal library** - favorite songs and quickly return to frequently
  played tracks.
- **Localized interface** - use English, Simplified Chinese, or Traditional
  Chinese, or follow the system language.

## Downloads

Maimai KTV is currently an **Alpha prerelease** intended for testing. Download
the current packages from
[GitHub Releases](https://github.com/voidvon/maimai-ktv/releases/tag/v1.0.0-alpha.7).

| Platform | Package | Notes |
|---|---|---|
| Android | APK (`arm64-v8a`, `armeabi-v7a`, `x86_64`, and universal) | Recommended; currently the most complete version |
| macOS | ZIP archive | Extract the archive and open the app |
| Windows x64 | ZIP archive | Extract the complete archive before launching |
| iOS | Unsigned IPA | For sideloading and device testing; not an App Store build |

SHA-256 values for distributed files are published in the
[update manifest](docs/public/latest.json).

## Getting Started

1. Download and install the package for your device.
2. Open **Settings** and choose a library source: a local folder, WebDAV, or
   Baidu Netdisk.
3. Select or import your karaoke video folder and wait for the scan to finish.
4. Return to the home screen, find a song, and add it to the queue.
5. During playback, use **Original**, **Accompaniment**, **Skip**, or
   **Restart** as needed.

Cloud songs are downloaded before playback. Download progress remains visible
in the song list and queue.

### Organize local files

Structured filenames make the library easier to search. The recommended format
is:

```text
Artist-Song title-Language-Tag.ext
```

For example:

```text
Jay Chou-Qi Li Xiang-Mandarin-Pop.mp4
```

Use `&` between multiple artists. Files that do not follow this format are
still imported with a fallback title. See the
[filename rules](docs/sqlite_song_import_rules.md) for details.

## Platform Notes

- Android is the primary platform and currently has the broadest feature
  coverage.
- Only Android currently supports karaoke videos that store original vocals
  and accompaniment as separate channels in a single audio track.
- The iOS package is unsigned and requires your own sideloading/signing method.
- All packages are prerelease builds. Back up important library metadata and
  keep your original media files separately.
- Cloud availability and download speed depend on the connected provider and
  your account permissions.

## Screenshots

| Desktop and big screen | Phone and tablet |
|---|---|
| ![Desktop song selection](docs/images/desktop-screen.png) | ![Mobile song selection](docs/images/mobile-screen.jpg) |

## Documentation

| Document | Description |
|---|---|
| [User Guide](https://maimai.0122.vip/guide/) | Installation, first launch, and everyday use |
| [Release History](https://maimai.0122.vip/release-history) | Published versions and packages |
| [Changelog](CHANGELOG.md) | User-visible changes by version |
| [Android Build Guide](docs/android_build.md) | Build and package the Android app |
| [Windows Build Guide](docs/windows_build.md) | Build and package the Windows app |

## Development

```bash
flutter pub get
flutter analyze
flutter test
```

Run the app with `flutter run -d android` or `flutter run -d macos`. To verify
the bundled player package separately:

```bash
cd packages/ktv_player
flutter analyze
flutter test
```

Issues and pull requests are welcome. Please include the affected platform,
reproduction steps, and relevant logs when reporting playback problems.
