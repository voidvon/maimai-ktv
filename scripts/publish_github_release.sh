#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
DEFAULT_RELEASE_HISTORY_FILE="${ROOT_DIR}/docs/release-history.md"
DEFAULT_LATEST_MANIFEST_FILE="${ROOT_DIR}/docs/public/latest.json"
DEFAULT_RELEASE_ENV_FILE="${ROOT_DIR}/.release.env.local"

usage() {
  cat <<'EOF'
Usage:
  scripts/publish_github_release.sh --repo <owner/repo> [options]

Options:
  --repo <owner/repo>      Target GitHub repository for the release. Required.
  --platform <name>        Release platform: android, windows, macos, ios. Default: android.
  --tag <tag>              Release tag. Defaults to v<pubspec version>.
  --title <title>          Release title. Defaults to "KTV Android <version>".
  --notes <text>           Release notes text.
  --notes-file <file>      Read release notes from a file.
  --asset <path>           Asset path to upload. Can be passed multiple times.
  --target <branch|sha>    Target branch or commit for a new tag.
  --release-history-file   Local markdown file used to append release history.
  --draft                  Create the release as a draft.
  --prerelease             Mark the release as a prerelease.
  --generate-notes         Let GitHub generate release notes automatically.
  --no-split-per-abi       Build a universal APK instead of split-per-abi APKs.
  --skip-build             Upload existing asset without running flutter build.
  --download-mode <mode>   Override manifest download mode: external, apk, appinstaller, sparkle.
  --download-url <url>     Override manifest download URL.
  --download-base-url <url>
                           Base public URL for uploaded assets. Uses <base>/<basename>.
  --feed-url <url>         Override manifest feed URL, e.g. Sparkle appcast.
  --upload-target <dest>   Upload assets to a local/remote directory via rsync before publishing.
  --skip-github-assets     Create/update GitHub Release without uploading release assets.
  --latest-manifest-file   Local latest.json path to update. Default: docs/public/latest.json.
  --skip-latest-manifest   Skip updating latest.json after publishing.
  --required-update        Mark the platform entry as required update in latest.json.
  --dry-run                Resolve assets & print release command without publishing.
  --skip-auth-check        Skip `gh auth status` validation.
  -h, --help               Show this help message.

Examples:
  scripts/publish_github_release.sh --repo your-name/ktv-releases

  scripts/publish_github_release.sh \
    --repo your-name/ktv-releases \
    --tag v1.2.0 \
    --title "KTV Android v1.2.0" \
    --generate-notes
EOF
}

load_release_env() {
  local env_file="${RELEASE_ENV_FILE:-${DEFAULT_RELEASE_ENV_FILE}}"
  if [[ -f "${env_file}" ]]; then
    set -a
    # shellcheck disable=SC1090
    source "${env_file}"
    set +a
  fi
}

require_command() {
  local command_name="$1"
  if ! command -v "${command_name}" >/dev/null 2>&1; then
    echo "Missing required command: ${command_name}" >&2
    exit 1
  fi
}

resolve_dart_command() {
  local flutter_bin
  local flutter_root
  local flutter_dart

  if flutter_bin="$(command -v flutter 2>/dev/null)"; then
    flutter_root="$(cd "$(dirname "${flutter_bin}")/.." && pwd)"
    flutter_dart="${flutter_root}/bin/cache/dart-sdk/bin/dart"
    if [[ -x "${flutter_dart}" ]]; then
      printf '%s' "${flutter_dart}"
      return
    fi
  fi

  if command -v dart >/dev/null 2>&1; then
    command -v dart
    return
  fi

  echo "Missing required command: dart" >&2
  exit 1
}

read_pubspec_version() {
  awk -F': *' '/^version:/ {print $2; exit}' "${ROOT_DIR}/pubspec.yaml"
}

sanitize_version() {
  printf '%s' "$1" | tr '+/' '--' | tr -cd '[:alnum:]._-'
}

default_android_asset_paths() {
  local version="$1"
  local split_per_abi="$2"
  local safe_version
  safe_version="$(sanitize_version "${version}")"
  local dist_dir="${ROOT_DIR}/dist/android"

  if [[ "${split_per_abi}" -eq 1 ]]; then
    printf '%s\n' \
      "${dist_dir}/maimai-ktv-${safe_version}-android-arm64-v8a.apk" \
      "${dist_dir}/maimai-ktv-${safe_version}-android-armeabi-v7a.apk" \
      "${dist_dir}/maimai-ktv-${safe_version}-android-x86_64.apk"
    return
  fi

  printf '%s\n' "${dist_dir}/maimai-ktv-${safe_version}-android-universal.apk"
}

