---
name: release-publisher
description: Use when the user wants to prepare or publish a new version, draft AI-written release notes, update changelog/history files, build release artifacts, or create/update a GitHub Release. This skill is specifically for release workflows where commit/branch metadata are support material, but the final update notes must be synthesized into human-readable product changes rather than mechanically copied from git logs.
---

# Release Publisher

## Overview

Handle end-to-end release work: choose the next version label, inspect the real code changes, write release notes in product language, build artifacts, publish the GitHub Release, and update local release records.

The key rule is that release notes are authored summaries, not commit dumps. Branch, tag, and commit data are evidence and traceability inputs, but the published notes should explain what changed for users.

## Use This Skill When

- The user asks to publish a new `alpha`, `beta`, `rc`, or stable version.
- The user wants release notes, changelog entries, or GitHub Release content.
- The user wants the next version number chosen from the current release history.
- The user wants packaged artifacts built and uploaded to a release.
- The user wants branch / commit / tag metadata recorded for traceability.

## Workflow

### 1. Establish Release Intent

Determine:

- release channel: `alpha`, `beta`, `rc`, or stable
- target repository for the GitHub Release
- target artifacts to build and upload
- whether this is a new release or an update to an existing tag

If the repo already has a release history, use it to infer the next version instead of guessing.

### 2. Gather Release Context

Collect release evidence before writing notes:

- current branch: `git branch --show-current`
- current commit: `git rev-parse --short HEAD`
- full commit: `git rev-parse HEAD`
- worktree state: `git status --porcelain`
- previous releases / tags
- current release tooling and project release docs
- the actual changed files or commits since the previous release

Prefer this order:

1. Read local files such as `CHANGELOG.md`, `docs/release-history.md`, and any repo-specific release script.
2. Inspect `git log`, `git diff --stat`, and targeted changed files.
3. Read only the specific source files needed to understand user-visible impact.

Do not write release notes from commit subjects alone.

### 3. Write AI Release Notes

Use the gathered context to synthesize 2-5 meaningful change themes.

Release notes should:

- describe user-visible outcomes
- group related changes into coherent themes
- mention platform or package scope when relevant
- mention risks or limitations only when they are real
- stay concise enough for GitHub Release consumption

Release notes should not:

- mechanically list every commit
- expose internal refactor noise unless it changes behavior
- claim verification you did not perform
- hide important limitations

Read `references/release-notes-style.md` before drafting the final notes.

### 4. Update Local Release Records

Keep two local records distinct:

- `CHANGELOG.md`
  - user-facing summary
  - newest version goes at the top
  - write product-facing language
- `docs/release-history.md`
  - operator-facing traceability
  - record date, branch, commit, dirty state, release link, and uploaded assets

If a publish script already updates the history file automatically, do not duplicate the same entry manually unless the script has not run yet.

### 5. Build and Publish

Prefer the repository's own publish script when one exists.

For the current KTV repository, default to:

- build Android with split-per-ABI packages
- use `scripts/publish_github_release.sh`
- publish to `voidvon/maimai-ktv` unless the user overrides it

If the target GitHub repository is empty, initialize it with a minimal first commit before creating the Release.

### 6. Verify the Release

After publishing:

- confirm the release URL
- confirm `prerelease` vs stable flag
- confirm uploaded asset names
- ensure local history files reflect the release

## Output Rules

- Present the proposed release notes before publishing if the user is still deciding on wording.
- When the user asks you to proceed directly, publish first and then show the exact notes that were used.
- Treat `branch`, `commit`, and `dirty worktree` as release metadata, not as the main body of update notes.
- If the current worktree is dirty, call that out explicitly because the release may not map cleanly to a single committed state.
- If there is not enough evidence to support a user-facing claim, either omit it or label it as a tentative note.

## KTV Repo Defaults

For `/Users/yytest/Documents/projects/ktv`:

- changelog file: `CHANGELOG.md`
- release history file: `docs/release-history.md`
- publish script: `scripts/publish_github_release.sh`
- default GitHub release repository: `voidvon/maimai-ktv`
- Android release preference: split-per-ABI APKs
- early releases should default to `alpha` unless the user says otherwise

## Example Requests

- `用 $release-publisher 帮我准备下一个 alpha 版本，先写一版更新说明给我确认。`
- `用 $release-publisher 根据上一个 release 到现在的改动，发布一个 beta 版本。`
- `用 $release-publisher 整理这次 Android 分包发布的 changelog，并同步发到 GitHub Release。`
