# Design

## Source of truth
Status: Active  
Date: 2026-09-12  
Product surfaces: MacPulse macOS app, with this revision focused on Settings and Disk Analyzer.  
Evidence reviewed: `README.md`, `MacPulse/App/RootView.swift`, `MacPulse/Models/NavigationItem.swift`, `MacPulse/Features/Settings/*`, `MacPulse/Features/DiskAnalyzer/*`, shared Liquid Glass helpers, localization resources, and the supplied Settings and Disk Analyzer screenshots.

## Brand
MacPulse should feel calm, capable, local-first, and unmistakably native to macOS. Trust comes from clear language, restrained color, visible safety boundaries, and standard platform controls. Avoid decorative gradients inside controls, oversized navigation, dense card walls, and novelty styling that competes with system information.

## Product goals
- Make maintenance settings easy to scan and safe to change.
- Keep advanced and destructive actions clearly separated from everyday preferences.
- Preserve a compact macOS information density without sacrificing localization or accessibility.
- Non-goal: expose unfinished integrations. Siri & AI remains implemented but is temporarily hidden from Settings navigation and search.
- Success signals: the settings sidebar has three clear destinations; each pane has a stable title and summary; related controls read as coherent groups; no existing settings behavior changes.

## Personas and jobs
- Everyday Mac owner: adjust appearance, notifications, permissions, and updates with confidence.
- Power user: tune scanning, deletion, process, and developer behavior without hunting through unrelated controls.
- Evaluator or contributor: understand privacy guarantees, support links, and product provenance.

## Information architecture
- App sidebar remains the single navigation rail.
- Settings section order: General, Advanced, About.
- General: access, appearance, maintenance, notifications, updates, and reset.
- Advanced: scanning, deletion, processes, developer options, and startup vendors.
- About: project/support links followed by privacy and safety guarantees.
- Settings search returns only currently visible destinations.
- Disk Analyzer uses a stable three-column workspace: scan/navigation context, visualization canvas, and selection inspector.
- The canvas toolbar separates location/search from visualization options; scanning, empty, error, and result states occupy the same predictable stage.

## Design principles
1. Native before novel: prefer SwiftUI/macOS controls and familiar grouping.
2. Progressive disclosure: everyday preferences precede advanced and destructive controls.
3. One accent per group: color identifies a section, not every piece of text.
4. Calm density: concise rows, consistent alignment, and readable spacing.
5. Safety is explicit: destructive actions use red only where consequences require it.

## Visual language
- Color: semantic system colors with the app accent used sparingly; content remains legible in light and dark appearances.
- Typography: system title for pane identity, headline for card names, body/caption for labels and supporting copy.
- Spacing: 20–24 pt pane margins, 16–18 pt card padding, 12–16 pt between groups.
- Alignment: fixed-width icon columns, equal-height tiles, balanced side panes, and
  complete grid rows without visually orphaned cards.
- Shape/elevation: continuous rounded rectangles and the existing Liquid Glass compatibility layer; subtle hairlines and restrained shadows.
- Motion: short system animations only for selection or state changes; honor reduced motion.
- Iconography: SF Symbols in small tinted containers for pane and group identity.

## Components
- `MacPulseLogo`: the single app-icon rendering primitive for the menu bar, sidebar brand lockup, monitor HUD, and About surface.
- `SettingsPageHeader`: pane identity and short description.
- `GlassCard`: shared grouped settings surface, including destructive variant.
- `SettingsSectionHeader`: compact icon, title, and subtitle block.
- `SettingsLabeledControl`, `SettingsToggleRow`, `SettingsActionRow`, `SettingsDivider`: stable row primitives.
- Existing `GlassPillPicker` owns compact option selection.
- Disk Analyzer: sidebar scan actions, compact visualization toolbar, centered state card, visualization canvas, and inspector detail/action groups.
- Shared colors, glass behavior, and accessibility fallbacks remain owned by `LiquidGlass+Compatibility.swift`.

## Accessibility
- Target native macOS accessibility behavior and WCAG 2.2 AA contrast where custom color is used.
- Preserve semantic buttons, toggles, pickers, search, keyboard traversal, and visible focus states.
- Do not encode status by color alone; keep symbols and text labels.
- Support increased text/localized expansion through `ViewThatFits` and wrapping subtitles.
- Respect reduced transparency through the existing glass surface fallback.

## Responsive behavior
- Primary target: macOS windows at or above the existing 1080×700 minimum.
- Detail content is capped at a readable width and centered on wide windows.
- Labeled rows fall back from horizontal to stacked layouts when content cannot fit.
- Long localized copy wraps rather than truncates; compact controls retain intrinsic width.

## Interaction states
- Search: matching rows identify their destination; empty results use `ContentUnavailableView`.
- Loading: update and maintenance actions retain progress indicators and disabled states.
- Success/error: existing status pills and alerts remain the source of feedback.
- Disabled/unavailable: hidden unfinished integrations do not appear as dead navigation.
- Destructive: reset remains behind confirmation and visually isolated.
- Disk scanning: keep location context visible, replace results with a focused progress card, expose a single Cancel action, then transition directly into results.
- Disk selection: the inspector shows a purposeful placeholder until a file or folder is selected.

## Content voice
Use concise, direct labels and one-line explanatory subtitles. Prefer concrete system terms such as “Full Disk Access” and “Move to Trash.” Avoid hype, emojis in section titles, and claims that are not supported by current behavior.

## Implementation constraints
- Swift 6 / SwiftUI, macOS 26 deployment target.
- No new dependencies or parallel design-system layer.
- Reuse localization keys and shared Liquid Glass helpers.
- Keep Siri & AI source code available for re-enablement; hide only its navigation/search exposure.
- Brand surfaces use the bundled application icon through `MacPulseLogo`; the tray uses a compact template silhouette of the same mark so macOS can size and tint it correctly. Feature/action symbols remain semantic SF Symbols.
- Validate with focused model tests and an Xcode build/test pass.

## Open questions
- [ ] Product owner: what readiness milestone should re-enable Siri & AI? Impact: determines when the hidden category and search entries return.
- [ ] Localization owner: should pane-specific subtitles replace the current shared Settings window subtitle? Impact: would improve contextual navigation copy across all locales.
