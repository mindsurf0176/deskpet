# Releasing DeskPet

Distribution target: GitHub Releases, macOS 13+, universal arm64/x86_64 ZIP.
The app requires a separately installed pet. No third-party artwork is bundled.

## Build and notarize

Increment CFBundleShortVersionString and CFBundleVersion in Resources/Info.plist for subsequent releases.
Use a Developer ID Application certificate and a notarytool Keychain profile:

```sh
SIGNING_IDENTITY='Developer ID Application: YOUR NAME (TEAMID)' \
NOTARY_PROFILE='your-profile' scripts/release.sh
```

The script builds both architectures, signs with hardened runtime and timestamp,
submits to Apple, staples and validates the ticket, checks Gatekeeper, and creates
`dist/<version>/DeskPet-<version>-universal.zip` with `SHA256SUMS`.
Without NOTARY_PROFILE it creates a signed candidate only, not a public release.
Never place credentials in this repository.

## Release gates

- Notarization accepted, staple validated, Gatekeeper assessment passed.
- Fresh user with no pets sees setup instructions; install a pet and reopen.
- Launch downloaded app on a Mac: menu/settings, drag, captions, window sitting.
- Verify waiting and completion notifications and click-to-focus across Orca workspaces.
- Check terminal fallback and operation without Orca installed.
- Intel build is included; Intel runtime validation must be reported separately.
- Inspect ZIP contents; include no personal pets, configuration, logs or credentials.
- Tag the tested commit and attach ZIP and SHA256SUMS to a GitHub draft release.
- Publish only after the gates above; record any limitations in release notes.

## Installation

Unzip, move DeskPet.app to Applications and open it. Add your pet as described in
[pets.md](pets.md). Add the app to macOS Login Items if automatic startup is desired.
The ZIP does not install agent hooks automatically. For full hook integration,
clone the matching source tag and run `make install` (requires Xcode command-line
tools and Python 3), then trust Codex hooks and restart OpenCode as in the README.

For app-only removal, quit and delete the app and remove its Login Item. For
source installation, run `make uninstall`. Pet artwork and configuration are retained.

## Disk image

After the notarized app is built, create the installer window:

```sh
SIGNING_IDENTITY='Developer ID Application: YOUR NAME (TEAMID)' \
NOTARY_PROFILE='your-profile' scripts/make-dmg.sh
```

`scripts/make-dmg-background.swift` renders the backdrop at 1x and 2x, and `dmgbuild` writes the
window bounds, icon size, and icon positions into the image. The script creates its own Python
environment under `.build/dmgtools` on first run. Finder's AppleScript view settings are not used
because current macOS drops the background picture without reporting an error.

The disk image is signed and notarized separately from the app it contains, then stapled and checked
with Gatekeeper. Verify the window visually after building: background, 128px icons, and the app
sitting left of the Applications shortcut. A Mac set to "Prefer tabs when opening documents: always"
opens the image as a Finder tab, which ignores the saved window size.
