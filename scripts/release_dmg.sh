#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="$ROOT_DIR/MacPulse/MacPulse.xcodeproj"
SCHEME="MacPulse"
VERSION="$(xcodebuild -project "$PROJECT" -scheme "$SCHEME" -showBuildSettings 2>/dev/null | awk -F' = ' '/MARKETING_VERSION/{print $2; exit}')"
VERSION="${VERSION:-dev}"
BUILD_DIR="$ROOT_DIR/.release-build"
STAGING_DIR="$BUILD_DIR/staging"
APP_PATH="$BUILD_DIR/Build/Products/Release/MacPulse.app"
DMG_PATH="$ROOT_DIR/MacPulse-${VERSION}.dmg"
CODESIGN_IDENTITY="${CODESIGN_IDENTITY:-}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"

rm -rf "$BUILD_DIR" "$DMG_PATH"
xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Release \
  -derivedDataPath "$BUILD_DIR" \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build

mkdir -p "$STAGING_DIR"
cp -R "$APP_PATH" "$STAGING_DIR/MacPulse.app"
ln -s /Applications "$STAGING_DIR/Applications"

if [[ -n "$CODESIGN_IDENTITY" ]]; then
  codesign --force --deep --options runtime --timestamp \
    --entitlements "$ROOT_DIR/MacPulse/MacPulse.entitlements" \
    --sign "$CODESIGN_IDENTITY" "$STAGING_DIR/MacPulse.app"
  codesign --verify --deep --strict --verbose=2 "$STAGING_DIR/MacPulse.app"
elif [[ -n "$NOTARY_PROFILE" ]]; then
  echo "NOTARY_PROFILE requires CODESIGN_IDENTITY" >&2
  exit 2
fi

hdiutil create -volname "MacPulse $VERSION" -srcfolder "$STAGING_DIR" \
  -ov -format UDZO "$DMG_PATH" >/dev/null

if [[ -n "$NOTARY_PROFILE" ]]; then
  xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$DMG_PATH"
  xcrun stapler validate "$DMG_PATH"
fi

shasum -a 256 "$DMG_PATH" > "$DMG_PATH.sha256"

echo "Created: $DMG_PATH"
cat "$DMG_PATH.sha256"
