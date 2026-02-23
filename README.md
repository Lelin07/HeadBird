<p align="center">
  <img src="docs/assets/headbird-icon-squircle.png" alt="HeadBird icon" width="180" />
</p>

<h1 align="center">HeadBird</h1>

<p align="center">
  HeadBird is a native macOS menu bar app that reads AirPods head-tracking motion and visualizes Roll, Pitch, and Yaw in real time.
</p>

<p align="center">
  <img alt="Version" src="https://img.shields.io/badge/version-v0.1.0-blue" />
  <img alt="Platform" src="https://img.shields.io/badge/platform-macOS%2014%2B-black?logo=apple" />
  <img alt="Language" src="https://img.shields.io/badge/Swift-6.0-F05138?logo=swift&logoColor=white" />
  <img alt="UI" src="https://img.shields.io/badge/UI-SwiftUI-0A84FF" />
  <img alt="Framework" src="https://img.shields.io/badge/Framework-AppKit-1F1F1F" />
  <img alt="Framework" src="https://img.shields.io/badge/Framework-Combine-0A84FF" />
  <img alt="Framework" src="https://img.shields.io/badge/Framework-CoreMotion-34C759" />
  <img alt="Framework" src="https://img.shields.io/badge/Framework-CoreBluetooth-007AFF" />
  <img alt="Framework" src="https://img.shields.io/badge/Framework-IOBluetooth-0A84FF" />
  <img alt="Framework" src="https://img.shields.io/badge/Framework-SpriteKit-EA4AAA" />
  <img alt="Framework" src="https://img.shields.io/badge/Framework-AudioToolbox-FF9F0A" />
  <img alt="Tooling" src="https://img.shields.io/badge/Xcode-15%2B-147EFB?logo=xcode&logoColor=white" />
</p>

## Table of Contents

- [Features](#features)
- [Install From Released DMG (Future Releases)](#install-from-released-dmg-future-releases)
- [If macOS Shows "Malware" / Unverified Developer Warning](#if-macos-shows-malware--unverified-developer-warning)
- [First-Launch Permissions](#first-launch-permissions)
- [Build From Source (Xcode)](#build-from-source-xcode)
- [Running Tests Locally](#running-tests-locally)
- [DMG Release Wizard (Maintainers)](#dmg-release-wizard-maintainers)
  - [Quickstart (Recommended)](#quickstart-recommended)
  - [Advanced Non-Interactive Usage](#advanced-non-interactive-usage)
  - [Troubleshooting](#troubleshooting)
- [Versioning](#versioning)
- [Privacy](#privacy)

## Features

- Real-time Roll, Pitch, and Yaw visualization.
- Motion history graph for quick trend reading.
- One-click zero calibration.
- Head-controlled mini game (tilt your head up/down to play).
- Lightweight macOS menu bar UX.

## Install From Released DMG (Future Releases)

When a release is published on GitHub:

1. Open the latest release and download `HeadBird-<version>-macos-*.dmg`.
2. Double-click the `.dmg` file.
3. Drag `HeadBird.app` into `Applications`.
4. Launch `HeadBird` from `Applications` or Spotlight.

## If macOS Shows "Malware" / Unverified Developer Warning

> [!WARNING]
> Because early releases may be distributed without Apple notarization, macOS Gatekeeper can block first launch.
>
> Use one of these methods:
>
> 1. **Finder method:**
>    - Open `Applications`.
>    - Right-click `HeadBird.app` and click `Open`.
>    - Click `Open` again in the security prompt.
> 2. **System Settings method:**
>    - Try opening the app once.
>    - Go to `System Settings -> Privacy & Security`.
>    - In the Security section, click `Open Anyway` for HeadBird.
> 3. **Terminal fallback (advanced users):**
>    ```bash
>    xattr -dr com.apple.quarantine "/Applications/HeadBird.app"
>    ```
>
> **Notes:**
> - Only remove quarantine for apps you trust.
> - If checksum is provided in the release notes, verify it before first launch.

## First-Launch Permissions

HeadBird requests:

- Bluetooth permission (to detect AirPods connection state).
- Motion permission (to read AirPods head-tracking data).

If previously denied, re-enable in `System Settings -> Privacy & Security`.

## Build From Source (Xcode)

Requirements:

- macOS 14+
- Xcode 15+
- AirPods connected to your Mac

Run:

1. Open `HeadBird.xcodeproj`.
2. Select scheme `HeadBird` and destination `My Mac`.
3. Press `Cmd + R`.
4. Click the menu bar icon to open the app UI.

## Running Tests Locally

Run the local test script:

```bash
./scripts/run-tests.sh
```

Or run `xcodebuild` directly:

```bash
xcodebuild test \
  -project HeadBird.xcodeproj \
  -scheme HeadBird \
  -destination 'platform=macOS,arch=arm64' \
  CODE_SIGNING_ALLOWED=NO
```

## DMG Release Wizard (Maintainers)

HeadBird now includes an interactive shell wizard for packaging a release DMG.

### Quickstart (Recommended)

1. Build `Release` in Xcode.
2. In Xcode, open `Product -> Show Build Folder in Finder`.
3. Locate `HeadBird.app` under `Build/Products/Release`.
4. Run the wizard:

```bash
./scripts/make-release-dmg.sh
```

5. Follow prompts for:
   - Absolute app path (`.../HeadBird.app`)
   - Version (`0.1.0`, etc.)
   - Output directory (default: `~/Desktop`)
   - Volume name (default: `HeadBird`)
   - Optional background image (`.png/.jpg`)
6. During the Finder layout step, place `HeadBird.app` on the left and `Applications` alias on the right.
7. After conversion, copy the printed SHA-256 and upload the final DMG to GitHub Releases.

### Advanced Non-Interactive Usage

For repeatable runs, you can pass all values as flags:

```bash
./scripts/make-release-dmg.sh \
  --app-path "/ABSOLUTE/PATH/TO/HeadBird.app" \
  --version "0.1.0" \
  --output-dir "$HOME/Desktop" \
  --volume-name "HeadBird" \
  --non-interactive
```

Optional flags:

- `--background-image "/ABSOLUTE/PATH/TO/background.png"`
- `--force` to overwrite an existing final DMG
- `--help` for full usage

### Troubleshooting

If conversion fails with `Resource temporarily unavailable`:

1. Ensure no Finder/terminal window is using the mounted volume.
2. Detach the mounted device:

```bash
hdiutil info
hdiutil detach <device> -force
```

3. Re-run the wizard or retry conversion.

The wizard also prints `lsof` output and exact recovery commands when conversion fails.

## Versioning

HeadBird follows Semantic Versioning.

- Current planned public baseline: `v0.1.0`.
- `MARKETING_VERSION` should remain `0.1.0` in Xcode for this release line.

## Privacy

- No microphone recording.
- No audio content processing.
- Uses local device state and motion signals only for app features.
