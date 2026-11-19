#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
app="dist/Resolve Timecode Window.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources" build
for arch in arm64 x86_64; do
    xcrun swiftc -module-cache-path "$PWD/build/cache-$arch" \
        -target "$arch-apple-macos14.0" -O \
        src/ViewerReader.swift src/TimecodeWindow.swift -o "build/app-$arch"
done
lipo -create build/app-arm64 build/app-x86_64 -output "$app/Contents/MacOS/ResolveTimecodeWindow"
cp src/Info.plist "$app/Contents/"
cp src/bridge.py "$app/Contents/Resources/"
codesign --force --sign - "$app"
codesign --verify --strict "$app"
cp HOWTO.md LICENSE NOTICE.md PRIVACY.md dist/
ditto -c -k --norsrc "$PWD/dist" Resolve-Timecode-Window-macOS.zip
