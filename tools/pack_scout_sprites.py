"""Cut the Scout's animation strips into frames and re-pack them on one grid.

The delivered strips each have their own scale and spacing, and neighbouring
frames overlap. Frames are separated with a minimum-cost vertical seam between
the expected frame centres (so a rifle tip touching the next cloak is cut at
the thinnest contact), then every animation is rescaled to a common figure
size and packed into fixed 400 x 336 cells with the feet on one line.
"""
import json
import os
import sys

import numpy as np
from PIL import Image

ROOT = r'E:\Dune'
# Superseded: the runtime Scout art now comes from the generated set
# (assets/characters/fremen_scout/generated, packed by
# tools/pack_character_sprites.py). This script only re-packs the first,
# hand-delivered strips, into their own folder so it can never overwrite the
# art the game uses.
SRC = os.path.join(ROOT, 'assets', 'characters', 'fremen_scout', 'source')
OUT = os.path.join(SRC, 'packed_first_delivery')
os.makedirs(OUT, exist_ok=True)
COUNTS = {'idle': 4, 'walk': 8, 'run': 8, 'crouch_walk': 8, 'crouch_idle': 4, 'aim': 4,
          'shoot': 4, 'reload': 10, 'crouch_shoot': 4, 'hit': 3, 'death': 8}
CELL_W, CELL_H, FEET = 400, 336, 312
# Standing figure height in the packed frames (matches the first test sheet).
TARGET_STANDING = 280.0
# Per-sheet scale correction relative to the standing reference, for sheets
# whose poses are not standing (crouches, death). Filled in by eye.
# Values chosen by eye against the rifle length in idle; see the git history.
POSE_FACTOR = json.loads(sys.argv[1]) if len(sys.argv) > 1 else {"crouch_walk": 0.97, "crouch_idle": 0.92, "crouch_shoot": 0.87}


def seam(alpha, x0, x1):
    """Minimum-alpha vertical path between columns x0 and x1."""
    h = alpha.shape[0]
    band = alpha[:, x0:x1].astype(np.float64)
    cost = band.copy()
    back = np.zeros_like(cost, dtype=np.int64)
    for y in range(1, h):
        prev = cost[y - 1]
        left = np.r_[np.inf, prev[:-1]]
        right = np.r_[prev[1:], np.inf]
        stack = np.vstack([left, prev, right])
        idx = np.argmin(stack, axis=0)
        cost[y] += stack[idx, np.arange(stack.shape[1])]
        back[y] = idx - 1
    xs = np.zeros(h, dtype=np.int64)
    xs[-1] = int(np.argmin(cost[-1]))
    for y in range(h - 1, 0, -1):
        xs[y - 1] = xs[y] + back[y, xs[y]]
    return xs + x0


def split(path, n):
    img = np.array(Image.open(path).convert('RGBA'))
    alpha = img[:, :, 3].astype(np.int64)
    h, w = alpha.shape
    cell = w / n
    centres = [(k + 0.5) * cell for k in range(n)]
    seams = [np.zeros(h, dtype=np.int64)]
    for k in range(n - 1):
        x0 = int(centres[k] + cell * 0.2)
        x1 = int(centres[k + 1] - cell * 0.2)
        seams.append(seam(alpha, x0, x1))
    seams.append(np.full(h, w, dtype=np.int64))
    frames = []
    cols = np.arange(w)
    for k in range(n):
        region = (cols[None, :] >= seams[k][:, None]) & (cols[None, :] < seams[k + 1][:, None])
        frame = img.copy()
        frame[~region] = 0
        ys, xs = np.nonzero(frame[:, :, 3] > 40)
        crop = frame[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
        frames.append(crop)
    return frames


def anchor_x(crop):
    """Body centre: mean x of the lower half (legs), rifle and cape excluded."""
    a = crop[:, :, 3] > 40
    lower = a[a.shape[0] // 2:]
    ys, xs = np.nonzero(lower)
    return float(xs.mean()) if xs.size else crop.shape[1] / 2


def pack(frames, scale):
    strip = Image.new('RGBA', (CELL_W * len(frames), CELL_H))
    for k, crop in enumerate(frames):
        im = Image.fromarray(crop)
        size = (max(1, round(im.width * scale)), max(1, round(im.height * scale)))
        im = im.resize(size, Image.LANCZOS)
        ax = anchor_x(crop) * scale
        x = int(round(k * CELL_W + CELL_W / 2 - ax))
        y = int(round(FEET - im.height))
        strip.alpha_composite(im, (max(x, k * CELL_W), max(y, 0)))
    return strip


def main():
    sheets = {}
    for name, n in COUNTS.items():
        sheets[name] = split(os.path.join(SRC, f'fremen_scout_{name}.png'), n)
    # Standing reference: median figure height of the upright animations.
    standing = ['idle', 'aim', 'shoot', 'walk', 'run', 'reload', 'hit']
    heights = {name: float(np.median([f.shape[0] for f in sheets[name]])) for name in sheets}
    report = {}
    for name, frames in sheets.items():
        if name == 'death':
            # Measured on the first frame, where he is still standing.
            base = float(frames[0].shape[0])
        else:
            base = heights[name] if name in standing else heights[name] / POSE_FACTOR.get(name, 1.0)
        scale = TARGET_STANDING / base
        report[name] = {'frames': len(frames), 'median_h': heights[name], 'scale': round(scale, 4)}
        pack(frames, scale).save(os.path.join(OUT, f'fremen_scout_{name}.png'))
    # Contact sheet: one frame of each, side by side, on a ground line.
    order = list(COUNTS)
    sheet = Image.new('RGBA', (CELL_W * len(order), CELL_H), (60, 52, 40, 255))
    for i, name in enumerate(order):
        strip = Image.open(os.path.join(OUT, f'fremen_scout_{name}.png'))
        frame = strip.crop((0, 0, CELL_W, CELL_H)) if name != 'death' else strip.crop((CELL_W * 7, 0, CELL_W * 8, CELL_H))
        sheet.alpha_composite(frame, (i * CELL_W, 0))
    arr = np.array(sheet)
    arr[FEET, :, :3] = (200, 60, 50)
    arr[FEET - int(TARGET_STANDING), :, :3] = (60, 160, 200)
    Image.fromarray(arr).save(r'E:\Dune\.validation\scout_contact.png')
    print(json.dumps(report, indent=1))


main()
