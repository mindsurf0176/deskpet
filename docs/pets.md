# Pet format

DeskPet loads Codex hatch-pet packages from `~/.codex/pets/<id>/`.

Required files:

```text
~/.codex/pets/<id>/
  pet.json
  spritesheet.webp
```

## pet.json

```json
{
  "id": "my-pet",
  "displayName": "My Pet",
  "spritesheetPath": "spritesheet.webp",
  "kind": "person"
}
```

`kind` is unused at runtime. `id` should match the folder name.

## spritesheet.webp

| | |
| --- | --- |
| Size | 1536×1872 |
| Grid | 8 columns × 9 rows |
| Cell | 192×208 |
| Unused cells | fully transparent |

Animation rows (durations in ms):

| Row | State | Frames |
| --- | --- | --- |
| 0 | idle | 6 — 280, 110, 110, 140, 140, 320 |
| 1 | running-right | 8 — 120×7 + 220 |
| 2 | running-left | 8 — 120×7 + 220 |
| 3 | waving | 4 — 140×3 + 280 |
| 4 | jumping | 5 — 140×4 + 280 |
| 5 | failed | 8 — 140×7 + 240 |
| 6 | waiting | 6 — 150×5 + 260 |
| 7 | running (work) | 6 — 120×5 + 220 |
| 8 | review | 6 — 150×5 + 280 |

Create pets with Codex CLI `/pets` or the `hatch-pet` skill. DeskPet does not ship artwork.
