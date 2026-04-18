#!/usr/bin/env bash

set -euo pipefail

mode="release"
skip_pub_get=0
clean=0
split_per_abi=1

usage() {
  cat <<'EOF'
Usage: scripts/build_android_apk.sh [options]

Options:
  --mode <debug|profile|release>  Build mode. Default: release
  --skip-pub-get                  Skip flutter pub get
  --clean                         Remove Android build outputs and dist/android
  --no-split-per-abi              Build a universal APK instead of split-per-abi
  --help                          Show this message

This script keeps Flutter's raw build output under build/, then copies the
final distributable APKs into dist/android.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)
      mode="${2:-}"
      shift 2
      ;;
    --skip-pub-get)
      skip_pub_get=1
      shift
      ;;
    --clean)
      clean=1
      shift
      ;;
    --no-split-per-abi)
      split_per_abi=0
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

case "$mode" in
  debug|profile|release)
    ;;
  *)
    echo "Unsupported mode: $mode" >&2
    exit 1
    ;;
esac

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dist_dir="$repo_root/dist/android"
flutter_apk_dir="$repo_root/build/app/outputs/flutter-apk"

version="$(sed -nE 's/^version:[[:space:]]*(.+)$/\1/p' "$repo_root/pubspec.yaml" | head -n 1)"
if [[ -z "$version" ]]; then
  version="unknown"
fi
safe_version="$(printf '%s' "$version" | tr '+/' '--' | tr -cd '[:alnum:]._-')"
artifact_prefix="maimai-ktv-${safe_version}-android"

if [[ $clean -eq 1 ]]; then
  rm -rf "$flutter_apk_dir" "$dist_dir"
fi

mkdir -p "$dist_dir"

if [[ $skip_pub_get -eq 0 ]]; then
  (cd "$repo_root" && flutter pub get)
fi

flutter_build_args=(build apk "--$mode")
if [[ $skip_pub_get -eq 1 ]]; then
  flutter_build_args+=(--no-pub)
fi
if [[ $split_per_abi -eq 1 ]]; then
  flutter_build_args+=(--split-per-abi)
fi

echo "==> Building Android APK"
(cd "$repo_root" && flutter "${flutter_build_args[@]}")

declare -a source_paths=()
declare -a target_paths=()

if [[ $split_per_abi -eq 1 ]]; then
  source_paths=(
    "$flutter_apk_dir/app-arm64-v8a-${mode}.apk"
    "$flutter_apk_dir/app-armeabi-v7a-${mode}.apk"
    "$flutter_apk_dir/app-x86_64-${mode}.apk"
  )
  target_paths=(
    "$dist_dir/${artifact_prefix}-arm64-v8a.apk"
    "$dist_dir/${artifact_prefix}-armeabi-v7a.apk"
    "$dist_dir/${artifact_prefix}-x86_64.apk"
  )
else
  source_paths=("$flutter_apk_dir/app-${mode}.apk")
  target_paths=("$dist_dir/${artifact_prefix}-universal.apk")
fi

for index in "${!source_paths[@]}"; do
  source_path="${source_paths[$index]}"
  target_path="${target_paths[$index]}"
  if [[ ! -f "$source_path" ]]; then
    echo "Expected APK was not produced: $source_path" >&2
    exit 1
  fi
  cp -f "$source_path" "$target_path"
  echo "Created distributable APK: $target_path"
done
