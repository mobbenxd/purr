#!/bin/zsh
# Builds Purr.app (menu bar only, no Dock icon) next to this script.
#
# Version comes from the VERSION file; the build number is the git commit
# count. Set PURR_SIGN_IDENTITY to a "Developer ID Application: …" identity to
# sign for distribution (hardened runtime); otherwise the app is ad-hoc signed.
set -e
cd "${0:A:h}"

VERSION=$(tr -d ' \n' < VERSION)
BUILD=$(git rev-list --count HEAD 2>/dev/null || echo 1)
# owner/name of the GitHub repo whose releases the app checks for updates.
REMOTE=$(git remote get-url origin 2>/dev/null || true)
REPO=mobbenxd/purr
if [[ "$REMOTE" == *github.com[:/]*/* ]]; then
    REPO=$(echo "$REMOTE" | sed -E 's#(\.git)?$##; s#^.*github\.com[:/]##')
fi

swift build -c release
APP=Purr.app
rm -rf $APP
mkdir -p $APP/Contents/MacOS $APP/Contents/Resources
cp .build/release/Purr $APP/Contents/MacOS/Purr

# App icon, drawn by the same code as the cat in the panel.
ICONSET=.build/AppIcon.iconset
rm -rf $ICONSET
.build/release/Purr --export-icon $ICONSET
iconutil -c icns $ICONSET -o $APP/Contents/Resources/AppIcon.icns

cp -R Resources/*.lproj $APP/Contents/Resources/

cat > $APP/Contents/Info.plist <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Purr</string>
    <key>CFBundleDisplayName</key><string>Purr</string>
    <key>CFBundleIdentifier</key><string>local.purr.menubar</string>
    <key>CFBundleExecutable</key><string>Purr</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>$BUILD</string>
    <key>CFBundleDevelopmentRegion</key><string>th</string>
    <key>CFBundleLocalizations</key><array><string>th</string><string>en</string></array>
    <key>PurrRepository</key><string>$REPO</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHumanReadableCopyright</key><string>Purr · powered by Mole</string>
</dict>
</plist>
PLIST

if [[ -n "$PURR_SIGN_IDENTITY" ]]; then
    codesign --force --options runtime --timestamp --sign "$PURR_SIGN_IDENTITY" $APP
else
    codesign --force --sign - $APP
fi
echo "Built $(pwd)/$APP  (v$VERSION, build $BUILD, updates from $REPO)"
