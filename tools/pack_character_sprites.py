"""Pack character animation strips with common scale and registered source rows."""
import argparse
import json
from pathlib import Path
import shutil

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
SPEC = {
    'idle': (4, 6, True), 'walk': (8, 12, True), 'run': (8, 14, True),
    'crouch_walk': (8, 10, True), 'crouch_idle': (4, 5, True),
    'aim': (4, 6, True), 'shoot': (4, 16, False), 'reload': (10, 7, False),
    'crouch_shoot': (4, 16, False), 'hit': (3, 12, False), 'death': (8, 10, False),
}


def transparent_seam(alpha, expected, radius):
    """Find a separating path through fully transparent pixels; never cut art."""
    h, w = alpha.shape
    start, end = max(1, int(expected - radius)), min(w - 1, int(expected + radius))
    occupied = (alpha[:, start:end] > 0).astype(np.int32)
    cost = occupied.copy()
    back = np.zeros_like(cost, dtype=np.int8)
    for y in range(1, h):
        previous = cost[y - 1]
        choices = np.stack([np.r_[1000000, previous[:-1]], previous, np.r_[previous[1:], 1000000]])
        choice = choices.argmin(axis=0)
        cost[y] += choices[choice, np.arange(end - start)]
        back[y] = choice - 1
    candidates = np.where(cost[-1] == 0)[0]
    assert len(candidates), 'No transparent path between adjacent poses; regeneration required'
    x = int(candidates[np.argmin(np.abs(candidates + start - expected))])
    seam = np.zeros(h, dtype=np.int32)
    for y in range(h - 1, -1, -1):
        seam[y] = x + start
        x += int(back[y, x])
    return seam


