#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
app="dist/Resolve Timecode Window.app"
helper="$app/Contents/Library/LoginItems/ResolveWatcher.app"
mkdir -p "$helper/Contents/MacOS" "$app/Contents/MacOS" "$app/Contents/Resources" "$app/Contents/Library/LaunchAgents" build/AppIcon.iconset
for size in 16 32 128 256 512; do
    sips -z "$size" "$size" resources/AppIcon.png --out "build/AppIcon.iconset/icon_${size}x${size}.png" >/dev/null
    double=$((size * 2))
    sips -z "$double" "$double" resources/AppIcon.png --out "build/AppIcon.iconset/icon_${size}x${size}@2x.png" >/dev/null
done
python3 make-icon.py
for arch in arm64 x86_64; do
    xcrun swiftc -module-cache-path "$PWD/build/cache-$arch" \
        -target "$arch-apple-macos14.0" -O \
        src/ViewerReader.swift src/TimecodeWindow.swift -o "build/app-$arch"
    xcrun swiftc -module-cache-path "$PWD/build/cache-$arch" \
        -target "$arch-apple-macos14.0" -O src/ResolveWatcher.swift -o "build/watcher-$arch"
done
lipo -create build/app-arm64 build/app-x86_64 -output "$app/Contents/MacOS/ResolveTimecodeWindow"
lipo -create build/watcher-arm64 build/watcher-x86_64 -output "$helper/Contents/MacOS/ResolveWatcher"
cp src/Info.plist "$app/Contents/"
cp src/bridge.py "$app/Contents/Resources/"
cp resources/local.resolve.timecodewindow.watcher.plist "$app/Contents/Library/LaunchAgents/"
cp resources/Watcher-Info.plist "$helper/Contents/Info.plist"
rm -f "$app/Contents/MacOS/ResolveWatcher"
codesign --force --sign - "$helper"
codesign --force --sign - "$app"
codesign --verify --strict "$app"
cp HOWTO.md LICENSE NOTICE.md PRIVACY.md dist/
ditto -c -k --norsrc "$PWD/dist" Resolve-Timecode-Window-macOS.zip
