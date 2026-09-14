#!/usr/bin/env bash
# Deploy MacPulse landing page to Cloudflare Pages (trymacpulse.pages.dev)
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo "Syncing website artifacts to .pages-dist..."
mkdir -p .pages-dist
cp -f index.html style.css tokens.css favicon.ico favicon.png apple-touch-icon.png .pages-dist/
cp -r assets .pages-dist/

echo "Deploying to Cloudflare Pages (project: trymacpulse)..."
npx wrangler pages deploy .pages-dist --project-name=trymacpulse --branch=main --commit-dirty=true

echo "Successfully deployed! Live at https://trymacpulse.pages.dev"

