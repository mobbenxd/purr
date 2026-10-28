#!/bin/zsh
# Builds Purr.app (menu bar only, no Dock icon) next to this script.
set -e
cd "${0:A:h}"

swift build -c release
APP=Purr.app
rm -rf $APP
mkdir -p $APP/Contents/MacOS $APP/Contents/Resources
cp .build/release/Purr $APP/Contents/MacOS/Purr

cat > $APP/Contents/Info.plist <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Purr</string>
    <key>CFBundleDisplayName</key><string>Purr</string>
    <key>CFBundleIdentifier</key><string>local.purr.menubar</string>
    <key>CFBundleExecutable</key><string>Purr</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
</dict>
</plist>
PLIST

codesign --force --sign - $APP
echo "Built $(pwd)/$APP"
