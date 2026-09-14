#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
: "${SIGNING_IDENTITY:?Set SIGNING_IDENTITY to a Developer ID Application identity}"
VERSION=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' Resources/Info.plist)
OUT="$PWD/dist/$VERSION"
mkdir -p "$OUT"
swift build -c release --arch arm64 --arch x86_64
BIN_DIR=$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)
sh scripts/make-app.sh "$BIN_DIR/deskpet" "$OUT/DeskPet.app"
codesign --force --options runtime --timestamp --sign "$SIGNING_IDENTITY" "$OUT/DeskPet.app"
codesign --verify --deep --strict --verbose=2 "$OUT/DeskPet.app"
lipo "$OUT/DeskPet.app/Contents/MacOS/deskpet" -verify_arch arm64 x86_64
ZIP="$OUT/DeskPet-$VERSION-universal.zip"
ditto -c -k --sequesterRsrc --keepParent "$OUT/DeskPet.app" "$ZIP"
if [[ -n "${NOTARY_PROFILE:-}" ]]; then
  xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$OUT/DeskPet.app"
  xcrun stapler validate "$OUT/DeskPet.app"
  spctl --assess --type execute --verbose=2 "$OUT/DeskPet.app"
  ditto -c -k --sequesterRsrc --keepParent "$OUT/DeskPet.app" "$ZIP"
else
  echo 'Signed candidate only: notarization NOT performed. Do not publish as notarized.' >&2
fi
(cd "$OUT" && shasum -a 256 "$(basename "$ZIP")" > SHA256SUMS)
echo "$ZIP"
