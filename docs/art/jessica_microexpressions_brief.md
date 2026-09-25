# Dune — Jessica's microexpressions: test brief

You are the art-production agent for **Dune — Tactical Prototype**. This is a small test batch: a large portrait of the Lady Jessica and a set of **microexpressions** drawn on exactly the same face. The game will cross-fade between them to see whether a player can *read* her face.

The rules in `docs/art/tutorial_assets_brief.md` still apply:
- section 2: art direction, no likeness of any actor, no text, clean transparency;
- section 9: validation and the three-attempt rule.

---

## 1. What this is for

At the Banquet, Paul answers each guest with one of three replies. When the player chooses **"Look at your mother"**, Jessica's large portrait appears beside the table. As the player moves the cursor over each of Paul's replies, her face shifts, very slightly:
- towards approval for a good reply;
- towards warning for a poor one;
- towards doubt for a half-good one.

She is a Bene Gesserit at a formal dinner, so she never *shows* an expression the guests could see. Only her son, who knows her face, can read it. **The changes must therefore be small, but unmistakable to a player who looks closely.** Think a fraction of a smile at the corner of the mouth, a slight narrowing of the eyes, a brow lifted by a millimetre. Nothing theatrical.

The test will answer two questions:
1. Can the expressions be told apart at game size?
2. Do they cross-fade cleanly into one another?

## 2. Who she is

Match `assets/ui/portraits/jessica.png` exactly: it is her only design reference.
- **Appearance:** early thirties, bronze hair, green eyes, an oval face, great composure.
- **Dress:** a simple, elegant dark aba robe; no jewellery but a small ring.
- **At the table:** seated, lit warmly from the upper left by suspensor lamps, the dinner hall a dark blur behind her. The background stays transparent: the game supplies the room.

## 3. References you will be given

| File | What it establishes |
|---|---|
| `assets/ui/portraits/jessica.png` | Her face, hair, costume, painted style and outline weight. **The identity must not change.** |
| `assets/ui/story/banquet.png` | The room's warm lamplight and palette, for her lighting |
| `assets/ui/portraits/paul.png` | House style for portraits |

If a reference is missing or unreadable, stop and report which one.

---

## 4. Format (exact)

**Folder:** `assets/ui/portraits/jessica_large/`.

- **RGBA PNG, exactly 768 × 1024** (portrait orientation), transparent background.
- **Framing:** head and shoulders to mid-chest, three-quarter view facing screen-left (towards the table), eyes on the horizontal line **y = 360**.
- **Registration (critical):** every file in the set is the **same drawing**. The head, hair, shoulders, robe, outline and lighting are pixel-for-pixel identical; **only the features the expression needs may change**. The game lays the frames on top of each other and cross-fades them over about 0.4 s. Any drift in the head position, hair or robe will show as a wobble and ruin the test.
- **Method:** generate the neutral base first. Derive every other frame *from that image* by editing only the face region (eyes, brows, mouth, and the muscles around them), not by generating a new portrait.

---

## 5. The set

Generate `neutral` first, and **deliver it alone for approval**. Continue with the rest only once the person handing you this brief approves it.

| # | File | Expression | What changes (and nothing else) |
|---|---|---|---|
| 1 | `neutral.png` | Composed, attentive, unreadable to a stranger | The base. Lips closed and relaxed, eyes calm, gaze resting just past the viewer towards the table. |
| 2 | `approve.png` | Quiet approval: *yes, that one* | The faintest softening round the eyes, and one corner of the mouth lifting a hair. Warm, not a smile. |
| 3 | `warn.png` | Warning: *not that* | Lips pressed a fraction thinner, a slight tightening at the eyes, the chin lowered by a hair. Cool, not a frown. |
| 4 | `doubt.png` | Doubt: *half right; think again* | One brow lifted a millimetre, the mouth still, the eyes a touch more open. |
| 5 | `still.png` | Too still: *careful, this one is listening for someone else* | Everything held perfectly: the eyes very slightly wider and unblinking, the face *more* composed than neutral. Used when the guest is the Harkonnen informant. |
| 6 | `glance_left.png` | A glance at a guest (to screen-left) | The irises move to the left edge of the eyes. The head does not move. |
| 7 | `glance_down.png` | A glance down (at a guest's hands or plate) | The eyes and upper lids lower slightly. The head does not move. |
| 8 | `blink.png` | Mid-blink | Eyelids closed, for life between readings. |

---

## 6. Checks for every file

Programmatic:
- exact size and RGBA mode, with a transparent background and no fringe;
- **the registration test:** take the absolute difference between each frame and `neutral.png`. It must be zero everywhere outside the face region (a box of roughly x 230–560, y 220–560). Report the bounding box of the pixels that differ, per frame.

Visual:
- same identity and style as `jessica.png`, and no actor likeness;
- each expression reads as described **at 50% scale** (384 × 512), when viewed side by side with neutral;
- `approve`, `warn` and `doubt` must be told apart from one another at that scale, **but none of them may look like an obvious smile, frown or raised-eyebrow cartoon at 100%**. Subtlety is the point.

Also deliver:
- `assets/ui/portraits/jessica_large/review_sheet.png`: all eight frames at 50%, in a 4 × 2 grid, labelled *outside* the images (on a separate strip), for the human review;
- `assets/ui/portraits/jessica_large/crossfade_neutral_to_warn.gif`: a looping preview of a 0.4 s cross-fade, neutral → warn → neutral, to show the registration holds.

---

## 7. Delivery

- **Files:** the eight PNGs, the review sheet and the GIF, in `assets/ui/portraits/jessica_large/`.
- **Manifest:** `assets/jessica_microexpressions_manifest.json`, in the same shape as the other asset manifests. For each file: path, size, mode, attempts, status, the registration bounding box, every check actually run with its result, and anything left for human review.
- **Summary:** a short note of what was delivered, what failed and why, and which expressions you think read weakest.

Three attempts per file. If an expression cannot be made both subtle and distinct in three attempts, deliver the best one, mark it with the reason, and continue.

Never report a check you did not actually run.
