#!/bin/bash
# Builds BabySmash.app, a fully native, self-contained macOS application.
# Requires only the Swift toolchain / Command Line Tools (no full Xcode).
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"

APP_NAME="BabySmash"
DISPLAY_NAME="BabySmash!"
VERSION="1.0.0"
BUNDLE_ID="com.hanselman.babysmash"
ICON_SRC="Resources/babysmash.png"

DIST="$HERE/dist"
APP="$DIST/$APP_NAME.app"
CONTENTS="$APP/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

echo ">> Building release binary..."
swift build -c release >/dev/null
BIN="$(swift build -c release --show-bin-path)/$APP_NAME"

echo ">> Assembling $APP ..."
rm -rf "$APP"
mkdir -p "$MACOS" "$RESOURCES/Sounds"
cp "$BIN" "$MACOS/$APP_NAME"
cp Resources/Sounds/*.wav "$RESOURCES/Sounds/"
cp Resources/Words.txt "$RESOURCES/Words.txt"

# Build an .icns icon from the shared PNG (best effort).
ICON_KEY=""
if [[ -f "$ICON_SRC" ]]; then
  ICONSET="$DIST/AppIcon.iconset"
  rm -rf "$ICONSET"; mkdir -p "$ICONSET"
  for size in 16 32 64 128 256 512; do
    sips -z $size $size "$ICON_SRC" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null 2>&1 || true
    sips -z $((size*2)) $((size*2)) "$ICON_SRC" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null 2>&1 || true
  done
  if iconutil -c icns "$ICONSET" -o "$RESOURCES/AppIcon.icns" 2>/dev/null; then
    ICON_KEY="<key>CFBundleIconFile</key><string>AppIcon</string>"
  fi
  rm -rf "$ICONSET"
fi

cat > "$CONTENTS/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>$APP_NAME</string>
    <key>CFBundleDisplayName</key><string>$DISPLAY_NAME</string>
    <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
    <key>CFBundleExecutable</key><string>$APP_NAME</string>
    <key>CFBundleVersion</key><string>$VERSION</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
    <key>LSMinimumSystemVersion</key><string>12.0</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>LSApplicationCategoryType</key><string>public.app-category.education</string>
    <key>NSPrincipalClass</key><string>NSApplication</string>
    $ICON_KEY
</dict>
</plist>
PLIST

# Ad-hoc signature so the Accessibility permission has a stable identity.
codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || \
  echo "   (codesign skipped; app still runs)"

echo ">> Done: $APP"

# Build a standard drag-to-Applications .dmg installer.
DMG="$DIST/$APP_NAME-macOS-arm64.dmg"
STAGING="$DIST/dmg-staging"
echo ">> Building $DMG ..."
rm -rf "$STAGING" "$DMG"
mkdir -p "$STAGING"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"   # drag target
hdiutil create -volname "$DISPLAY_NAME" -srcfolder "$STAGING" \
  -fs HFS+ -format UDZO -ov "$DMG" >/dev/null
rm -rf "$STAGING"
echo ">> Done: $DMG"
