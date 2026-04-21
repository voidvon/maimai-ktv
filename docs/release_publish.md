# Release Publish Guide

## 目标

本文档用于说明麦麦 KTV 当前仓库的多平台发版流程，以及如何同步维护更新入口文件 `docs/public/latest.json`。

当前约束：

- 各平台可以独立发版
- 各平台不要求同一天发布
- 客户端只读取当前平台对应的最新版本记录
- 统一入口文件仍然只有一份：`docs/public/latest.json`

## 关键文件

- 发布脚本：`scripts/publish_github_release.sh`
- manifest 写入器：`scripts/update_latest_manifest.dart`
- 更新入口文件：`docs/public/latest.json`
- 本地发版配置示例：`.release.env.example`
- 站点访问路径：`/latest.json`
- 发布历史：`docs/release-history.md`
- Android 构建说明：`docs/android_build.md`
- Windows 构建说明：`docs/windows_build.md`
- 更新策略说明：`docs/app_update_strategy.md`

## VitePress 托管约定

当前仓库把 `latest.json` 放在 `docs/public/` 下，VitePress 构建后会原样复制到站点根目录。

当前仓库当前已配置 CDN 域名 `maimai.0122.vip`。发布后客户端应读取：

```text
https://maimai.0122.vip/latest.json
```

如果未来取消 CDN/自定义域名，站点会退回 GitHub Pages 项目地址 `https://voidvon.github.io/maimai-ktv/`。如果更换域名，也要同步修改 workflow 中的 `VITEPRESS_CUSTOM_DOMAIN` 和 `docs/public/CNAME`。

本地开发和普通 `npm run docs:build` 仍然默认使用 `/`，不会影响本地预览。

## 发版前检查

发布任意平台前，建议先确认：

- `pubspec.yaml` 版本号已更新
- `CHANGELOG.md` 已补充本次用户可感知变更
- 对应平台产物已验证可安装或可运行
- `gh auth status` 可正常通过
- 清楚本次发版的平台

如果只是某个平台单独修复，不要为了“对齐”去强行更新其他平台的 `latest.json` 条目。

## latest.json 的规则

`docs/public/latest.json` 是统一更新入口，但它内部按平台分开记录：

```json
{
  "platforms": {
    "android": { "...": "android latest entry" },
    "windows": { "...": "windows latest entry" },
    "macos": { "...": "macos latest entry" },
    "ios": { "...": "ios latest entry" }
  }
}
```

重要规则：

- Android、Windows、macOS、iOS 各自维护自己的最新版本
- Windows 晚发版时，只更新 `platforms.windows`
- Android 发版时，只更新 `platforms.android`
- 不要用新的 Windows 版本覆盖 Android 的版本号

## 本地环境文件

发布脚本会自动读取仓库根目录下的 `.release.env.local`。

推荐做法：

1. 复制 `.release.env.example` 为 `.release.env.local`
2. 填入你自己的上传目录、下载域名和明文 SSH 私钥
3. 本地执行：

```bash
chmod 600 .release.env.local
```

说明：

- `.release.env.local` 只用于本地，不要提交到仓库
- 命令行参数优先级高于 `.release.env.local`
- 如果设置了 `SSH_PRIVATE_KEY`，脚本会在上传前临时写入私钥文件，用完即删
- 如果没设置 `SSH_KNOWN_HOSTS_FILE`，脚本会使用 `StrictHostKeyChecking=accept-new`

## 脚本参数

当前发布脚本核心参数：

- `--repo <owner/repo>`
- `--platform <android|windows|macos|ios>`
- `--asset <path>`
- `--skip-build`
- `--latest-manifest-file <path>`
- `--skip-latest-manifest`
- `--download-mode <external|apk|appinstaller|sparkle>`
- `--download-url <url>`
- `--download-base-url <url>`
- `--feed-url <url>`
- `--upload-target <dest>`
- `--skip-github-assets`
- `--required-update`
- `--dry-run`

说明：

- `--platform` 决定更新 `latest.json` 的哪个区块
- `--skip-build` 适用于 Windows、macOS、iOS 等已提前构建好产物的情况
- `--latest-manifest-file` 默认就是 `docs/public/latest.json`
- `--dry-run` 只打印 GitHub Release 和 manifest 更新命令，不会真正发布
- `--upload-target` 会在发版前通过 `rsync` 把产物同步到本地目录或远端目录
- `--download-base-url` 会把 manifest 里的下载地址改写为 `<base>/<basename>`
- `--skip-github-assets` 适用于“保留 GitHub Release 页面，但安装包只走自建下载源”的情况

## Android 发版

Android 是当前唯一支持脚本内自动构建的平台。

默认发布 split APK：

```bash
scripts/publish_github_release.sh \
  --repo voidvon/maimai-ktv \
  --platform android
```

行为：

- 自动读取 `pubspec.yaml` 版本
- 自动构建 Android APK
- 默认上传 split-per-ABI APK
- 自动把 `arm64-v8a`、`armeabi-v7a`、`x86_64` 写入 `latest.json`
- 如果有 universal APK，会写入 `fallbackUrl`

