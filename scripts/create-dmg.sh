#!/usr/bin/env bash
set -euo pipefail

# ── Configuration ──────────────────────────────────────────────────
APP_NAME="ShiftChange"
BUNDLE_ID="net.adamdexter.ShiftChange"
VERSION="${1:-1.0.0}"
DMG_NAME="${APP_NAME}-${VERSION}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PKG_DIR="${PROJECT_DIR}/NightShiftToggle"
BUILD_DIR="${PKG_DIR}/.build-dmg"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"
DMG_TEMP="${BUILD_DIR}/${DMG_NAME}-temp.dmg"
DMG_FINAL="${PROJECT_DIR}/${DMG_NAME}.dmg"

echo "==> Building ${APP_NAME} v${VERSION}..."

# ── 1. Build release binary ───────────────────────────────────────
cd "$PKG_DIR"
swift build -c release 2>&1

BINARY="${PKG_DIR}/.build/release/ShiftChange"
if [ ! -f "$BINARY" ]; then
    echo "ERROR: Binary not found at ${BINARY}"
    exit 1
fi

# Find the resource bundle
RESOURCE_BUNDLE=$(find "${PKG_DIR}/.build/release" -name "ShiftChange_ShiftChange.bundle" -maxdepth 1 | head -1)

# ── 2. Create .app bundle ─────────────────────────────────────────
echo "==> Creating ${APP_NAME}.app bundle..."
rm -rf "$BUILD_DIR"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

# Copy binary
cp "$BINARY" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"

# Copy resource bundle (contains AppIcon.icns etc.)
if [ -n "$RESOURCE_BUNDLE" ] && [ -d "$RESOURCE_BUNDLE" ]; then
    cp -R "$RESOURCE_BUNDLE" "${APP_BUNDLE}/Contents/Resources/"
fi

# Copy icon
cp "${PKG_DIR}/shiftchange.icns" "${APP_BUNDLE}/Contents/Resources/AppIcon.icns"

# Create Info.plist
cat > "${APP_BUNDLE}/Contents/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026 Adam Dexter. All rights reserved.</string>
</dict>
</plist>
PLIST

echo "==> ${APP_NAME}.app created."

# ── 3. Generate DMG background ────────────────────────────────────
echo "==> Generating DMG background image..."

BG_DIR="${BUILD_DIR}/dmg-background"
mkdir -p "$BG_DIR"

# Use Swift to render background with CoreGraphics (no third-party deps)
swift - "$BG_DIR" << 'SWIFTEOF'
import Foundation
import CoreGraphics
import CoreText
import ImageIO
import UniformTypeIdentifiers

let bgDir = CommandLine.arguments[1]

func createBackground(width: Int, height: Int, scale: Int, outputPath: String) {
    let pw = width * scale
    let ph = height * scale
    let cs = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(
        data: nil, width: pw, height: ph,
        bitsPerComponent: 8, bytesPerRow: pw * 4,
        space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return }

    ctx.scaleBy(x: CGFloat(scale), y: CGFloat(scale))
    let w = CGFloat(width)
    let h = CGFloat(height)

    // ── Background gradient ──
    let colors = [
        CGColor(red: 0.96, green: 0.96, blue: 0.97, alpha: 1.0),
        CGColor(red: 0.90, green: 0.90, blue: 0.92, alpha: 1.0),
    ] as CFArray
    let gradient = CGGradient(colorsSpace: cs, colors: colors, locations: [0.0, 1.0])!
    ctx.drawLinearGradient(gradient,
        start: CGPoint(x: 0, y: h),
        end: CGPoint(x: 0, y: 0),
        options: [])

    // ── Arrow (shaft + arrowhead) ──
    let arrowY = h - 205
    let shaftStartX: CGFloat = 235
    let shaftEndX: CGFloat = 415

    ctx.setStrokeColor(red: 0.55, green: 0.55, blue: 0.58, alpha: 1.0)
    ctx.setLineWidth(2.5)
    ctx.setLineCap(.round)
    ctx.move(to: CGPoint(x: shaftStartX, y: arrowY))
    ctx.addLine(to: CGPoint(x: shaftEndX, y: arrowY))
    ctx.strokePath()

    // Arrowhead
    let headSize: CGFloat = 12
    ctx.setFillColor(red: 0.55, green: 0.55, blue: 0.58, alpha: 1.0)
    ctx.move(to: CGPoint(x: shaftEndX + headSize + 4, y: arrowY))
    ctx.addLine(to: CGPoint(x: shaftEndX - 2, y: arrowY + headSize))
    ctx.addLine(to: CGPoint(x: shaftEndX - 2, y: arrowY - headSize))
    ctx.closePath()
    ctx.fillPath()

    // ── Text ──
    let text = "Drag ShiftChange to Applications" as CFString
    let font = CTFontCreateWithName("Helvetica Neue" as CFString, 15, nil)
    let attrs: [CFString: Any] = [
        kCTFontAttributeName: font,
        kCTForegroundColorAttributeName: CGColor(red: 0.45, green: 0.45, blue: 0.48, alpha: 1.0),
    ]
    let attrString = CFAttributedStringCreate(nil, text, attrs as CFDictionary)!
    let line = CTLineCreateWithAttributedString(attrString)
    let textBounds = CTLineGetBoundsWithOptions(line, [])
    let textX = (w - textBounds.width) / 2
    let textY = h - 320

    ctx.textPosition = CGPoint(x: textX, y: textY)
    CTLineDraw(line, ctx)

    // ── Save as PNG ──
    guard let image = ctx.makeImage() else { return }
    let url = URL(fileURLWithPath: outputPath) as CFURL
    guard let dest = CGImageDestinationCreateWithURL(url, UTType.png.identifier as CFString, 1, nil) else { return }
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)
}

