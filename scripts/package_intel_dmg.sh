#!/bin/bash
set -e

SOURCE_APP="/Users/umut/Documents/COMPLETE/build_intel/Somnius-Intel.xcarchive/Products/Applications/Somnius.app"
DEST_DIR="/Users/umut/Documents/Somnius dev"
DMG_FINAL="$DEST_DIR/Somnius-Intel-macOS.dmg"
STAGING_DIR="/Users/umut/Documents/COMPLETE/build_intel/dmg_staging"
TEMP_DMG="/Users/umut/Documents/COMPLETE/build_intel/temp.dmg"

echo "🛠️ Staging Intel app..."
rm -rf "$STAGING_DIR" "$TEMP_DMG"
mkdir -p "$STAGING_DIR/.background"

APP_PATH="$STAGING_DIR/Somnius.app"
cp -R "$SOURCE_APP" "$APP_PATH"

# Ensure proper bundle plist
plutil -replace CFBundleName -string "Somnius" "$APP_PATH/Contents/Info.plist"
plutil -replace CFBundleDisplayName -string "Somnius" "$APP_PATH/Contents/Info.plist"
plutil -replace CFBundleIdentifier -string "com.beratheon.Somnius" "$APP_PATH/Contents/Info.plist"
plutil -replace LSMinimumSystemVersion -string "12.0" "$APP_PATH/Contents/Info.plist"

# Resign bundle ad-hoc so dyld validation passes
codesign --force --deep --sign - "$APP_PATH"

# Prepare staging with Applications symlink
ln -s /Applications "$STAGING_DIR/Applications"
cp "/Users/umut/Documents/COMPLETE/build_output/dmg_background.png" "$STAGING_DIR/.background/background.png" 2>/dev/null || true

echo "💿 Creating temporary DMG..."
hdiutil create -srcfolder "$STAGING_DIR" -volname "Somnius Intel" -fs HFS+ -fsargs "-c c=64,a=16,e=16" -format UDRW -size 700m "$TEMP_DMG" -quiet

# Unmount stale if any
diskutil unmount force "/Volumes/Somnius Intel" 2>/dev/null || true

DEVICE=$(hdiutil attach -readwrite -noverify -noautoopen "$TEMP_DMG" | awk 'NR==1{print $1}')
sleep 1

osascript <<APPLESCRIPT || true
tell application "Finder"
    tell disk "Somnius Intel"
        open
        delay 1
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {200, 120, 860, 540}
        set viewOptions to the icon view options of container window
        set icon size of viewOptions to 120
        set arrangement of viewOptions to not arranged
        try
            set background picture of viewOptions to POSIX file ("/Volumes/Somnius Intel/.background/background.png")
        end try
        delay 1
        try
            set position of item "Somnius.app" of container window to {175, 175}
        end try
        try
            set position of item "Applications" of container window to {485, 175}
        on error
            try
                set position of file "Applications" of container window to {485, 175}
            end try
        end try
        delay 1
        update without registering applications
        delay 1
        close
    end tell
end tell
APPLESCRIPT

sleep 2
sync
hdiutil detach "$DEVICE" -quiet -force || true
sleep 1

echo "🗜️ Converting to compressed DMG..."
rm -f "$DMG_FINAL"
hdiutil convert "$TEMP_DMG" -format UDZO -imagekey zlib-level=9 -o "$DMG_FINAL" -quiet

rm -rf "$STAGING_DIR" "$TEMP_DMG"

echo "✅ Created: $DMG_FINAL"
ls -lh "$DMG_FINAL"
