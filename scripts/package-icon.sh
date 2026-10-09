#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
source_image="Resources/CarmentaIcon.png"
iconset=".build/CarmentaIcon.iconset"
mkdir -p "$iconset"
for size in 16 32 128 256 512; do
    sips -z "$size" "$size" "$source_image" --out "$iconset/icon_${size}x${size}.png" >/dev/null
    doubled=$((size * 2))
    sips -z "$doubled" "$doubled" "$source_image" --out "$iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$iconset" -o Resources/CarmentaIcon.icns
