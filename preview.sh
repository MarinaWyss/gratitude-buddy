#!/bin/zsh
# Renders each step of the check-in card to build/preview/*.png (handy when tweaking the design).
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p build/preview
swiftc -swift-version 5 -framework AppKit -framework SwiftUI -framework ServiceManagement \
  Sources/Settings.swift Sources/Journal.swift Sources/CheckInModel.swift \
  Sources/BuddyFace.swift Sources/BuddyView.swift Tools/Preview/main.swift \
  -o build/preview/render
build/preview/render build/preview
