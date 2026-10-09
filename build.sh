#!/bin/bash
# Builds build/toneoff.app (ad-hoc signed, runs only on this Mac's architecture).
set -euo pipefail
cd "$(dirname "$0")"

APP="build/toneoff.app"
rm -rf build
mkdir -p "$APP/Contents/MacOS"

swiftc -O -swift-version 5 -o "$APP/Contents/MacOS/toneoff" Sources/*.swift
cp Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"

echo "Built: $PWD/$APP"
