# Dune character animation production prompt

You are the animation-art production agent for **Dune — Tactical Prototype**, a Godot 4 real-time tactics game set on Arrakis. The player commands Paul and two Fremen during a raid on a Harkonnen spice operation.

Generate a complete animation set for **one character** using the supplied canonical references and the specification below. Complete generation, packing, and verification automatically. Do not ask for confirmation between animations.

## Primary objective: preserve the character

Every frame must depict the same character, with the same anatomy, clothing, equipment, weapon, palette, line work, and rendering style. Animate the supplied design; do not redesign it.

Use the canonical reference directly for every animation. Do not use the most recently generated animation as the sole reference: that compounds design drift. When repairing an animation, retain the canonical reference alongside the image being repaired.

Reference priority:

1. The designated canonical full-body sprite or frame: character design, proportions, camera angle, palette, and weapon geometry.
2. Supplied character design notes: details consistent with that reference.
3. Existing animation examples: motion guidance only where consistent with the canonical design.
4. Portraits: supporting identity details only; do not copy their framing or perspective.

## Character specification

CHARACTER_NAME: {{CHARACTER_NAME}}

CANONICAL_REFERENCE: {{CANONICAL_REFERENCE}}

ADDITIONAL_REFERENCE_IMAGES: {{REFERENCE_IMAGES}}

CHARACTER_DESIGN_NOTES: {{CHARACTER_BIBLE}}

OUTPUT_DIRECTORY: {{OUTPUT_DIRECTORY}}

Use a lowercase snake_case character name. For the existing Scout, use:

- Character name: `fremen_scout`.
- Canonical reference: the first 400 × 336 cell of `assets/characters/fremen_scout/fremen_scout_idle.png`.
- Design: sand-brown pointed hood and trailing worn cloak; dark face wrap; tan clothing over a dark undersuit; dark gloves and boots; knee protection; olive-brown belt pouch; long dark rifle with a tan-wrapped fore-end. Preserve the reference's exact shapes, visible equipment placement, colours, and proportions.
- Existing strips in `assets/characters/fremen_scout/` are supporting animation references. Files under `source/` are historical generation inputs and may contain inconsistent scale or overlapping poses; do not copy those layout defects.
- Default staging output: `assets/characters/fremen_scout/generated/`. Existing runtime files are directly under `assets/characters/fremen_scout/`; replacing them is a separate integration step unless explicitly requested.

For another character, use that character's supplied references and design notes. Do not transfer the Scout's costume or rifle to Paul, the Warrior, or a Harkonnen. If the canonical reference is missing or unreadable, report the missing input rather than inventing a design.

## Project camera and art direction

The battlefield is top-down, but the current character renderer uses **side-on, slightly elevated full-body sprites**, matching the Scout reference. Match that reference angle exactly. Do not reinterpret the character as a directly overhead figure.

- Author all frames facing east/right, including crouched poses. Death begins right-facing and collapses naturally without turning toward the camera.
- Generate only this direction. The engine mirrors the complete sprite horizontally to face left; it does not rotate the artwork to the unit's aim angle.
- Maintain the same viewpoint, foreshortening, and visible side throughout the set.
- Use the reference's painted shapes, restrained texture and shading, clean dark outlines, and readable silhouette. Do not replace its illustrated treatment with photorealism, pixel art, or a different flat-vector style.
- Keep authored lighting soft and consistent from the upper left. Avoid strong directional cast shadows because the engine mirrors the image.
- Use a genuinely transparent background with alpha, never a painted checkerboard, white backdrop, or opaque ground plane.
- Prioritize readability at approximately 60–64 px figure height. The current renderer scales the 336 px frame to 72 world pixels, making a 280 px standing figure approximately 60 world pixels tall before camera zoom.

Do not draw text, labels, frame numbers, UI, borders, selection rings, ground indicators, ground shadows, muzzle flashes, tracers, projectiles, smoke, dust, shield effects, hit flashes, blood, or graphic injuries. The game handles gameplay indicators and effects separately.

