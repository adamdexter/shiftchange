# CLAUDE.md

## Project Overview

**ShiftChange** is a macOS menu bar app that automatically disables Night Shift when color-critical apps (Photoshop, Lightroom, DaVinci Resolve, etc.) are in focus, and restores it when you switch away.

- **Language:** Swift 5.9, Objective-C (for private framework bridge)
- **Platform:** macOS 13+ (Ventura)
- **Build system:** Swift Package Manager
- **Architecture:** Menu bar accessory app (LSUIElement)

## Project Structure

```
ShiftChange/
├── Package.swift
├── Sources/
│   ├── CBlueLightBridge/          # Obj-C bridge to private CoreBrightness framework
│   │   ├── CBlueLightBridge.m     # Dynamic loading of CBBlueLightClient
│   │   └── include/
│   │       └── CBlueLightBridge.h
│   └── NightShiftToggle/          # Main Swift app
│       ├── main.swift             # Entry point
│       ├── NightShiftToggleApp.swift  # AppDelegate, menu bar, About window
│       ├── NightShiftManager.swift    # Night Shift enable/disable/restore logic
│       ├── FocusMonitor.swift         # NSWorkspace app focus observer
│       ├── ExcludeListManager.swift   # User's excluded app list (UserDefaults)
│       ├── ContentView.swift          # Settings window UI
│       └── Resources/
│           ├── AppIcon.icns
│           └── VERSION                # Single source of truth for app version
├── Tests/
│   └── ShiftChangeTests/          # XCTest suite (state machine, exclude list, app scanning)
scripts/
├── create-dmg.sh                  # Builds .app bundle and DMG for distribution
└── install.sh                     # curl-based installer (fetches latest GitHub release)
.github/workflows/
├── ci.yml                         # Build + test (macOS) and shellcheck, on every push/PR
└── release.yml                    # Tag-triggered: builds DMG, creates release, updates cask
```

## Build, Test & Run

```bash
cd ShiftChange
swift build -c release                  # Build binary
swift test                              # Run the test suite
.build/release/ShiftChange              # Run directly
../scripts/create-dmg.sh                # Build distributable DMG (reads version from Resources/VERSION)
```

## Testing

- Unit tests live in `ShiftChange/Tests/ShiftChangeTests/` and run via `swift test`, and automatically in CI (`.github/workflows/ci.yml`) on every push and pull request.
- The Night Shift override state machine is tested against `FakeBlueLightClient` (a `BlueLightControlling` implementation in `Fakes.swift`). Tests do NOT exercise the real private CoreBrightness framework, so the manual regression checklist below is still required before releases.
- Tests use isolated `UserDefaults` suites (`makeIsolatedDefaults()`) — never write to the standard defaults domain in tests.
- When changing Night Shift logic, add or update a unit test pinning the behavior; the excluded→excluded restore-loss bug and the schedule-outside-hours rules are both pinned this way.

## Key Technical Details

### CoreBrightness Bridge
The app uses Apple's **private** `CoreBrightness` framework via runtime dynamic loading (`dlopen`/`objc_msgSend`). The `BlueLightStatus` struct is reverse-engineered:
- `active` — the Night Shift feature is running/monitoring (true whenever a schedule is configured, even outside warming hours)
- `enabled` — Night Shift is currently applying a color shift (manual toggle or schedule-triggered)
- `mode` — 0=off, 1=sunSchedule, 2=customSchedule

**Important:** `active` does NOT mean "display is currently being warmed." Use `enabled` to determine if Night Shift is actually shifting color temperature.

Swift code should not call `CBlueLightBridge` directly — go through `NightShiftManager`, which wraps the bridge behind the `BlueLightControlling` protocol so logic stays testable.

### Night Shift Restore Logic
When an excluded app gains focus, we only disable and later restore Night Shift if `enabled` was true. A configured schedule alone (`mode != 0`) is not sufficient — restoring based on schedule existence would force-enable Night Shift outside schedule hours (e.g., toggling "Turn On Until Sunrise" at 6pm when sunset is 7:25pm). This was a past bug — see commit history.

`disableForExcludedApp()` must stay guarded against re-entry: when switching directly between two excluded apps, re-reading `isEnabled` would see the value we already set to false and drop the pending restore. This was also a past bug, now pinned by `testSwitchingBetweenExcludedAppsPreservesRestore`.

## Release Checklist

When making changes:

1. **Increment the version** in `ShiftChange/Sources/NightShiftToggle/Resources/VERSION` for any user-facing change. This is the single source of truth — the About screen, `create-dmg.sh`, and the release workflow all read from it.
2. **Run the test suite** (`swift test`) — CI also runs it on every push.
3. **Regression test Night Shift toggling on real hardware** after any change to `NightShiftManager.swift`, `FocusMonitor.swift`, or `CBlueLightBridge.m` (unit tests cover the state machine but not the real private framework):
   - Switch to an excluded app while Night Shift IS warming (after sunset) → Night Shift should disable; switching back should restore it
   - Switch between two excluded apps, then to a normal app → Night Shift should still restore
   - Switch to an excluded app while Night Shift is NOT warming (before sunset, with schedule) → nothing should change in either direction; "Turn On Until Sunrise" must NOT get toggled
   - Switch to an excluded app with Night Shift off and no schedule → nothing should change
   - Quit the app while overriding → Night Shift should restore
4. **Release:** merge to `main` with the bumped VERSION file. The release workflow (`.github/workflows/release.yml`) triggers on VERSION changes to main, builds the DMG, creates the `v<VERSION>` tag and GitHub release, and updates the Homebrew cask automatically. It skips silently if the version is already tagged, so a re-run is always safe. (Manual fallback: `./scripts/create-dmg.sh` then `gh release create v<VERSION> ./ShiftChange-<VERSION>.dmg --title "ShiftChange <VERSION>" --notes "<changelog>"`.)

## Code Signing & Notarization

The release workflow signs and notarizes the DMG when these GitHub Actions secrets are configured (Settings → Secrets and variables → Actions). If they're missing, the release still publishes — unsigned, with a warning in the run log.

| Secret | Contents |
|---|---|
| `MACOS_CERTIFICATE` | base64-encoded Developer ID Application certificate (.p12) |
| `MACOS_CERTIFICATE_PASSWORD` | password set when exporting the .p12 |
| `NOTARY_API_KEY` | contents of the App Store Connect API key (.p8) |
| `NOTARY_KEY_ID` | App Store Connect API key ID |
| `NOTARY_ISSUER_ID` | App Store Connect issuer UUID |

For local signed builds, `create-dmg.sh` honors `CODESIGN_IDENTITY` (a "Developer ID Application: ..." identity) and notarizes when `NOTARY_KEY_PATH`, `NOTARY_KEY_ID`, and `NOTARY_ISSUER_ID` are set. With none set, it builds unsigned exactly as before.

## Distribution

- **Homebrew:** `brew tap adamdexter/shiftchange && brew install --cask shiftchange`
- **curl installer:** `curl -fsSL https://raw.githubusercontent.com/adamdexter/shiftchange/main/scripts/install.sh | sh`
- **DMG:** GitHub Releases page
