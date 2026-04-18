---
name: windows-release-publisher
description: Build Flutter Windows desktop release ZIPs and upload the x64 artifact to an existing GitHub Release with normalized asset naming. Use when Codex needs to package a Windows desktop app from a repo that already contains Windows Flutter support, produce an x64 ZIP from local build output, or attach that ZIP to the latest or specified GitHub release without committing build artifacts.
---

# Windows Release Publisher

## Overview

Package a Flutter Windows desktop app into a release ZIP, normalize the asset name for GitHub Releases, and upload the x64 artifact to an existing release.

## Workflow

1. Confirm the repo already contains Windows desktop support and a usable packaging entry point.
2. Prefer a repo-provided build script if one exists. For Flutter Windows repos, look for `scripts/build_windows.ps1` before inventing new commands.
3. Build only the needed target. Default to `x64` unless the user explicitly asks for another architecture.
4. Keep build artifacts out of Git by verifying `dist/`, `build/`, and `.dart_tool/` are ignored.
5. Upload only the intended release artifact. If the user asks for the latest existing release, resolve the latest published tag first rather than creating a new release.

## Packaging

For repos with a Windows packaging script:

```powershell
$env:Path = 'C:\Users\yytest\flutter\bin;C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin;' + $env:Path
powershell -ExecutionPolicy Bypass -File .\scripts\build_windows.ps1 -Arch x64 -Mode Release
```

Expected output pattern:

```text
dist/windows/ktv2_example-<version>-windows-x64.zip
```

If the repository uses a different naming pattern, preserve the build output and normalize only the uploaded GitHub asset name.

## Naming

Prefer a release asset name that matches the repository's existing release naming scheme instead of the raw local filename.

For the `voidvon/maimai-ktv` repository, use:

```text
maimai-ktv-v<version-without-build-metadata>-windows-x64.zip
```

Examples:

- Local build output: `ktv2_example-1.0.0-alpha.6+6-windows-x64.zip`
- Release asset name: `maimai-ktv-v1.0.0-alpha.6-windows-x64.zip`

Strip Flutter build metadata after `+` when deriving the GitHub asset version.

## Release Upload

Prefer `gh release upload` over raw upload API calls for large files on Windows.

Use [scripts/publish_windows_x64_release.ps1](scripts/publish_windows_x64_release.ps1) when:

- the asset already exists locally,
- the release already exists on GitHub,
- a `GH_TOKEN` or explicit token is available,
- the task is to upload or replace the Windows x64 ZIP only.

Default behavior of the script:

- resolves the latest release tag when `-Tag` is omitted,
- derives the normalized asset name from the ZIP filename,
- removes an older asset with the same normalized name,
- uploads the replacement asset with `gh release upload`.

## Checks

Before uploading:

1. Confirm the local ZIP exists.
2. Confirm the target release exists.
3. Confirm the final uploaded asset name matches the repo's release naming pattern.

After uploading:

1. Query the release asset list again.
2. Confirm the Windows x64 asset is present once.
3. Return the final browser download URL.
