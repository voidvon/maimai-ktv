#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
DEFAULT_RELEASE_HISTORY_FILE="${ROOT_DIR}/docs/release-history.md"

usage() {
  cat <<'EOF'
Usage:
  scripts/publish_github_release.sh --repo <owner/repo> [options]

Options:
  --repo <owner/repo>      Target GitHub repository for the release. Required.
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

require_command() {
  local command_name="$1"
  if ! command -v "${command_name}" >/dev/null 2>&1; then
    echo "Missing required command: ${command_name}" >&2
    exit 1
  fi
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

is_worktree_dirty() {
  if [[ -n "$(git -C "${ROOT_DIR}" status --porcelain)" ]]; then
    echo "yes"
  else
    echo "no"
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

REPO=""
TAG=""
TITLE=""
NOTES=""
NOTES_FILE=""
TARGET=""
SHOULD_BUILD=1
SHOULD_CHECK_AUTH=1
GENERATE_NOTES=0
DRAFT=0
PRERELEASE=0
USE_SPLIT_PER_ABI=1
RELEASE_HISTORY_FILE="${DEFAULT_RELEASE_HISTORY_FILE}"
declare -a ASSET_PATHS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)
      REPO="${2:-}"
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

if [[ ${SHOULD_BUILD} -eq 1 ]]; then
  require_command flutter
fi

VERSION="$(read_pubspec_version)"
if [[ -z "${VERSION}" ]]; then
  echo "Failed to read version from pubspec.yaml." >&2
  exit 1
fi

CURRENT_BRANCH="$(current_branch)"
CURRENT_COMMIT_SHORT="$(current_commit_short)"
CURRENT_COMMIT_FULL="$(current_commit_full)"
CURRENT_DATE="$(current_date)"
WORKTREE_DIRTY="$(is_worktree_dirty)"

if [[ -z "${TAG}" ]]; then
  TAG="v${VERSION%%+*}"
fi

if [[ -z "${TITLE}" ]]; then
  TITLE="KTV Android ${TAG}"
fi

if [[ ${SHOULD_CHECK_AUTH} -eq 1 ]]; then
  echo "Checking GitHub authentication..."
  gh auth status >/dev/null
fi

if [[ ${#ASSET_PATHS[@]} -eq 0 ]]; then
  while IFS= read -r asset_path; do
    ASSET_PATHS+=("${asset_path}")
  done < <(default_android_asset_paths "${VERSION}" "${USE_SPLIT_PER_ABI}")
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

for asset_path in "${ASSET_PATHS[@]}"; do
  if [[ ! -f "${asset_path}" ]]; then
    echo "Asset not found: ${asset_path}" >&2
    exit 1
  fi
done

if [[ -n "${NOTES_FILE}" ]]; then
  if [[ ! -f "${NOTES_FILE}" ]]; then
    echo "Notes file not found: ${NOTES_FILE}" >&2
    exit 1
  fi
fi

declare -a gh_args
gh_args=(release create "${TAG}" --repo "${REPO}" --title "${TITLE}")

for asset_path in "${ASSET_PATHS[@]}"; do
  gh_args+=("${asset_path}")
done

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
  if [[ ${USE_SPLIT_PER_ABI} -eq 1 ]]; then
    gh_args+=(--notes "Android split-per-abi release package for ${TAG}.")
  else
    gh_args+=(--notes "Android release package for ${TAG}.")
  fi
fi

echo "Publishing release ${TAG} to ${REPO}..."
RELEASE_URL="$(gh "${gh_args[@]}")"

echo "Release published successfully."
echo "${RELEASE_URL}"

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
