#!/bin/bash
# Builds the app, copies it to ~/Applications and (re)launches it.
set -euo pipefail
cd "$(dirname "$0")"

./build.sh

DEST="$HOME/Applications"
mkdir -p "$DEST"
pkill -x Toneoff 2>/dev/null || true
rm -rf "$DEST/Toneoff.app"
cp -R "build/Toneoff.app" "$DEST/"
open "$DEST/Toneoff.app"

echo "Installed to $DEST/Toneoff.app"
echo "Tick \"Launch at Login\" in its menu bar menu to start it automatically."
