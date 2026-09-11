# DeskPet

Always-on macOS overlay pet that reacts to OpenCode, Codex, Orca, and other agent terminals.

Drag it. Click to wave. It walks when idle, jumps when work starts, waits on permission prompts, and slumps on errors.

macOS 13+. No bundled sprites — drop a [Codex hatch-pet](docs/pets.md) into `~/.codex/pets/`.

한국어 안내: [아래](#한국어).

## Install

```bash
git clone https://github.com/mindsurf0176/deskpet.git
cd deskpet
make install
```

Needs Swift 5.9+ (`xcode-select --install`). This builds a release binary into `~/.local/bin/deskpet`, copies the OpenCode plugin, and registers a Login Item (`ai.deskpet`).

Restart OpenCode after install so the plugin loads.

```bash
make stop       # quit
make uninstall  # quit + remove LaunchAgent, binary, plugin
```

Settings live in the menu bar paw. Pick a pet and scale (0.35–1.5). Position persists in `~/.codex/pets/deskpet-config.json`.

## How it notices work

1. **OpenCode plugin** — `plugin/deskpet.ts` writes `~/.codex/pets/deskpet-state.json` (`running` / `waiting` / `failed` / `review`).
2. **Orca** — reads `~/Library/Application Support/orca/agent-hooks/last-status.json` (internal terminals included).
3. **Process fallback** — libproc CPU on `opencode` / `codex` / `claude` / `gemini` CLIs and the OpenCode Helper Renderer. Ignores `codex app-server` and `codex-code-mode-host`.

Priority: waiting > running > failed > review > process.

## Pets

Put packages here:

```text
~/.codex/pets/<id>/pet.json
~/.codex/pets/<id>/spritesheet.webp
```

Atlas contract: 1536×1872 WebP, 8×9 grid, 192×208 cells. Full layout in [docs/pets.md](docs/pets.md).

Override the selected pet with `DESKPET_ID=<id>`.

## License

MIT. Pet artwork belongs to whoever created it — this repo does not include any.

---

## 한국어

OpenCode·Codex·Orca 작업 상태에 맞춰 움직이는 macOS 상시 오버레이 펫.

```bash
git clone https://github.com/mindsurf0176/deskpet.git
cd deskpet
make install
```

메뉴바 발바닥 아이콘 → 설정에서 크기와 펫을 바꿉니다. 스프라이트는 포함하지 않습니다. Codex `/pets` 또는 hatch-pet으로 `~/.codex/pets/<이름>/`에 두면 됩니다.

OpenCode 플러그인은 앱 재시작 후 적용됩니다.
