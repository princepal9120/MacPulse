# Design System & Specifications: MacPulse

## Source of Truth
- **Status**: Active
- **Date**: 2026-09-15
- **Platform Target**: macOS 26+ (Swift 6 / SwiftUI)
- **Foundations**: Apple Design (WWDC Fluid Interfaces & macOS HIG), UX Skills Framework (Intent & Ethic-first design).
- **Scope**: Full MacPulse macOS application architecture, shared components, interaction physics, and surface guidelines.

---

## 1. Brand Identity & Product Philosophy

MacPulse feels calm, capable, local-first, and unmistakably native to macOS. Trust is earned through:
- **Restrained color & semantic hierarchy**: No flashy AI gradients, neon highlights, or novelty styling competing with system diagnostics.
- **Explicit safety boundaries**: High-impact or destructive actions (permanent deletion, killing vital processes, full reset) are isolated, require explicit intent, and default to reversible Trash workflows.
- **Calm density**: Information density matches native macOS utilities (Activity Monitor, Disk Utility, System Settings) — compact, scannable, and respectful of screen real estate.
- **Local-first privacy**: Zero telemetry or external data leakage; all operations run on-device.

---

## 2. Core Apple Design Principles

MacPulse adheres to the eight foundational principles from Apple's design philosophy:

1. **Purpose**: Every control and metric earns its place. Features assist in understanding, optimizing, and maintaining the Mac without unnecessary bloat or background thrashing.
2. **Agency**: Users remain in full control. Cleanups present clear breakdowns with itemized inspection; operations are cancelable; decisions are never forced without confirmation.
3. **Responsibility**: System integrity comes first. System-critical paths, protected background items, and active apps are shielded with defensive safety policies.
4. **Familiarity**: Strict adherence to macOS interface patterns: standard sidebar navigation rails, native split views, macOS table layouts, standard shortcut bindings (`⌘,` for Settings, `⌘W` for close), and standard window controls.
5. **Flexibility**: Responsive layouts that scale smoothly from the 1080×700 minimum window size up to full studio display dimensions. Full support for keyboard traversal and Dynamic Type.
6. **Simplicity (Not Minimalism)**: Do not hide essential status behind nested clicks. Expose clear summaries (e.g., reclaimable space, live CPU/RAM load) upfront; provide deep diagnostic details one layer down.
7. **Craft**: Pixel-perfect alignment, optical text sizing, subtle hairline borders, and fluid springs that respond immediately to input.
8. **Delight**: Smooth state transitions, satisfying tactile feedback, and crisp visual feedback that feels like physical hardware rather than a web application.

---

## 3. Motion Physics & Fluid Interfaces

Interfaces feel alive when motion begins instantly from the current on-screen value, responds to user gestures, and can be interrupted or reversed at any millisecond.

### 3.1 Spring Parameters & Motion Tokens
Pre-scripted linear or `easeInOut` animations lock input and introduce artificial lag. All interactive transitions use Apple spring physics defined by **Response** and **Damping Ratio**:

| Motion Class | Response | Damping | Use Case |
|---|---|---|---|
| **Critically Damped (Default)** | `0.32s` | `1.0` | Sheet presentation, tab switching, card expansion, list updates, disclosure triangles. Zero bounce; settles cleanly. |
| **Momentum / Physical** | `0.36s` | `0.8` | Drag release, pill picker sliding indicator, toast bounce, swipe gesture follow-through. |
| **Snappy Action** | `0.22s` | `0.9` | Button press state, checkbox toggle, segmented control switch. |
| **Progressive Scan** | `1.8s – 2.4s` | Smooth Continuous | Background radar sweep, disk scanner pulse (subtle, non-distracting). |

### 3.2 Response & Latency
- **Down-state response**: Interactive elements provide immediate visual/haptic feedback on pointer-down (active scaling `0.98`, subtle highlight), committing on release.
- **Interruptibility**: Animations never lock user input. Clicking a tab while another is transitioning immediately pivots motion from the current presentation transform without jumping.
- **Velocity handoff**: Dragged elements preserve pointer release velocity into the spring rather than resetting to zero velocity.
- **Spatial consistency**: Elements exit back to their source origin (e.g., sheets dismiss back to trigger, toasts dismiss along their entrance axis).

---

## 4. Materials, Depth & Liquid Glass

MacPulse utilizes macOS vibrancy and translucent materials to establish visual hierarchy without clutter.

