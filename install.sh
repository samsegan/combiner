#!/bin/bash
# Installs (or updates) Combiner:
#     curl -fsSL https://samsegan.github.io/combiner/install.sh | bash
# Downloads the newest Combiner.dmg from https://github.com/samsegan/combiner,
# copies Combiner.app into /Applications (~/Applications if that isn't
# writable) and opens it. A download made by curl isn't quarantined, so macOS
# doesn't ask you to approve Combiner the way it does for one from a browser.
#
# Everything is inside main, called on the last line: bash runs a piped
# script as it arrives, so a download cut off half way would otherwise run
# the half it got (as far as deleting the old Combiner, say). Cut off
# anywhere, this runs nothing.
set -euo pipefail

main() {
    local URL="${COMBINER_DMG_URL:-https://github.com/samsegan/combiner/releases/latest/download/Combiner.dmg}"
    local APP_DIR="${COMBINER_APP_DIR:-/Applications}"
    [[ -w "$APP_DIR" ]] || APP_DIR="$HOME/Applications"

    if [[ "$(uname -m)" != arm64 ]]; then
        echo "Combiner needs a Mac with Apple silicon (M1 or newer)." >&2
        exit 1
    fi
    local MAJOR
    MAJOR="$(sw_vers -productVersion | cut -d. -f1)"
    if [[ "$MAJOR" -lt 14 ]]; then
        echo "Combiner needs macOS 14 Sonoma or later (this Mac has $(sw_vers -productVersion))." >&2
        exit 1
    fi

    TMP="$(mktemp -d)"
    MOUNT="$TMP/mount"
    # The new copy goes beside the old one under another name (the same disk,
    # so swapping it in is a rename), and the old one is moved aside, not
    # deleted, until the new one is in place.
    NEW="$APP_DIR/.Combiner.installing.$$.app"
    OLD="$APP_DIR/.Combiner.replaced.$$.app"
    cleanup() {
        hdiutil detach "$MOUNT" -quiet 2>/dev/null || true
        rm -rf "$TMP" "$NEW"
        # Stopped between the two renames: the old Combiner goes back.
        if [[ -d "$OLD" && ! -d "$APP_DIR/Combiner.app" ]]; then mv "$OLD" "$APP_DIR/Combiner.app"; fi
        rm -rf "$OLD"
    }
    trap cleanup EXIT

    echo "Downloading Combiner…"
    curl -fL --progress-bar -o "$TMP/Combiner.dmg" "$URL"
    mkdir -p "$MOUNT" "$APP_DIR"
    hdiutil attach "$TMP/Combiner.dmg" -nobrowse -readonly -quiet -mountpoint "$MOUNT"

    # Copied and checked before anything installed is touched: a download or
    # a copy that went wrong leaves the Combiner already there as it was.
    ditto "$MOUNT/Combiner.app" "$NEW"
    if ! codesign --verify --deep --strict "$NEW" 2>/dev/null; then
        echo "The Combiner that was downloaded didn't pass its signature check, so nothing was installed." >&2
        echo "Try again; if it keeps happening, download it from https://github.com/samsegan/combiner/releases" >&2
        exit 1
    fi

    # The Combiner being replaced quits first (it saves as it goes).
    local RUNNING="$APP_DIR/Combiner.app/Contents/MacOS/Combiner"
    if pgrep -f "$RUNNING" >/dev/null; then
        osascript -e 'tell application id "com.samsegan.combiner" to quit' 2>/dev/null || true
        for _ in 1 2 3 4 5 6 7 8 9 10; do pgrep -f "$RUNNING" >/dev/null || break; sleep 1; done
    fi
    if [[ -e "$APP_DIR/Combiner.app" ]]; then mv "$APP_DIR/Combiner.app" "$OLD"; fi
    mv "$NEW" "$APP_DIR/Combiner.app"
    rm -rf "$OLD"

    local VERSION
    VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_DIR/Combiner.app/Contents/Info.plist")"
    echo "Installed Combiner $VERSION in $APP_DIR. Opening it: look for its icon in the Dock and the menu bar."
    open "$APP_DIR/Combiner.app"
}

main "$@"
