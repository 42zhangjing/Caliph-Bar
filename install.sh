#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

./build-app.sh
DEST="/Applications/CaliphBar.app"
if [ -w "/Applications" ]; then
  DEST_DIR="/Applications"
else
  DEST_DIR="$HOME/Applications"
  mkdir -p "$DEST_DIR"
fi

DEST="$DEST_DIR/CaliphBar.app"
pkill -x CaliphBar 2>/dev/null || true

if [ -e "$DEST" ]; then
  STAMP="$(date '+%Y%m%d-%H%M%S')"
  BACKUP="$HOME/.Trash/CaliphBar-old-$STAMP.app"
  mv "$DEST" "$BACKUP"
  echo "Moved previous app to $BACKUP"
fi

cp -R "CaliphBar.app" "$DEST"
open "$DEST"
echo "Installed to $DEST"