### 4.1 Surface Hierarchy
1. **Window Base**: Native sidebar material (`.sidebar`) and window background (`.windowBackground`).
2. **Structural Glass Cards**: `GlassCard` built with `NSVisualEffectView` (`.hudWindow` or `.underWindowBackground` blending within window) with a `1px` subtle hairline border (`Color.primary.opacity(0.07)`) and soft ambient shadow (`radius: 12, y: 4, opacity: 0.07`).
3. **Interactive Overlays**: Floating HUD, alerts, and toasts use elevated glass surfaces (`.menu` or `.hudWindow`) with increased contrast border (`Color.primary.opacity(0.12)`).
4. **Anti-Slop Transparency Rule**: Never stack a translucent light surface directly over another translucent surface. Legibility and contrast must be maintained.
5. **Accessibility Fallback**: When `accessibilityReduceTransparency` is active, translucent surfaces fall back to solid `NSColor.controlBackgroundColor` with a defined border.

---

## 5. Typography & Optical Sizing

MacPulse uses the San Francisco (SF Pro / SF Pro Rounded) system font family.

- **Large Display Titles** (28pt+): Use tight line leading and negative tracking (`-0.02em` / `-0.5pt`) to prevent characters from drifting apart visually.
- **Section Headers & Headlines** (13pt–16pt): System font with medium/semibold weight for rapid scanning.
- **Labels & Values** (12pt–13pt): Monospaced numbers (`.monospacedDigit()`) for metrics, memory addresses, byte sizes, and percentages to prevent layout jitter during live updates.
- **Captions & Footnotes** (10pt–11pt): Secondary foreground style with neutral tracking for crisp legibility.
- **Dynamic Type & Localization**: Avoid fixed text frames. All labels support expansion through `ViewThatFits` and wrapping multi-line text for German, French, and Japanese localizations.

---

## 6. Information Architecture & Navigation

The application uses a stable two-pane `NavigationSplitView` architecture:

```
┌─────────────────┬────────────────────────────────────────────────────────┐
│ App Sidebar     │ Detail Canvas                                          │
│                 │                                                        │
│ • Dashboard     │ ┌────────────────────────────────────────────────────┐ │
│ • Cleanup       │ │ ScreenHeader (Title, Subtitle, Trailing Actions)   │ │
│ • Disk Space    │ ├────────────────────────────────────────────────────┤ │
│ • Duplicates    │ │ Feature Workspace                                  │ │
│ • Processes     │ │                                                    │ │
│ • Monitor       │ │ • Context & Filter Bar                             │ │
│ • Privacy       │ │ • Core Visual Canvas / Diagnostic List             │ │
│ • Startup Items │ │ • Selection Detail / Action Inspector              │ │
│ • Uninstaller   │ └────────────────────────────────────────────────────┘ │
│ ────────────────│                                                        │
│ • Settings      │                                                        │
│ • About         │                                                        │
└─────────────────┴────────────────────────────────────────────────────────┘
```

### Navigation Rules
- The sidebar is the single navigation source. Selecting an item immediately activates the target pane.
- Navigation state preserves selection across transitions.
- Global navigation notifications (`.macPulseNavigate`) route directly to the target feature.

---

## 7. Feature Surface Specifications

### 7.1 Dashboard
- **Role**: At-a-glance system health and one-click smart maintenance entry point.
- **Components**:
  - Hero Quick Clean card with estimated reclaimable space and immediate "Scan System" action.
  - Vital metrics grid: CPU, Memory, Storage, and Battery ring indicators.
  - Recent activity timeline and safety recommendations.

### 7.2 System Monitor & Menu Bar HUD
- **Role**: Real-time diagnostic monitoring for performance, memory pressure, and network throughput.
- **Components**:
  - Multi-series live sparklines for CPU cores, RAM distribution (wired, active, compressed), and network I/O.
  - Compact Menu Bar HUD popover featuring `MacPulseLogo` status silhouette and quick kill/clean actions.
  - Monospaced numeric updates with jitter-free layout frames.

### 7.3 Smart Cleanup
- **Role**: Safe space reclamation with transparent itemization.
- **Safety Tiers**:
  1. *Safe (Tier 1)*: User caches, browser caches, log files, trash. Auto-selected by default.
  2. *Caution (Tier 2)*: Developer caches (Xcode DerivedData, CocoaPods, node_modules), mail downloads. Requires user review.
  3. *Review (Tier 3)*: Large orphaned files, dormant archives. Never auto-selected.