current_branch() {
  git -C "${ROOT_DIR}" branch --show-current
}

current_commit_short() {
  git -C "${ROOT_DIR}" rev-parse --short HEAD
}

current_commit_full() {
  git -C "${ROOT_DIR}" rev-parse HEAD
}

current_date() {
  date '+%Y-%m-%d'
}

current_timestamp_utc() {
  date -u '+%Y-%m-%dT%H:%M:%SZ'
}

is_worktree_dirty() {
  if [[ -n "$(git -C "${ROOT_DIR}" status --porcelain)" ]]; then
    echo "yes"
  else
    echo "no"
  fi
}

display_version() {
  printf '%s' "${1%%+*}"
}

build_number() {
  local version="$1"
  if [[ "${version}" == *+* ]]; then
    printf '%s' "${version##*+}"
  else
    printf '0'
  fi
}

normalize_platform() {
  case "$1" in
    android|windows|macos|ios)
      printf '%s' "$1"
      ;;
    *)
      echo "Unsupported platform: $1" >&2
      exit 1
      ;;
  esac
}

default_release_title() {
  local platform="$1"
  local tag="$2"
  case "${platform}" in
    android) printf 'KTV Android %s' "${tag}" ;;
    windows) printf 'KTV Windows %s' "${tag}" ;;
    macos) printf 'KTV macOS %s' "${tag}" ;;
    ios) printf 'KTV iOS %s' "${tag}" ;;
  esac
}

default_release_notes() {
  local platform="$1"
  local tag="$2"
  case "${platform}" in
    android)
      if [[ ${USE_SPLIT_PER_ABI} -eq 1 ]]; then
        printf 'Android split-per-abi release package for %s.' "${tag}"
      else
        printf 'Android release package for %s.' "${tag}"
      fi
      ;;
    windows) printf 'Windows release package for %s.' "${tag}" ;;
    macos) printf 'macOS release package for %s.' "${tag}" ;;
    ios) printf 'iOS release package for %s.' "${tag}" ;;
  esac
}

release_asset_url() {
  local repo="$1"
  local tag="$2"
  local asset_path="$3"
  printf 'https://github.com/%s/releases/download/%s/%s' \
    "${repo}" \
    "${tag}" \
    "$(basename "${asset_path}")"
}

trim_trailing_slash() {
  local value="$1"
  while [[ "${value}" == */ ]]; do
    value="${value%/}"
  done
  printf '%s' "${value}"
}

is_remote_target() {
  local target="$1"
  [[ "${target}" =~ ^[^/][^:]*:.+$ ]]
}

shell_escape_single_quotes() {
  printf "%s" "$1" | sed "s/'/'\\\\''/g"
}

