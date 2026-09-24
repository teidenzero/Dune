# Fremen Warrior animation set

11 RGBA PNG strips, 65 frames, 400 x 336 pixels per frame. Generated with the built-in image generator using the authorized new `fremen_warrior_reference.png` design in the Scout's painted style.

Open `review/index.html` for playback, frame stepping, mirroring, and sand/rock backgrounds. `review/overview.png` compares the canonical reference with every animation. GIF previews repeat for review; runtime loop flags are recorded in the manifest. GIF timing is rounded to centiseconds.

Dimensions, transparency, clear cell boundaries, distinct frames and playback metadata passed technical checks. Static images were inspected. Live playback and in-game transitions remain for manual review. Inspect gait cadence, facial/head consistency, cloth continuity, recoil magnitude, and reload hand/part continuity.

These files are staged assets. The existing game assets were not replaced. Integration into the character's scene/resource and any additional weapon, melee or prescience animation support are separate work.

`source/` preserves generation attempts. `prompts/` and `generation_prompts.json` record the prompts. The project tool `tools/pack_character_sprites.py` removes almost invisible alpha noise (alpha <= 8), separates poses only through transparent pixels, registers source rows/columns when required, and packs the final strips. It uses one scale per animation and never scales individual poses independently.