- **Feedback**: Atomic transaction rollback journal (`TransactionJournal`), progress bar with real-time file counter, and celebratory summary with reclaimed gigabytes.

### 7.4 Disk Analyzer (Disk Space)
- **Role**: Interactive visualization of storage consumption.
- **Components**:
  - Three-column layout: Path navigation tree, visualization stage, file/folder inspector.
  - Multi-view visualizer: Sunburst, Treemap, Flame Graph, Size Rings, Age Map, Folders Grid, Bubbles, and Mind Map.
  - Toolbar controls for sorting, filtering, and deep search.
  - Empty, scanning, error, and result states share the same predictable stage.

### 7.5 Duplicates Finder
- **Role**: Identify identical files and safely prune duplicates.
- **Components**:
  - Grouped list of duplicate clusters with hash validation and file creation dates.
  - Smart Selection rules: "Keep Oldest", "Keep Newest", "Keep in Specific Directory".
  - Side-by-side preview inspector (QuickLook integration, image/document preview).

### 7.6 App Uninstaller & Leftover Removal
- **Role**: Complete removal of applications and their scattered support files.
- **Components**:
  - App catalog with installation dates, architecture (Universal/Intel/Apple Silicon), and total footprint.
  - Associated artifacts breakdown: Application Support, Caches, Preferences, Launch Agents, Crash Reports.
  - Orphaned Residuals scanner for apps already deleted via Finder.

### 7.7 Background & Processes
- **Role**: Inspection and management of running processes and login launch services.
- **Safety Boundaries**:
  - Protected system daemons and critical user processes are flagged with lock badges and cannot be terminated.
  - Resource consumption badges: High CPU (Orange), Heavy Memory (Purple).
  - Explicit confirmation for process termination with process tree hierarchy view.

### 7.8 Privacy & Permissions
- **Role**: Transparent security guidance and Full Disk Access (FDA) onboarding.
- **Components**:
  - Plain-English rationale for permissions (e.g., "Full Disk Access is needed to scan user application caches outside the sandbox").
  - One-click deep link to macOS System Settings Privacy pane.
  - Live permission status detection with automatic refresh.

### 7.9 Settings & About
- **Role**: User preferences and product provenance.
- **Layout**:
  - Three clean panes: General, Advanced, About.
  - Grouped `GlassCard` rows with `SettingsLabeledControl`, `SettingsToggleRow`, and `GlassPillPicker`.
  - Destructive reset controls visually quarantined in a distinct warning card with two-step confirmation.

---

## 8. Accessibility & Ergonomics (WCAG 2.2 AA)

- **Contrast**: Text elements meet minimum 4.5:1 contrast against both light and dark glass backdrops.
- **Status Independence**: Color is never used as the sole indicator of status. Every alert or state pairs color with an SF Symbol and localized label.
- **Keyboard Traversal**: Full tab key traversal across all forms, lists, and modal sheets. Visible focus ring (`Color.accentColor`) on all focusable elements.
- **Reduced Motion**: Respects `accessibilityReduceMotion`. Disables spring bounces, radar sweeps, and sliding transitions, replacing them with subtle `0.15s` cross-fades.
- **Reduced Transparency**: Respects `accessibilityReduceTransparency`. Converts glass blur surfaces to high-contrast opaque containers.

---

## 9. Content Voice & Ethical Stance

- **Voice**: Calm, precise, professional, and unhurried.
- **Terminology**: Use concrete native macOS terminology ("Move to Trash", "System Settings", "Full Disk Access") rather than synthetic branded marketing terms.
- **Zero Dark Patterns**:
  - No scare tactics or artificial urgency ("Your Mac is in critical danger!").
  - No hidden checkboxes or pre-selected destructive options.
  - No fake scan delays added for theatrical effect.
  - Clear item count and exact size calculations before initiating cleanup.

---

## 10. Engineering Validation & Constraints

- **Language & SDK**: Swift 6, macOS 26 SDK.
- **Build Validation**: Clean Xcode build with zero compiler warnings; existing unit test suite (`MacPulseTests`) passing.
- **Component Hygiene**: Shared components live in `MacPulse/SharedViews/` and `MacPulse/Infrastructure/LiquidGlass+Compatibility.swift`. No redundant third-party styling frameworks.
