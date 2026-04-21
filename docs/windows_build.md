# Windows Build

## 前提

- 只能在 Windows 主机上构建 Windows 包。
- 安装 Visual Studio 2022，并勾选：
  - `Desktop development with C++`
  - `MSVC v143 - VS 2022 C++ x64/x86 build tools`
  - `MSVC v143 - VS 2022 C++ ARM64 build tools`
  - `C++ CMake tools for Windows`
  - `Windows 10/11 SDK`
- Flutter 已启用 Windows 桌面支持：

```powershell
flutter config --enable-windows-desktop
```

## 一键打包

仓库已提供 PowerShell 脚本 [`scripts/build_windows.ps1`](/Users/yytest/Documents/projects/ktv/scripts/build_windows.ps1)。

在 Windows 机器上进入仓库根目录执行：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build_windows.ps1 -Arch all
```

只打某一个架构：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build_windows.ps1 -Arch x64
powershell -ExecutionPolicy Bypass -File .\scripts\build_windows.ps1 -Arch arm64
```

默认输出：

- `dist/windows/maimai-ktv-v<version>-windows-x64.zip`
- `dist/windows/maimai-ktv-v<version>-windows-arm64.zip`

脚本会优先使用系统自带的 `tar.exe` 生成 ZIP，避免 `Compress-Archive` 在 VLC 目录较大时明显变慢。

## 可选参数

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build_windows.ps1 -Arch all -Mode Release -Clean
```

说明：

- `-Arch` 支持 `x64`、`arm64`、`all`
- `-Mode` 支持 `Debug`、`Profile`、`Release`
- `-Clean` 会先删除对应架构的旧构建目录
- `-SkipZip` 只编译，不压缩
- `-SkipPubGet` 跳过 `flutter pub get`

脚本会在每个架构构建前清理 Flutter 放在共享 `build/` 目录里的 Windows 原生产物，再由后续的 CMake/tool_backend 按当前 `FLUTTER_TARGET_PLATFORM` 重新生成。这样可以避免在同一台机器上连续构建 `x64` 和 `arm64` 时，把错误架构的 `sqlite3.dll` 或 `app.so` 混入最终包。

## 产物目录

未压缩目录位于：

- `build/windows/x64/runner/Release/`
- `build/windows/arm64/runner/Release/`

压缩包位于：

- `dist/windows/`

## Windows 一键发布

如果你是在 Windows 主机上把桌面包上传到自建下载源，并同步更新 `docs/public/latest.json`，优先使用：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\publish_windows_release.ps1
```

默认行为：

- 读取仓库根目录的 `.release.env.local`
- 如未传 `-SkipBuild`，先调用 `scripts/build_windows.ps1`
- 把 ZIP 上传到 `<UPLOAD_TARGET>/v<display-version>`
- 把公开下载地址写成 `<DOWNLOAD_BASE_URL>/v<display-version>/<filename>`
- 更新 `docs/public/latest.json` 的 `platforms.windows`

常用变体：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\publish_windows_release.ps1 -SkipBuild
powershell -ExecutionPolicy Bypass -File .\scripts\publish_windows_release.ps1 -SkipBuild -DryRun
powershell -ExecutionPolicy Bypass -File .\scripts\publish_windows_release.ps1 -SkipBuild -CommitManifest
powershell -ExecutionPolicy Bypass -File .\scripts\publish_windows_release.ps1 -SkipBuild -CommitManifest -Push
```

注意：

- 默认只会改本地 `docs/public/latest.json`
- 传 `-CommitManifest` 时，脚本会只提交 `docs/public/latest.json`
- 传 `-CommitManifest -Push` 时，脚本会把这个提交推到默认的 `origin/main`
