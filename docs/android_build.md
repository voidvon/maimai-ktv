# Android Build

## 目录约定

- `build/`：Flutter 默认原始构建目录
- `dist/android/`：项目约定的最终可分发 APK 目录

这和 iOS、Windows 现在保持一致：先在 `build/` 里完成平台原始构建，再把最终要上传 Release 的文件复制到 `dist/`。

## 一键打包

仓库已提供脚本 [`scripts/build_android_apk.sh`](/Users/yytest/Documents/projects/ktv/scripts/build_android_apk.sh)。

默认构建 release split-per-abi APK：

```bash
scripts/build_android_apk.sh
```

输出文件：

- `dist/android/maimai-ktv-<version>-android-arm64-v8a.apk`
- `dist/android/maimai-ktv-<version>-android-armeabi-v7a.apk`
- `dist/android/maimai-ktv-<version>-android-x86_64.apk`

如果要构建 universal APK：

```bash
scripts/build_android_apk.sh --no-split-per-abi
```

输出文件：

- `dist/android/maimai-ktv-<version>-android-universal.apk`

## 可选参数

```bash
scripts/build_android_apk.sh --clean --skip-pub-get
```

- `--mode <debug|profile|release>`：构建模式，默认 `release`
- `--skip-pub-get`：跳过 `flutter pub get`
- `--clean`：删除 `build/app/outputs/flutter-apk` 和 `dist/android`
- `--no-split-per-abi`：生成 universal APK
