# Dune — Prologue asset pack: production brief

You are the art-production agent for **Dune — Tactical Prototype**, a Godot 4 tactics game set on Arrakis. This brief covers every graphic asset needed for the game's opening: the main menu, the intro, the prologue's three training sections, and their title cards.

- **The training hall:** Gurney Halleck teaches Paul to fight, in an isometric interior.
- **The yard:** Duke Leto teaches Paul to command a squad, on a top-down exterior map.
- **The council chamber:** the Duke teaches politics.

Produce the assets batch by batch in the order given in section 9. Complete generation, packing and verification automatically, and do not ask for confirmation between assets. Each file must match its specification exactly, because the game loads them by filename, size and anchor point with no manual adjustment.

---

## 1. References you will be given

The person handing you this brief will attach these existing, approved assets. They define the house style. Match them.

| File | What it establishes |
|---|---|
| `assets/ui/portraits/paul.png` (512 × 512) | Portrait style: painted, clean dark outlines, soft shading, head-and-shoulders framing |
| `assets/ui/portraits/fremen_scout.png` (512 × 512) | Portrait style for Fremen: stillsuits, hoods, desert palette |
| `assets/characters/paul/paul_idle.png` (strip of 400 × 336 cells) | Character sprite style, scale and camera angle |
| `docs/art/character_animation_prompt.md` | The full contract for character animation sets (used in batch F) |

If a reference is missing or unreadable, stop and report which one. Do not invent the house style.

## 2. Art direction for everything

- **Setting:** Frank Herbert's *Dune* novels, not any film or television adaptation. Designs must be original, following the books' descriptions. **No character may resemble an actor** from any adaptation, and no costume may copy a film costume.
- **Style:** painted illustration with clean dark outlines, restrained texture and soft shading, the same treatment as the references. No photorealism, no pixel art, no flat vector, no anime.
- **Palette:** Arrakis is ochre, sand, rust, bone and deep shadow, with spice-orange and the blue of spice-saturated eyes as accents. Atreides spaces add dark green, black, brass and old wood. Harkonnen things are black, grey and cold blue.
- **Light:** soft, from the upper left, in every asset that sits in the game world (tiles, props, sprites). Illustrations may use dramatic lighting.
- **Never draw** text, letters, numbers, logos, watermarks, signatures, frames, borders, UI elements or captions in any asset. The game adds all text itself.
- **Transparency:** every asset marked RGBA must have a real alpha channel with a transparent background. Never paint a checkerboard, white or black backdrop. Alpha edges must be clean, with no light or dark fringe.
- **Content:** no blood or graphic injury.

### Character descriptions (from the books)

Use these for portraits and illustrations. Everyone is original, and resembles no actor.

| Character | Description |
|---|---|
| **Duke Leto Atreides** | Tall, lean, olive-skinned, dark hair, grey eyes, a thin aquiline face; early forties; grave, tired, kind. Black Atreides uniform with a red hawk crest at the breast; the ducal signet ring. |
| **Paul Atreides** | Fifteen. Use the attached `paul.png` as his only design reference. |
| **Lady Jessica** | Early thirties. Bronze hair, green eyes, an oval face, great composure. Bene Gesserit: simple, elegant dark aba robe; no jewellery but a small ring. |
| **Gurney Halleck** | Stocky, powerful, ugly and likeable; a lumpy jaw with a purple-blue inkvine whip scar along it; thinning fair hair. Atreides soldier's field kit. His baliset (a nine-string instrument) is optional in the portrait. |
| **Duncan Idaho** | Young (mid-twenties), athletic, a round open face, black curly hair. Swordmaster of the Ginaz; Atreides uniform, a sword hilt at the shoulder. |
| **Thufir Hawat** | Old, thin, leathery; lips stained dark red from sapho juice; sharp, still eyes. A Mentat: a plain dark tunic, no ornament. |
| **Liet-Kynes** | Tall and thin, a sandy beard, deeply tanned; the blue-within-blue eyes of the spice. Stillsuit under a worn Fremen robe; the Imperial planetologist's badge of office on a cord. |

---

