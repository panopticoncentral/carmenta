#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
configuration="${1:-release}"
if [[ "$configuration" != "debug" && "$configuration" != "release" ]]; then
    echo "Usage: $0 [debug|release]" >&2
    exit 1
fi
export CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-module-cache"
if [[ -z "${DEVELOPER_DIR:-}" && -d /Applications/Xcode.app/Contents/Developer ]]; then
    export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi
xcrun swift build -c "$configuration" --disable-sandbox
binary_directory="$(xcrun swift build -c "$configuration" --show-bin-path)"
app="$PWD/build/Carmenta.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$binary_directory/Carmenta" "$app/Contents/MacOS/Carmenta"
cp Resources/Info.plist "$app/Contents/Info.plist"
if [[ ! -f Resources/CarmentaIcon.icns || Resources/CarmentaIcon.png -nt Resources/CarmentaIcon.icns ]]; then
    bash scripts/package-icon.sh
fi
cp Resources/CarmentaIcon.icns "$app/Contents/Resources/CarmentaIcon.icns"
codesign --force --sign - "$app"
echo "Built $app"
