#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="CaliphBar"
BUNDLE_ID="dev.chengyu.caliphbar"
APP="$APP_NAME.app"
EDGE_SVG="Resources/Shapes/caliph-edge-tab.svg"
EDGE_SWIFT="Sources/CaliphBar/UI/SideNotchShape.swift"

if ! diff -u \
  <(sed -nE 's/^[[:space:]]*C ([0-9.]+) ([0-9.]+) ([0-9.]+) ([0-9.]+) ([0-9.]+) ([0-9.]+)/\1 \2 \3 \4 \5 \6/p' "$EDGE_SVG") \
  <(sed -nE 's/.*control1: \.init\(x: ([0-9.]+), y: ([0-9.]+)\), control2: \.init\(x: ([0-9.]+), y: ([0-9.]+)\), end: \.init\(x: ([0-9.]+), y: ([0-9.]+)\).*/\1 \2 \3 \4 \5 \6/p' "$EDGE_SWIFT")
then
  echo "Canonical edge-tab SVG and Swift path coordinates differ." >&2
  exit 1
fi

EDGE_SVG_STRAIGHT=$(sed -nE 's/^[[:space:]]*L (0) ([0-9.]+)$/\1 \2/p' "$EDGE_SVG")
EDGE_SWIFT_STRAIGHT=$(sed -nE 's/.*straightEdgeBottom = CGPoint\(x: ([0-9.]+), y: ([0-9.]+)\).*/\1 \2/p' "$EDGE_SWIFT")
if [ "$EDGE_SVG_STRAIGHT" != "$EDGE_SWIFT_STRAIGHT" ]; then
  echo "Canonical edge-tab straight edge coordinates differ." >&2
  exit 1
fi

echo "Building universal CaliphBar binary (arm64 + x86_64)…"
swift build -c release --triple arm64-apple-macosx
swift build -c release --triple x86_64-apple-macosx

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
lipo -create \
  ".build/arm64-apple-macosx/release/$APP_NAME" \
  ".build/x86_64-apple-macosx/release/$APP_NAME" \
  -output "$APP/Contents/MacOS/$APP_NAME"

if [ -d "Resources" ]; then
  cp -R Resources/* "$APP/Contents/Resources/"
fi

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundleDisplayName</key>
  <string>$APP_NAME</string>
  <key>CFBundleShortVersionString</key>
  <string>0.2.0</string>
  <key>CFBundleVersion</key>
  <string>2</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSUIElement</key>
  <true/>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>LSApplicationCategoryType</key>
  <string>public.app-category.developer-tools</string>
  <key>NSHumanReadableCopyright</key>
  <string>CaliphBar contributors. Not affiliated with Anthropic, OpenAI, or Google.</string>
</dict>
</plist>
PLIST

codesign --force --deep --sign - "$APP"
codesign --verify --deep --strict "$APP"
lipo -info "$APP/Contents/MacOS/$APP_NAME"

echo "Built $APP"