## 3. Batch A — Illustrations (menu, intro, title cards)

**Format:** opaque RGB PNG, exactly **1920 × 1080**, full bleed.

The game lays text over these, centred on screen, with a dark overlay at about 55%. So each illustration must leave a **calm, low-detail band** where the text sits: x 440–1480, y 380–700. Put the subject above or around that band, never behind it. For `menu_background`, keep the **left third** calm instead: the menu buttons sit there.

**Folder:** `assets/ui/story/`.

| File | Subject |
|---|---|
| `menu_background.png` | Arrakis at dusk: long dunes, two moons rising, and far off on a rock shelf the silhouette of the Arrakeen Residency. Grand, quiet, lonely. |
| `intro_01_spice.png` | The spice melange: glowing orange-cinnamon dust drifting in a dark Imperial hall, the vast shape of a throne dim in the background. |
| `intro_02_arrakis.png` | Arrakis from low orbit at the terminator line: a dun, cloudless world, a hint of the polar cap, a storm band in the south. |
| `intro_03_the_gift.png` | Duke Leto alone on a sea-cliff of Caladan at night, looking up at the stars; green-black seas; a weight on his shoulders. His face need not be fully shown. |
| `intro_04_arrival.png` | Atreides ornithopters and a frigate settling onto the Arrakeen landing field in the heat-haze; the Residency and the Shield Wall beyond. |
| `card_prologue.png` | The Residency's training hall, still full of packing crates; a practice mat; weapon racks; light from high narrow windows. No people. |
| `card_yard.png` | The Residency's walled training yard seen from the gallery above; sand, rock, a few practice targets; a figure watching from the gallery, seen from behind (the Duke). |
| `card_council.png` | The Duke's council room at evening: a long table with a map of Arrakis, lamps, heavy green hangings, empty chairs. |
| `card_act1.png` | The Arrakeen Residency at night from outside, its windows lit; the city dark around it; a sense of being watched. |
| `card_hunter_seeker.png` | Paul's darkened bedchamber from a low angle; a thin silver needle-shaped drone hanging in the air near the bed; moonlight through a shutter. |

---

## 4. Batch B — Speaker portraits

**Format:** RGBA PNG, exactly **512 × 512**, transparent background. Match the attached `paul.png` in framing (head and shoulders, three-quarter view, eyes at about 40% from the top), scale, outline weight and rendering.

**Folder:** `assets/ui/portraits/`. **Files:** `duke_leto.png`, `jessica.png`, `gurney.png`, `duncan.png`, `thufir.png`, `kynes.png`.

These are shown small (about 120 px) next to spoken lines, so every face must read clearly at that size.

---

## 5. Batch C — Emblems (the council screen)

