# HeadBird

A minimal macOS menu bar app that visualizes your AirPods status and motion with a clean horizon view, dials, and history graph. Includes a head‑controlled mini game.

## Standard App Flow (User)

1. Install the app (see Install below).
2. Launch HeadBird — it appears in the **menu bar**.
3. Click the icon to open the popover.
4. **Motion tab** shows:
   - AirPods model name + Connected/Not connected pill
   - Horizon + pitch/roll/yaw dials
   - History graph with selectable styles
   - Set Zero to calibrate
5. **Game tab** shows:
   - Status pill
   - Play/Reset controls
   - Tilt your head to fly
6. **About tab** shows:
   - Version, privacy, signals, and GitHub link

## Install (One‑Click for Users)

The easiest one‑click experience is a **signed + notarized** DMG or ZIP from GitHub Releases:

1. Download the latest release.
2. Open the DMG and drag **HeadBird.app** into **Applications**.
3. Launch HeadBird from Applications (or Spotlight).

If the app is **not notarized**, macOS Gatekeeper will block it. In that case:
- Right‑click the app → **Open** → **Open**.
- Or go to **System Settings → Privacy & Security → Open Anyway**.

## Build from Source (Developers)

### Prerequisites
- macOS 14 or later
- Xcode 15 or later
- AirPods connected to the Mac

### Run in Xcode (Recommended)
1. Open `HeadBird.xcodeproj` in Xcode.
2. Select the `HeadBird` scheme and `My Mac` run destination.
3. Press `Cmd + R` to build and run.
4. Click the menu bar icon to open HeadBird.
5. On first launch, allow:
   - Bluetooth access (for connected headset detection)
   - Motion access (for AirPods head-tracking data)

### Verify It Is Working
1. Set AirPods as the default output device in macOS.
2. Open HeadBird and go to the **Motion** tab.
3. Confirm the status is connected and motion values update when moving your head.

### Troubleshooting
- If motion does not start, quit HeadBird, reconnect AirPods, and relaunch.
- If prompts were previously denied, re-enable permissions in:
  `System Settings -> Privacy & Security`.
- If Xcode appears to run stale binaries, use `Product -> Clean Build Folder` and run again.

## Pre‑Release DMG (Maintainers)

### 1) Build unsigned app
```bash
./scripts/build-unsigned.sh
```
This outputs the app path at `dist/HeadBird.app`.

### 2) Create DMG (drag‑to‑Applications)
```bash
./scripts/make-dmg.sh "dist/HeadBird.app"
```

The DMG will be at `dist/HeadBird.dmg`.

### 3) Upload to GitHub Releases
- Mark the release as **Pre‑release**
- Upload `dist/HeadBird.dmg` as the binary

## Motion Permission

HeadBird needs motion permission to read AirPods motion data.
- Ensure `NSMotionUsageDescription` exists in the app Info.plist.
- You will be prompted on first run.

## Signals (Current)

- Default audio output device
- Bluetooth connection state for AirPods
- Headphone motion (CMHeadphoneMotionManager)

## Privacy

- No microphone usage
- No audio processing

## Distribution (Maintainers)

To provide a true one‑click install experience:
1. Archive the app in Xcode.
2. Sign with a **Developer ID** certificate.
3. Notarize with Apple.
4. Staple the notarization ticket.
5. Ship a DMG/ZIP on GitHub Releases.

This ensures users can install without Gatekeeper prompts.

## 3D Roadmap (Planned, not implemented)

- Standard asset name: `HeadMesh.usdz`
- Bundle resource loading with explicit error reporting
- Camera fitting based on model bounds
- Motion mapping to node rotation with clamping and smoothing
- Feature-flag gated renderer (`FeatureFlags.enable3DHead`)
