#!/bin/bash
set -e

# ==============================================================================
# Somnius Release & Sparkle Update Generator
# Usage: ./scripts/build_release.sh [version, e.g. 1.0.1]
# ==============================================================================

VERSION="${1:-1.0.1}"
APP_NAME="Somnius"
SCHEME="Untitled Project"
BUILD_DIR="$(pwd)/build_output"
ARCHIVE_PATH="$BUILD_DIR/$APP_NAME.xcarchive"
APP_PATH="$BUILD_DIR/$APP_NAME.app"
DMG_PATH="$BUILD_DIR/$APP_NAME-$VERSION.dmg"

# ==============================================================================
# MANDATORY PRE-FLIGHT: Auto-Update System Integrity Check
# Never allow a build or release to proceed without the update system intact!
# ==============================================================================
echo "🔍 Verifying Auto-Update system integrity..."
if ! grep -q "remoteGatekeeper.showUpdateModal" "Untitled Project/ui/ContentView.swift"; then
    echo "❌ FATAL: Auto-update modal overlay missing from ContentView.swift!"
    exit 1
fi
if ! grep -q "remoteGatekeeper.checkStatus" "Untitled Project/ui/ContentView.swift"; then
    echo "❌ FATAL: Auto-update checkStatus call missing from ContentView.swift onAppear!"
    exit 1
fi
if ! grep -q "checkStatus" "Untitled Project/core/RemoteGatekeeper.swift"; then
    echo "❌ FATAL: checkStatus missing from RemoteGatekeeper.swift!"
    exit 1
fi
echo "✅ Auto-Update system verified intact."

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
  CURRENT_PROJECT_VERSION="2" \
  MACOSX_DEPLOYMENT_TARGET="12.0" \
  -quiet

# 2. Export .app
echo "📂 Extracting $APP_NAME.app..."
rm -rf "$APP_PATH"
if [ -d "$ARCHIVE_PATH/Products/Applications/Somnius.app" ]; then
    ditto "$ARCHIVE_PATH/Products/Applications/Somnius.app" "$APP_PATH"
elif [ -d "$ARCHIVE_PATH/Products/Applications/Untitled Project.app" ]; then
    ditto "$ARCHIVE_PATH/Products/Applications/Untitled Project.app" "$APP_PATH"
else
    FOUND_APP=$(find "$ARCHIVE_PATH/Products/Applications" -maxdepth 1 -name "*.app" | head -n 1)
    ditto "$FOUND_APP" "$APP_PATH"
fi

# Explicitly guarantee macOS Menu Bar reads Somnius and minimum OS version is 12.0 (supports Monterey 12, Ventura 13, Sonoma 14, Sequoia 15, Tahoe 26.x, and 27+)
plutil -replace CFBundleName -string "Somnius" "$APP_PATH/Contents/Info.plist"
plutil -replace CFBundleDisplayName -string "Somnius" "$APP_PATH/Contents/Info.plist"
plutil -replace CFBundleIdentifier -string "com.beratheon.Somnius" "$APP_PATH/Contents/Info.plist"
plutil -replace LSMinimumSystemVersion -string "12.0" "$APP_PATH/Contents/Info.plist"

python3 - "$APP_PATH" <<'PYEOF'
import os, sys, plistlib, subprocess

app_path = sys.argv[1]
main_bin = os.path.join(app_path, "Contents/MacOS/Somnius")
if os.path.exists(main_bin):
    with open(main_bin, "rb") as bf:
        bdata = bf.read()
    old_sym = b"\x00__swiftImmortalRefCount\x00"
    new_sym = b"\x00_swiftEmptyArrayStorage\x00"
    if old_sym in bdata:
        bdata = bdata.replace(old_sym, new_sym)
        with open(main_bin, "wb") as bf:
            bf.write(bdata)

