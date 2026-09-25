# Act I, 1.3 The Harvester in the Open: asset brief

The Atreides trooper is **not** a separate character: it is the prologue's `atreides_drill_soldier` (see `docs/art/asset_backlog.md`). The full, prioritised list of what the game still needs is in that backlog, and `docs/art/priority1_brief.md` supersedes this brief with exact canvases and anchors.

New art for 1.3. Follow the prologue brief (`docs/art/tutorial_assets_brief.md`) for style, format and delivery. The unit sprites follow its sprite section (the same sheet layout and facings as `paul`, `fremen_scout`, `fremen_warrior`), the illustration its section 3.

## Standing rules

- No likeness of any actor from any film or series.
- No text or lettering in any image.
- Everything must read at the squad view's isometric scale, against pale orange sand.

## Units: `assets/characters/<name>/`

| Name | Who | Look |
|---|---|---|
| `harvester_crew` | Spice crawler hands (eight men, one sheet with tint variants) | Heavy tan-ochre work coveralls, stained dark at the knees; a hood or cap; dust masks around the neck; tool belts. Ordinary workers, not soldiers: no weapons. Poses: idle, walk, run (panicked, arms loose), an injured limp (one arm bandaged in white), and carried over a shoulder (the injured man is carried out). |
| `gurney` (squad sprite) | Gurney Halleck in the field | Matches his portrait: a solid, scarred veteran, a green-and-brown field coat, a baliset slung on his back, a short rifle. Idle, walk, crouch, aim, fire. |

## Set pieces: `assets/environment/squad/`, RGBA PNG, drawn for the isometric view (2:1)

| File | What |
|---|---|
| `harvester_iso.png` | The spice crawler seen from the squad camera: a huge tracked machine, rust-and-sand coloured, its intake scoop at the front, a tall exhaust stack, catwalks and ladders on its flanks. About 760 × 320 world units of footprint; roughly 1100 × 800 px. A second frame with it half swallowed (tilted, sand pouring over it) for after the worm. |
| `ornithopter_iso.png` | An Atreides ornithopter parked on rock: a long, narrow fuselage with a glazed cockpit, four long articulated wings folded back, landing skids. Muted green-grey with the hawk crest. About 320 px long. |
| `thumper_iso.png` | A Fremen thumper: a spring-loaded metal stake planted in sand, about a man's knee high; two frames (up and striking). |

## Illustration: `assets/ui/story/`, RGB PNG, 1920 × 1080

| File | What |
|---|---|
| `card_harvester.png` | The title card: seen from an ornithopter's open door, a spice crawler alone on endless open sand under a white-hot sky, dust streaming from it; far off, a long ripple in the dunes heading its way. |
