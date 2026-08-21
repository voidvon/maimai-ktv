# Changelog

All notable user-facing changes should be recorded in this file.

The format is intentionally simple:

- Add the newest version at the top.
- Focus on what users can perceive.
- Avoid implementation details unless they affect usage.

## [v1.0.0-alpha.8] - 2026-08-21

### 新增

- 新增 SMB 3.x 歌曲数据源，支持 SMB 3.0、3.0.2 和 3.1.1，并提供歌曲扫描、缓存播放和断点下载。
- SMB 设置改为分步向导：连接服务器、按需登录、浏览共享与子目录，用户无需手动填写共享名称。
- WebDAV 歌曲根目录改为远程目录选择，支持逐级浏览、返回上级、刷新和重试。

### 变更

- SMB 和 WebDAV 的歌曲目录均通过选择器确定，减少手动输入路径造成的配置错误。
- 暂时隐藏尚未稳定的升调、降调和原调入口，保留底层能力供后续继续调试。

### 说明

- SMB 文件访问仅协商 SMB 3.x，并启用消息签名。
- 这是一个 Alpha 预发布版本，主要用于测试与验证。

## [v1.0.0-alpha.7] - 2026-04-19

### 新增

- GitHub Releases 新增 Windows x64 桌面测试包。
- GitHub Releases 新增 iOS unsigned IPA 测试包，便于 iPhone 真机安装验证。

### 变更

- iOS 本地媒体导入更稳定，改进了 `.dat` 文件导入和目录扫描处理。
- iOS 播放切换到 MobileVLCKit 后端，提升了与当前播放器集成的兼容性。
- 横屏播放布局和 KTV 外壳切换更稳定，减少了演唱过程中预览区和控制层状态不一致的问题。

### 说明

- 当前版本已支持 Android、macOS、Windows x64 与 iOS 测试分发。
- 仅 Android 支持单音轨 KTV 视频资源，其他平台暂不支持这类资源。
- 这是一个 Alpha 预发布版本，主要用于测试与验证。

## [v1.0.0-alpha.6] - 2026-04-13

### Changed

- Playback now preserves the previous paused state after minimizing and returning to the app, instead of resuming automatically.

### Notes

- This is an alpha prerelease intended for testing and validation.

## [v1.0.0-alpha.5] - 2026-04-13

### Added

- Settings now includes an About page with a short app introduction and the open-source repository link for quick reference.

### Changed

- Downloading songs now keep a more consistent queued state, reducing mismatches between the song list, queue, and playback readiness.
- Song list item actions are more unified, making add-to-queue and related operations feel clearer and more predictable.

### Notes

- This is an alpha prerelease intended for testing and validation.

## [v1.0.0-alpha.4] - 2026-04-12

### Changed

- The player now restores the last playback session after relaunch, so unfinished songs can continue from the previous progress more reliably.
- Queue cleanup after the final song finishes is more consistent, reducing stale playback state after the queue ends.
- Progress scrubbing is smoother: dragging the progress bar now previews the target position first and only seeks after release.
- The video preview surface itself now supports horizontal scrubbing in both embedded and fullscreen playback, while keeping tap-to-fullscreen and tap-to-show-controls behaviors intact.

### Notes

- This is an alpha prerelease intended for testing and validation.

## [v1.0.0-alpha.3] - 2026-04-11

### Changed

- App name is now unified as `麦麦KTV`, and the app icons across Android, iOS, and macOS have been refreshed for the new brand.
- Cloud songs now follow a clearer queue flow: tapping an undownloaded song adds it to the bottom of 已点, keeps it out of playback until the download completes, and shows download progress directly in the song list.
- 已点列表 now uses the same item component as the song list, removes horizontal swipe paging, and keeps downloading songs visible with a thin inline progress bar.
- Skip, restart, and paused playback behaviors are more consistent, including showing a toast when there is no next playable song and restarting correctly from paused state.
- Baidu Netdisk download state handling is more consistent, with clearer unavailable-file feedback and fewer false “login expired” prompts.

### Notes

- This is an alpha prerelease intended for testing and validation.

## [v1.0.0-alpha.2] - 2026-04-09

### Added

- First macOS desktop release package published through GitHub Releases.
- Android prerelease artifacts now include both split-per-ABI APKs and a universal APK for easier installation on different devices.

### Changed

- Alpha distribution metadata now aligns the app package version, release tag, and uploaded assets for the current prerelease build.

### Notes

- This is an alpha prerelease intended for testing and validation.

## [v1.0.0-alpha.1] - 2026-04-08

### Added

- First Android alpha release distributed through GitHub Releases.
- Split-per-ABI Android packages for `armeabi-v7a`, `arm64-v8a`, and `x86_64`.
- Initial GitHub Release publishing flow for packaged builds.

### Notes

- This is an alpha prerelease, not a production release.