join_command_quoted() {
  local command=("$@")
  local index
  for index in "${!command[@]}"; do
    printf '%q' "${command[index]}"
    if [[ "${index}" -lt $((${#command[@]} - 1)) ]]; then
      printf ' '
    fi
  done
}

public_asset_url() {
  local asset_path="$1"
  if [[ -n "${DOWNLOAD_BASE_URL}" ]]; then
    printf '%s/%s' \
      "$(trim_trailing_slash "${DOWNLOAD_BASE_URL}")" \
      "$(basename "${asset_path}")"
    return
  fi
  release_asset_url "${REPO}" "${TAG}" "${asset_path}"
}

upload_release_assets() {
  local target="$1"
  shift
  local asset_paths=("$@")
  local normalized_target
  local ssh_command=("ssh")
  local ssh_key_file=""
  local ssh_rsh=""

  if [[ ${#asset_paths[@]} -eq 0 ]]; then
    return
  fi

  normalized_target="${target}"
  if is_remote_target "${target}"; then
    local remote_spec="${target%%:*}"
    local remote_path="${target#*:}"
    local escaped_remote_path
    escaped_remote_path="$(shell_escape_single_quotes "${remote_path}")"
    normalized_target="${remote_spec}:${remote_path%/}/"

    if [[ -n "${SSH_PRIVATE_KEY}" ]]; then
      ssh_key_file="$(mktemp "${TMPDIR:-/tmp}/maimai-release-key.XXXXXX")"
      chmod 600 "${ssh_key_file}"
      printf '%s\n' "${SSH_PRIVATE_KEY}" > "${ssh_key_file}"
      ssh_command+=("-i" "${ssh_key_file}" "-o" "IdentitiesOnly=yes")
    fi
    if [[ -n "${SSH_KNOWN_HOSTS_FILE}" ]]; then
      ssh_command+=(
        "-o" "UserKnownHostsFile=${SSH_KNOWN_HOSTS_FILE}"
        "-o" "StrictHostKeyChecking=yes"
      )
    else
      ssh_command+=("-o" "StrictHostKeyChecking=accept-new")
    fi
    ssh_rsh="$(join_command_quoted "${ssh_command[@]}")"

    echo "Uploading assets to ${normalized_target}..."
    if ! rsync -a -e "${ssh_rsh}" \
      --rsync-path="mkdir -p '${escaped_remote_path}' && rsync" \
      "${asset_paths[@]}" \
      "${normalized_target}"; then
      if [[ -n "${ssh_key_file}" ]]; then
        rm -f "${ssh_key_file}"
      fi
      return 1
    fi
    if [[ -n "${ssh_key_file}" ]]; then
      rm -f "${ssh_key_file}"
    fi
    return
  fi

  mkdir -p "${target}"
  normalized_target="${target%/}/"
  echo "Uploading assets to ${normalized_target}..."
  rsync -a "${asset_paths[@]}" "${normalized_target}"
}

file_sha256() {
  local asset_path="$1"
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "${asset_path}" | awk '{print $1}'
    return
  fi
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "${asset_path}" | awk '{print $1}'
    return
  fi
  return 1
}

add_manifest_note_args() {
  local text="$1"
  local line
  while IFS= read -r line; do
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    if [[ -n "${line}" ]]; then
      MANIFEST_ARGS+=(--note "${line}")
    fi
  done <<< "${text}"
}

manifest_args_have_target() {
  local arg
  for arg in "${MANIFEST_ARGS[@]}"; do
    case "${arg}" in
      --url|--feed-url|--fallback-url|--variant)
        return 0
        ;;
    esac
  done
  return 1
}

build_manifest_args_for_android() {
  MANIFEST_ARGS+=(--mode apk)
  if [[ -n "${DOWNLOAD_URL}" ]]; then
    MANIFEST_ARGS+=(--url "${DOWNLOAD_URL}")
    return
  fi
  local asset_path
  local asset_name
  local asset_url
  local sha256
  local variant_count=0

  if [[ ${#ASSET_PATHS[@]} -gt 0 ]]; then
    for asset_path in "${ASSET_PATHS[@]}"; do
      asset_name="$(basename "${asset_path}")"
      asset_url="$(public_asset_url "${asset_path}")"
      sha256="$(file_sha256 "${asset_path}" 2>/dev/null || true)"
      case "${asset_name}" in
        *android-arm64-v8a.apk)
          MANIFEST_ARGS+=(--variant "arm64-v8a|${asset_url}|${sha256}")
          variant_count=$((variant_count + 1))
          ;;
        *android-armeabi-v7a.apk)
          MANIFEST_ARGS+=(--variant "armeabi-v7a|${asset_url}|${sha256}")
          variant_count=$((variant_count + 1))
          ;;
        *android-x86_64.apk)
          MANIFEST_ARGS+=(--variant "x86_64|${asset_url}|${sha256}")
          variant_count=$((variant_count + 1))
          ;;
        *android-universal.apk)
          MANIFEST_ARGS+=(--fallback-url "${asset_url}")
          if [[ -n "${sha256}" ]]; then
            MANIFEST_ARGS+=(--fallback-sha256 "${sha256}")
          fi
          ;;
      esac
    done
  fi

  if [[ ${variant_count} -eq 0 && ${#ASSET_PATHS[@]} -gt 0 ]]; then
    asset_path="${ASSET_PATHS[0]}"
    asset_url="$(public_asset_url "${asset_path}")"
    sha256="$(file_sha256 "${asset_path}" 2>/dev/null || true)"
    MANIFEST_ARGS+=(--url "${asset_url}")
    if [[ -n "${sha256}" ]]; then
      MANIFEST_ARGS+=(--sha256 "${sha256}")
    fi
  fi
}

build_manifest_args_for_generic_platform() {
  local resolved_mode="${DOWNLOAD_MODE:-}"
  local resolved_url="${DOWNLOAD_URL:-}"
  local sha256=""
  local asset_path=""
  local asset_name=""

  if [[ -z "${resolved_mode}" ]]; then
    case "${PLATFORM}" in
      windows)
        if [[ ${#ASSET_PATHS[@]} -gt 0 ]]; then
          for asset_path in "${ASSET_PATHS[@]}"; do
            asset_name="$(basename "${asset_path}")"
            if [[ "${asset_name}" == *.appinstaller ]]; then
              resolved_mode="appinstaller"
              if [[ -z "${resolved_url}" ]]; then
                resolved_url="$(public_asset_url "${asset_path}")"
              fi
              break
            fi
          done
        fi
        ;;
      macos)
        if [[ -n "${FEED_URL}" ]]; then
          resolved_mode="sparkle"
        fi
        ;;
    esac
  fi

  if [[ -z "${resolved_mode}" ]]; then
    resolved_mode="external"
  fi

  MANIFEST_ARGS+=(--mode "${resolved_mode}")

  if [[ -n "${FEED_URL}" ]]; then
    MANIFEST_ARGS+=(--feed-url "${FEED_URL}")
  fi

  if [[ -z "${resolved_url}" && "${resolved_mode}" != "sparkle" && ${#ASSET_PATHS[@]} -gt 0 ]]; then
    asset_path="${ASSET_PATHS[0]}"
    resolved_url="$(public_asset_url "${asset_path}")"
    sha256="$(file_sha256 "${asset_path}" 2>/dev/null || true)"
  fi

  if [[ -n "${resolved_url}" ]]; then
    MANIFEST_ARGS+=(--url "${resolved_url}")
  fi
  if [[ -n "${sha256}" ]]; then
    MANIFEST_ARGS+=(--sha256 "${sha256}")
  fi
}

ensure_release_history_file() {
  local history_file="$1"
  local history_dir
  history_dir="$(dirname "${history_file}")"
  mkdir -p "${history_dir}"

  if [[ ! -f "${history_file}" ]]; then
    cat > "${history_file}" <<'EOF'
# Release History

This file records the exact branch, commit and release link used for each published package.
EOF
  fi
}

append_release_history() {
  local history_file="$1"
  local tag="$2"
  local release_title="$3"
  local release_url="$4"
  local repo="$5"
  local branch="$6"
  local commit_short="$7"
  local commit_full="$8"
  local worktree_dirty="$9"
  local release_date="${10}"
  shift 10
  local asset_paths=("$@")
  local asset_name

  ensure_release_history_file "${history_file}"

  {
    printf '\n## %s\n' "${tag}"
    printf -- '- Date: %s\n' "${release_date}"
    printf -- '- Title: %s\n' "${release_title}"
    printf -- '- Repo: %s\n' "${repo}"
    printf -- '- Branch: %s\n' "${branch}"
    printf -- '- Commit: %s (%s)\n' "${commit_short}" "${commit_full}"
    printf -- '- Dirty Worktree: %s\n' "${worktree_dirty}"
    printf -- '- Release: %s\n' "${release_url}"
    printf -- '- Assets:\n'
    for asset_path in "${asset_paths[@]}"; do
      asset_name="$(basename "${asset_path}")"
      printf '  - %s\n' "${asset_name}"
    done
  } >> "${history_file}"
}

load_release_env

REPO="${REPO:-}"
PLATFORM="${PLATFORM:-android}"
TAG="${TAG:-}"
TITLE="${TITLE:-}"
NOTES="${NOTES:-}"
NOTES_FILE="${NOTES_FILE:-}"
TARGET="${TARGET:-}"
SHOULD_BUILD="${SHOULD_BUILD:-1}"
SHOULD_CHECK_AUTH="${SHOULD_CHECK_AUTH:-1}"
GENERATE_NOTES="${GENERATE_NOTES:-0}"
DRAFT="${DRAFT:-0}"
PRERELEASE="${PRERELEASE:-0}"
USE_SPLIT_PER_ABI="${USE_SPLIT_PER_ABI:-1}"
DRY_RUN="${DRY_RUN:-0}"
RELEASE_HISTORY_FILE="${RELEASE_HISTORY_FILE:-${DEFAULT_RELEASE_HISTORY_FILE}}"
LATEST_MANIFEST_FILE="${LATEST_MANIFEST_FILE:-${DEFAULT_LATEST_MANIFEST_FILE}}"
SHOULD_UPDATE_LATEST_MANIFEST="${SHOULD_UPDATE_LATEST_MANIFEST:-1}"
DOWNLOAD_MODE="${DOWNLOAD_MODE:-}"
DOWNLOAD_URL="${DOWNLOAD_URL:-}"
FEED_URL="${FEED_URL:-}"
REQUIRED_UPDATE="${REQUIRED_UPDATE:-0}"
DOWNLOAD_BASE_URL="${DOWNLOAD_BASE_URL:-}"
UPLOAD_TARGET="${UPLOAD_TARGET:-}"
SKIP_GITHUB_ASSETS="${SKIP_GITHUB_ASSETS:-0}"
SSH_PRIVATE_KEY="${SSH_PRIVATE_KEY:-}"
SSH_KNOWN_HOSTS_FILE="${SSH_KNOWN_HOSTS_FILE:-}"
declare -a ASSET_PATHS=()
declare -a MANIFEST_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)
      REPO="${2:-}"
      shift 2
      ;;
    --platform)
      PLATFORM="$(normalize_platform "${2:-}")"
      shift 2
      ;;
    --tag)
      TAG="${2:-}"
      shift 2
      ;;
    --title)
      TITLE="${2:-}"
      shift 2
      ;;
    --notes)
      NOTES="${2:-}"
      shift 2
      ;;
    --notes-file)
      NOTES_FILE="${2:-}"
      shift 2
      ;;
    --asset)
      ASSET_PATHS+=("${2:-}")
      shift 2
      ;;
    --target)
      TARGET="${2:-}"
      shift 2
      ;;
    --release-history-file)
      RELEASE_HISTORY_FILE="${2:-}"
      shift 2
      ;;
    --draft)
      DRAFT=1
      shift
      ;;
    --prerelease)
      PRERELEASE=1
      shift
      ;;
    --generate-notes)
      GENERATE_NOTES=1
      shift
      ;;
    --no-split-per-abi)
      USE_SPLIT_PER_ABI=0
      shift
      ;;
    --skip-build)
      SHOULD_BUILD=0
      shift
      ;;
    --download-mode)
      DOWNLOAD_MODE="${2:-}"
      shift 2
      ;;
    --download-url)
      DOWNLOAD_URL="${2:-}"
      shift 2
      ;;
    --download-base-url)
      DOWNLOAD_BASE_URL="${2:-}"
      shift 2
      ;;
    --feed-url)
      FEED_URL="${2:-}"
      shift 2
      ;;
    --upload-target)
      UPLOAD_TARGET="${2:-}"
      shift 2
      ;;
    --skip-github-assets)
      SKIP_GITHUB_ASSETS=1
      shift
      ;;
    --latest-manifest-file)
      LATEST_MANIFEST_FILE="${2:-}"
      shift 2
      ;;
    --skip-latest-manifest)
      SHOULD_UPDATE_LATEST_MANIFEST=0
      shift
      ;;
    --required-update)
      REQUIRED_UPDATE=1
      shift
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --skip-auth-check)
      SHOULD_CHECK_AUTH=0
      shift
      ;;
    -h|--help)
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

