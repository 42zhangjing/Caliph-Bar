#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

./build-app.sh
DEST="/Applications/CaliphBar.app"
if [ -w "/Applications" ]; then
  rm -rf "$DEST"
  cp -R "CaliphBar.app" "$DEST"
else
  mkdir -p "$HOME/Applications"
  DEST="$HOME/Applications/CaliphBar.app"
  rm -rf "$DEST"
  cp -R "CaliphBar.app" "$DEST"
fi
open "$DEST"
echo "Installed to $DEST"
