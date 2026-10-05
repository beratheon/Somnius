#!/bin/bash
set -e

# ==============================================================================
# Somnius Release & Sparkle Update Generator
# Usage: ./scripts/build_release.sh [version, e.g. 1.0.1]
# ==============================================================================

VERSION="${1:-1.0.0}"
APP_NAME="Somnius"
SCHEME="Untitled Project"
BUILD_DIR="$(pwd)/build_output"
ARCHIVE_PATH="$BUILD_DIR/$APP_NAME.xcarchive"
APP_PATH="$BUILD_DIR/$APP_NAME.app"
DMG_PATH="$BUILD_DIR/$APP_NAME-$VERSION.dmg"

echo "🚀 Building $APP_NAME version $VERSION..."
mkdir -p "$BUILD_DIR"

# 1. Archive Release Build
echo "📦 Creating Xcode archive..."
xcodebuild archive \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination 'platform=macOS' \
  -archivePath "$ARCHIVE_PATH" \
  MARKETING_VERSION="$VERSION" \
  CURRENT_PROJECT_VERSION="1" \
  -quiet

# 2. Export .app
echo "📂 Extracting $APP_NAME.app..."
rm -rf "$APP_PATH"
cp -R "$ARCHIVE_PATH/Products/Applications/Untitled Project.app" "$APP_PATH"

# 3. Create Custom Styled DMG installer
echo "💿 Generating DMG artwork and staging installer..."
swift "$(pwd)/scripts/generate_dmg_background.swift" "$BUILD_DIR/dmg_background.png"

DMG_STAGING="$BUILD_DIR/dmg_staging"
rm -rf "$DMG_STAGING"
mkdir -p "$DMG_STAGING/.background"
cp -R "$APP_PATH" "$DMG_STAGING/$APP_NAME.app"
ln -s /Applications "$DMG_STAGING/Applications"
cp "$BUILD_DIR/dmg_background.png" "$DMG_STAGING/.background/background.png"

echo "💿 Packaging into $DMG_PATH..."
rm -f "$DMG_PATH" "$BUILD_DIR/temp.dmg"

# Create temporary writeable DMG
hdiutil create -srcfolder "$DMG_STAGING" -volname "$APP_NAME" -fs HFS+ -fsargs "-c c=64,a=16,e=16" -format UDRW -size 700m "$BUILD_DIR/temp.dmg" -quiet

# Mount writeable DMG
DEVICE=$(hdiutil attach -readwrite -noverify -noautoopen "$BUILD_DIR/temp.dmg" | awk 'NR==1{print $1}')
sleep 1

# Configure Finder visual presentation via AppleScript
osascript <<APPLESCRIPT || true
tell application "Finder"
    tell disk "$APP_NAME"
        open
        delay 0.5
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {200, 120, 860, 540}
        set viewOptions to the icon view options of container window
        set icon size of viewOptions to 120
        set arrangement of viewOptions to not arranged
        try
            set background picture of viewOptions to file ".background:background.png"
        end try
        delay 0.5
        try
            set position of item "$APP_NAME.app" of container window to {175, 175}
        end try
        try
            set position of item "Applications" of container window to {485, 175}
        on error
            try
                set position of file "Applications" of container window to {485, 175}
            end try
        end try
        update without registering applications
        delay 0.5
        close
    end tell
end tell
APPLESCRIPT

sync
hdiutil detach "$DEVICE" -quiet -force || true
sleep 1

# Convert to final compressed DMG
hdiutil convert "$BUILD_DIR/temp.dmg" -format UDZO -imagekey zlib-level=9 -o "$DMG_PATH" -quiet
rm -f "$BUILD_DIR/temp.dmg"
rm -rf "$DMG_STAGING"

# 4. Create ZIP package
ZIP_PATH="$BUILD_DIR/$APP_NAME-$VERSION-macOS.zip"
echo "🗜️ Packaging into $ZIP_PATH..."
rm -f "$ZIP_PATH"
(cd "$BUILD_DIR" && ditto -c -k --sequesterRsrc --keepParent "$APP_NAME.app" "$ZIP_PATH")

# 5. Create PKG installer (One-click native macOS installer with all bundled dependencies)
PKG_PATH="$BUILD_DIR/$APP_NAME-$VERSION.pkg"
echo "📦 Packaging into $PKG_PATH..."
rm -f "$PKG_PATH"
pkgbuild --component "$APP_PATH" --install-location /Applications "$PKG_PATH"

echo "✅ Successfully built release artifacts:"
echo "   📦 PKG: $PKG_PATH (Native macOS installer)"
echo "   💿 DMG: $DMG_PATH (Disk Image)"
echo "   🗜️ ZIP: $ZIP_PATH (Portable bundle)"
echo "👉 When ready to publish your release to GitHub:"
echo "   1. Go to github.com/beratheon/Somnius/releases/new"
echo "   2. Tag: v$VERSION, Title: Somnius $VERSION"
echo "   3. Attach $APP_NAME-$VERSION.pkg, $APP_NAME-$VERSION.dmg, and $APP_NAME-$VERSION-macOS.zip"

