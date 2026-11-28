#!/bin/bash
set -e

# ==============================================================================
# TidyMac Universal Release & DMG Packaging Pipeline
# Features:
#   - Universal Binary (arm64 + x86_64) compilation via SwiftPM + lipo
#   - Bundles Info.plist, AppIcon.icns, and PrivacyInfo.xcprivacy
#   - Hardened Runtime Code-Signing with TidyMac.entitlements
#   - Supports Developer ID Application certificate signing
#   - Automated Notarization via xcrun notarytool (when credentials provided)
#   - Automated Ticket Stapling via xcrun stapler
#   - DMG generation via create-dmg or native hdiutil
# ==============================================================================

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

APP_NAME="TidyMac"
BUILD_DIR="$PROJECT_DIR/build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
DMG_OUTPUT="$BUILD_DIR/$APP_NAME.dmg"
STAGING_DIR="$BUILD_DIR/dmg_staging"
ENTITLEMENTS="$PROJECT_DIR/TidyMac/Resources/TidyMac.entitlements"
APP_ICON="$PROJECT_DIR/TidyMac/Resources/AppIcon.icns"

SIGNING_IDENTITY="${DEVELOPER_ID_APPLICATION:-${SIGNING_IDENTITY:-"-"}}"

echo "========================================================"
echo "  🚀 Starting $APP_NAME Universal Release Pipeline"
echo "========================================================"
echo "  Target:        Universal Binary (arm64 + x86_64)"
echo "  Signing ID:    $SIGNING_IDENTITY"
echo "  Entitlements:  $ENTITLEMENTS"
echo "========================================================"

mkdir -p "$BUILD_DIR"

# ------------------------------------------------------------------------------
# Step 1: Compile Universal Binary (arm64 and x86_64)
# ------------------------------------------------------------------------------
echo "📦 Step 1: Compiling Release binaries for Apple Silicon & Intel..."

echo "  Compiling for arm64..."
swift build -c release --triple arm64-apple-macosx
ARM64_BIN="$PROJECT_DIR/.build/arm64-apple-macosx/release/$APP_NAME"

echo "  Compiling for x86_64..."
swift build -c release --triple x86_64-apple-macosx
X86_BIN="$PROJECT_DIR/.build/x86_64-apple-macosx/release/$APP_NAME"

if [ ! -f "$ARM64_BIN" ] || [ ! -f "$X86_BIN" ]; then
    echo "❌ Error: Could not compile both architecture slices."
    exit 1
fi

UNIVERSAL_BIN="$BUILD_DIR/$APP_NAME-universal"
echo "  Merging slices into Universal Binary using lipo..."
lipo -create -output "$UNIVERSAL_BIN" "$ARM64_BIN" "$X86_BIN"
echo "  Universal Binary verified:"
lipo -info "$UNIVERSAL_BIN"

# ------------------------------------------------------------------------------
# Step 2: Ensure App Icon Exists
# ------------------------------------------------------------------------------
if [ ! -f "$APP_ICON" ]; then
    echo "🎨 Generating AppIcon.icns..."
    swift "$PROJECT_DIR/scripts/generate_app_icon.swift"
fi

# ------------------------------------------------------------------------------
# Step 3: Assemble macOS Application Bundle
# ------------------------------------------------------------------------------
echo "📂 Step 2: Assembling $APP_BUNDLE..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$UNIVERSAL_BIN" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
chmod +x "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

if [ -f "$PROJECT_DIR/TidyMac/Resources/Info.plist" ]; then
    cp "$PROJECT_DIR/TidyMac/Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
fi

if [ -f "$APP_ICON" ]; then
    cp "$APP_ICON" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
fi

if [ -f "$PROJECT_DIR/TidyMac/Resources/BrandIcon.png" ]; then
    cp "$PROJECT_DIR/TidyMac/Resources/BrandIcon.png" "$APP_BUNDLE/Contents/Resources/BrandIcon.png"
fi

if [ -f "$PROJECT_DIR/TidyMac/Resources/PrivacyInfo.xcprivacy" ]; then
    cp "$PROJECT_DIR/TidyMac/Resources/PrivacyInfo.xcprivacy" "$APP_BUNDLE/Contents/Resources/PrivacyInfo.xcprivacy"
fi

# ------------------------------------------------------------------------------
# Step 4: Code Signing (Hardened Runtime + Entitlements)
# ------------------------------------------------------------------------------
echo "🔏 Step 3: Signing $APP_NAME.app with Hardened Runtime..."

