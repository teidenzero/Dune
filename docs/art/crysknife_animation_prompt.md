# Paul crysknife animation production prompt

This is an **addition** to `docs/art/character_animation_prompt.md`. Every rule in that document still applies - character preservation, reference priority, camera and art direction, the exact 400 × 336 export contract, the ground anchor at (200, 312), the 280 px standing height, in-place motion, no effects, validation, up to three attempts, the manifest - except its line forbidding melee animations: this document is that melee specification. Where the two disagree, this document wins for these animations only.

## Task

Generate Paul's **crysknife** animation set: 6 animations, in the order below, packed into engine-ready strips beside his existing set.

- Character name: `paul`.
- Canonical reference: `assets/characters/paul/generated/paul_reference.png`, together with the first 400 × 336 cell of `assets/characters/paul/paul_idle.png` for the in-engine scale and anchor.
- Supporting motion references: Paul's existing strips in `assets/characters/paul/` (`idle`, `walk`, `crouch_walk`, `aim`, `hit`). Match their body proportions, costume, cloak behaviour and scale exactly.
- Output directory: `assets/characters/paul/generated/`, filenames `paul_<animation_name>.png`, plus an updated `paul_animation_manifest.json` that lists these 6 animations alongside the existing 11. Do not regenerate or overwrite the existing 11 strips.

## The weapon and the grip

- The **crysknife** is the one already visible in the reference: sheathed at the front of Paul's belt, a milky-white, slightly curved blade about the length of a forearm, with a pale bone-like handle. Draw its blade milky white with a faint translucent sheen, never steel-grey. Keep its length and curve identical in every frame.
- In all 6 animations the crysknife is **drawn in Paul's right, leading (screen-right) hand**. The Maula pistol stays in his **left, rear hand**, held low and back along his thigh, muzzle pointing down. The pistol must stay visible and consistent; it does not fire and does not move to the leading hand.
- The first frame of `knife_draw_charge` may begin with the blade still leaving the sheath; every other frame shows the blade drawn.

## How the game uses these animations

The player presses the mouse on an enemy and Paul raises the blade **immediately**. How long the button is held decides the stroke:

- Released before **0.35 s**: the **quick strike**, a fast flick.
- Held past **0.35 s**: the blade is **charged**; releasing commits the **slow strike**, a heavy, deliberate thrust. It is slow on purpose: in Dune, personal shields stop fast blades, and only a slow blade passes through.

While the button is held, Paul may still be **walking toward the target** with the blade raised. The engine switches between these animations by state, so each must start from, and end in, poses that connect:

| From | To |
|---|---|
| `aim` or `idle` | `knife_draw_charge` |
| last frame of `knife_draw_charge` | `knife_charged_hold` or `knife_charged_walk` (same raised-blade pose) |
| `knife_charged_hold` / `knife_charged_walk` | `knife_quick` or `knife_slow` (released) |
| last frame of `knife_quick` / `knife_slow` | `idle` |

The raised, charged pose is the **shared key pose** of this set: the last frame of `knife_draw_charge`, every frame of `knife_charged_hold`, and the upper body of `knife_charged_walk` must all show the same blade position. Establish it once, then reuse it.

## Animation specification and generation order

| Order | Animation | Frames | FPS | Loop | Final PNG size | Motion |
|---|---|---:|---:|---|---|---|
| 1 | `knife_draw_charge` | 4 | 11 | No | 1600 × 336 | From the ready stance, draw the crysknife from the belt and raise it into the **charged pose**: weight settling onto the back foot, blade drawn back at shoulder height, point toward screen-right, body coiled. Frame 1 hand on the hilt / blade leaving the sheath; frame 2 blade clear; frame 3 blade rising; frame 4 the charged pose (held by the next animation). About 0.36 s: this must feel responsive, not ceremonial. |
| 2 | `knife_charged_hold` | 4 | 6 | Yes | 1600 × 336 | Standing still in the charged pose, ready to strike: very small breathing and a slight tension in the blade arm. The blade does not travel; this is a sustained hold that can last seconds. Seamless loop. |
| 3 | `knife_charged_walk` | 8 | 10 | Yes | 3200 × 336 | A careful, deliberate in-place advance with the blade held in the charged pose: short, planted steps, upper body steady, eyes on the target. The lower body walks; the blade arm stays in the key pose. Slower and more guarded than `walk`. |
| 4 | `knife_quick` | 6 | 13 | No | 2400 × 336 | The fast strike from the charged pose. **Frame 1** wind-up (a short snap back); **frames 2–3** the cut: a fast diagonal slash forward, blade extended to full reach at screen-right (frame 2 is the contact frame); **frames 4–6** recovery: blade returning, body re-balancing, ending in a pose that connects to `idle`. About 0.46 s in total. Light, quick, wrist and forearm; little body commitment. |
| 5 | `knife_slow` | 9 | 8 | No | 3600 × 336 | The slow, penetrating strike from the charged pose. **Frames 1–4** wind-up: the whole body gathers, blade drawn further back, weight rocking onto the back foot; **frames 5–6** the thrust: a slow, heavy, straight push of the point into the target at screen-right, whole body behind it, front knee bending (frame 5 is the contact frame); **frames 7–9** recovery: withdrawing the blade and returning to a stance that connects to `idle`. About 1.13 s. It must read as controlled and deliberate, not a fast lunge. |
| 6 | `knife_crouch_quick` | 6 | 13 | No | 2400 × 336 | The stealth strike from the crouch: the same timing and contact frame as `knife_quick` (frame 1 wind-up, frames 2–3 the cut, frames 4–6 recovery), but low, starting and ending in Paul's `crouch_idle` pose and anatomy. A quick, silent cut upward and forward. |

Reach: at the contact frame of `knife_quick`, `knife_slow` and `knife_crouch_quick`, the blade tip should reach about **70–80 px** in front of Paul's chest (toward screen-right), inside the cell, with transparent clearance from the right edge. The game's hit wedge extends 70 px from the body's centre; the art should match it, not exceed the cell.

Timing notes for playback: the engine plays `knife_draw_charge` once when the button goes down, then loops `knife_charged_hold` (standing) or `knife_charged_walk` (moving) until release. It then plays `knife_quick` or `knife_slow` once. The quick and slow strikes are timed against the gameplay wind-up (0.10 s / 0.50 s), active window (0.12 s / 0.18 s) and recovery (0.25 s / 0.45 s); keep the contact frames where the table puts them so the hit lands on the frame that shows it.

## Specific cautions

- Do not draw a slash trail, motion blur streak, glint, spark, blood or shield effect: the game draws the blade arc and the shield flash itself.
- The blade arm is the leading (screen-right, nearer the viewer) arm, the same arm that holds the pistol in the reference. Keep left and right limbs consistent across the set; do not swap the knife between hands.
- Keep the crysknife the same size in every frame; do not let it lengthen into a sword during the thrust.
- Keep the pistol in the rear hand in every frame, low and pointing down, never crossing the blade.
- Record in the manifest the frame index of each strike's contact frame (`knife_quick`: 2, `knife_slow`: 5, `knife_crouch_quick`: 2) so the runtime can verify the timing.

## Deliverables

The 6 verified PNG strips in `assets/characters/paul/generated/`, and `paul_animation_manifest.json` updated to list all 17 of Paul's animations, with the new entries carrying name, filename, requested and actual frame count, FPS, loop flag, dimensions, attempt count, generation and validation status, contact frame (for the three strikes), and any consistency problems or unverified details. Wiring these into the game is a separate integration step; do not modify scripts or runtime assets.
