#!/bin/sh
set -e
BIN="$1"
APP="$2"
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
if [ -z "$BIN" ] || [ -z "$APP" ]; then
  echo "usage: make-app.sh <deskpet-binary> <DeskPet.app>" >&2
  exit 2
fi
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/deskpet"
chmod +x "$APP/Contents/MacOS/deskpet"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
if ! swift "$ROOT/scripts/make-icns.swift" "$APP/Contents/Resources/AppIcon.icns"; then
  echo "deskpet: AppIcon.icns skipped" >&2
fi

