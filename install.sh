#!/bin/bash
# Builds the app, copies it to ~/Applications and (re)launches it.
set -euo pipefail
cd "$(dirname "$0")"

./build.sh

DEST="$HOME/Applications"
mkdir -p "$DEST"
pkill -x toneoff 2>/dev/null || true
rm -rf "$DEST/toneoff.app"
cp -R "build/toneoff.app" "$DEST/"
open "$DEST/toneoff.app"

echo "Installed to $DEST/toneoff.app"
echo "Tick \"Launch at Login\" in its menu bar menu to start it automatically."
