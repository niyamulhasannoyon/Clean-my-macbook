#!/bin/bash
set -e

# ==============================================================================
# TidyMac DMG Packaging Script
# Supports: native macOS 'hdiutil' (default) and 'create-dmg' (if available)
# ==============================================================================

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

APP_NAME="TidyMac"
BUILD_DIR="$PROJECT_DIR/build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
DMG_OUTPUT="$BUILD_DIR/$APP_NAME.dmg"
STAGING_DIR="$BUILD_DIR/dmg_staging"

echo "========================================================"
echo "  🚀 Starting $APP_NAME DMG Creation Pipeline"
echo "========================================================"

# Step 1: Ensure Release Build is Up-to-Date
echo "📦 Step 1: Building Release binary (swift build -c release)..."
swift build -c release

RELEASE_BIN="$PROJECT_DIR/.build/arm64-apple-macosx/release/$APP_NAME"
if [ ! -f "$RELEASE_BIN" ]; then
    # Fallback check for x86_64 or universal if on Intel
    RELEASE_BIN=$(find "$PROJECT_DIR/.build" -type f -name "$APP_NAME" -path "*/release/*" | head -n 1)
fi

if [ -z "$RELEASE_BIN" ] || [ ! -f "$RELEASE_BIN" ]; then
    echo "❌ Error: Release binary could not be found."
    exit 1
fi
echo "  Found binary at: $RELEASE_BIN"

# Step 2: Ensure App Icon Exists
if [ ! -f "$PROJECT_DIR/AppIcon.icns" ]; then
    echo "🎨 Generating AppIcon.icns..."
    swift "$PROJECT_DIR/scripts/generate_app_icon.swift"
fi

# Step 3: Assemble macOS Application Bundle
echo "📂 Step 2: Assembling $APP_BUNDLE..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$RELEASE_BIN" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
chmod +x "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

if [ -f "$PROJECT_DIR/TidyMac/Resources/Info.plist" ]; then
    cp "$PROJECT_DIR/TidyMac/Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
fi

if [ -f "$PROJECT_DIR/AppIcon.icns" ]; then
    cp "$PROJECT_DIR/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
fi

# Ad-hoc code signing for local execution
echo "🔏 Step 3: Code-signing $APP_NAME.app with ad-hoc signature..."
codesign --force --deep --sign - "$APP_BUNDLE"
codesign --verify --deep "$APP_BUNDLE"

# Step 4: Prepare DMG Staging Directory
echo "📁 Step 4: Staging DMG contents..."
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"

cp -R "$APP_BUNDLE" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

# Include Volume Icon if available
if [ -f "$PROJECT_DIR/AppIcon.icns" ]; then
    cp "$PROJECT_DIR/AppIcon.icns" "$STAGING_DIR/.VolumeIcon.icns"
    if command -v SetFile &>/dev/null; then
        SetFile -a C "$STAGING_DIR" 2>/dev/null || true
    fi
fi

# Step 5: Build DMG (create-dmg vs native hdiutil)
rm -f "$DMG_OUTPUT"

if command -v create-dmg &>/dev/null; then
    echo "📀 Step 5: Building polished DMG with 'create-dmg'..."
    create-dmg \
        --volname "$APP_NAME" \
        --volicon "$PROJECT_DIR/AppIcon.icns" \
        --window-pos 200 120 \
        --window-size 600 400 \
        --icon-size 100 \
        --icon "$APP_NAME.app" 160 190 \
        --hide-extension "$APP_NAME.app" \
        --app-drop-link 440 190 \
        "$DMG_OUTPUT" \
        "$STAGING_DIR" || {
            echo "⚠️  create-dmg encountered an issue, falling back to hdiutil..."
            hdiutil create -volname "$APP_NAME" -srcfolder "$STAGING_DIR" -ov -format UDZO "$DMG_OUTPUT"
        }
else
    echo "📀 Step 5: Building compressed DMG using native macOS 'hdiutil'..."
    hdiutil create \
        -volname "$APP_NAME" \
        -srcfolder "$STAGING_DIR" \
        -ov \
        -format UDZO \
        "$DMG_OUTPUT"
fi

# Step 6: Cleanup Temporary Staging
rm -rf "$STAGING_DIR"

echo "========================================================"
echo "  ✅ SUCCESS: DMG Created Successfully!"
echo "========================================================"
echo "  Location: $DMG_OUTPUT"
echo "  Size:     $(du -h "$DMG_OUTPUT" | cut -f1)"
echo "  SHA-256:  $(shasum -a 256 "$DMG_OUTPUT" | cut -d' ' -f1)"
echo "========================================================"
echo "  To test opening the DMG:"
echo "    open \"$DMG_OUTPUT\""
echo "========================================================"
