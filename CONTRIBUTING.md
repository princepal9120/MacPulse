# Contributing to MacPulse

Thanks for helping make MacPulse safer and faster.

## Before you start

1. Read the [README](README.md) and [MIT license](LICENSE).
2. Search existing issues before opening a new one.
3. Never include personal paths, telemetry, credentials, or real cleanup data
   in issues, pull requests, fixtures, or screenshots.

## Development

Requirements: Xcode 17 or newer and macOS 26.0 or newer.

```sh
xcodebuild -project MacPulse/MacPulse.xcodeproj -scheme MacPulse -configuration Debug build
xcodebuild test -project MacPulse/MacPulse.xcodeproj -scheme MacPulse -destination 'platform=macOS'
```

Keep changes focused, use existing SwiftUI/Foundation patterns, and add
regression tests for scanner, cleanup, or safety behavior. Do not add network
calls or dependencies without documenting why they are necessary.

## Pull requests

- Explain the user-visible change and safety impact.
- Include tests and, for UI changes, a screenshot or short recording.
- Keep commits small and descriptive.
- Confirm that `git diff --check` is clean.

## Security

Report vulnerabilities privately using [SECURITY.md](SECURITY.md) instead of
opening a public issue.