def pack(args):
    out = ROOT / 'assets/characters' / args.character / 'generated'
    count, fps, loop = SPEC[args.name]
    for folder in [out, out / 'source', out / 'review']:
        folder.mkdir(parents=True, exist_ok=True)
    source = out / 'source' / f'{args.character}_{args.name}_attempt{args.attempt}.png'
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
    row_edges = [0]
    row_occupied = np.any(arr[:, :, 3] > 8, axis=1)
    empty_rows = np.where(~(row_occupied | np.roll(row_occupied, 1) | np.roll(row_occupied, -1)))[0]
    for row in range(1, rows):
        expected = row * image.height / rows
        candidates = empty_rows[np.abs(empty_rows - expected) < image.height / rows * 0.2]
        assert len(candidates), f'No transparent separation between source rows {row - 1} and {row}'
        row_edges.append(int(candidates[np.argmin(np.abs(candidates - expected))]))
    row_edges.append(image.height)
    seams_by_row = []
    for row in range(rows):
        top, bottom = row_edges[row:row + 2]
        occupied = np.any(arr[top:bottom, :, 3] > 8, axis=0)
        seams = [np.zeros(bottom - top, dtype=np.int32)]
        for col in range(1, cols):
            expected = col * image.width / cols
            radius = image.width / cols * 0.2
            candidates = np.where(~(occupied | np.roll(occupied, 1) | np.roll(occupied, -1)))[0]
            candidates = candidates[np.abs(candidates - expected) < radius]
            if len(candidates):
                seams.append(np.full(bottom - top, int(candidates[np.argmin(np.abs(candidates - expected))]), dtype=np.int32))
            else:
                seams.append(transparent_seam(arr[top:bottom, :, 3], expected, radius))
        seams.append(np.full(bottom - top, image.width, dtype=np.int32))
        seams_by_row.append(seams)
    for i in range(count):
        col, row = i % cols, i // cols
        left_seam, right_seam = seams_by_row[row][col:col + 2]
        left = max(0, int(left_seam.min()) - 2)
        right = min(image.width, int(right_seam.max()) + 2)
        top, bottom = row_edges[row:row + 2]
        pixels = arr[top:bottom, left:right].copy()
        xcoords = np.arange(left, right)[None, :]
        pixels[(xcoords < left_seam[:, None]) | (xcoords >= right_seam[:, None])] = 0
        cell = Image.fromarray(pixels)
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
    if (loop or args.register_rows) and rows > 1:
        # Generated source rows may use different baseline offsets. Register
        # whole rows, keeping every pose's relative bob within each row.
        row_grounds = [float(np.median([b[3] for b in bounds[r * cols:(r + 1) * cols]])) for r in range(rows)]
    if args.row_grounds:
        assert len(args.row_grounds) == rows, 'One source ground coordinate per row required'
        row_grounds = args.row_grounds
    strip = Image.new('RGBA', (400 * count, 336))
    frames = []
    output_bounds = []
    column_offsets = args.column_offsets or [0.0] * cols
    assert len(column_offsets) == cols, 'One horizontal registration offset per source column required'
    for i, cell in enumerate(cells):
        # Common scale and source-row offsets preserve pose bob and proportions.
        # Horizontal mapping uses the original source grid, not pose bounds.
        tx = centres[i] - 200 / factor + args.offset_x + column_offsets[i % cols]
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
    filename = f'{args.character}_{args.name}.png'
    strip.save(out / filename)
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
    preview_frames[0].save(out / 'review' / f'{args.name}.gif', save_all=True,
                           append_images=preview_frames[1:], duration=durations, loop=0)
    contact = Image.new('RGB', (400 * min(count, 4), 370 * ((count + 3) // 4)), '#75664e')
    for i, frame in enumerate(frames):
        pos = ((i % 4) * 400, (i // 4) * 370)
        contact.paste(frame, pos, frame)
        ImageDraw.Draw(contact).text((pos[0] + 12, pos[1] + 342), f'{args.name} {i + 1}', fill='white')
    contact.save(out / 'review' / f'{args.name}_frames.png')
    manifest_path = out / f'{args.character}_animation_manifest.json'
    manifest = json.loads(manifest_path.read_text(encoding='utf-8')) if manifest_path.exists() else {
        'character_name': args.character,
        'canonical_reference': args.reference,
        'frame_size': [400, 336], 'reference_ground_anchor': [200, 312],
        'standing_reference_height': 280, 'generation_mode': 'built-in image_gen',
        'animations': [], 'overall_result': 'incomplete',
    }
    record = dict(name=args.name, filename=filename, requested_frame_count=count,
                  actual_frame_count=count, fps=fps, loop=loop, dimensions=list(strip.size),
                  generation_attempt_count=args.attempt, generation_status='generated',
                  validation_status='technical_checks_passed_visual_review_pending',
                  source=str(source.relative_to(out)), source_dimensions=list(image.size), source_grid=[cols, rows],
                  packing_scale=factor, source_ground_y=row_grounds, source_row_edges=row_edges, source_column_offsets=column_offsets,
                  low_alpha_noise_pixels_cleared=cleared, frame_bounds=output_bounds,
                  issues=[])
    manifest['animations'] = [r for r in manifest['animations'] if r['name'] != args.name] + [record]
    manifest_path.write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(record))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('name', choices=SPEC)
    parser.add_argument('source')
    parser.add_argument('--character', choices=['paul', 'fremen_warrior', 'fremen_scout'], required=True)
    parser.add_argument('--reference', required=True, help='Canonical reference path recorded in the manifest')
    parser.add_argument('--height', type=float, default=280)
    parser.add_argument('--offset-x', type=float, default=0)
    parser.add_argument('--attempt', type=int, default=1)
    parser.add_argument('--columns', type=int)
    parser.add_argument('--row-grounds', nargs='+', type=float)
    parser.add_argument('--register-rows', action='store_true', help='Align planted-foot baseline independently for each source row')
    parser.add_argument('--column-offsets', nargs='+', type=float, help='Horizontal registration corrections per source column')
    pack(parser.parse_args())
