# Dune — Priority 1 asset pack: production brief

You are the art-production agent for **Dune — Tactical Prototype**, a Godot 4 tactics game set on Arrakis. This brief covers the assets the game is using right now as placeholder shapes: the Harkonnen soldiers, the Act I missions 1.1 to 1.3, and the Atreides drill soldier's animations.

Everything in the prologue brief still applies unless this brief says otherwise:
- `docs/art/tutorial_assets_brief.md`, section 2 (art direction, palette, light, transparency, no text) and section 9 (validation and the three-attempt rule);
- `docs/art/character_animation_prompt.md`, the full contract for character animation sets.

Produce the batches in the order of section 7. Complete generation, packing and verification automatically, and do not ask for confirmation between assets, **except** at the two approval gates named below.

---

## 1. References you will be given

| File | What it establishes |
|---|---|
| `assets/ui/portraits/paul.png`, `gurney.png`, `thufir.png`, `duncan.png` | Portrait style and framing |
| `assets/characters/paul/paul_idle.png` | Sprite style, scale and camera angle |
| `assets/characters/fremen_warrior/` (any strip) | A second sprite set, for consistency |
| `assets/environment/iso_residency/fuel_drum.png`, `console.png` | Isometric prop style, light and outline weight |
| `assets/environment/yard/rock_large.png` | Exterior prop style |
| `assets/characters/atreides_drill_soldier/atreides_drill_soldier_reference.png` | The drill soldier's canonical reference (batch E) |

If a reference is missing or unreadable, stop and report which one.

## 2. Standing rules

- The books, not any adaptation. **No character may resemble an actor**, and no costume may copy a film costume.
- No text, letters, numbers, logos or watermarks in any image. No blood or graphic injury.
- Keep every prompt and generated original, as in the prologue pack.

---

## 3. Batch A — Portraits

**Format:** RGBA PNG, exactly **512 × 512**, transparent background, the same head-and-shoulders framing, painted style and outline weight as the reference portraits. Every face must read at 120 px.

**Folder:** `assets/ui/portraits/`.

| File | Who | Look |
|---|---|---|
| `mapes.png` | Shadout Mapes, the Fremen housekeeper of the Residency | Old, small and wiry. Dark, leathery skin; all-blue spice eyes; grey hair bound back. A plain dark housekeeper's robe over a stillsuit collar. Stern, watchful, dignified. |
| `lingar_bewt.png` | Lingar Bewt, master of the water-sellers' guild | Late fifties, soft and well fed in a town where most people are lean. Heavy-lidded, careful eyes. Rich, dust-coloured robes with a water-seller's brass cups hung on a chain. He smiles easily and doesn't mean it. |
| `mael_serrin.png` | Mael Serrin, banker of the Spacing Guild | Tall and thin, pale from a life off-planet. Severe grey clothes with a high collar and a plain disc pin. A narrow, amused, faintly contemptuous face. |
| `carthag_ryme.png` | Carthag Ryme, factor for CHOAM | Middle-aged and precise: a neat beard, spectacles on a chain, a dark formal coat. An accountant's face, alert and unreadable. |
| `esmar_tuek.png` | Esmar Tuek, the smugglers' man | Weathered and sun-dark, sharp-eyed, a short grey beard. Plain travel clothes of good cloth, a desert scarf loose at the neck. Relaxed, amused, watchful. |

---

## 4. Batch B — Illustrations

**Format:** opaque RGB PNG, exactly **1920 × 1080**, full bleed. The game lays text over each one with a dark overlay, so leave a calm, low-detail band at x 440–1480, y 380–700, as in the prologue brief. `banquet.png` is the exception: it sits dimmed behind the Banquet screen, so keep its **centre** calm instead.

**Folder:** `assets/ui/story/`.

| File | Subject |
|---|---|
| `card_banquet.png` | The Residency's great hall at night, set for a formal dinner. A long table under suspensor lamps, water in fine glasses at every place (a show of wealth on Arrakis), the guests' chairs empty and waiting. Warm light, deep shadows. |
| `banquet.png` | The same hall mid-dinner, seen from above the table, the guests only as shapes. Nothing in the centre that would fight the interface. |
| `card_harvester.png` | From an ornithopter's open door: a spice crawler alone on endless open sand under a white-hot sky, dust streaming from it. Far off, a long ripple in the dunes heading its way. |

---

## 5. Batch C — Set pieces for the squad view

The squad maps are seen **isometrically**: a top-down world tilted 2:1, like the Residency interior kit. A standing man is about **65 px** tall at this scale. Light from the upper left. Each set piece is **one RGBA image** that the game places by its anchor: the point on the ground under the object's centre.

**Folder:** `assets/environment/squad/`.

