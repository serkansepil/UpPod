# UpPod

UpPod is a macOS menu bar app that uses compatible AirPods headphone motion data to track head tilt, estimate neck posture strain, and guide short neck exercise sessions. Calibration, posture summaries, and exercise summaries are stored locally on the Mac.

## Screenshots

<p align="center">
  <img src="docs/screenshots/uppod.png" alt="UpPod posture popover" width="280">
</p>

<p align="center">
  <img src="docs/screenshots/exercises-1.png" alt="Neck exercises overview" width="360">
  <img src="docs/screenshots/exercises-2.png" alt="Guided neck exercise session" width="360">
</p>

## Requirements

- macOS 14 or newer
- Xcode Command Line Tools with Swift 5.9 or newer
- Compatible AirPods with headphone motion support
- Motion & Fitness permission
- Homebrew and `create-dmg` only when packaging a DMG

## Quick Start

Run the tests:

```bash
swift test
```

Run the app from SwiftPM with mock motion data:

```bash
UPPOD_MOCK=1 swift run
```

Mock mode is useful for local development without AirPods. Internal debug flags are only honored in SwiftPM debug builds.

## Build

```bash
./build.sh
open UpPod.app
```

`build.sh` creates `UpPod.app`, copies bundled resources, and signs the app. By default it uses ad-hoc signing for local builds.

For Developer ID signing:

```bash
UPPOD_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./build.sh
```

For notarization:

```bash
UPPOD_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
UPPOD_NOTARIZE=1 \
UPPOD_NOTARY_APPLE_ID="apple-id@example.com" \
UPPOD_NOTARY_PASSWORD="app-specific-password" \
UPPOD_TEAM_ID="TEAMID" \
./build.sh
```

Or store notarization credentials once in Keychain and reuse the profile:

```bash
xcrun notarytool store-credentials uppod-ecma \
  --apple-id "apple-id@example.com" \
  --team-id "TEAMID" \
  --password "app-specific-password"

UPPOD_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
UPPOD_NOTARIZE=1 \
UPPOD_NOTARY_PROFILE=uppod-ecma \
./build.sh
```

Create a DMG after building:

```bash
brew install create-dmg
./build.sh
./package-dmg.sh
```

`package-dmg.sh` uses `Resources/dmg-background.png`, creates `uppod.dmg`, verifies it with `hdiutil`, and prints a SHA-256 checksum.

For a signed and notarized DMG:

```bash
UPPOD_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
UPPOD_NOTARIZE=1 \
UPPOD_NOTARY_PROFILE=uppod-ecma \
./package-dmg.sh
```

## GitHub CI/CD

The repository includes two GitHub Actions workflows:

- `.github/workflows/ci.yml`: runs `swift test` on pushes to `main`, pull requests, and manual dispatch.
- `.github/workflows/release.yml`: builds, signs, notarizes, packages, publishes a GitHub Release, and updates the Sparkle appcast.

Automatic releases are triggered by pushing a version tag:

```bash
git tag v0.1.0
git push origin v0.1.0
```

The release workflow can also be started manually from GitHub Actions with a version such as `v0.1.0`.

Release signing and notarization require these repository secrets:

- `APPLE_CERTIFICATE_BASE64`: base64-encoded `.p12` Developer ID Application certificate.
- `APPLE_CERTIFICATE_PASSWORD`: password for the `.p12` file.
- `APPLE_SIGNING_IDENTITY`: codesign identity, for example `Developer ID Application: Your Name (TEAMID)`.
- `APPLE_ID`: Apple ID email used for notarization.
- `APPLE_APP_PASSWORD`: app-specific password for notarization.
- `APPLE_TEAM_ID`: Apple Developer Team ID.
- `SPARKLE_PRIVATE_KEY`: Sparkle EdDSA private key used to sign appcast updates.

To encode the certificate on macOS:

```bash
base64 -i DeveloperIDApplication.p12 | pbcopy
```

The release uploads both `uppod.dmg` and `uppod.zip`, writes SHA-256 checksums into the GitHub Release notes, and deploys `appcast.xml` to GitHub Pages.

## Updates

UpPod uses Sparkle 2 for app updates.

- Feed URL: `https://serkansepil.github.io/UpPod/appcast.xml`
- Public EdDSA key: stored in `Info.plist` as `SUPublicEDKey`.
- Private EdDSA key: stored only as the `SPARKLE_PRIVATE_KEY` GitHub Actions secret.

The first Sparkle-enabled build must still be installed manually. Later releases can be discovered through Sparkle's automatic checks or the popover's update button.

## Debug Builds

Common debug commands:

```bash
UPPOD_MOCK=1 swift run
UPPOD_MOCK=1 UPPOD_DEBUG=1 swift run
UPPOD_MOCK=1 UPPOD_MOCK_EXERCISE=1 swift run
UPPOD_MOCK=1 UPPOD_EX_AUTOSTART=1 UPPOD_EX_AUTOPRESENT=1 swift run
```

Release builds ignore these flags.

Useful flags:

- `UPPOD_MOCK=1`: use generated motion samples instead of AirPods.
- `UPPOD_DEBUG=1`: print posture pipeline logs.
- `UPPOD_MOCK_EXERCISE=1`: widen mock motion for exercise-session testing.
- `UPPOD_EX_AUTOSTART=1`: start the short test exercise plan automatically.
- `UPPOD_EX_AUTOPRESENT=1`: open the exercise window after autostart.
- `UPPOD_AUTOCAL=1`: auto-calibrate after the first stable mock samples.
- `UPPOD_PERSIST=1`: persist state even when `UPPOD_MOCK=1`.
- `UPPOD_STORE_PATH=/tmp/uppod-state.json`: override the JSON store path in debug builds.

## Tests

```bash
swift test
```

The test suite covers:

- Posture pipeline smoothing, flexion estimation, motion gating, classification, and dwell behavior.
- Neck load and strain curve calculations.
- Daily scoring and calibration helpers.
- JSON persistence, tolerant decoding, migration stamping, and corrupt-file backup.

## Data

UpPod stores calibration, sensitivity, daily posture summaries, and exercise session summaries in:

```text
~/Library/Application Support/uppod/state.json
```

No posture data is sent to a server by this app.

See `PRIVACY.md` for the privacy summary.

## Current Production Status

Ready for local signed builds and manual QA. Before public distribution:

- Sign with a Developer ID certificate.
- Notarize and staple the app.
- Run manual QA with real AirPods on supported macOS versions.

## Architecture

```text
main.swift               NSApplication bootstrap
RuntimeFlags.swift       debug-only environment flags
Theme.swift              shared colors and bundled image lookup
L10n.swift               lightweight Turkish/English text helpers
Motion.swift             AirPods or mock motion source
Pipeline.swift           gravity-fused flexion, smoothing, gate, classifier
Strain.swift             neck load and strain estimate
Scoring.swift            daily dose and posture score
Persistence.swift        local JSON persistence
PostureEngine.swift      posture state orchestration
StatusBar.swift          NSStatusItem and popover host
PopoverContentView.swift menu bar popover UI
Exercise.swift           exercise definitions and default plans
ExerciseEngine.swift     exercise session logic
ExerciseSessionView.swift exercise UI
ExerciseWindow.swift     persistent exercise window controller
```
