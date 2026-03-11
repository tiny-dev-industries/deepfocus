#!/bin/bash
set -e

# DeepFocus DMG Builder
# This script builds a release version of DeepFocus and creates a .dmg installer.

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_FILE="$PROJECT_DIR/DeepFocus.xcodeproj"
SCHEME="DeepFocus"
BUILD_DIR="$PROJECT_DIR/build"
DMG_OUTPUT="$PROJECT_DIR"

echo "===================================================================="
echo "  DeepFocus DMG Builder"
echo "===================================================================="
echo ""
echo "Project: $PROJECT_FILE"
echo "Scheme: $SCHEME"
echo ""

# Set Xcode developer directory
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer

# Clean previous builds
echo "Cleaning previous builds..."
rm -rf "$BUILD_DIR"
xcodebuild clean \
  -project "$PROJECT_FILE" \
  -scheme "$SCHEME" \
  -configuration Release \
  > /dev/null 2>&1

# Build the app for Release
echo "Building DeepFocus (Release configuration)..."
xcodebuild build \
  -project "$PROJECT_FILE" \
  -scheme "$SCHEME" \
  -configuration Release \
  -derivedDataPath "$BUILD_DIR" \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGN_STYLE=Manual \
  | xcbeautify 2>/dev/null || cat

APP_PATH="$BUILD_DIR/Build/Products/Release/DeepFocus.app"

if [ ! -d "$APP_PATH" ]; then
    echo "❌ Build failed: DeepFocus.app not found at $APP_PATH"
    exit 1
fi

echo ""
echo "✅ Build succeeded: $APP_PATH"
echo ""

# Create DMG
DMG_NAME="DeepFocus-$(date +%Y%m%d).dmg"
DMG_PATH="$DMG_OUTPUT/$DMG_NAME"

echo "Creating DMG installer..."
hdiutil create \
  -volname "DeepFocus" \
  -srcfolder "$APP_PATH" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

echo ""
echo "===================================================================="
echo "✅ DMG created successfully!"
echo "===================================================================="
echo ""
echo "📦 $DMG_PATH"
echo ""

# Copy to shared Drop Box for network access
DROP_BOX="$HOME/Public/Drop Box"
if [ -d "$DROP_BOX" ]; then
    cp "$DMG_PATH" "$DROP_BOX/$DMG_NAME"
    echo "📬 Copied to: $DROP_BOX/$DMG_NAME"
else
    echo "⚠️  Drop Box not found at: $DROP_BOX"
fi
echo ""
echo "===================================================================="
