#!/usr/bin/env bash
# Install latest MacPulse release (unsigned OSS). Clears Gatekeeper quarantine.
set -euo pipefail

REPO="${MACPULSE_REPO:-princepal9120/MacPulse}"
DEST="${MACPULSE_DEST:-${HOME}/Applications}"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

# The release workflow publishes a stable-name MacPulse.dmg on every release,
# so releases/latest/download works forever — no GitHub API call needed
# (unauthenticated api.github.com is rate-limited to 60 req/hr per IP and
# 403s on shared NAT/VPN/CI egress).
DMG_NAME="MacPulse.dmg"
DMG_URL="https://github.com/${REPO}/releases/latest/download/${DMG_NAME}"

echo "Downloading ${DMG_NAME} from ${REPO}..."
if ! curl -fL --progress-bar -o "${TMP}/${DMG_NAME}" "${DMG_URL}"; then
  echo "Stable-name asset not found — falling back to release API lookup..."
  URLS="$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" \
    | sed -n 's/.*"browser_download_url": *"\([^"]*\.dmg\)".*/\1/p')"
  DMG_URL="$(printf '%s\n' "${URLS}" | head -n1)"
  [[ -n "${DMG_URL}" ]] || { echo "No DMG asset found in latest release" >&2; exit 1; }
  DMG_NAME="$(basename "${DMG_URL}")"
  curl -fL --progress-bar -o "${TMP}/${DMG_NAME}" "${DMG_URL}"
fi

echo "Mounting..."
ATTACH_OUT="$(hdiutil attach "${TMP}/${DMG_NAME}" -nobrowse)"
MNT="$(echo "${ATTACH_OUT}" | awk -F'\t' '/\/Volumes\//{print $NF; exit}')"
[[ -d "${MNT}/MacPulse.app" ]] || { echo "MacPulse.app missing in DMG" >&2; exit 1; }

mkdir -p "${DEST}"
echo "Installing to ${DEST}/MacPulse.app..."
rm -rf "${DEST}/MacPulse.app"
ditto "${MNT}/MacPulse.app" "${DEST}/MacPulse.app"
hdiutil detach "${MNT}" >/dev/null

# Unsigned GitHub builds get quarantine; clear so Gatekeeper won't say "damaged".
# `xattr -cr` is recursive on stock macOS; fall back to a per-file clear so a
# stricter xattr implementation can never abort the install (set -e).
if ! /usr/bin/xattr -cr "${DEST}/MacPulse.app" 2>/dev/null; then
  /usr/bin/find "${DEST}/MacPulse.app" -exec /usr/bin/xattr -c {} \; 2>/dev/null || true
fi
/usr/bin/xattr -d com.apple.quarantine "${DEST}/MacPulse.app" 2>/dev/null || true

echo "Done. Opening MacPulse..."
open "${DEST}/MacPulse.app"
echo "Installed: ${DEST}/MacPulse.app"