if [[ -z "${REPO}" ]]; then
  echo "--repo is required." >&2
  usage >&2
  exit 1
fi

if [[ -n "${NOTES}" && -n "${NOTES_FILE}" ]]; then
  echo "--notes and --notes-file cannot be used together." >&2
  exit 1
fi

if [[ ${GENERATE_NOTES} -eq 1 && ( -n "${NOTES}" || -n "${NOTES_FILE}" ) ]]; then
  echo "--generate-notes cannot be combined with --notes or --notes-file." >&2
  exit 1
fi

require_command gh

if [[ -n "${UPLOAD_TARGET}" ]]; then
  require_command rsync
fi

if [[ ${SHOULD_BUILD} -eq 1 ]]; then
  if [[ "${PLATFORM}" != "android" ]]; then
    echo "Automatic build is currently only supported for --platform android." >&2
    echo "Use --skip-build and pass --asset for ${PLATFORM} releases." >&2
    exit 1
  fi
  require_command flutter
fi

if [[ ${SHOULD_UPDATE_LATEST_MANIFEST} -eq 1 ]]; then
  DART_CMD="$(resolve_dart_command)"
fi

VERSION="$(read_pubspec_version)"
if [[ -z "${VERSION}" ]]; then
  echo "Failed to read version from pubspec.yaml." >&2
  exit 1
