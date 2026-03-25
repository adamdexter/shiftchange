#!/usr/bin/env bash
set -euo pipefail

# ── ShiftChange Installer ────────────────────────────────────────
# Usage: curl -fsSL https://raw.githubusercontent.com/adamdexter/shiftchange/main/scripts/install.sh | sh
# ──────────────────────────────────────────────────────────────────

APP_NAME="ShiftChange"
REPO="adamdexter/shiftchange"
INSTALL_DIR="/Applications"

# ── Helpers ───────────────────────────────────────────────────────

info()  { printf '  \033[1;34m==>\033[0m %s\n' "$*"; }
error() { printf '  \033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

cleanup() {
    if [ -n "${TMPDIR_INSTALL:-}" ] && [ -d "$TMPDIR_INSTALL" ]; then
        rm -rf "$TMPDIR_INSTALL"
    fi
    if [ -n "${MOUNT_POINT:-}" ] && [ -d "$MOUNT_POINT" ]; then
        hdiutil detach "$MOUNT_POINT" -quiet 2>/dev/null || true
    fi
}
trap cleanup EXIT

# ── Pre-flight checks ────────────────────────────────────────────

if [ "$(uname)" != "Darwin" ]; then
    error "ShiftChange is a macOS app. This installer only works on macOS."
fi

if ! command -v curl >/dev/null 2>&1; then
    error "curl is required but not found."
fi

if ! command -v hdiutil >/dev/null 2>&1; then
    error "hdiutil is required but not found (are you on macOS?)."
fi

# ── Fetch latest release ─────────────────────────────────────────

info "Fetching latest ${APP_NAME} release..."

LATEST_URL="https://api.github.com/repos/${REPO}/releases/latest"
RELEASE_JSON=$(curl -fsSL "$LATEST_URL") || error "Failed to fetch release info from GitHub."

# Extract the DMG download URL
DMG_URL=$(printf '%s' "$RELEASE_JSON" | grep -o '"browser_download_url":\s*"[^"]*\.dmg"' | head -1 | sed 's/.*"browser_download_url":\s*"//;s/"$//')

if [ -z "$DMG_URL" ]; then
    error "No DMG found in the latest release. Please install manually from https://github.com/${REPO}/releases"
fi

VERSION=$(printf '%s' "$RELEASE_JSON" | grep -o '"tag_name":\s*"[^"]*"' | head -1 | sed 's/.*"tag_name":\s*"//;s/"$//')
info "Latest version: ${VERSION}"

# ── Download ──────────────────────────────────────────────────────

TMPDIR_INSTALL=$(mktemp -d)
DMG_PATH="${TMPDIR_INSTALL}/${APP_NAME}.dmg"

info "Downloading ${APP_NAME}..."
curl -fSL --progress-bar -o "$DMG_PATH" "$DMG_URL" || error "Download failed."

# ── Mount & install ───────────────────────────────────────────────

info "Mounting disk image..."
MOUNT_POINT=$(hdiutil attach -nobrowse -readonly "$DMG_PATH" 2>/dev/null | grep -o '/Volumes/.*' | xargs)

if [ -z "$MOUNT_POINT" ] || [ ! -d "$MOUNT_POINT" ]; then
    error "Failed to mount DMG."
fi

APP_SRC="${MOUNT_POINT}/${APP_NAME}.app"
if [ ! -d "$APP_SRC" ]; then
    error "${APP_NAME}.app not found inside the disk image."
fi

# Remove existing installation if present
if [ -d "${INSTALL_DIR}/${APP_NAME}.app" ]; then
    info "Removing existing installation..."
    rm -rf "${INSTALL_DIR}/${APP_NAME}.app" || error "Failed to remove existing installation. Try running with sudo."
fi

info "Installing to ${INSTALL_DIR}..."
cp -R "$APP_SRC" "${INSTALL_DIR}/" || error "Failed to copy to ${INSTALL_DIR}. Try running with sudo."

# ── Done ──────────────────────────────────────────────────────────

info "Unmounting disk image..."
hdiutil detach "$MOUNT_POINT" -quiet 2>/dev/null || true
MOUNT_POINT=""

echo ""
echo "  ✅ ${APP_NAME} ${VERSION} installed to ${INSTALL_DIR}/${APP_NAME}.app"
echo ""
echo "  Launch it from your Applications folder or run:"
echo "    open -a ${APP_NAME}"
echo ""
