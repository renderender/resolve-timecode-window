#!/bin/bash
set -euo pipefail
resources="$(cd "$(dirname "$0")" && pwd)"
source_app="$resources/Resolve Timecode Window.app"
target_app="/Applications/Resolve Timecode Window.app"
label="local.resolve.timecodewindow.watcher"
domain="local.resolve.timecodewindow"
user_id="$(id -u)"

if [ ! -x "$source_app/Contents/MacOS/ResolveTimecodeWindow" ]; then
    echo "The setup package is incomplete."
    exit 1
fi
/usr/bin/codesign --verify --deep --strict "$source_app"
desired="$(/usr/bin/defaults read "$domain" LaunchWithResolve 2>/dev/null || true)"
if /bin/launchctl print "gui/$user_id/$label" >/dev/null 2>&1; then
    desired=1
fi

# Stop only this utility. Resolve and the user's other apps remain running.
/bin/launchctl bootout "gui/$user_id/$label" >/dev/null 2>&1 || true
/usr/bin/pkill -x ResolveWatcher >/dev/null 2>&1 || true
/usr/bin/pkill -x ResolveTimecodeWindow >/dev/null 2>&1 || true
for attempt in 1 2 3 4 5; do
    if ! /usr/bin/pgrep -x ResolveTimecodeWindow >/dev/null &&
       ! /usr/bin/pgrep -x ResolveWatcher >/dev/null; then break; fi
    /bin/sleep 1
done
if /usr/bin/pgrep -x ResolveTimecodeWindow >/dev/null ||
   /usr/bin/pgrep -x ResolveWatcher >/dev/null; then
    echo "The running utility could not be stopped. Please close it and try Setup again."
    exit 1
fi

# Stage a complete, verified copy before replacing an installed copy.
/bin/mkdir -p "$HOME/Library/Caches/local.resolve.timecodewindow"
stage="$(/usr/bin/mktemp -d "$HOME/Library/Caches/local.resolve.timecodewindow/update.XXXXXX")"
trap '/bin/rm -rf "$stage"' EXIT
/usr/bin/ditto "$source_app" "$stage/Resolve Timecode Window.app"
/usr/bin/codesign --verify --deep --strict "$stage/Resolve Timecode Window.app"

if [ -w /Applications ] && { [ ! -e "$target_app" ] || [ -w "$target_app" ]; }; then
    /bin/bash "$resources/replace.sh" "$stage/Resolve Timecode Window.app"
else
    /usr/bin/osascript - "$resources/replace.sh" "$stage/Resolve Timecode Window.app" <<'APPLESCRIPT'
on run argv
    do shell script "/bin/bash " & quoted form of (item 1 of argv) & " " & quoted form of (item 2 of argv) with administrator privileges
end run
APPLESCRIPT
fi

/usr/bin/codesign --verify --deep --strict "$target_app"
if [ "$desired" = 1 ]; then
    /usr/bin/defaults write "$domain" LaunchWithResolve -bool true
    /usr/bin/defaults write "$domain" RestoreLaunchAfterUpdate -bool true
fi
if [ "${1:-}" = "--reset-screen-permission" ]; then
    /usr/bin/tccutil reset ScreenCapture "$domain"
fi
/usr/bin/open "$target_app"
