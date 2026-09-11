# MacPulse

The quiet, native Mac cleaner that leaves no trace.

MacPulse is a macOS system utility for deep cache cleaning, residual app
uninstallation, startup service inspection, APFS disk analysis, duplicate
finding, and live resource monitoring — built entirely in Swift & SwiftUI.

**Free for personal use. Not open source.** See [LICENSE](LICENSE).

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

- macOS 14 or later
- Full Disk Access is required for complete scan coverage

## Getting MacPulse

Download the latest `.dmg` from the
[Releases](https://github.com/princepal/MacPulse/releases/latest) page.

## Build

```sh
xcodebuild -project MacPulse/MacPulse.xcodeproj -scheme MacPulse -configuration Release build
```

## Rooms

- Pure Swift & SwiftUI
- Zero background daemons
- Zero telemetry
- Local, atomic pre-deletion snapshots

## License

**Personal Use License.** You may use MacPulse on your own computer for
personal, non-commercial purposes. You may **not** modify, redistribute,
sublicense, or reverse-engineer the Software. No open source license applies.
See the full terms in [LICENSE](LICENSE).

## Author

Prince Pal