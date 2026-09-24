# Fremen Scout animation set

Generated with the built-in image generation tool from the first frame of the project's existing Scout idle strip. This is a staged replacement candidate; current runtime assets were not overwritten.

The 11 RGBA PNGs contain 65 frames in total. Each frame is 400 × 336 pixels, ordered left to right. FPS and loop settings are in `fremen_scout_animation_manifest.json` and match `UnitSprite.PLAYBACK`.

Open `review/index.html` locally for exact-FPS playback, frame stepping, mirroring, and sand/rock backgrounds. `review/overview.png` compares the complete set with the canonical reference. Individual GIFs provide quick game-size previews; GIF timing is rounded to centiseconds and one-shot previews repeat after a final-pose pause.

Technical checks cover dimensions, transparency, frame count, distinct frames, and clear cell boundaries. Static visual review covers all frames, character identity, weapon silhouette, and the death end pose. Live playback and in-game transitions remain for manual review because no browser was available during this session. Pay particular attention to locomotion footfall cadence, cloth changes, and reload mechanics: the reference does not show the rifle's loading mechanism, so the generated reload uses partly occluded hand gestures.

`source/` preserves accepted generator outputs. `generation_prompts.json` records the prompts, including the rejected first walk attempt and accepted second prompt. The packing tool is `tools/pack_generated_scout.py` in the project. It removes only almost invisible alpha noise (alpha ≤ 8), finds transparent boundaries without cutting the artwork, applies a common scale per animation, registers source-row baselines where needed, and packs the export cells. No per-frame scale changes are applied. Crouching and forward-running poses retain lower overall heights rather than being stretched to standing height.

Integration: copy the selected strips to `assets/characters/fremen_scout/` when ready to replace the existing assets. The filenames and animation keys already match the Scout resource. No code or playback changes are needed for those replacements.