if [ "$SIGNING_IDENTITY" != "-" ]; then
    echo "  Signing using Developer ID identity: $SIGNING_IDENTITY"
    codesign --force --options runtime --deep --timestamp \
        --entitlements "$ENTITLEMENTS" \
        --sign "$SIGNING_IDENTITY" \
        "$APP_BUNDLE"
else
    echo "⚠️  No Developer ID specified. Falling back to local ad-hoc signature."
    echo "    NOTE: Ad-hoc builds run locally but will trigger Gatekeeper warnings on other Macs."
    codesign --force --deep --sign - "$APP_BUNDLE"
fi

codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"
echo "  Bundle signature valid."

# ------------------------------------------------------------------------------
# Step 5: Prepare DMG Staging Directory
# ------------------------------------------------------------------------------
echo "📁 Step 4: Staging DMG distribution contents..."
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"

cp -R "$APP_BUNDLE" "$STAGING_DIR/"

if [ -f "$APP_ICON" ]; then
    cp "$APP_ICON" "$STAGING_DIR/.VolumeIcon.icns"
    if command -v SetFile &>/dev/null; then
        SetFile -a C "$STAGING_DIR" 2>/dev/null || true
    fi
fi

# ------------------------------------------------------------------------------
# Step 6: Build Disk Image (DMG)
# ------------------------------------------------------------------------------
rm -f "$DMG_OUTPUT"

if command -v create-dmg &>/dev/null; then
    echo "📀 Step 5: Building styled DMG with 'create-dmg'..."
    VOLICON_ARGS=()
    if [ -f "$APP_ICON" ]; then
        VOLICON_ARGS=(--volicon "$APP_ICON")
    fi
    create-dmg \
        --volname "$APP_NAME" \
        "${VOLICON_ARGS[@]}" \
        --window-pos 200 120 \
        --window-size 600 400 \
        --icon-size 100 \
        --icon "$APP_NAME.app" 160 190 \
        --hide-extension "$APP_NAME.app" \
        --app-drop-link 440 190 \
        "$DMG_OUTPUT" \
        "$STAGING_DIR" || {
            echo "⚠️  create-dmg encountered an issue, falling back to hdiutil..."
            rm -f "$DMG_OUTPUT"
            ln -sfn /Applications "$STAGING_DIR/Applications"
            hdiutil create -volname "$APP_NAME" -srcfolder "$STAGING_DIR" -ov -format UDZO "$DMG_OUTPUT"
        }
else
    echo "📀 Step 5: Building compressed DMG using native macOS 'hdiutil'..."
    ln -sfn /Applications "$STAGING_DIR/Applications"
    hdiutil create \
        -volname "$APP_NAME" \
        -srcfolder "$STAGING_DIR" \
        -ov \
        -format UDZO \
        "$DMG_OUTPUT"
fi

rm -rf "$STAGING_DIR"

# ------------------------------------------------------------------------------
# Step 7: Sign DMG & Notarize (if Developer ID provided)
# ------------------------------------------------------------------------------
if [ "$SIGNING_IDENTITY" != "-" ]; then
    echo "🔏 Step 6: Code-signing DMG image..."
    codesign --force --sign "$SIGNING_IDENTITY" --timestamp "$DMG_OUTPUT"
    
    if [ -n "$NOTARY_KEYCHAIN_PROFILE" ]; then
        echo "☁️  Step 7: Submitting DMG to Apple Notarization Service (notarytool)..."
        xcrun notarytool submit "$DMG_OUTPUT" --keychain-profile "$NOTARY_KEYCHAIN_PROFILE" --wait
        
        echo "📎 Stapling notarization ticket to DMG..."
        xcrun stapler staple "$DMG_OUTPUT"
        
        echo "🛡️  Gatekeeper Verification:"
        spctl --assess --type open --context context:primary-signature -v "$DMG_OUTPUT"
    else
        echo "ℹ️  Tip: Set NOTARY_KEYCHAIN_PROFILE to automate Apple notarytool submission & stapling."
    fi
fi

echo "========================================================"
echo "  ✅ SUCCESS: Universal $APP_NAME DMG Ready!"
echo "========================================================"
echo "  Location: $DMG_OUTPUT"
echo "  Size:     $(du -h "$DMG_OUTPUT" | cut -f1)"
echo "  SHA-256:  $(shasum -a 256 "$DMG_OUTPUT" | cut -d' ' -f1)"
echo "========================================================"
