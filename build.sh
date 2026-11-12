#!/bin/bash
# Builds ClaudeMeter.app into build/. With --install, copies it to /Applications
# and (re)starts it.
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release

APP=build/ClaudeMeter.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/ClaudeMeter "$APP/Contents/MacOS/ClaudeMeter"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$APP"
echo "Built $APP"

if [ "${1:-}" = "--install" ]; then
    pkill -x ClaudeMeter || true
    rm -rf "/Applications/ClaudeMeter.app"
    cp -R "$APP" "/Applications/"
    open "/Applications/ClaudeMeter.app"
    echo "Installed and started /Applications/ClaudeMeter.app"
fi
