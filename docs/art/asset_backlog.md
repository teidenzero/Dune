# Asset backlog: what the game still needs

One list of every graphic asset still to make, in priority order. The formats, art direction, delivery rules and the three-attempt stop rule are in `docs/art/tutorial_assets_brief.md` (sections 1–2 and 9) and `docs/art/character_animation_prompt.md`; they apply to everything here. Designs follow the books, never a film or series: **no likeness of any actor**, no text or lettering in any image.

Status as of 2026-09-25.

## Already delivered and in the game

- Portraits: Paul, Duke Leto, Jessica, Gurney, Duncan (redone), Thufir, Kynes, the two Fremen.
- Illustrations: menu, intro (4), title screen, cards for the prologue, yard, council, Act I and 1.1.
- Emblems (8), the Residency interior kit (walls, doors, floors, props, console, hatch), the yard kit (grounds, rocks).
- Characters with full animation sets: Paul, the Fremen scout, the Fremen warrior. Paul's knife animations are in progress.
- Priority 1, first delivery (2026-09-25), in the game: portraits of Mapes and the four Banquet guests; `card_banquet`, `banquet` (the Banquet backdrop) and `card_harvester`; the painted crawler and its swallowed version, used in 1.3 and the Harvester Raid. ChatGPT marked `harvester_iso.png` failed (its footprint is 20-35 px off the spec after three attempts); the offset is invisible at play scale, so it is used as delivered.
- Still to come from priority 1: the ornithopter and thumper set pieces, and the four character references (Harkonnen guard and elite, Gurney in the field, the harvester crew), which wait for approval before their animations.
- New in this pass: the training dummy (idle, hit, broken) and the target board, now in the Arrakeen yard; the Atreides drill soldier (11 animations), used for Gurney's sparring soldiers and the 1.3 trooper.

Not used: `ground_rock_shelf.png` attempt 3 was marked failed and left out. The game keeps the earlier version, whose cracked plates read clearly as rock (rock is the worm-safe ground, so it must never look like sand). All three attempts are kept in `assets/prologue_source/`.

---

## Priority 1: in the game now, drawn as placeholders

**Production brief:** `docs/art/priority1_brief.md` covers everything in this section, ready to hand to the art agent. Where it and the per-mission briefs differ, it wins.

### 1a. The Atreides drill soldier: delivered (2026-09-25)

All 11 animations are delivered and in the game: Gurney's sparring soldiers in the Solo training, and the Atreides trooper in 1.3. Playback is reviewed in play. A field version (a desert cloak over the same kit) can come later if wanted.

### 1b. Harkonnen soldiers: two animation sets

Every Harkonnen in the game (1.1, the Harvester Raid, the Solo interiors, Act I onward) is still a placeholder shape. This is the most visible gap.

| Character | Folder | Look |
|---|---|---|
| `harkonnen_guard` | `assets/characters/harkonnen_guard/` | A Harkonnen trooper: black and slate-grey armour over a padded suit, a closed helmet with a narrow visor, the blue griffin as a shoulder shape only, a lasgun. Heavier and cruder than the Atreides soldier. |
| `harkonnen_elite` | `assets/characters/harkonnen_elite/` | An officer or shield-trooper: the same kit with heavier plates, a half-cape, a short blade on the hip and a visible shield-belt generator. Taller stance. |

Both use the full 11-animation set of `character_animation_prompt.md`, with the same cell (400 × 336) and anchor (200, 312) as Paul.

### 1c. Mapes: portrait

`assets/ui/portraits/mapes.png`, 512 × 512 RGBA. She speaks in 1.1 without a face.

- **Who:** Shadout Mapes, the Fremen housekeeper of the Residency. Old, small and wiry, dark leathery skin, all-blue spice eyes, grey hair bound back.
- **Dress:** a plain dark housekeeper's robe over a stillsuit collar.
- **Manner:** stern, watchful, dignified.

### 1d. The Banquet (1.2)

Unchanged from `docs/art/banquet_assets_brief.md`:
- **Guest portraits (4):** Lingar Bewt, Mael Serrin, Carthag Ryme, Esmar Tuek.
- **Illustrations:** `card_banquet.png` and the dimmed backdrop `banquet.png`.

### 1e. The Harvester in the Open (1.3)

