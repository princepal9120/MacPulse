# MacPulse

The quiet, native Mac cleaner that leaves no trace.

MacPulse is a macOS system utility for deep cache cleaning, residual app
uninstallation, startup service inspection, APFS disk analysis, duplicate
finding, and live resource monitoring — built entirely in Swift & SwiftUI.

**Open source under the MIT license.** See [LICENSE](LICENSE).

---

## Features

- **Deep Cleanup** — scan and clear application caches, logs, developer
  artifacts, and system junk with safety-gated, recoverable deletions.
- **Deep Uninstaller** — remove apps and the hidden leftovers they leave
  behind (preferences, caches, orphaned files), backed by a local snapshot
  journal for undo.
- **Disk Analyzer** — treemap, sunburst, and age-map visualizations of disk
  usage to find the heavy folders.
- **Duplicates Finder** — detect and remove duplicate files.
- **Process Monitor** — live overview of running processes, memory, and
  resource usage.
- **Startup Services** — inspect and manage login items, launch daemons, and
  background agents.
- **Safety by default** — pre-deletion snapshots, atomic journaling, and an
  evidence-based safety boundary keep your data protected.

## Requirements

- macOS 26.0 or later
- Full Disk Access is required for complete scan coverage

## Getting MacPulse

Download the latest `.dmg` from the
[Releases](https://github.com/princepal9120/MacPulse/releases/latest) page, or
build one locally with `scripts/release_dmg.sh`.

## Build

```sh
xcodebuild -project MacPulse/MacPulse.xcodeproj -scheme MacPulse -configuration Debug build
xcodebuild test -project MacPulse/MacPulse.xcodeproj -scheme MacPulse -destination 'platform=macOS'
./scripts/release_dmg.sh
```

The release script builds a Release DMG and writes a SHA-256 checksum.
With a Developer ID certificate + notary profile configured, it also signs
and notarizes so Gatekeeper accepts GitHub downloads.

### Sign + notarize (required for “Download → Open” without Terminal)

1. Enroll in [Apple Developer Program](https://developer.apple.com/programs/) ($99/year)
2. In Xcode → Settings → Accounts → your team → Manage Certificates → **Developer ID Application**
3. Run once:

```sh
chmod +x scripts/setup_signing.sh scripts/release_dmg.sh
./scripts/setup_signing.sh
```

4. Ship:

```sh
./scripts/release_dmg.sh
```

Until that is done, downloaded builds need:

```sh
xattr -cr /Applications/MacPulse.app
```

## Rooms

- Pure Swift & SwiftUI
- Zero background daemons
- Zero telemetry
- Local, atomic pre-deletion snapshots

## License

MacPulse is released under the [MIT License](LICENSE). Contributions are
welcome; see [CONTRIBUTING.md](CONTRIBUTING.md).

## Author

Prince Pal
