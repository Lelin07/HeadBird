# Contributing to HeadBird

Thanks for contributing to HeadBird. This guide explains how to report issues, propose features, and submit high-quality pull requests.

## Table of Contents

- [Ways to Contribute](#ways-to-contribute)
- [Before You Open an Issue](#before-you-open-an-issue)
- [Development Setup](#development-setup)
- [Build, Run, and Test Locally](#build-run-and-test-locally)
- [Project Structure](#project-structure)
- [Coding Guidelines](#coding-guidelines)
- [Testing Guidelines](#testing-guidelines)
- [Branch and Commit Guidelines](#branch-and-commit-guidelines)
- [Pull Request Guidelines](#pull-request-guidelines)
- [CI and Automation](#ci-and-automation)
- [Labels and Triage](#labels-and-triage)
- [Privacy and Security Notes](#privacy-and-security-notes)
- [Need Help?](#need-help)

## Ways to Contribute

You can help by:

- Reporting bugs
- Proposing features
- Improving documentation
- Adding or improving tests
- Refactoring for readability and maintainability
- Fixing performance or stability issues

## Before You Open an Issue

1. Check existing issues and pull requests for duplicates.
2. Use the appropriate issue template:
   - `Bug report`
   - `Feature request`
   - `Question`
3. Include enough detail for reproduction or evaluation:
   - macOS version
   - Mac model/chip
   - AirPods model (if relevant)
   - Xcode version (if relevant)
4. For bugs, include clear steps to reproduce and expected vs. actual behavior.

Issue templates are in `.github/ISSUE_TEMPLATE/`.

## Development Setup

### Requirements

- macOS 14+
- Xcode 15+
- AirPods (recommended for hardware-dependent features)

### Clone and Open

```bash
git clone https://github.com/Lelin07/HeadBird.git
cd HeadBird
open HeadBird.xcodeproj
```

In Xcode:

1. Select scheme `HeadBird`.
2. Select destination `My Mac`.
3. Build or run with `Cmd + B` / `Cmd + R`.

## Build, Run, and Test Locally

### Run the Test Script

```bash
./scripts/run-tests.sh
```

### Run Tests Directly with `xcodebuild`

```bash
xcodebuild test \
  -project HeadBird.xcodeproj \
  -scheme HeadBird \
  -destination 'platform=macOS,arch=arm64' \
  CODE_SIGNING_ALLOWED=NO
```

### Optional: Mirror CI Build + Analyze + Test Flow

```bash
xcodebuild build \
  -project HeadBird.xcodeproj \
  -scheme HeadBird \
  -destination 'platform=macOS,arch=arm64' \
  CODE_SIGNING_ALLOWED=NO

xcodebuild analyze \
  -project HeadBird.xcodeproj \
  -scheme HeadBird \
  -destination 'platform=macOS,arch=arm64' \
  CODE_SIGNING_ALLOWED=NO

xcodebuild test \
  -project HeadBird.xcodeproj \
  -scheme HeadBird \
  -destination 'platform=macOS,arch=arm64' \
  CODE_SIGNING_ALLOWED=NO
```

## Project Structure

High-level layout:

- `HeadBird/Sources/App/`: App lifecycle, status bar integration, app intents
- `HeadBird/Sources/UI/`: SwiftUI views and reusable UI components
- `HeadBird/Sources/Services/`: Motion, Bluetooth, and action execution services
- `HeadBird/Sources/Models/`: Domain and state models
- `HeadBird/Sources/Game/`: Game views/scenes and game state
- `HeadBirdTests/`: Unit tests and behavioral tests
- `scripts/`: Utility scripts (tests, release packaging)
- `.github/workflows/`: CI, labeling, and workflow lint jobs
- `docs/`: Project assets and documentation resources

## Coding Guidelines

Follow existing code patterns in the touched area; optimize for consistency over personal preference.

### Swift and Architecture

- Keep responsibilities clear by layer (`App`, `UI`, `Services`, `Models`, `Game`).
- Prefer small, focused types and methods.
- Avoid force unwraps unless there is a documented invariant.
- Handle errors and optional states explicitly.
- Minimize side effects in model logic; isolate IO in service/app layers.

### Readability

- Use descriptive names.
- Remove dead code and stale comments.
- Add concise comments only where behavior is non-obvious.

### Scope Control

- Keep PRs focused on one logical change.
- Avoid mixing refactors with feature/bug changes unless required.
- Do not introduce new dependencies without clear justification.

## Testing Guidelines

### Expectations

- Add or update tests for all behavior changes.
- Include regression tests for bug fixes when feasible.
- Keep tests deterministic and independent.

### Test Placement

- Add tests under `HeadBirdTests/`.
- Prefer locating tests near related domain areas (for example, gesture, model, or game logic tests).

### Hardware-Dependent Changes

For changes that depend on AirPods/head motion:

- Add unit tests for logic that can be isolated.
- Document manual verification steps in the PR description.

## Branch and Commit Guidelines

### Branching

- Start from the latest `main`.
- Use a short, descriptive branch name, for example:
  - `fix/yaw-history-overflow`
  - `feature/gesture-threshold-tuning`
  - `docs/update-contributing-guide`

### Commits

- Use imperative mood (for example, `Fix crash in motion monitor`).
- Keep commits focused and reviewable.
- Squash noisy "fix typo" commits before merge when possible.

## Pull Request Guidelines

### Before Opening a PR

- Rebase on latest `main` (or merge `main` if your workflow requires it).
- Run tests locally.
- Ensure no unrelated files are changed.
- Verify the app builds cleanly in Xcode.

### PR Description Checklist

Include:

- What changed
- Why it changed
- How it was tested (commands + results)
- Any manual verification performed
- Screenshots/recordings for UI changes
- Linked issue(s), if applicable

### Review Readiness

- Keep PRs as small as practical.
- Call out tradeoffs or known limitations.
- Mark draft PRs clearly until ready.

## CI and Automation

This repository currently uses:

- `Xcode Build and Analyze` workflow:
  - Runs `build`, `analyze`, and `test` for code changes in:
    - `HeadBird/**`
    - `HeadBirdTests/**`
    - `HeadBird.xcodeproj/**`
- `Workflow Lint` workflow:
  - Runs on workflow/config changes in `.github/workflows/**`, `.github/labeler.yml`, and `.github/issue-labeler.yml`
- `Pull Request Labeler`:
  - Applies labels based on changed file paths using `.github/labeler.yml`
- `Issue Labeler`:
  - Applies labels based on issue title/body using `.github/issue-labeler.yml`

If CI fails, include diagnosis and fix in the same PR when possible.

## Labels and Triage

### Common Area Labels (PRs)

Labels are applied automatically from changed paths, including:

- `app`
- `game`
- `models`
- `services`
- `ui`
- `tests`
- `assets`
- `build`
- `ci`
- `docs`

### Issue Labels

Issue templates and title/body matching can apply labels such as:

- `bug`
- `enhancement`
- `question`
- `documentation`
- `tests`
- `ci`

## Privacy and Security Notes

HeadBird uses local device state and motion signals. When reporting issues:

- Do not include personal/private data in screenshots or logs.
- Redact machine names, account IDs, and other sensitive details as needed.

For security-sensitive findings, open a private security report through GitHub Security Advisories instead of filing a public issue.

## Need Help?

- For setup/usage questions, use the `Question` issue template.
- Check the project README first for install, permissions, build, test, and troubleshooting guidance.
