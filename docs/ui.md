# UI

Limit Lens has two primary surfaces:

- a compact menu-bar meter for ambient awareness
- a window/popover detail view for routing, setup, diagnostics, and controls

## Menu Bar

The menu-bar label is rendered as a small two-provider visual meter:

- `Cx` shows Codex
- `Cl` shows Claude
- each provider has a compact usage bar
- failed or unavailable providers dim their bar
- stale providers keep showing their last known values while the detail state says `Stale`

The menu-bar label is intentionally small. Routing text stays in the popover/window where it can be read comfortably.

## Detail Window

The detail view keeps the current structure:

- suggested route
- provider header
- current limit buckets
- diagnostics/signals
- source note

Cards are reserved for repeated buckets, metrics, and the route summary. The main split view keeps native macOS sidebar behavior.

## Settings

Settings live in the app’s settings pane:

- Launch at Login
- Demo Mode
- Refresh
- Reset Alerts
- Codex Setup
- Claude Setup
- Command Sources

The app is bundled as an `LSUIElement` menu-bar utility, so the Dock icon is hidden for built app bundles.
