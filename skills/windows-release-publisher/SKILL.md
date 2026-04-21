---
name: windows-release-publisher
description: Build Flutter Windows desktop release ZIPs and publish them from a Windows host. Use when Codex needs to package a Windows desktop app, upload the x64 ZIP to a self-hosted download server over SSH/SCP, update docs/public/latest.json for the Windows channel, or refresh the VitePress download entry. Prefer this skill over the generic shell release flow when working on Windows because it avoids rsync-specific steps and handles temporary SSH key ACLs.
---

# Windows Release Publisher

## Overview

Package a Flutter Windows desktop app into a release ZIP, upload the x64 artifact to the configured download server, and update the Windows entry in `docs/public/latest.json`.

## Workflow

1. Confirm the repo already contains Windows desktop support and a usable packaging entry point.
2. Prefer the repo-provided scripts:
   - `scripts/build_windows.ps1` for packaging
   - `scripts/publish_windows_release.ps1` for build/upload/manifest update on Windows
3. Build only the needed target. Default to `x64` unless the user explicitly asks for another architecture.
4. Keep build artifacts out of Git by verifying `dist/`, `build/`, and `.dart_tool/` are ignored.
5. Upload only the intended release artifact, and update only `platforms.windows` in `docs/public/latest.json`.

## Packaging

Prefer the repository packaging script:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build_windows.ps1 -Arch x64 -Mode Release
```

Expected output pattern:

```text
dist/windows/maimai-ktv-v<version>-windows-x64.zip
```

The build script now prefers `tar.exe` for ZIP creation on Windows because `Compress-Archive` is too slow for the VLC-heavy release directory.

## Server Publish

For the current repository, prefer the dedicated publish script:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\publish_windows_release.ps1
```

Default behavior:

- reads `.release.env.local`
- builds `x64` unless `-SkipBuild` is passed
- uploads the ZIP to `<UPLOAD_TARGET>/v<display-version>`
- derives the public download URL from `<DOWNLOAD_BASE_URL>/v<display-version>/<filename>`
- writes the Windows channel entry into `docs/public/latest.json`
- prints the final SHA256 and public URL
- can optionally create a commit that contains only `docs/public/latest.json`
- can optionally push that manifest commit to `origin/main`

Useful variants:

```text
powershell -ExecutionPolicy Bypass -File .\scripts\publish_windows_release.ps1 -SkipBuild
powershell -ExecutionPolicy Bypass -File .\scripts\publish_windows_release.ps1 -SkipBuild -DryRun
powershell -ExecutionPolicy Bypass -File .\scripts\publish_windows_release.ps1 -SkipBuild -CommitManifest
powershell -ExecutionPolicy Bypass -File .\scripts\publish_windows_release.ps1 -SkipBuild -CommitManifest -Push
powershell -ExecutionPolicy Bypass -File .\scripts\publish_windows_release.ps1 -Arch arm64 -SkipBuild
```

If the user only wants to refresh the hosted ZIP and local manifest, this PowerShell flow is the default. Do not route the task through `scripts/publish_github_release.sh` on Windows unless the user explicitly needs the GitHub Release asset path.

## Checks

Before publishing:

1. Confirm the local ZIP exists.
2. Confirm `.release.env.local` contains `UPLOAD_TARGET`, `DOWNLOAD_BASE_URL`, and `SSH_PRIVATE_KEY`.
3. Confirm the final public URL matches the repo's release naming pattern.

After publishing:

1. Query the remote version directory again.
2. Confirm `docs/public/latest.json` now contains `platforms.windows`.
3. Return the final browser download URL and SHA256.
4. If the user passed `-CommitManifest -Push`, confirm that the manifest commit went to `origin/main`.
5. Otherwise remind the user that VitePress goes live only after `docs/public/latest.json` is committed and pushed.