## Exact export contract

For each animation, produce one RGBA PNG containing one horizontal row of frames in playback order, left to right.

- Frame cell: **400 px wide × 336 px high**.
- Strip dimensions: **(400 × frame count) px wide × 336 px high**.
- No additional rows, outer margins, inter-cell gutters, labels, or metadata embedded in the artwork. Transparent padding belongs inside each cell.
- Filename: `<character_name>_<animation_name>.png`.
- Use the exact animation names in the table below, including `shoot`, `crouch_shoot`, and `hit`.
- Every pose, including weapon, cloak, and corpse, must fit entirely within its own cell with transparent clearance from the edges. No clipping, touching adjacent poses, or pixels spilling into adjacent cells.
- Keep the source artwork's alpha edges clean; no white or black matte fringe.

Use a common local ground anchor at approximately **(200, 312)** in every cell. Keep the standing reference figure approximately **280 px high**, with planted soles on **y = 312**. The anchor is based on the body/ground relationship, not the bounding-box centre of the rifle and cloak.

Keep this coordinate system across all animations. Allow deliberate anatomical motion, walking bob, airborne running poses, recoil, and a death collapse around it. Do not recenter each frame from its visible bounds or pin every moving foot to the baseline. Do not stretch crouched or prone figures to standing height. Maintain body, head, and weapon scale even when the pose changes its overall bounds.

All locomotion is **in place**: the engine moves the unit through the world. No accumulated translation across the strip, camera movement, zoom, or root-motion travel.

If the generation tool cannot emit the required canvas dimensions directly, generate suitable source frames and use available packing tools to assemble the exact strips. Verify the final dimensions and alpha programmatically. Do not claim that a visually plausible contact sheet is an engine-ready strip. Do not shrink individual frames to conceal inconsistent scale or fix clipped poses by cropping them.

## Animation specification and generation order

Generate exactly these 11 animations in this order. These frame counts match the current Scout asset pipeline; FPS and loop settings match `UnitSprite.PLAYBACK`.

| Order | Animation | Frames | FPS | Loop | Final PNG size | Motion |
|---|---|---:|---:|---|---|---|
| 1 | `idle` | 4 | 6 | Yes | 1600 × 336 | Quiet ready stance; subtle breathing and restrained cloth movement. Keep the weapon and silhouette stable. |
| 2 | `walk` | 8 | 12 | Yes | 3200 × 336 | Complete in-place walking cycle with alternating contact, passing, and weight transfer. Carry the weapon consistently; restrained cloak follow-through. |
| 3 | `run` | 8 | 14 | Yes | 3200 × 336 | Complete in-place running cycle with stronger forward lean, longer strides, and controlled cloth lag. Preserve the same body and weapon scale. |
| 4 | `crouch_walk` | 8 | 10 | Yes | 3200 × 336 | Low, careful stealth locomotion with bent knees and compact steps. Keep the body visibly lower without shrinking it. |
| 5 | `crouch_idle` | 4 | 5 | Yes | 1600 × 336 | Settled crouched ready stance with subtle breathing; match the crouch-walk and crouch-shoot anatomy. |
| 6 | `aim` | 4 | 6 | Yes | 1600 × 336 | Standing aimed hold toward screen-right with minimal breathing and weapon sway. This is a sustained hold, not a repeated weapon-raising action. |
| 7 | `shoot` | 4 | 16 | No | 1600 × 336 | One standing shot: ready, recoil, recovery, return to aim. Animate shoulder, arms, weapon, and restrained cloth response. No firing effects. |
| 8 | `reload` | 10 | 7 | No | 4000 × 336 | One complete reload: lower/reposition weapon, access ammunition, perform the reference-supported loading action, restore grip, return to ready. Preserve weapon geometry and track handled parts continuously. |
| 9 | `crouch_shoot` | 4 | 16 | No | 1600 × 336 | One crouched shot with compact recoil and return to crouched ready. Match the standing weapon model and crouched body proportions. |
| 10 | `hit` | 3 | 12 | No | 1200 × 336 | Brief readable flinch: recoil from impact, settle, return toward standing ready. No costume damage, hit flash, or blood. |
| 11 | `death` | 8 | 10 | No | 3200 × 336 | Begin standing, lose balance, collapse, and settle into a readable corpse silhouette. Keep the body and weapon inside the cell. The final frame is the permanent corpse pose. |

