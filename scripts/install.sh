#!/usr/bin/env bash
# Install latest MacPulse release (unsigned OSS). Clears Gatekeeper quarantine.
set -euo pipefail

REPO="${MACPULSE_REPO:-princepal9120/MacPulse}"
DEST="${MACPULSE_DEST:-$HOME/Applications}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "Fetching latest release from $REPO…"
API="https://api.github.com/repos/${REPO}/releases/latest"
DMG_URL="$(curl -fsSL "$API" | python3 -c 'import json,sys; r=json.load(sys.stdin); print(next(a["browser_download_url"] for a in r["assets"] if a["name"].endswith(".dmg") and not a["name"].endswith(".sha256")))')"
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
/usr/bin/xattr -cr "$DEST/MacPulse.app"

echo "Done. Opening MacPulse…"
open "$DEST/MacPulse.app"
echo "Installed: $DEST/MacPulse.app"
