#!/bin/bash
set -e

# ==============================================================================
# Somnus Release & Sparkle Update Generator
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

echo "✅ Successfully built: $DMG_PATH"
echo "👉 When ready to publish an update:"
echo "   1. Upload $APP_NAME-$VERSION.dmg to your GitHub Release"
echo "   2. Run generate_appcast to update appcast.xml"