如果要发布 universal APK：

```bash
scripts/publish_github_release.sh \
  --repo voidvon/maimai-ktv \
  --platform android \
  --no-split-per-abi
```

如果已经提前构建好产物：

```bash
scripts/publish_github_release.sh \
  --repo voidvon/maimai-ktv \
  --platform android \
  --skip-build \
  --asset dist/android/maimai-ktv-1.0.0-alpha.8-android-arm64-v8a.apk \
  --asset dist/android/maimai-ktv-1.0.0-alpha.8-android-armeabi-v7a.apk \
  --asset dist/android/maimai-ktv-1.0.0-alpha.8-android-x86_64.apk \
  --asset dist/android/maimai-ktv-1.0.0-alpha.8-android-universal.apk
```

如果要把 Android APK 同步到自有服务器目录，并让客户端走 EdgeOne/CDN 域名下载：

```bash
scripts/publish_github_release.sh \
  --repo voidvon/maimai-ktv \
  --platform android \
  --skip-build \
  --asset dist/android/maimai-ktv-1.0.0-alpha.8-android-arm64-v8a.apk \
  --asset dist/android/maimai-ktv-1.0.0-alpha.8-android-armeabi-v7a.apk \
  --asset dist/android/maimai-ktv-1.0.0-alpha.8-android-x86_64.apk \
  --asset dist/android/maimai-ktv-1.0.0-alpha.8-android-universal.apk \
  --upload-target deploy@example.com:/data/downloads/maimai-ktv/releases/v1.0.0-alpha.8 \
  --download-base-url https://download.example.com/maimai-ktv/releases/v1.0.0-alpha.8 \
  --skip-github-assets
```

行为：

- 先把 APK 上传到服务器版本目录
- `latest.json` 中的 `variants` 和 `fallbackUrl` 自动改写为 CDN 地址
- GitHub Release 仍会创建，但不会重复上传安装包资产

## Windows 发版

在 Windows 主机上，优先使用专用脚本 `scripts/publish_windows_release.ps1`，不要默认走 `rsync` 风格的 Linux 发布链路。

推荐命令：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\publish_windows_release.ps1
```

默认行为：

- 必要时先调用 `scripts/build_windows.ps1`
- 通过 OpenSSH 的 `ssh.exe` / `scp.exe` 上传 ZIP
- 自动处理临时 SSH 私钥文件 ACL
- 自动计算 SHA256
- 自动更新 `docs/public/latest.json` 的 `platforms.windows`

如需先检查参数解析结果：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\publish_windows_release.ps1 -SkipBuild -DryRun
```

如需把 `docs/public/latest.json` 一并提交并推到 `origin/main`：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\publish_windows_release.ps1 -SkipBuild -CommitManifest -Push
```

当前通用 shell 脚本不会自动构建 Windows，需要先准备好产物。

如果当前仍然发布 ZIP：

```bash
scripts/publish_github_release.sh \
  --repo voidvon/maimai-ktv \
  --platform windows \
  --skip-build \
  --asset dist/windows/maimai-ktv-v1.0.0-alpha.9-windows-x64.zip
```

行为：

- 上传 Windows 资产
- 更新 `platforms.windows`
- 默认会把首个资产 URL 写进 `download.url`
- 默认 `mode` 为 `external`

如果未来改成 `MSIX + .appinstaller`，推荐这样：

```bash
scripts/publish_github_release.sh \
  --repo voidvon/maimai-ktv \
  --platform windows \
  --skip-build \
  --asset dist/windows/maimai-ktv-1.0.0-alpha.9-windows-x64.msix \
  --asset dist/windows/maimai-ktv.appinstaller
```

此时脚本会优先识别 `.appinstaller`，把 `mode` 写成 `appinstaller`。

如果你想强制指定下载入口，也可以显式传：

```bash
scripts/publish_github_release.sh \
  --repo voidvon/maimai-ktv \
  --platform windows \
  --skip-build \
  --asset dist/windows/maimai-ktv-1.0.0-alpha.9-windows-x64.msix \
  --download-mode appinstaller \
  --download-url https://example.com/maimai-ktv.appinstaller
```

如果你想保留 GitHub Release 记录，但 Windows ZIP 实际从自建下载域名分发：

```bash
scripts/publish_github_release.sh \
  --repo voidvon/maimai-ktv \
  --platform windows \
  --skip-build \
  --asset dist/windows/maimai-ktv-v1.0.0-alpha.9-windows-x64.zip \
  --upload-target deploy@example.com:/data/downloads/maimai-ktv/releases/v1.0.0-alpha.9 \
  --download-base-url https://download.example.com/maimai-ktv/releases/v1.0.0-alpha.9 \
  --skip-github-assets
```

## macOS 发版

当前脚本不会自动构建 macOS，需要先准备好桌面包。

如果当前只是普通下载包：

```bash
scripts/publish_github_release.sh \
  --repo voidvon/maimai-ktv \
  --platform macos \
  --skip-build \
  --asset dist/macos/maimai-ktv-1.0.0-alpha.8-macos.zip
