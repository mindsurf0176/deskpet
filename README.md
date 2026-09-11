# DeskPet

Always-on macOS overlay pet that reacts to OpenCode, Codex, Orca, and other agent terminals.

Drag it. Click to wave. It walks when idle, jumps when work starts, waits on permission prompts, and slumps on errors.
When "Sit on windows" is on, it perches on title bars, climbs window sides, and walks off the edge to fall.

macOS 13+. No bundled sprites — drop a [Codex hatch-pet](docs/pets.md) into `~/.codex/pets/`.

한국어 안내: [아래](#한국어).

## Install

```bash
git clone https://github.com/mindsurf0176/deskpet.git
cd deskpet
make install
```

Needs Swift 5.9+ (`xcode-select --install`). This builds `~/Applications/DeskPet.app`, symlinks `~/.local/bin/deskpet`, copies the OpenCode plugin, and registers a Login Item (`ai.deskpet`).

Restart OpenCode after install so the plugin loads.

Codex: `make install` also registers `~/.codex/pets/codex-hook.py` in `~/.codex/hooks.json`. Trust it once with `/hooks` so the pet can see this session. Existing Orca/impeccable hooks stay in place.

```bash
make stop       # quit
make uninstall  # quit + remove LaunchAgent, binary, plugin
```

Settings live in the menu bar paw. Pick a pet, scale, click-through, captions, window sitting, and alert sound. Waiting changes the menu bar icon; click the pet to jump to the waiting Orca pane or Ghostty/Terminal/iTerm window. Position persists in `~/.codex/pets/deskpet-config.json`.

## How it notices work

1. **OpenCode plugin** — `plugin/deskpet.ts` writes `~/.codex/pets/deskpet-state.json` (`running` / `waiting` / `failed` / `review`).
2. **Codex hook** — `plugin/codex-hook.py` writes the same state file from PreToolUse / PermissionRequest / Stop and related events.
3. **Orca** — reads `~/Library/Application Support/orca/agent-hooks/last-status.json` (internal terminals included).
4. **Process fallback** — libproc CPU on `opencode` / `codex` / `claude` / `gemini` CLIs and the OpenCode Helper Renderer. Ignores `codex app-server` and `codex-code-mode-host`.

Priority: waiting > running > failed > review > process. Empty pixels click through by default; waiting hops and shows a caption so permission prompts are hard to miss.
A finished turn still chimes even if another agent is still running.
Finished turns also post a Notification Center banner, so it still lands if Orca is in front.

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
창에 앉기는 설정에서 켤 수 있습니다. 타이틀바와 창 옆면을 오르고, 끝에 닿으면 돌아섭니다. 승인 대기 중 펫을 클릭하면 Orca 칸 또는 Ghostty/Terminal 창으로 점프합니다.

OpenCode 플러그인은 앱 재시작 후 적용됩니다.
Codex 훅은 설치 후 `/hooks`에서 한 번 신뢰해야 이 세션이 펫을 움직입니다.
