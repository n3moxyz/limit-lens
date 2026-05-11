# Distribution Plan

Limit Lens remains a SwiftPM-first macOS app during development. The release path is an app bundle produced by `script/build_and_run.sh`.

## Current Bundle

The build script:

- runs `swift build`
- creates `dist/LimitLens.app`
- copies the executable and app icon
- writes `Info.plist`
- marks the app as `LSUIElement`
- ad-hoc signs the bundle for local execution

## Near-Term Release Checklist

1. Add a release mode to the script that does not launch the app.
2. Sign with a Developer ID certificate.
3. Notarize the app bundle.
4. Package a `.dmg`.
5. Publish GitHub Releases assets.
6. Add a Homebrew cask once the signed artifact is stable.

## Deferred

Auto-update should wait until signing and notarization are reliable. Sparkle is the likely choice, but it should not be added before the release pipeline is real.
