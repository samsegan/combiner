#!/bin/bash
# Installs (or updates) Combiner:
#     curl -fsSL https://samsegan.github.io/combiner/install.sh | bash
# Downloads the newest Combiner.dmg from https://github.com/samsegan/combiner,
# copies Combiner.app into /Applications (~/Applications if that isn't
# writable) and opens it. A download made by curl isn't quarantined, so macOS
# doesn't ask you to approve Combiner the way it does for one from a browser.
set -euo pipefail

URL="${COMBINER_DMG_URL:-https://github.com/samsegan/combiner/releases/latest/download/Combiner.dmg}"
APP_DIR="${COMBINER_APP_DIR:-/Applications}"
[[ -w "$APP_DIR" ]] || APP_DIR="$HOME/Applications"

if [[ "$(uname -m)" != arm64 ]]; then
    echo "Combiner needs a Mac with Apple silicon (M1 or newer)." >&2
    exit 1
fi
MAJOR="$(sw_vers -productVersion | cut -d. -f1)"
if [[ "$MAJOR" -lt 14 ]]; then
    echo "Combiner needs macOS 14 Sonoma or later (this Mac has $(sw_vers -productVersion))." >&2
    exit 1
fi

TMP="$(mktemp -d)"
MOUNT="$TMP/mount"
cleanup() {
    hdiutil detach "$MOUNT" -quiet 2>/dev/null || true
    rm -rf "$TMP"
}
trap cleanup EXIT

echo "Downloading Combiner…"
curl -fL --progress-bar -o "$TMP/Combiner.dmg" "$URL"
mkdir -p "$MOUNT" "$APP_DIR"
hdiutil attach "$TMP/Combiner.dmg" -nobrowse -readonly -quiet -mountpoint "$MOUNT"

# The Combiner being replaced quits first (it saves as it goes).
RUNNING="$APP_DIR/Combiner.app/Contents/MacOS/Combiner"
if pgrep -f "$RUNNING" >/dev/null; then
    osascript -e 'tell application id "com.samsegan.combiner" to quit' 2>/dev/null || true
    for _ in 1 2 3 4 5 6 7 8 9 10; do pgrep -f "$RUNNING" >/dev/null || break; sleep 1; done
fi
rm -rf "$APP_DIR/Combiner.app"
ditto "$MOUNT/Combiner.app" "$APP_DIR/Combiner.app"

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_DIR/Combiner.app/Contents/Info.plist")"
echo "Installed Combiner $VERSION in $APP_DIR. Opening it: look for its icon in the menu bar."
open "$APP_DIR/Combiner.app"
