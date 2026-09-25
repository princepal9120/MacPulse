#!/usr/bin/env bash
# Install latest MacPulse release (unsigned OSS). Clears Gatekeeper quarantine.
set -euo pipefail

REPO="${MACPULSE_REPO:-princepal9120/MacPulse}"
DEST="${MACPULSE_DEST:-$HOME/Applications}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "Fetching latest release from $REPO…"
API="https://api.github.com/repos/${REPO}/releases/latest"
# Prefer the stable-name asset (MacPulse.dmg); fall back to the versioned name.
# grep/sed only — python3 is a CLT stub on fresh macOS installs.
URLS="$(curl -fsSL "$API" | sed -n 's/.*"browser_download_url": *"\([^"]*\.dmg\)".*/\1/p')"
DMG_URL="$(printf '%s\n' "$URLS" | grep '/MacPulse\.dmg$' | head -n1)"
[[ -n "$DMG_URL" ]] || DMG_URL="$(printf '%s\n' "$URLS" | head -n1)"
[[ -n "$DMG_URL" ]] || { echo "No DMG asset found in latest release" >&2; exit 1; }
DMG_NAME="$(basename "$DMG_URL")"

echo "Downloading $DMG_NAME…"
curl -fL --progress-bar -o "$TMP/$DMG_NAME" "$DMG_URL"

echo "Mounting…"
ATTACH_OUT="$(hdiutil attach "$TMP/$DMG_NAME" -nobrowse)"
MNT="$(echo "$ATTACH_OUT" | awk -F'\t' '/\/Volumes\//{print $NF; exit}')"
[[ -d "$MNT/MacPulse.app" ]] || { echo "MacPulse.app missing in DMG" >&2; exit 1; }

mkdir -p "$DEST"
echo "Installing to $DEST/MacPulse.app…"
rm -rf "$DEST/MacPulse.app"
ditto "$MNT/MacPulse.app" "$DEST/MacPulse.app"
hdiutil detach "$MNT" >/dev/null

# Unsigned GitHub builds get quarantine; clear so Gatekeeper won’t say “damaged”.
# `xattr -cr` is recursive on stock macOS; fall back to a per-file clear so a
# stricter xattr implementation can never abort the install (set -e).
if ! /usr/bin/xattr -cr "$DEST/MacPulse.app" 2>/dev/null; then
  /usr/bin/find "$DEST/MacPulse.app" -exec /usr/bin/xattr -c {} \; 2>/dev/null || true
fi
/usr/bin/xattr -d com.apple.quarantine "$DEST/MacPulse.app" 2>/dev/null || true

echo "Done. Opening MacPulse…"
open "$DEST/MacPulse.app"
echo "Installed: $DEST/MacPulse.app"
