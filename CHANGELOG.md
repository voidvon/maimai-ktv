# Changelog

All notable user-facing changes should be recorded in this file.

The format is intentionally simple:

- Add the newest version at the top.
- Focus on what users can perceive.
- Avoid implementation details unless they affect usage.

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
