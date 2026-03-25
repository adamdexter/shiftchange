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
scripts/
├── create-dmg.sh                  # Builds .app bundle and DMG for distribution
└── install.sh                     # curl-based installer (fetches latest GitHub release)
```

## Build & Run

```bash
cd ShiftChange
swift build -c release                  # Build binary
.build/release/ShiftChange              # Run directly
../scripts/create-dmg.sh                # Build distributable DMG (reads version from Resources/VERSION)
```

## Key Technical Details

### CoreBrightness Bridge
The app uses Apple's **private** `CoreBrightness` framework via runtime dynamic loading (`dlopen`/`objc_msgSend`). The `BlueLightStatus` struct is reverse-engineered:
- `active` — the Night Shift feature is running/monitoring (true whenever a schedule is configured, even outside warming hours)
- `enabled` — Night Shift is currently applying a color shift (manual toggle or schedule-triggered)
- `mode` — 0=off, 1=sunSchedule, 2=customSchedule

**Important:** `active` does NOT mean "display is currently being warmed." Use `enabled` to determine if Night Shift is actually shifting color temperature.

### Night Shift Restore Logic
When an excluded app gains focus, we only disable and later restore Night Shift if `enabled` was true. A configured schedule alone (`mode != 0`) is not sufficient — restoring based on schedule existence would force-enable Night Shift outside schedule hours (e.g., toggling "Turn On Until Sunrise" at 6pm when sunset is 7:25pm). This was a past bug — see commit history.

## Release Checklist

When making changes:

1. **Increment the version** in `ShiftChange/Sources/NightShiftToggle/Resources/VERSION` for any user-facing change. This is the single source of truth — the About screen and `create-dmg.sh` both read from it.
2. **Regression test Night Shift toggling** after any change to `NightShiftManager.swift`, `FocusMonitor.swift`, or `CBlueLightBridge.m`:
   - Switch to an excluded app while Night Shift IS warming (after sunset) → Night Shift should disable; switching back should restore it
   - Switch to an excluded app while Night Shift is NOT warming (before sunset, with schedule) → nothing should change in either direction; "Turn On Until Sunrise" must NOT get toggled
   - Switch to an excluded app with Night Shift off and no schedule → nothing should change
   - Quit the app while overriding → Night Shift should restore
3. **Build the DMG:** `./scripts/create-dmg.sh`
4. **Create GitHub release:** `gh release create v<VERSION> ./ShiftChange-<VERSION>.dmg --title "ShiftChange <VERSION>" --notes "<changelog>"`
5. **Update Homebrew tap** if applicable

## Distribution

- **Homebrew:** `brew tap adamdexter/shiftchange && brew install --cask shiftchange`
- **curl installer:** `curl -fsSL https://raw.githubusercontent.com/adamdexter/shiftchange/main/scripts/install.sh | sh`
- **DMG:** GitHub Releases page