From `docs/art/harvester_open_assets_brief.md`, with the trooper removed (see 1a):
- **Characters:** `harvester_crew`, one sheet with tint variants. It needs idle, walk, run and an injured limp, plus a **carried** pose (slung over a shoulder): the injured man is now carried.
- **Gurney's field sprite:** his full animation set, to match his portrait.
- **Set pieces:** the crawler (whole, and half-swallowed), the ornithopter and the thumper (up and striking).
- **Illustration:** `card_harvester.png`.

---

## Priority 2: the rest of Act I (designs not built yet; specs may change)

These follow the campaign plan. Each mission is designed before it is built, so treat this as a forecast. Characters that recur (marked ♦) come first, because several missions use them.

### 1.4 The Embassy: Duncan goes among the Fremen

- ♦ **Duncan's field sprite**, full animation set, matching his new portrait: Atreides field kit, a sword at the shoulder.
- ♦ **Stilgar portrait** (`stilgar.png`): the naib Duncan meets. Tall, black-bearded, hawk-faced, blue-within-blue eyes, a stillsuit and a worn desert robe. Stern and fair.
- **Fremen elders:** `fremen_elder.png`, one portrait with a tint variant.
- **Sietch approach kit** (exterior, `assets/environment/desert/`): a cave mouth in a rock wall, wind-carved boulders, a dew-collector, and a seamless `ground_dunes.png` with larger ripples than the yard sand.
- **Illustration:** `card_embassy.png`, Duncan and two men on a ridge at dusk, a far rock wall with a hidden entrance.

### 1.5 The Smugglers' Price: Gurney deals with the smugglers

- **Esmar Tuek:** his portrait is already in the Banquet list.
- ♦ **Smuggler sprite** (`smuggler`), full set: mismatched off-world gear, desert scarves, a light rifle.
- **Staban Tuek portrait** (`staban_tuek.png`): Esmar's son, younger and harder.
- **A smugglers' sand-crawler,** isometric and smaller than a spice harvester, patched and loaded.
- **Illustration:** `card_smugglers.png`, a smugglers' camp under a rock overhang at night, lamps shaded.

### 1.6 The Traitor Within: Thufir hunts the traitor

- ♦ **Dr. Yueh portrait** (`yueh.png`): the Suk doctor. Slight and old-young, a diamond tattoo on the forehead, a long moustache and a silver-ringed queue of black hair. Gentle, tired, secretly desperate.
- **Household staff:** one sprite set (`servant`), idle, walk and flee only.
- **Residency service levels:** additions to `iso_residency/`:
  - kitchen counters
  - water tanks and pipes
  - storage shelving
  - a laundry
  - a cellar floor
  - a service stair
- **Illustration:** `card_traitor.png`, a lamp-lit service corridor, a shadow at the far end.

### 1.7 The Night of Betrayal: the act finale

- ♦ **Sardaukar sprite set:** the Emperor's terror troops, disguised in Harkonnen livery but plainly deadlier. The same black-and-grey kit worn differently: bare heads or skull caps, no visors, curved blades and lasguns, economical stances.
- ♦ **Jessica's field sprite,** full set: her dark aba robe, for the Solo escape.
- **Portraits:** `baron.png` (Baron Vladimir Harkonnen: vast, suspensor-borne, soft pale face, black eyes; menace, not caricature) and `piter.png` (Piter de Vries, the twisted Mentat: thin, pale, sapho-red lips, blue-within-blue eyes).
- **Residency grounds at night:** a night variant of the yard kit (grounds and rocks), plus burning debris and a breached gate.
- **Testing station in the False Wall** (Solo interior, Duncan's last stand): a small ecological station of instrument racks, dew-precipitators and sealed doors.
- **Illustrations:**
  - `card_betrayal.png`: the Residency burning at night, ornithopters overhead.
  - `card_duncan.png`: Duncan alone in a doorway, holding.

---

## Priority 3: later acts

Not specified yet. They'll be written as each act is designed. They'll include the deep-desert and sietch kits, Stilgar's band, Chani, Jamis, the worm (ridden), and Feyd-Rautha.

## Delivery checklist (every asset)

- Exact size, mode and anchor, as the brief for its type says.
- Transparent where RGBA, with no fringe. No text, logos or watermarks.
- Portraits must read at 120 px. Sprites must read at 72 px tall on sand.
- Record each file in a manifest (path, size, attempts, checks, source, prompt), as `assets/prologue_asset_manifest.json` does, and keep sources and prompts.