**Format:** RGBA PNG, exactly **256 × 256**, transparent background. Draw each emblem as a **single flat white shape** (#FFFFFF, fully opaque) with no shading, outline or other colour: the game tints them. Centre each emblem with 16 px of transparent margin, and make them all read at 48 px.

**Folder:** `assets/ui/emblems/`.

| File | Emblem |
|---|---|
| `house_atreides.png` | A hawk, wings raised, in profile. |
| `house_harkonnen.png` | A griffin, rampant. |
| `emperor.png` | A lion's head, crowned (House Corrino). |
| `fremen.png` | A crysknife over the curve of a sandworm's back. |
| `guild.png` | An infinity-like fold enclosing a star (space folded). |
| `choam.png` | A balance scale over a single grain, in a ring. |
| `bene_gesserit.png` | An eye within an eye, stylised, over a veil. |
| `smugglers.png` | A sand-skimmer's sail over crossed hooks. |

---

## 6. Batch D — Isometric interior kit: the training hall

The Solo scope's interiors are **isometric** (2:1 dimetric). One floor tile is a diamond **128 px wide × 64 px high**. Characters (existing sprites, about 60–70 px tall at this scale) walk on them.

**Style:** stone and plastone walls, dark-green hangings, brass fittings, old wood, the Arrakeen Residency's training hall and its service levels. Light from the upper left, matching the game's lighting. Draw walls as solid blocks showing their top face, their left face (lit) and their right face (shade).

**Folder:** `assets/environment/iso_residency/`.

### 6.1 Canvas and anchor rules (exact)

**Floor tiles**
- Canvas **128 × 64**.
- The diamond fills the canvas: its corners sit at the midpoints of the canvas edges, (64, 0), (128, 32), (64, 64) and (0, 32).
- Everything outside the diamond is transparent.
- Tiles must sit seamlessly against neighbours. Keep a subtle edge line, and keep features away from the corners.

**Blocks** (walls, pillars, doors, props that stand on a tile)
- Canvas **128 × 128**.
- The **footprint** is the same 128 × 64 diamond, with its centre at **(64, 96)**, so its bottom corner touches the canvas bottom at (64, 128).
- Walls rise **52 px** above their footprint: the top face is the footprint diamond moved up by 52 px, with its centre at (64, 44).
- Nothing may extend outside the canvas.

**Small props**
- Use the canvas given for each prop, with the anchor given for each.

The anchor is where the game places the tile's centre on the grid. Do not shift artwork to centre its visible bounds.

### 6.2 Files

**Floors** (128 × 64)

| File | Description |
|---|---|
| `floor_stone_a.png` | Pale sandstone flags, worn. |
| `floor_stone_b.png` | The same with a slightly different flag pattern. The game alternates a and b in a checker, so they must match in tone. |
| `floor_mat.png` | A practice mat: dark red-brown woven fabric laid over stone. |
| `floor_grate.png` | Service-level metal grating over darkness, with brass edges. |

**Walls and pillars** (128 × 128, footprint centre (64, 96), 52 px high)

| File | Description |
|---|---|
| `wall_plain.png` | Plastered stone block, sand-coloured. |
| `wall_panel.png` | The same with a recessed stone panel on each face. |
| `wall_hanging.png` | A plain block with a dark-green Atreides hanging (no emblem) on its left face. |
| `pillar.png` | A round stone column filling the footprint, the same 52 px high, with a brass band. |

**Doors** (128 × 128, same anchor)

A door sits in a line of wall blocks and runs along that line:
- `se` runs from upper-left to lower-right, along the diamond's north-west to south-east axis (screen direction right-and-down, 2:1).
- `sw` runs from upper-right to lower-left.

Draw the door panel as a thin slab spanning the tile along its line, 52 px high, in a stone frame, with the threshold plate visible on the floor.

| File | State |
|---|---|
| `door_se_closed.png` | Panel closed: dark wood with brass strips. |
| `door_se_open.png` | Panel slid down into the floor; only the frame and threshold show. |
| `door_se_locked.png` | Closed, with a small red lamp on the frame. |
| `door_sw_closed.png` | As above, other axis. |
| `door_sw_open.png` | As above, other axis. |
| `door_sw_locked.png` | As above, other axis. |

**Props**

| File | Canvas | Anchor | Description |
|---|---|---|---|
| `console.png` | 128 × 128 | (64, 96) | Waist-high wall console, 44 px tall, footprint about 55% of a tile; a softly lit blue-white screen on its top face. |
| `crate_stack.png` | 128 × 128 | (64, 96) | Two or three stacked packing crates with Atreides stencilling (shapes only, no letters); up to 60 px tall. |
| `weapon_rack.png` | 128 × 128 | (64, 96) | A wooden rack of practice blades and a practice lasgun, against nothing (it stands free). |
| `hatch.png` | 128 × 64 | (64, 32) | A round floor hatch in a square brass frame, flush with the floor. |
| `fuel_drum.png` | 64 × 96 | (32, 80) | A squat spice-fuel drum with hazard bands; its base sits on the anchor. |

---

## 7. Batch E — Exterior kit: the yard

The Squad scope's maps are seen **top-down**, with characters drawn side-on and slightly elevated (see the attached sprite). Ground is a seamless texture. Rocks and props are drawn **top-down with a slight southward tilt**, so their south faces show a little, to sit with the side-on characters.

**Folder:** `assets/environment/yard/`.

| File | Format | Description |
|---|---|---|
| `ground_sand.png` | RGB, **512 × 512**, seamless on all four edges | Fine desert sand with faint wind ripples running diagonally. Low contrast. |
| `ground_courtyard.png` | RGB, **512 × 512**, seamless | Packed sand over worn paving stones, the Residency yard's floor. |
| `ground_rock_shelf.png` | RGB, **512 × 512**, seamless | Flat, cracked brown rock with drifts of sand in the cracks. |
| `rock_small.png` | RGBA, **256 × 256** | A single weathered boulder, centred, with about 24 px transparent margin. |
| `rock_medium.png` | RGBA, **384 × 384** | A cluster of two or three boulders, centred. |
| `rock_large.png` | RGBA, **512 × 512** | A low rock outcrop, irregular, centred. |
| `target_board.png` | RGBA, **400 × 336**, side-on like the characters, anchor (200, 312) | A practice target on a post, about 200 px tall; concentric rings as shapes, no numbers. |

Seamless means that when the image is tiled 3 × 3, no seam, repeated landmark or brightness jump is visible. Check this before delivering.

---

## 8. Batch F — Characters

Follow **`docs/art/character_animation_prompt.md` exactly** for each character below: the same 400 × 336 cells, (200, 312) anchor, 280 px standing height, the 11 animations in their order, and the same validation and manifest. The notes here only supply what that prompt asks for as `{{CHARACTER_NAME}}` and `{{CHARACTER_BIBLE}}`. No canonical sprite exists for these yet, so **first generate one idle frame** as the canonical reference, deliver it for approval, and then use it for every animation.

**`atreides_drill_soldier`**: an Atreides house guard in training kit. Padded dark-green jacket and black trousers, a light open-faced practice helmet, a plain dark practice lasgun (rifle-sized, blunt, no glowing parts), and a hawk shoulder patch as a shape only. A disciplined, ordinary soldier, not a hero. Folder: `assets/characters/atreides_drill_soldier/`.

**`training_dummy`** does not use the 11-animation set. It needs only these strips, same cell and anchor:

| File | Frames | Description |
|---|---|---|
| `training_dummy_idle.png` | 1 | A wooden practice figure on a post: padded torso, a crossbar for arms, a leather head. About 260 px tall. |
| `training_dummy_hit.png` | 3 | It rocks back on its post and returns. |
| `training_dummy_broken.png` | 1 | Crossbar snapped, torso split, still on its post. |

Folder: `assets/characters/training_dummy/`.

---

## 9. Order, validation and delivery

Produce the batches in this order: **B (portraits), A (illustrations), C (emblems), D (interior kit), E (exterior kit), F (characters)**. Within a batch, go file by file in the table's order.

For **every file**:

1. Generate it, then bring it to the exact canvas size and alpha mode specified. Resize or pad as needed, but never crop away part of the subject, and never stretch it out of proportion.
2. **Check programmatically** that:
   - the pixel size is exact;
   - the mode is RGBA or RGB as specified;
   - transparent assets really are transparent outside the subject, with no subject pixels touching the canvas edge unless the spec says so (floors, seamless textures, illustrations);
   - for floor tiles, the pixels outside the diamond have alpha 0;
   - for seamless textures, the image tiled 3 × 3 shows no seam.
3. **Check visually** that:
   - it has no text or letters, and no watermark;
   - no character resembles an actor;
   - its style is consistent with the references and with the other files of its batch;
   - the calm text band is clear (illustrations);
   - it reads at game size: portraits at 120 px, emblems at 48 px, tiles at 1:1 next to a character sprite.
4. If it fails, regenerate. Allow up to **three attempts** per file. If the third attempt fails, save what you have, mark the file failed with the exact reason, and continue with the next file. For batch F, follow the stop rule in the character prompt instead.

Deliver:

- All files in the folders named above, with exactly these filenames.
- **`assets/prologue_asset_manifest.json`**, listing every file with:
  - its path, size, and alpha mode;
  - the number of attempts;
  - its status (delivered / failed);
  - every check actually performed, with its result;
  - anything left for human review.
- A short summary: what was delivered, what failed and why, and what needs a human eye.

Never report a check you did not actually run, and never describe unverified work as finished.
