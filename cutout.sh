#!/bin/zsh
# Turns an illustration on a white background into a transparent buddy PNG.
#   ./cutout.sh <input.png> <Resources/buddies/name-mood.png> [dark]
# Pass "dark" for black animals: it also strips the white fringe from soft fur edges.
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p build/tmp
if [[ ! -x build/tmp/cutout || Tools/Cutout/main.swift -nt build/tmp/cutout ]]; then
  swiftc -O -swift-version 5 -framework AppKit -framework Vision -framework CoreImage \
    Tools/Cutout/main.swift -o build/tmp/cutout
fi
build/tmp/cutout cutout 640 "$2" "$1" "${3:-}"
