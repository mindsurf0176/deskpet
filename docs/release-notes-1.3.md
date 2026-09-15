# DeskPet 1.3

A macOS menu bar pet that reacts to coding agents, with window sitting, climbing, completion
captions, and click-to-focus for Orca and terminal sessions.

## Install

Open `DeskPet-1.3.dmg`, drag DeskPet onto Applications, and open it. Choose **Add a Pet** and pick
a folder holding `pet.json` and `spritesheet.webp`. Artwork is not bundled; see [pet format](docs/pets.md).
Requires macOS 13 or later.

## Changes since 1.1

- Add a pet from inside the app. The first launch walks you through it, and settings keep a **+** button.
- **Open at Login** in settings replaces the LaunchAgent that earlier source installs created. Installing over an older copy retires that agent.
- `make install` now installs to /Applications, so DeskPet sits with your other apps.
- The disk image opens on a laid-out installer window.
- Native Orca chats are located by provider session identity, and their workspace is activated before the tab is selected.

## Verification

The app and the disk image are both signed with Developer ID, notarized by Apple, and stapled.
The binary is universal for Apple Silicon and Intel; Intel has not been exercised at runtime.
Agent hooks for Codex and OpenCode still require the source install described in the README.
