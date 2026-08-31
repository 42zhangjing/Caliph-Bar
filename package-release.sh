#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

./build-app.sh

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' CaliphBar.app/Contents/Info.plist)"
OUTPUT_DIR="${1:-dist}"
ARCHIVE_NAME="CaliphBar-v${VERSION}-macOS-universal.zip"
ARCHIVE_PATH="$OUTPUT_DIR/$ARCHIVE_NAME"
CHECKSUM_PATH="$ARCHIVE_PATH.sha256"

mkdir -p "$OUTPUT_DIR"
rm -f "$ARCHIVE_PATH" "$CHECKSUM_PATH"

ditto -c -k --sequesterRsrc --keepParent CaliphBar.app "$ARCHIVE_PATH"
(
  cd "$OUTPUT_DIR"
  shasum -a 256 "$ARCHIVE_NAME" > "$ARCHIVE_NAME.sha256"
)

echo "Created $ARCHIVE_PATH"
echo "Created $CHECKSUM_PATH"
