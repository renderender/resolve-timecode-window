#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
app="setup-dist/Install Resolve Timecode Window.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources" build
for arch in arm64 x86_64; do
    xcrun swiftc -module-cache-path "$PWD/build/cache-$arch" \
        -target "$arch-apple-macos14.0" -O setup/Setup.swift -o "build/setup-$arch"
done
lipo -create build/setup-arm64 build/setup-x86_64 -output "$app/Contents/MacOS/Setup"
cp setup/Info.plist "$app/Contents/"
cp setup/install.sh setup/replace.sh "$app/Contents/Resources/"
cp resources/AppIcon.png "$app/Contents/Resources/SetupIcon.png"
cp "dist/Resolve Timecode Window.app/Contents/Resources/AppIcon.icns" "$app/Contents/Resources/"
ditto "dist/Resolve Timecode Window.app" "$app/Contents/Resources/Resolve Timecode Window.app"
codesign --force --sign - "$app"
codesign --verify --deep --strict "$app"
cp HOWTO.md LICENSE NOTICE.md PRIVACY.md setup-dist/
ditto -c -k --norsrc setup-dist Resolve-Timecode-Window-2.0.2-Setup.zip
