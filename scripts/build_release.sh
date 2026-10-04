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

# 3. Create DMG installer
echo "💿 Packaging into $DMG_PATH..."
rm -f "$DMG_PATH"
hdiutil create -volname "$APP_NAME" -srcfolder "$APP_PATH" -ov -format UDZO "$DMG_PATH" -quiet

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

