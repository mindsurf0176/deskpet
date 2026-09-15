#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' Resources/Info.plist)
OUT="$PWD/dist/$VERSION"
APP="$OUT/DeskPet.app"
DMG="$OUT/DeskPet-$VERSION.dmg"
VOLUME_NAME="DeskPet $VERSION"

xcrun stapler validate "$APP"

# dmgbuild writes the window layout straight into the disk image. Finder's
# AppleScript view settings silently drop the background on current macOS.
TOOLS="$PWD/.build/dmgtools"
if [[ ! -x "$TOOLS/bin/dmgbuild" ]]; then
  /usr/bin/python3 -m venv "$TOOLS"
  "$TOOLS/bin/pip" install --quiet --disable-pip-version-check dmgbuild
fi

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
BACKGROUND="$WORK/background.tiff"
swift scripts/make-dmg-background.swift "$BACKGROUND"

DESKPET_APP="$APP" \
DESKPET_VOLUME_ICON="$APP/Contents/Resources/AppIcon.icns" \
DESKPET_BACKGROUND="$BACKGROUND" \
  "$TOOLS/bin/dmgbuild" -s scripts/dmg-settings.py "$VOLUME_NAME" "$DMG"

if [[ -n "${SIGNING_IDENTITY:-}" ]]; then
  codesign --force --timestamp --sign "$SIGNING_IDENTITY" "$DMG"
  codesign --verify --strict --verbose=2 "$DMG"
  if [[ -n "${NOTARY_PROFILE:-}" ]]; then
    xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$DMG"
    xcrun stapler validate "$DMG"
    spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG"
  else
    echo "deskpet: disk image signed but NOT notarized." >&2
  fi
else
  echo "deskpet: disk image is unsigned. Set SIGNING_IDENTITY before publishing." >&2
fi

NAME=$(basename "$DMG")
SUMS="$OUT/SHA256SUMS"
if [[ -f "$SUMS" ]]; then
  grep -v " $NAME$" "$SUMS" > "$WORK/sums" || true
  mv "$WORK/sums" "$SUMS"
fi
(cd "$OUT" && shasum -a 256 "$NAME" >> SHA256SUMS)
echo "$DMG"
