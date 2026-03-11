#!/bin/bash
set -e

# DeepFocus DMG Builder + GitHub Release Publisher
#
# Usage:
#   ./create_dmg.sh           — build DMG and publish a GitHub release
#   ./create_dmg.sh --no-release — build + Drop Box copy only, skip GitHub

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_FILE="$PROJECT_DIR/DeepFocus.xcodeproj"
SCHEME="DeepFocus"
BUILD_DIR="$PROJECT_DIR/build"
DMG_OUTPUT="$PROJECT_DIR"
CHANGELOG="$PROJECT_DIR/CHANGELOG.md"
PUBLISH_RELEASE=true

for arg in "$@"; do
  case $arg in
    --no-release) PUBLISH_RELEASE=false ;;
  esac
done

# ── Read version from CHANGELOG ───────────────────────────────────────────────
VERSION=$(grep -m1 '## \[' "$CHANGELOG" | sed 's/## \[\(.*\)\].*/\1/')
TAG="v${VERSION}"

# Extract release notes for this version (between its heading and the next)
RELEASE_NOTES=$(awk "/^## \[${VERSION}\]/{found=1; next} found && /^## \[/{exit} found{print}" "$CHANGELOG" | sed '/^[[:space:]]*$/d' | head -60)

echo "===================================================================="
echo "  DeepFocus DMG Builder"
echo "===================================================================="
echo ""
echo "Project: $PROJECT_FILE"
echo "Scheme:  $SCHEME"
echo "Version: $VERSION  →  tag $TAG"
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
DMG_NAME="DeepFocus-${VERSION}.dmg"
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

# ── GitHub Release ─────────────────────────────────────────────────────────────
if [ "$PUBLISH_RELEASE" = true ]; then
    echo "===================================================================="
    echo "  Publishing GitHub Release $TAG"
    echo "===================================================================="
    echo ""

    cd "$PROJECT_DIR"

    # Tag the current commit (skip if tag already exists)
    if git rev-parse "$TAG" >/dev/null 2>&1; then
        echo "⚠️  Tag $TAG already exists — skipping tag creation"
    else
        git tag -a "$TAG" -m "Release $TAG"
        echo "🏷️  Created tag $TAG"
    fi

    # Push tag to origin
    git push origin "$TAG"
    echo "🚀 Pushed tag to origin"
    echo ""

    # Create (or update) the GitHub release and upload the DMG
    if gh release view "$TAG" >/dev/null 2>&1; then
        echo "ℹ️  Release $TAG already exists — uploading DMG as updated asset"
        gh release upload "$TAG" "$DMG_PATH" --clobber
    else
        gh release create "$TAG" "$DMG_PATH" \
            --title "DeepFocus $TAG" \
            --notes "$RELEASE_NOTES" \
            --repo tiny-dev-industries/deepfocus
        echo "✅ GitHub Release published: https://github.com/tiny-dev-industries/deepfocus/releases/tag/$TAG"
    fi
    echo ""
fi

echo "===================================================================="