createBackground(width: 660, height: 400, scale: 1,
    outputPath: "\(bgDir)/background.png")
createBackground(width: 660, height: 400, scale: 2,
    outputPath: "\(bgDir)/background@2x.png")

print("Background images created.")
SWIFTEOF

# ── 4. Create DMG ─────────────────────────────────────────────────
echo "==> Assembling DMG..."

DMG_STAGING="${BUILD_DIR}/dmg-staging"
rm -rf "$DMG_STAGING"
mkdir -p "$DMG_STAGING/.background"

# Copy app bundle
cp -R "$APP_BUNDLE" "$DMG_STAGING/"

# Create Applications symlink
ln -s /Applications "$DMG_STAGING/Applications"

# Copy background
cp "${BG_DIR}/background.png" "$DMG_STAGING/.background/background.png"
cp "${BG_DIR}/background@2x.png" "$DMG_STAGING/.background/background@2x.png"

# Create the DMG
rm -f "$DMG_TEMP" "$DMG_FINAL"
hdiutil create -volname "$APP_NAME" \
    -srcfolder "$DMG_STAGING" \
    -ov -format UDRW \
    "$DMG_TEMP" 2>/dev/null

# Mount it to configure the Finder window
echo "==> Configuring DMG Finder window..."
MOUNT_DIR=$(hdiutil attach -readwrite -noverify "$DMG_TEMP" 2>/dev/null | grep "/Volumes/" | sed 's/.*\/Volumes/\/Volumes/')
MOUNT_DIR=$(echo "$MOUNT_DIR" | xargs)  # trim whitespace

if [ -z "$MOUNT_DIR" ]; then
    echo "ERROR: Failed to mount DMG"
    exit 1
fi

echo "   Mounted at: ${MOUNT_DIR}"

# Give Finder time to notice the new volume
sleep 2

# Use AppleScript to configure the Finder window appearance
# Retry up to 3 times since Finder may not see the disk immediately
for attempt in 1 2 3; do
    if osascript << ASCRIPT
        tell application "Finder"
            -- Wait for disk to appear
            set maxWait to 10
            set diskFound to false
            repeat maxWait times
                try
                    set diskFound to exists disk "${APP_NAME}"
                end try
                if diskFound then exit repeat
                delay 1
            end repeat

            if not diskFound then
                error "Disk ${APP_NAME} not found after waiting"
            end if

            tell disk "${APP_NAME}"
                open
                set current view of container window to icon view
                set toolbar visible of container window to false
                set statusbar visible of container window to false
                set the bounds of container window to {100, 100, 760, 500}
                set viewOptions to the icon view options of container window
                set arrangement of viewOptions to not arranged
                set icon size of viewOptions to 80
                set text size of viewOptions to 13
                set background picture of viewOptions to file ".background:background.png"
                set position of item "${APP_NAME}.app" of container window to {180, 190}
                set position of item "Applications" of container window to {480, 190}
                close
                open
                update without registering applications
                delay 1
                close
            end tell
        end tell
ASCRIPT
    then
        echo "   Finder window configured."
        break
    else
        echo "   Attempt ${attempt} failed, retrying..."
        sleep 2
    fi
done

# Set volume icon
if [ -f "${APP_BUNDLE}/Contents/Resources/AppIcon.icns" ]; then
    cp "${APP_BUNDLE}/Contents/Resources/AppIcon.icns" "${MOUNT_DIR}/.VolumeIcon.icns"
    SetFile -c icnC "${MOUNT_DIR}/.VolumeIcon.icns" 2>/dev/null || true
    SetFile -a C "${MOUNT_DIR}" 2>/dev/null || true
fi

sync
hdiutil detach "$MOUNT_DIR" 2>/dev/null

# ── 5. Compress to final DMG ──────────────────────────────────────
echo "==> Compressing final DMG..."
hdiutil convert "$DMG_TEMP" -format UDZO -imagekey zlib-level=9 -o "$DMG_FINAL" 2>/dev/null

rm -f "$DMG_TEMP"

echo ""
echo "==================================================="
echo "  ${APP_NAME} v${VERSION} DMG created successfully!"
echo "==================================================="
echo ""
echo "  ${DMG_FINAL}"
echo "  Size: $(du -h "$DMG_FINAL" | cut -f1)"
echo ""
