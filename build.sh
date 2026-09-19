#!/bin/zsh
# Builds build/Gratitude Buddy.app. No Xcode project needed, just the command-line tools.
set -euo pipefail
cd "$(dirname "$0")"

NAME="Gratitude Buddy"
APP="build/$NAME.app"
ARCH="$(uname -m)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" build/tmp

echo "▸ compiling"
swiftc -O -swift-version 5 \
  -target "$ARCH-apple-macosx14.0" \
  -framework AppKit -framework SwiftUI -framework ServiceManagement \
  Sources/*.swift \
  -o "$APP/Contents/MacOS/$NAME"

cp Info.plist "$APP/Contents/Info.plist"
mkdir -p "$APP/Contents/Resources/buddies"
cp Resources/buddies/*.png "$APP/Contents/Resources/buddies/"

echo "▸ icon"
if swiftc -O -swift-version 5 -target "$ARCH-apple-macosx14.0" \
     -framework AppKit -framework SwiftUI -framework ServiceManagement \
     $(ls Sources/*.swift | grep -v "/main.swift") Tools/MakeIcon/main.swift -o build/tmp/MakeIcon 2>/dev/null \
   && build/tmp/MakeIcon build/tmp/AppIcon.iconset >/dev/null \
   && iconutil -c icns build/tmp/AppIcon.iconset -o "$APP/Contents/Resources/AppIcon.icns"; then
  :
else
  echo "  (icon generation failed, continuing without one)"
fi

echo "▸ signing (ad hoc)"
codesign --force --sign - "$APP" >/dev/null 2>&1 || echo "  (codesign skipped)"

rm -rf build/tmp
echo "✓ built $APP"