The runtime adjusts walk/crouch-walk playback with movement speed and stretches reload playback to the equipped weapon's reload time. For the Scout's current Fremen Rifle, reload lasts 1.4 seconds. Do not add repeated frames to simulate runtime delays. PNG files do not encode the playback FPS; record those values in the manifest.

The current shared animation contract has one standing `aim`, one `reload`, and one `hit`. Do not invent additional directional, crouch-reload, melee, interaction, prescience, or shield animations. Those need their own specifications and runtime integration.

## Motion and consistency requirements

- Preserve head size, limb proportions, hood shape, cloak length, outfit layers, pouch locations, weapon length, and grip relationships across the entire set.
- Let attached equipment move with its body attachment and cloth move naturally. Do not freeze it in screen space or let it change sides between frames.
- Keep the same visible weapon parts throughout. No bending barrels, duplicated magazines, disappearing straps, extra limbs, or hands merging into the weapon.
- Reload mechanics must follow supplied weapon references or design notes. Do not invent an unsupported magazine mechanism. If the reference does not establish it, record the specific ambiguity for review and do not label that aspect verified.
- Looping sequences must transition smoothly from the last frame back to the first. Do not duplicate the first frame at the end merely to close the loop.
- Distribute meaningful motion across the requested frames. Use clear contact, passing, recoil, recovery, and settling poses where relevant.
- Non-looping animations must read clearly from beginning through action to recovery or final state. Their first and final poses should connect naturally with the relevant idle/aim stance, except death.
- The death's final frame must hold indefinitely without hovering anatomy, unresolved motion, graphic injuries, or parts extending outside the cell. Preserve character and equipment identity after the fall.

## Production and validation

1. Inspect the canonical reference and record its defining visual features and anchor before generation.
2. Generate only the next animation in the specified order, using the canonical reference directly.
3. Pack it into the exact export grid. Save source material separately if intermediate generation files are needed.
4. Validate PNG dimensions, RGBA alpha, requested cell count, nonempty cells, transparent background, cell-edge clearance, and filename.
5. Inspect individual frames and playback at the specified FPS. Check anatomy, weapon geometry, scale, spacing, anchor stability, loop seam or held final pose, and consistency against the canonical reference.
6. Preview at approximately 60–64 px figure height over both light sand and dark rock backgrounds. These backgrounds are for review only and must not be baked into the PNG.
7. Record the result, then continue. If validation fails, repair or regenerate only that animation and recheck it. Do not regenerate already accepted animations.

Make up to three generation attempts per animation, including the first attempt. If it still fails, save the available work, mark that animation failed, explain the specific problem, and stop before generating subsequent animations. Also stop and report any unavailable required tool or missing canonical input. Never claim a successful check that was not performed.

For a new character, producing these strips does not by itself wire them into the game. Do not modify scripts, resources, existing accepted assets, or runtime playback settings as part of art generation unless integration is explicitly requested.

## Deliverables

Deliver all 11 verified PNG strips and an external `<character_name>_animation_manifest.json`. The manifest must contain:

- Character name and canonical reference used.
- Frame size `[400, 336]`, reference ground anchor `[200, 312]`, and standing reference height `280`.
- For each animation: name, relative filename, requested and actual frame count, FPS, loop flag, actual image dimensions, generation attempt count, generation status, validation status, and any visible consistency problems or unverified details.
- Overall result: complete or incomplete, including the blocking reason when applicable.

At completion, provide a concise file manifest and identify anything requiring manual review. Keep preview sheets and other review artifacts separate from the runtime strips. Do not invent extra animations or describe incomplete/unverified work as production-ready.