fi
DISPLAY_VERSION="$(display_version "${VERSION}")"
BUILD_NUMBER="$(build_number "${VERSION}")"
PUBLISHED_AT="$(current_timestamp_utc)"

CURRENT_BRANCH="$(current_branch)"
CURRENT_COMMIT_SHORT="$(current_commit_short)"
CURRENT_COMMIT_FULL="$(current_commit_full)"
CURRENT_DATE="$(current_date)"
WORKTREE_DIRTY="$(is_worktree_dirty)"

if [[ -z "${TAG}" ]]; then
  TAG="v${DISPLAY_VERSION}"
fi

if [[ -z "${TITLE}" ]]; then
  TITLE="$(default_release_title "${PLATFORM}" "${TAG}")"
fi

if [[ ${SHOULD_CHECK_AUTH} -eq 1 && ${DRY_RUN} -eq 0 ]]; then
  echo "Checking GitHub authentication..."
  gh auth status >/dev/null
fi

if [[ ${#ASSET_PATHS[@]} -eq 0 ]]; then
  if [[ "${PLATFORM}" == "android" ]]; then
    while IFS= read -r asset_path; do
      ASSET_PATHS+=("${asset_path}")
    done < <(default_android_asset_paths "${DISPLAY_VERSION}" "${USE_SPLIT_PER_ABI}")
  fi
fi

if [[ ${SHOULD_BUILD} -eq 1 ]]; then
  echo "Building Android release APK..."
  build_args=()
  if [[ ${USE_SPLIT_PER_ABI} -eq 0 ]]; then
    build_args+=(--no-split-per-abi)
  fi
  (
    cd "${ROOT_DIR}"
    scripts/build_android_apk.sh "${build_args[@]}"
  )
fi

if [[ ${#ASSET_PATHS[@]} -gt 0 ]]; then
  for asset_path in "${ASSET_PATHS[@]}"; do
    if [[ ! -f "${asset_path}" ]]; then
      echo "Asset not found: ${asset_path}" >&2
      exit 1
    fi
  done
fi

if [[ -n "${NOTES_FILE}" ]]; then
  if [[ ! -f "${NOTES_FILE}" ]]; then
    echo "Notes file not found: ${NOTES_FILE}" >&2
    exit 1
  fi
fi

if [[ -n "${DOWNLOAD_BASE_URL}" ]]; then
  DOWNLOAD_BASE_URL="$(trim_trailing_slash "${DOWNLOAD_BASE_URL}")"
fi

if [[ ${SHOULD_UPDATE_LATEST_MANIFEST} -eq 1 ]]; then
  MANIFEST_ARGS=(
    --file "${LATEST_MANIFEST_FILE}"
    --platform "${PLATFORM}"
    --version "${DISPLAY_VERSION}"
    --build-number "${BUILD_NUMBER}"
    --published-at "${PUBLISHED_AT}"
  )

  if [[ ${REQUIRED_UPDATE} -eq 1 ]]; then
    MANIFEST_ARGS+=(--required-update)
  fi

  if [[ -n "${NOTES}" ]]; then
    add_manifest_note_args "${NOTES}"
  elif [[ -n "${NOTES_FILE}" ]]; then
    add_manifest_note_args "$(cat "${NOTES_FILE}")"
  elif [[ ${GENERATE_NOTES} -eq 0 ]]; then
    add_manifest_note_args "$(default_release_notes "${PLATFORM}" "${TAG}")"
  fi

  if [[ "${PLATFORM}" == "android" ]]; then
    build_manifest_args_for_android
  else
    build_manifest_args_for_generic_platform
  fi

  if ! manifest_args_have_target; then
    echo "Cannot update latest manifest without a download target for ${PLATFORM}." >&2
    echo "Pass --asset, --download-url, or --feed-url, or use --skip-latest-manifest." >&2
    exit 1
  fi
fi

declare -a gh_args
gh_args=(release create "${TAG}" --repo "${REPO}" --title "${TITLE}")

if [[ ${SKIP_GITHUB_ASSETS} -eq 0 && ${#ASSET_PATHS[@]} -gt 0 ]]; then
  for asset_path in "${ASSET_PATHS[@]}"; do
    gh_args+=("${asset_path}")
  done
fi

if [[ -n "${TARGET}" ]]; then
  gh_args+=(--target "${TARGET}")
fi

if [[ ${DRAFT} -eq 1 ]]; then
  gh_args+=(--draft)
fi

if [[ ${PRERELEASE} -eq 1 ]]; then
  gh_args+=(--prerelease)
fi

if [[ ${GENERATE_NOTES} -eq 1 ]]; then
  gh_args+=(--generate-notes)
elif [[ -n "${NOTES}" ]]; then
  gh_args+=(--notes "${NOTES}")
elif [[ -n "${NOTES_FILE}" ]]; then
  gh_args+=(--notes-file "${NOTES_FILE}")
else
  gh_args+=(--notes "$(default_release_notes "${PLATFORM}" "${TAG}")")
fi

if [[ ${DRY_RUN} -eq 1 ]]; then
  echo "Dry run only. Release will not be published."
  echo "Platform: ${PLATFORM}"
  echo "Repo: ${REPO}"
  echo "Tag: ${TAG}"
  echo "Title: ${TITLE}"
  echo "Assets:"
  if [[ ${#ASSET_PATHS[@]} -gt 0 ]]; then
    for asset_path in "${ASSET_PATHS[@]}"; do
      echo "  - ${asset_path}"
    done
  else
    echo "  (none)"
  fi
  echo "Command:"
  printf '  gh'
  for arg in "${gh_args[@]}"; do
    printf ' %q' "${arg}"
  done
  printf '\n'
  if [[ -n "${UPLOAD_TARGET}" && ${#ASSET_PATHS[@]} -gt 0 ]]; then
    echo "Upload target: ${UPLOAD_TARGET}"
    echo "Upload command:"
    printf '  rsync -a'
    for asset_path in "${ASSET_PATHS[@]}"; do
      printf ' %q' "${asset_path}"
    done
    printf ' %q\n' "${UPLOAD_TARGET}"
  fi
  if [[ ${SHOULD_UPDATE_LATEST_MANIFEST} -eq 1 ]]; then
    echo "Latest manifest file: ${LATEST_MANIFEST_FILE}"
    echo "Manifest update command:"
    printf '  %q %q' "${DART_CMD}" "scripts/update_latest_manifest.dart"
    for arg in "${MANIFEST_ARGS[@]}"; do
      printf ' %q' "${arg}"
    done
    printf '\n'
  fi
  exit 0
fi

if [[ -n "${UPLOAD_TARGET}" && ${#ASSET_PATHS[@]} -gt 0 ]]; then
  upload_release_assets "${UPLOAD_TARGET}" "${ASSET_PATHS[@]}"
fi

echo "Publishing release ${TAG} to ${REPO}..."
RELEASE_URL="$(gh "${gh_args[@]}")"

echo "Release published successfully."
echo "${RELEASE_URL}"

if [[ ${SHOULD_UPDATE_LATEST_MANIFEST} -eq 1 ]]; then
  (
    cd "${ROOT_DIR}"
    "${DART_CMD}" scripts/update_latest_manifest.dart "${MANIFEST_ARGS[@]}"
  )
  echo "Latest manifest updated: ${LATEST_MANIFEST_FILE}"
fi

append_release_history \
  "${RELEASE_HISTORY_FILE}" \
  "${TAG}" \
  "${TITLE}" \
  "${RELEASE_URL}" \
  "${REPO}" \
  "${CURRENT_BRANCH}" \
  "${CURRENT_COMMIT_SHORT}" \
  "${CURRENT_COMMIT_FULL}" \
  "${WORKTREE_DIRTY}" \
  "${CURRENT_DATE}" \
  "${ASSET_PATHS[@]}"

echo "Release history updated: ${RELEASE_HISTORY_FILE}"
