#!/bin/bash
set -euo pipefail
source_app="$1"
target="/Applications/Resolve Timecode Window.app"
/usr/bin/codesign --verify --deep --strict "$source_app"
transaction="$(/usr/bin/mktemp -d /Applications/.ResolveTimecodeUpdate.XXXXXX)"
committed=0
cleanup() {
    if [ "$committed" = 0 ] && [ -d "$transaction/previous.app" ] && [ ! -e "$target" ]; then
        /bin/mv "$transaction/previous.app" "$target"
    fi
    /bin/rm -rf "$transaction"
}
trap cleanup EXIT
/usr/bin/ditto "$source_app" "$transaction/new.app"
/usr/bin/codesign --verify --deep --strict "$transaction/new.app"
if [ -e "$target" ]; then /bin/mv "$target" "$transaction/previous.app"; fi
/bin/mv "$transaction/new.app" "$target"
committed=1
