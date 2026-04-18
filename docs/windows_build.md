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

- `dist/windows/ktv2_example-<version>-windows-x64.zip`
- `dist/windows/ktv2_example-<version>-windows-arm64.zip`

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

## 产物目录

未压缩目录位于：

- `build/windows/x64/runner/Release/`
- `build/windows/arm64/runner/Release/`

压缩包位于：

- `dist/windows/`
