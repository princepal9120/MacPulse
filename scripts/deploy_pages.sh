#!/usr/bin/env bash
# Deploy MacPulse landing page to Cloudflare Pages (trymacpulse.pages.dev)
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# Fail fast and clearly in automation when credentials are missing, rather
# than letting wrangler print an interactive login/error flow.
: "${CLOUDFLARE_API_TOKEN:?Set CLOUDFLARE_API_TOKEN before deploying}"
: "${CLOUDFLARE_ACCOUNT_ID:?Set CLOUDFLARE_ACCOUNT_ID before deploying}"

echo "Syncing website artifacts to .pages-dist..."
mkdir -p .pages-dist
cp -f index.html style.css tokens.css favicon.ico favicon.png apple-touch-icon.png .pages-dist/
cp -r assets .pages-dist/

echo "Deploying to Cloudflare Pages (project: trymacpulse)..."
# --yes keeps npx non-interactive on a clean box (no "Ok to proceed?" prompt).
npx --yes wrangler pages deploy .pages-dist --project-name=trymacpulse --branch=main --commit-dirty=true

echo "Successfully deployed! Live at https://trymacpulse.pages.dev"

