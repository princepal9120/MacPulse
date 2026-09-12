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

rm -rf "$BUILD_DIR" "$DMG_PATH"
xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Release \
  -derivedDataPath "$BUILD_DIR" \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build

mkdir -p "$STAGING_DIR"
cp -R "$APP_PATH" "$STAGING_DIR/MacPulse.app"
ln -s /Applications "$STAGING_DIR/Applications"

hdiutil create -volname "MacPulse $VERSION" -srcfolder "$STAGING_DIR" \
  -ov -format UDZO "$DMG_PATH" >/dev/null
shasum -a 256 "$DMG_PATH" > "$DMG_PATH.sha256"

echo "Created: $DMG_PATH"
cat "$DMG_PATH.sha256"
