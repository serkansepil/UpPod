#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

APP="UpPod.app"
ZIP="uppod.zip"
BUNDLE_ID="com.uppod.app"
SIGN_IDENTITY="${UPPOD_SIGN_IDENTITY:--}"

echo "→ swift build (release)"
swift build -c release

BIN_DIR="$(swift build -c release --show-bin-path)"
BIN="$BIN_DIR/uppod"
SPARKLE_FRAMEWORK="$BIN_DIR/Sparkle.framework"

echo "→ .app bundle"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Frameworks" "$APP/Contents/Resources"
cp Info.plist "$APP/Contents/Info.plist"
cp "$BIN" "$APP/Contents/MacOS/uppod"
ditto "$SPARKLE_FRAMEWORK" "$APP/Contents/Frameworks/Sparkle.framework"
if ! otool -l "$APP/Contents/MacOS/uppod" | grep -q '@executable_path/../Frameworks'; then
  install_name_tool -add_rpath '@executable_path/../Frameworks' "$APP/Contents/MacOS/uppod"
fi
cp Sources/uppod/Assets/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp Sources/uppod/Assets/coach-flexion.png "$APP/Contents/Resources/coach-flexion.png"
cp Sources/uppod/Assets/coach-roll.png "$APP/Contents/Resources/coach-roll.png"
cp Sources/uppod/Assets/coach-chintuck.png "$APP/Contents/Resources/coach-chintuck.png"
cp Sources/uppod/Assets/coach-yaw.png "$APP/Contents/Resources/coach-yaw.png"
cp Sources/uppod/Assets/posture-spine-icon.png "$APP/Contents/Resources/posture-spine-icon.png"
cp Sources/uppod/Assets/status-head.png "$APP/Contents/Resources/status-head.png"
mkdir -p "$APP/Contents/Resources/en.lproj" "$APP/Contents/Resources/tr.lproj"
cp Resources/en.lproj/InfoPlist.strings "$APP/Contents/Resources/en.lproj/InfoPlist.strings"
cp Resources/tr.lproj/InfoPlist.strings "$APP/Contents/Resources/tr.lproj/InfoPlist.strings"

if [[ "$SIGN_IDENTITY" == "-" ]]; then
  echo "→ ad-hoc signing"
  codesign --force --deep --sign - "$APP/Contents/Frameworks/Sparkle.framework"
  codesign --force --sign - --identifier "$BUNDLE_ID" "$APP"
else
  echo "→ Developer ID signing"
  codesign --force --deep --sign "$SIGN_IDENTITY" --options runtime --timestamp "$APP/Contents/Frameworks/Sparkle.framework"
  codesign --force --sign "$SIGN_IDENTITY" --identifier "$BUNDLE_ID" --options runtime --timestamp "$APP"
fi
codesign --verify --deep --strict --verbose=2 "$APP"

if [[ "${UPPOD_NOTARIZE:-0}" == "1" ]]; then
  echo "→ notarization zip"
  rm -f "$ZIP"
  ditto -c -k --keepParent "$APP" "$ZIP"
  echo "→ submit notarization"
  if [[ -n "${UPPOD_NOTARY_PROFILE:-}" ]]; then
    xcrun notarytool submit "$ZIP" \
      --keychain-profile "$UPPOD_NOTARY_PROFILE" \
      --wait
  else
    : "${UPPOD_NOTARY_APPLE_ID:?Set UPPOD_NOTARY_APPLE_ID or UPPOD_NOTARY_PROFILE}"
    : "${UPPOD_NOTARY_PASSWORD:?Set UPPOD_NOTARY_PASSWORD or UPPOD_NOTARY_PROFILE}"
    : "${UPPOD_TEAM_ID:?Set UPPOD_TEAM_ID or UPPOD_NOTARY_PROFILE}"
    xcrun notarytool submit "$ZIP" \
      --apple-id "$UPPOD_NOTARY_APPLE_ID" \
      --password "$UPPOD_NOTARY_PASSWORD" \
      --team-id "$UPPOD_TEAM_ID" \
      --wait
  fi
  echo "→ staple ticket"
  xcrun stapler staple "$APP"
  echo "→ final stapled zip"
  rm -f "$ZIP"
  ditto -c -k --keepParent "$APP" "$ZIP"
fi

echo "✓ $APP"
echo "  Real:  ./$APP/Contents/MacOS/uppod"
echo "  Debug flags are available only in SwiftPM debug builds."
if [[ "$SIGN_IDENTITY" == "-" ]]; then
  echo "  Signing: ad-hoc. Set UPPOD_SIGN_IDENTITY for Developer ID signing."
else
  echo "  Signing: $SIGN_IDENTITY"
fi