| File | Canvas | Anchor | What |
|---|---|---|---|
| `harvester_iso.png` | 1024 × 768 | (512, 560) | The spice crawler: a huge tracked machine, rust-and-sand coloured, with a tall exhaust stack, catwalks and ladders on its flanks. **Its footprint** on the ground is a parallelogram with corners at anchor + (155, 191), (382, 78), (−155, −191) and (−382, −78). The long axis runs from upper-left to lower-right. The intake scoop runs along the long side facing the viewer (lower-left). The machine rises about 150 px above its footprint. Nothing may leave the canvas. |
| `harvester_iso_swallowed.png` | 1024 × 768 | (512, 560) | The same crawler after the worm: tilted, half sunk, sand pouring over it, the stack bent. Same anchor and footprint. |
| `ornithopter_iso.png` | 512 × 384 | (256, 300) | An Atreides ornithopter parked on rock: a long narrow fuselage with a glazed cockpit, four long articulated wings folded back, landing skids. Muted green-grey, the hawk crest as a shape only. About 420 px long, its long axis from upper-left to lower-right; its skids stand on the anchor. |
| `thumper_iso.png` | 64 × 96 | (32, 84) | A Fremen thumper: a spring-loaded metal stake planted in sand, about 45 px tall, its base on the anchor. |
| `thumper_iso_strike.png` | 64 × 96 | (32, 84) | The same at the bottom of its stroke: the head driven down, a small puff of sand at the base. |

Check that the harvester's footprint corners fall where specified: overlay the parallelogram on a copy of the image and inspect it.

---

## 6. Batch D — New characters: references first (approval gate 1)

These characters have no sprite yet. For each one, follow `docs/art/character_animation_prompt.md` but **first generate one idle frame** (400 × 336 cell, anchor (200, 312), 280 px standing height) as its canonical reference. **Deliver all four references together for approval, then stop.** Generate their animations only once the person handing you this brief approves each one.

| Name | Folder | Character notes (`{{CHARACTER_BIBLE}}`) | Animations |
|---|---|---|---|
| `harkonnen_guard` | `assets/characters/harkonnen_guard/` | A Harkonnen trooper: black and slate-grey armour over a padded suit, a closed helmet with a narrow visor, the blue griffin as a shoulder shape only, a lasgun. Heavier and cruder than an Atreides soldier. | The full 11 |
| `harkonnen_elite` | `assets/characters/harkonnen_elite/` | A Harkonnen officer or shield-trooper: the same kit with heavier plates, a short half-cape, a short blade on the hip and a visible shield-belt generator at the waist. A taller, prouder stance. | The full 11 |
| `gurney_field` | `assets/characters/gurney_field/` | Gurney Halleck in the field, matching `gurney.png`: stocky and powerful, the inkvine scar along the jaw, thinning fair hair. A green-and-brown Atreides field coat, a baliset slung on his back, a short rifle. | The full 11 |
| `harvester_crew` | `assets/characters/harvester_crew/` | A spice-crawler hand: heavy tan-ochre work coveralls stained dark at the knees, a hood, a dust mask round the neck, a tool belt. An ordinary worker: **no weapon**. The game tints the coveralls, so keep them one clean colour family. | **Five only**, table below |

**`harvester_crew` strips**, in the same cell and anchor:

| # | Name | Frames | FPS | Loop | Description |
|---|---|---|---|---|---|
| 1 | `idle` | 4 | 6 | Yes | Standing, uneasy, glancing about. |
| 2 | `walk` | 8 | 12 | Yes | An ordinary walk. |
| 3 | `run` | 8 | 14 | Yes | A panicked run, arms loose and flailing, head turned back. |
| 4 | `limp` | 8 | 8 | Yes | The injured man: one arm bandaged in white and held to his chest, dragging a leg. |
| 5 | `carried` | 2 | 3 | Yes | The injured man limp, draped over an unseen shoulder, drawn alone. The game places him over his carrier. Keep him inside the cell, his waist near (200, 150). |

## 7. Batch E — The Atreides drill soldier's animations: DONE

Delivered on 2026-09-25 and in the game. Skip this batch.

<details><summary>Original instructions</summary>


Generate the full 11-animation set for `atreides_drill_soldier` from its existing reference. **Do this batch only if the person handing you this brief says the reference is approved.** If they don't, skip it and report that it is waiting.

It is used twice in the game: as the drill soldier in the prologue yard, and as the Atreides trooper escorting the Duke in 1.3.

</details>

---

## 8. Order, validation and delivery

**Order:**
1. **A** (portraits).
2. **B** (illustrations).
3. **C** (set pieces).
4. **D** references, delivered together. Stop at approval gate 1.
5. **E**, if approved.
6. **D** animations, after approval.

For every file, run the checks of the prologue brief's section 9, plus:
- set pieces: the anchor and footprint overlay;
- sprites: the checks of the character prompt.

Deliver:
- All files in the folders named above, with exactly these filenames.
- **`assets/priority1_asset_manifest.json`**, in the same shape as `assets/prologue_asset_manifest.json`: path, size, mode, attempts, status, every check actually run with its result, and anything left for human review.
- A short summary: what was delivered, what failed and why, what is waiting for approval, and what needs a human eye.

Never report a check you did not actually run, and never describe unverified work as finished.
