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
├── Package.swift                  # Package name MUST stay "ShiftChange" — see Resource Bundle Naming
├── Sources/
│   ├── CBlueLightBridge/          # Obj-C bridge to private CoreBrightness framework
│   │   ├── CBlueLightBridge.m     # Dynamic loading of CBBlueLightClient
│   │   └── include/
│   │       └── CBlueLightBridge.h
│   └── ShiftChange/               # Main Swift app
│       ├── main.swift             # Entry point (pure AppKit, no SwiftUI App lifecycle)
│       ├── ShiftChangeApp.swift   # AppDelegate, menu bar, About window
│       ├── NightShiftManager.swift    # Night Shift enable/disable/restore logic
│       ├── FocusMonitor.swift         # NSWorkspace app focus observer
│       ├── ExcludeListManager.swift   # User's excluded app list (UserDefaults)
│       ├── InstalledAppsFinder.swift  # Scans /Applications etc. for .app bundles
│       ├── ContentView.swift          # Settings window UI
│       └── Resources/
│           ├── AppIcon.icns
│           └── VERSION                # Single source of truth for app version
├── Tests/
│   └── ShiftChangeTests/          # XCTest suite (state machine, exclude list, app scanning)
scripts/
├── create-dmg.sh                  # Builds .app bundle and DMG for distribution
└── install.sh                     # curl-based installer (fetches latest GitHub release)
HomebrewFormula/
└── shiftchange.rb                 # CI-updated cask copy; the live tap is a separate repo — see Distribution
.github/workflows/
├── ci.yml                         # Build + test (macOS) and shellcheck, on every push/PR
└── release.yml                    # On VERSION change to main: builds/signs DMG, creates release, updates cask + tap
```

## Build, Test & Run

```bash
cd ShiftChange
swift build -c release                  # Build binary
swift test                              # Run the test suite (requires full Xcode for XCTest)
.build/release/ShiftChange              # Run directly
../scripts/create-dmg.sh                # Build distributable DMG (reads version from Resources/VERSION)
```

**iCloud gotcha:** if this checkout lives under `~/Documents` (iCloud-synced),
sync can corrupt `.build` mid-build — symptoms are `LLVM ERROR: IO failure on
output stream: Bad file descriptor`, sqlite "disk I/O error" on build.db, or
spurious SDK-mismatch errors, plus stray Finder-style duplicates like
`NightShiftManager 2.swift` appearing in Sources (delete those; they break the
build). Work around it with `swift build --scratch-path /tmp/shiftchange-build`
(`create-dmg.sh` honors `SHIFTCHANGE_SCRATCH_PATH` for the same purpose)
or keep the repo outside iCloud-synced folders.

## Testing

- Unit tests live in `ShiftChange/Tests/ShiftChangeTests/` and run via `swift test`, and automatically in CI (`.github/workflows/ci.yml`) on every push and pull request.
- The Night Shift override state machine is tested against `FakeBlueLightClient` (a `BlueLightControlling` implementation in `Fakes.swift`). Tests do NOT exercise the real private CoreBrightness framework, so the manual regression checklist below is still required before releases.
- Tests use isolated `UserDefaults` suites (`makeIsolatedDefaults()`) — never write to the standard defaults domain in tests.
- When changing Night Shift logic, add or update a unit test pinning the behavior; the excluded→excluded restore-loss bug and the schedule-outside-hours rules are both pinned this way.

## Key Technical Details

### Resource Bundle Naming & Loading (read before touching resources)
SwiftPM names the resource bundle `<package>_<target>.bundle` — with both named `ShiftChange`, that's `ShiftChange_ShiftChange.bundle`. `create-dmg.sh` resolves that exact path (and fails the build if absent) and copies it into `Contents/Resources`.

**Never use `Bundle.module` directly in app code — go through `AppResources.bundle`.** SwiftPM's generated accessor for *executable* targets only checks the .app ROOT (`Bundle.main.bundleURL`) and a baked-in absolute path into the build machine's `.build` directory; it never checks `Contents/Resources`, so `Bundle.module` fatalErrors at launch in the packaged app. This crashed every release from v1.0.0 through v1.2.0 — and passed every on-machine test, because on the build machine the baked-in `.build` fallback path exists. **Launch tests of the packaged app only count with the build directory renamed/hidden** (the release workflow's smoke-test step does this automatically).

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

State updates must happen BEFORE `setEnabled` side effects in the manager: the framework notifies on every status change (including self-caused ones), and `FakeBlueLightClient` fires that handler synchronously in tests to enforce re-entrancy safety.

### External Status Changes (schedule triggers, System Settings)
The bridge registers a `setStatusNotificationBlock:` handler (delivered on the main queue) so ShiftChange reacts to Night Shift changes it didn't make. If the schedule (or the user, via System Settings/Control Center) turns Night Shift on while an excluded app has focus, `handleExternalStatusChange()` immediately re-disables it and sets the restore intent to on — the display never warms mid-session in a color-critical app. Self-triggered notifications terminate safely: after our own disable, `enabled` is false, so the handler no-ops. Pinned by `testScheduleFiringWhileOverridingIsReDisabledAndRestoredLater`.

Known remaining edge: if an override spans the *end* of a schedule window (e.g. in Photoshop from 11pm past sunrise), the snapshotted restore intent re-enables Night Shift outside schedule hours when focus leaves. Detecting this would require parsing schedule times from the private status struct.

### Global Night Shift Toggle (menu bar)
The menu bar has a "Turn On/Off Night Shift" item (`NightShiftManager.setGlobalEnabled(_:)`). Calling `setEnabled:` is the same thing System Settings' toggle does — when a schedule is configured, the OS itself handles the "until tomorrow / until sunset" scheduling.

Override interplay: if an excluded app has focus, the toggle does NOT touch the display — it only updates the restore intent (the state ShiftChange applies when focus leaves the excluded app). `effectiveEnabled` reports the user-intended state through any active override, and the menu refreshes in `menuWillOpen` plus on every status-change notification, because Night Shift state can change externally.

## Release Checklist

When making changes:

1. **Increment the version** in `ShiftChange/Sources/ShiftChange/Resources/VERSION` for any user-facing change. This is the single source of truth — the About screen, `create-dmg.sh`, and the release workflow all read from it.
2. **Run the test suite** (`swift test`) — CI also runs it on every push.
3. **Regression test Night Shift toggling on real hardware** after any change to `NightShiftManager.swift`, `FocusMonitor.swift`, or `CBlueLightBridge.m` (unit tests cover the state machine but not the real private framework):
   - Switch to an excluded app while Night Shift IS warming (after sunset) → Night Shift should disable; switching back should restore it
   - Switch between two excluded apps, then to a normal app → Night Shift should still restore
   - Switch to an excluded app while Night Shift is NOT warming (before sunset, with schedule) → nothing should change in either direction; "Turn On Until Sunrise" must NOT get toggled
   - Switch to an excluded app with Night Shift off and no schedule → nothing should change
   - With an excluded app in focus BEFORE sunset, wait for (or simulate) the schedule trigger → display must stay unshifted; leaving the excluded app afterwards should enable Night Shift
   - Menu bar "Turn Off Night Shift" while warming → display unshifts; System Settings shows it off until the next schedule trigger
   - Menu bar toggle while an excluded app is in focus → display must NOT change; the chosen state applies when focus leaves the excluded app
   - Toggle Night Shift in System Settings/Control Center → menu status line and toggle title reflect the change
   - Quit the app while overriding → Night Shift should restore
   - Launch the packaged .app from the DMG **with `.build` renamed away** — the baked-in fallback path makes dev-machine launch tests pass even when the packaged app is broken (CI's release smoke test also covers this)
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

### Homebrew tap (separate repo!)

The tap that `brew tap adamdexter/shiftchange` actually installs from is the
**separate repo `adamdexter/homebrew-shiftchange`** (`Casks/shiftchange.rb`).
`HomebrewFormula/shiftchange.rb` in this repo is only a CI-maintained copy.
On each release, `release.yml` pushes the updated cask to the tap **if the
`TAP_PUSH_TOKEN` secret is configured** (a PAT with write access to the tap
repo); without it the workflow warns and the tap must be updated manually,
or brew users stay pinned to the old version (this happened: the tap served
v1.0.0 while v1.1.2 was current).