for root, _, files in os.walk(app_path):
    for f in files:
        full_path = os.path.join(root, f)
        if os.path.islink(full_path):
            continue
        if f == "Info.plist":
            try:
                with open(full_path, "rb") as pf:
                    data = plistlib.load(pf)
                changed = False
                for key, val in [("LSMinimumSystemVersion", "12.0"), ("MinimumOSVersion", "12.0"), ("DTPlatformVersion", "12.0"), ("DTSDKName", "macosx12.0")]:
                    if key in data:
                        data[key] = val
                        changed = True
                if full_path.endswith("Somnius.app/Contents/Info.plist"):
                    data["LSMinimumSystemVersion"] = "12.0"
                    data["CFBundleSupportedPlatforms"] = ["MacOSX"]
                    changed = True
                if changed:
                    with open(full_path, "wb") as pf:
                        plistlib.dump(data, pf)
            except Exception:
                pass
        elif os.access(full_path, os.X_OK):
            try:
                ft = subprocess.check_output(["file", full_path]).decode()
                if "Mach-O" in ft:
                    vt = subprocess.check_output(["vtool", "-show-build", full_path], stderr=subprocess.DEVNULL).decode()
                    if "LC_BUILD_VERSION" in vt:
                        subprocess.run([
                            "vtool", "-set-build-version", "macos", "12.0", "14.0",
                            "-tool", "ld", "27037.1", "-replace", "-output", full_path, full_path
                        ], capture_output=True)
            except Exception:
                pass
PYEOF

echo "🔏 Re-signing $APP_NAME.app and embedded frameworks for macOS 12.0+ compatibility..."
if [ -d "$APP_PATH/Contents/Frameworks/Sparkle.framework" ]; then
    find "$APP_PATH/Contents/Frameworks/Sparkle.framework" -depth \( -name "*.xpc" -o -name "*.app" -o -name "Autoupdate" \) | while read -r item; do
        if [ ! -L "$item" ]; then
            codesign --force --sign - --timestamp=none "$item"
        fi
    done
fi
for fw in "$APP_PATH/Contents/Frameworks/"*.framework; do
    codesign --force --sign - --timestamp=none "$fw"
done
codesign --force --sign - --timestamp=none "$APP_PATH"
codesign --verify --deep --strict "$APP_PATH"

# 3. Create Custom Styled DMG installer
echo "💿 Generating DMG artwork and staging installer..."
swift "$(pwd)/scripts/generate_dmg_background.swift" "$BUILD_DIR/dmg_background.png"

DMG_STAGING="$BUILD_DIR/dmg_staging"
rm -rf "$DMG_STAGING"
mkdir -p "$DMG_STAGING/.background"
ditto "$APP_PATH" "$DMG_STAGING/$APP_NAME.app"
ln -s /Applications "$DMG_STAGING/Applications"
cp "$BUILD_DIR/dmg_background.png" "$DMG_STAGING/.background/background.png"

echo "💿 Packaging into $DMG_PATH..."
rm -f "$DMG_PATH" "$BUILD_DIR/temp.dmg"

# Create temporary writeable DMG
hdiutil create -srcfolder "$DMG_STAGING" -volname "$APP_NAME" -fs HFS+ -fsargs "-c c=64,a=16,e=16" -format UDRW -size 700m "$BUILD_DIR/temp.dmg" -quiet

# Unmount any stale volume to avoid mount collision
diskutil unmount force "/Volumes/$APP_NAME" 2>/dev/null || true

# Mount writeable DMG
DEVICE=$(hdiutil attach -readwrite -noverify -noautoopen "$BUILD_DIR/temp.dmg" | awk 'NR==1{print $1}')
sleep 1

# Configure Finder visual presentation via AppleScript
osascript <<APPLESCRIPT || true
tell application "Finder"
    tell disk "$APP_NAME"
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
            set background picture of viewOptions to POSIX file ("/Volumes/$APP_NAME/.background/background.png")
        end try
        delay 1
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
        delay 1
        update without registering applications
        delay 1
        close
    end tell
end tell
APPLESCRIPT

# Wait for Finder to flush .DS_Store
sleep 2
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

