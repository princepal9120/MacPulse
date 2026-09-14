#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
[[ -f "$ROOT_DIR/.signing.env" ]] && source "$ROOT_DIR/.signing.env"

PROJECT="$ROOT_DIR/MacPulse/MacPulse.xcodeproj"
SCHEME="MacPulse"
VERSION="$(xcodebuild -project "$PROJECT" -scheme "$SCHEME" -showBuildSettings 2>/dev/null | awk -F' = ' '/MARKETING_VERSION/{print $2; exit}')"
VERSION="${VERSION:-dev}"
BUILD_DIR="$ROOT_DIR/.release-build"
STAGING_DIR="$BUILD_DIR/staging"
APP_PATH="$BUILD_DIR/Build/Products/Release/MacPulse.app"
DMG_PATH="$ROOT_DIR/MacPulse-${VERSION}.dmg"
ENTITLEMENTS="$ROOT_DIR/MacPulse/MacPulse.entitlements"
NOTARY_PROFILE="${NOTARY_PROFILE:-MacPulse-Notary}"

if [[ -z "${CODESIGN_IDENTITY:-}" ]]; then
  CODESIGN_IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null \
    | awk -F'"' '/Developer ID Application/{print $2; exit}')"
fi

rm -rf "$BUILD_DIR" "$DMG_PATH"
# Universal build (arm64 + x86_64): a plain CLI build narrows ARCHS to the host
# architecture and silently ships an Apple-Silicon-only app.
xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Release \
  -destination "generic/platform=macOS" \
  -derivedDataPath "$BUILD_DIR" \
  ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build

mkdir -p "$STAGING_DIR"
cp -R "$APP_PATH" "$STAGING_DIR/MacPulse.app"
ln -s /Applications "$STAGING_DIR/Applications"

if [[ -n "${CODESIGN_IDENTITY:-}" ]]; then
  echo "Signing app with: $CODESIGN_IDENTITY"
  codesign --force --deep --options runtime --timestamp \
    --entitlements "$ENTITLEMENTS" \
    --sign "$CODESIGN_IDENTITY" "$STAGING_DIR/MacPulse.app"
else
  # Ad-hoc signing is still required: the raw build leaves an unsealed bundle
  # ("code has no resources but signature indicates they must be present"),
  # which Gatekeeper reports as "MacPulse is damaged" — a dead end with no
  # "Open Anyway" override. Sealing ad-hoc restores the normal
  # unidentified-developer flow.
  echo "No Developer ID cert — ad-hoc signing bundle (free OSS path)."
  codesign --force --deep --entitlements "$ENTITLEMENTS" \
    --sign - "$STAGING_DIR/MacPulse.app"
fi

# Fail the release instead of publishing an app Gatekeeper calls "damaged".
codesign --verify --deep --strict --verbose=2 "$STAGING_DIR/MacPulse.app" \
  || { echo "error: invalid code signature in staged app" >&2; exit 1; }
lipo -info "$STAGING_DIR/MacPulse.app/Contents/MacOS/MacPulse"

hdiutil create -volname "MacPulse $VERSION" -srcfolder "$STAGING_DIR" \
  -ov -format UDZO "$DMG_PATH" >/dev/null

if [[ -n "${CODESIGN_IDENTITY:-}" ]]; then
  codesign --force --timestamp --sign "$CODESIGN_IDENTITY" "$DMG_PATH"
fi

if [[ -n "${CODESIGN_IDENTITY:-}" ]] && xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" &>/dev/null; then
  echo "Notarizing with profile: $NOTARY_PROFILE"
  xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$DMG_PATH"
  xcrun stapler validate "$DMG_PATH"
elif [[ -n "${CODESIGN_IDENTITY:-}" ]]; then
  echo "Signed but not notarized — run: ./scripts/setup_signing.sh"
fi

shasum -a 256 "$DMG_PATH" > "$DMG_PATH.sha256"
echo "Created: $DMG_PATH"
cat "$DMG_PATH.sha256"
echo
echo "Next steps for a public release:"
echo "  1. Upload $DMG_PATH and $DMG_PATH.sha256 to the GitHub release."
echo "  2. Update the sha256 in Casks/macpulse.rb (Homebrew tap) to:"
echo "     $(awk '{print $1}' "$DMG_PATH.sha256")"
echo "  3. Update the checksum pill + download sizes in index.html."
