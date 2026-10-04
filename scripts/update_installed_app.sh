#!/bin/bash
set -e

APP_NAME="Somnius"
SCHEME="Untitled Project"
TARGET_DIR="/Applications"

echo "⚡ Fast building $APP_NAME for local testing..."

xcodebuild -scheme "$SCHEME" \
  -configuration Release \
  -destination 'platform=macOS' \
  build -quiet

DERIVED_APP="/Users/umut/Library/Developer/Xcode/DerivedData/Untitled_Project-ghqrescnryenmpdwqhsuzxszaquj/Build/Products/Release/Untitled Project.app"

if [ -d "$DERIVED_APP" ]; then
    echo "📲 Updating $TARGET_DIR/$APP_NAME.app..."
    pkill -x "$APP_NAME" 2>/dev/null || true
    rm -rf "$TARGET_DIR/$APP_NAME.app"
    cp -R "$DERIVED_APP" "$TARGET_DIR/$APP_NAME.app"
    echo "✅ Done! Your installed $APP_NAME.app in /Applications has been updated with your latest changes."
    echo "💡 Launch it anytime with: open /Applications/Somnius.app"
else
    echo "❌ Build output not found."
    exit 1
fi