```

如果 ZIP 会先上传到自建下载源，再通过 EdgeOne/CDN 分发：

```bash
scripts/publish_github_release.sh \
  --repo voidvon/maimai-ktv \
  --platform macos \
  --skip-build \
  --asset dist/macos/maimai-ktv-1.0.0-alpha.8-macos.zip \
  --upload-target deploy@example.com:/data/downloads/maimai-ktv/releases/v1.0.0-alpha.8 \
  --download-base-url https://download.example.com/maimai-ktv/releases/v1.0.0-alpha.8 \
  --skip-github-assets
```

如果未来接入 Sparkle，应优先写 appcast：

```bash
scripts/publish_github_release.sh \
  --repo voidvon/maimai-ktv \
  --platform macos \
  --skip-build \
  --asset dist/macos/maimai-ktv-1.0.0-alpha.8-macos.zip \
  --download-mode sparkle \
  --feed-url https://example.com/appcast.xml
```

此时客户端会优先使用 `feedUrl`，而不是直接打开 zip。

## iOS 发版

当前 iOS 更适合写外部分发地址，而不是应用内安装包地址。

如果是 TestFlight：

```bash
scripts/publish_github_release.sh \
  --repo voidvon/maimai-ktv \
  --platform ios \
  --skip-build \
  --asset dist/ios/maimai-ktv-1.0.0-alpha.8-ios-unsigned.ipa \
  --download-mode external \
  --download-url https://testflight.apple.com/join/xxxx
```

如果只是保留 GitHub Release 交付，也可以不传 `--download-url`，脚本会默认使用首个资产 URL。

如果你只是想把 IPA 作为测试包放到自建目录，不依赖 GitHub 资产：

```bash
scripts/publish_github_release.sh \
  --repo voidvon/maimai-ktv \
  --platform ios \
  --skip-build \
  --asset dist/ios/maimai-ktv-1.0.0-alpha.8-ios-unsigned.ipa \
  --upload-target deploy@example.com:/data/downloads/maimai-ktv/releases/v1.0.0-alpha.8 \
  --download-base-url https://download.example.com/maimai-ktv/releases/v1.0.0-alpha.8 \
  --skip-github-assets
```

## 自建下载源建议

推荐目录结构：

```text
/data/downloads/maimai-ktv/releases/v1.0.0-alpha.8/
```

推荐公网地址：

```text
https://download.example.com/maimai-ktv/releases/v1.0.0-alpha.8/
```

这样有几个好处：

- 每个版本目录不可变，适合 CDN 强缓存
- 旧版本文件保留，方便回滚
- `download-base-url` 只需要和服务器目录一一对应
- GitHub Release 和自建下载源可以长期并存

## 强制更新

如果某个平台需要强制更新，只给那个平台加：

```bash
--required-update
```

这只会写入当前 `--platform` 对应的条目，不会影响其他平台。

## dry-run

发版前建议先跑：

```bash
scripts/publish_github_release.sh \
  --repo voidvon/maimai-ktv \
  --platform windows \
  --skip-build \
  --asset dist/windows/example.zip \
  --dry-run
```

它会输出：

- 预计执行的 `gh release create`
- 预计写入 `latest.json` 的 manifest 更新命令

这一步适合先检查：

- 平台是否选对
- tag/title 是否正确
- 下载模式是否正确
- manifest 是否会写到预期文件

## 发布后要做什么

脚本更新的是仓库里的本地 `docs/public/latest.json`。该目录会被 VitePress 当作静态资源目录，站点构建后会产出根路径 `/latest.json`。

发布完成后至少还要完成：

1. 把 `docs/public/latest.json` 提交到仓库
2. 部署 VitePress 站点，让客户端通过站点根路径 `/latest.json` 访问

如果客户端读取的是站点固定地址，而你只在本地改了文件但没有重新部署站点，应用端仍然看不到新版本。

## 推荐发布顺序

推荐顺序：

1. 更新 `pubspec.yaml`
2. 更新 `CHANGELOG.md`
3. 构建并验证目标平台产物
4. 先执行 `--dry-run`
5. 正式执行发布脚本
6. 检查 `docs/public/latest.json` 是否只更新了目标平台条目
7. 部署 VitePress 站点，并确认线上 `/latest.json` 已更新

## 常见错误

- 忘记传 `--platform`
  - 会默认按 `android` 处理
- Windows 单独发版却覆盖了 Android 版本
  - 现在脚本已按平台写入，不应再手工改成全局结构
- macOS Sparkle 只上传 zip 没写 `--feed-url`
  - 客户端会退化成普通外链，不会走 Sparkle
- iOS 把 unsigned IPA 直接当作正式更新入口
  - 更合理的是写 TestFlight 或 App Store 地址
- 发布后没部署包含 `docs/public/latest.json` 的站点
  - 客户端更新检查不会看到新版本

## 相关文档

- [多平台更新策略](./app_update_strategy.md)
- [Android 构建说明](./android_build.md)
- [Windows 构建说明](./windows_build.md)
