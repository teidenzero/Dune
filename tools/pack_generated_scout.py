"""Pack generated Scout strips with common scale and registered source rows."""
import argparse
import json
from pathlib import Path
import shutil

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/characters/fremen_scout/generated'
SPEC = {
    'idle': (4, 6, True), 'walk': (8, 12, True), 'run': (8, 14, True),
    'crouch_walk': (8, 10, True), 'crouch_idle': (4, 5, True),
    'aim': (4, 6, True), 'shoot': (4, 16, False), 'reload': (10, 7, False),
    'crouch_shoot': (4, 16, False), 'hit': (3, 12, False), 'death': (8, 10, False),
}


def pack(args):
    count, fps, loop = SPEC[args.name]
    for folder in [OUT, OUT / 'source', OUT / 'review']:
        folder.mkdir(parents=True, exist_ok=True)
    source = OUT / 'source' / f'fremen_scout_{args.name}_attempt{args.attempt}.png'
    shutil.copy2(args.source, source)
    image = Image.open(source)
    assert image.mode == 'RGBA', 'Source must have genuine RGBA transparency'
    arr = np.array(image)
    # The generator can leave alpha <= 8 noise far outside the painted sprite.
    # Clear only that almost invisible noise; preserve the generated edge alpha.
    cleared = int(np.count_nonzero((arr[:, :, 3] > 0) & (arr[:, :, 3] <= 8)))
    arr[arr[:, :, 3] <= 8] = 0
    image = Image.fromarray(arr)
    cells = []
    bounds = []
    centres = []
    cols = args.columns or count
    rows = (count + cols - 1) // cols
    seams_by_row = []
    for row in range(rows):
        top, bottom = round(row * image.height / rows), round((row + 1) * image.height / rows)
        occupied = np.any(arr[top:bottom, :, 3] > 8, axis=0)
        seams = [0]
        for col in range(1, cols):
            expected = col * image.width / cols
            radius = image.width / cols * 0.2
            candidates = np.where(~(occupied | np.roll(occupied, 1) | np.roll(occupied, -1)))[0]
            candidates = candidates[np.abs(candidates - expected) < radius]
            assert len(candidates), f'No transparent separation at row {row}, column {col}'
            seams.append(int(candidates[np.argmin(np.abs(candidates - expected))]))
        seams.append(image.width)
        seams_by_row.append(seams)
    for i in range(count):
        col, row = i % cols, i // cols
        left, right = seams_by_row[row][col:col + 2]
        top, bottom = round(row * image.height / rows), round((row + 1) * image.height / rows)
        cell = image.crop((left, top, right, bottom))
        bbox = cell.getbbox()
        assert bbox is not None, f'Empty source cell {i}'
        assert bbox[0] > 0 and bbox[1] > 0 and bbox[2] < cell.width and bbox[3] < cell.height, f'Source touches cell edge {i}: {bbox}'
        cells.append(cell)
        bounds.append(bbox)
        centres.append((col + 0.5) * image.width / cols - left)
    reference_bounds = bounds[:1] if args.name == 'death' else bounds
    source_height = float(np.median([b[3] - b[1] for b in reference_bounds]))
    factor = args.height / source_height
    ground = float(np.median([b[3] for b in reference_bounds]))
    row_grounds = [ground] * rows
    if loop and rows > 1:
        # Generated source rows may use different baseline offsets. Register
        # whole rows, keeping every pose's relative bob within each row.
        row_grounds = [float(np.median([b[3] for b in bounds[r * cols:(r + 1) * cols]])) for r in range(rows)]
    if args.row_grounds:
        assert len(args.row_grounds) == rows, 'One source ground coordinate per row required'
        row_grounds = args.row_grounds
    strip = Image.new('RGBA', (400 * count, 336))
    frames = []
    output_bounds = []
    for i, cell in enumerate(cells):
        # Common scale and source-row offsets preserve pose bob and proportions.
        # Horizontal mapping uses the original source grid, not pose bounds.
        tx = centres[i] - 200 / factor + args.offset_x
        ty = row_grounds[i // cols] - 312 / factor
        frame = cell.transform((400, 336), Image.Transform.AFFINE,
                               (1 / factor, 0, tx, 0, 1 / factor, ty),
                               Image.Resampling.BICUBIC)
        bbox = frame.getbbox()
        assert bbox and bbox[0] > 0 and bbox[1] > 0 and bbox[2] < 400 and bbox[3] < 336, f'Clipped frame {i}: {bbox}'
        # Reject transforms that would discard visible source pixels.
        b = bounds[i]
        mapped = ((b[0] - tx) * factor, (b[1] - ty) * factor,
                  (b[2] - tx) * factor, (b[3] - ty) * factor)
        assert mapped[0] >= 1 and mapped[1] >= 1 and mapped[2] <= 399 and mapped[3] <= 335, f'Source exceeds cell {i}: {mapped}'
        strip.alpha_composite(frame, (400 * i, 0))
        frames.append(frame)
        output_bounds.append(bbox)
    filename = f'fremen_scout_{args.name}.png'
    strip.save(OUT / filename)
    preview_frames = []
    for frame in frames:
        panel = Image.new('RGB', (400, 170), '#d1b98a')
        draw = ImageDraw.Draw(panel)
        draw.rectangle((200, 0, 400, 170), fill='#373b40')
        thumb = frame.resize((86, 72), Image.Resampling.LANCZOS)
        panel.paste(thumb, (56, 60), thumb)
        panel.paste(thumb, (256, 60), thumb)
        draw.text((12, 12), f'{args.name} / sand', fill='#24211c')
        draw.text((212, 12), 'rock / ~60px body', fill='#eeeeee')
        preview_frames.append(panel)
    durations = [round(1000 / fps)] * count
    if not loop:
        durations[-1] = 1500
    preview_frames[0].save(OUT / 'review' / f'{args.name}.gif', save_all=True,
                           append_images=preview_frames[1:], duration=durations, loop=0)
    contact = Image.new('RGB', (400 * min(count, 4), 370 * ((count + 3) // 4)), '#75664e')
    for i, frame in enumerate(frames):
        pos = ((i % 4) * 400, (i // 4) * 370)
        contact.paste(frame, pos, frame)
        ImageDraw.Draw(contact).text((pos[0] + 12, pos[1] + 342), f'{args.name} {i + 1}', fill='white')
    contact.save(OUT / 'review' / f'{args.name}_frames.png')
    manifest_path = OUT / 'fremen_scout_animation_manifest.json'
    manifest = json.loads(manifest_path.read_text()) if manifest_path.exists() else {
        'character_name': 'fremen_scout',
        'canonical_reference': '../fremen_scout_idle.png, first 400x336 cell',
        'frame_size': [400, 336], 'reference_ground_anchor': [200, 312],
        'standing_reference_height': 280, 'generation_mode': 'built-in image_gen',
        'animations': [], 'overall_result': 'incomplete',
    }
    record = dict(name=args.name, filename=filename, requested_frame_count=count,
                  actual_frame_count=count, fps=fps, loop=loop, dimensions=list(strip.size),
                  generation_attempt_count=args.attempt, generation_status='generated',
                  validation_status='technical_checks_passed_visual_review_pending',
                  source=str(source.relative_to(OUT)), source_dimensions=list(image.size), source_grid=[cols, rows],
                  packing_scale=factor, source_ground_y=row_grounds,
                  low_alpha_noise_pixels_cleared=cleared, frame_bounds=output_bounds,
                  issues=[])
    manifest['animations'] = [r for r in manifest['animations'] if r['name'] != args.name] + [record]
    manifest_path.write_text(json.dumps(manifest, indent=2) + '\n')
    print(json.dumps(record))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('name', choices=SPEC)
    parser.add_argument('source')
    parser.add_argument('--height', type=float, default=280)
    parser.add_argument('--offset-x', type=float, default=0)
    parser.add_argument('--attempt', type=int, default=1)
    parser.add_argument('--columns', type=int)
    parser.add_argument('--row-grounds', nargs='+', type=float)
    pack(parser.parse_args())
