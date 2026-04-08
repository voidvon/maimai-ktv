# Release Notes Style

## Goal

Turn git history and changed files into a short product update that a human can read quickly.

## Preferred Structure

Use this order when it fits:

1. one-line release summary
2. 2-5 grouped change bullets
3. optional risk / compatibility note

## Writing Rules

- Prefer outcome language: `improves playback switching` instead of `refactors player controller`.
- Merge low-level commits into one higher-level point when they serve the same behavior.
- Mention platform scope when needed: `Android`, `macOS`, `KTV shell`, `download flow`.
- Keep each bullet self-contained.
- If the release is prerelease, say so explicitly.

## Avoid

- raw commit lists
- file path dumps
- vague bullets like `fix some issues`
- claiming a fix is stable if it was not verified

## Good Patterns

- `Improved cloud-song download continuity, with clearer recovery behavior after interruptions.`
- `Refined the KTV control flow so queue actions and playback controls are easier to follow during active singing.`
- `Added split-per-ABI Android packages for smaller and more targeted installation artifacts.`

## Traceability

Branch, commit, tag, release URL, and asset names belong in release history records, not in the main update bullets unless the user explicitly asks for operator-facing notes.
