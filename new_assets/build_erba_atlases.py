#!/usr/bin/env python3
"""Build the ERBA tile atlases in assets/active/tilesets/erba/ from the raw
AI-generated textures in new_assets/erba/.

Each floor/wall/road texture becomes a 2x2 MACRO BLOCK of 64px tiles (128px
per texture). RoomBuilder places the quadrant matching the cell position
(posmod(x,2), posmod(y,2)), so the art reads at double size (32 world px per
texture) while the 16px collision/layout grid stays untouched.

Run from the repo root:  python3 new_assets/build_erba_atlases.py
"""
from PIL import Image
import numpy as np
from collections import deque

SRC = 'new_assets/erba'
OUT = 'assets/active/tilesets/erba'
T = 64        # tile size in the atlas (drawn at 16 world px -> 4x texel density)
B = 2 * T     # macro block: one texture spans 2x2 tiles


def block(path):
    """Full-bleed texture -> one 128px macro block."""
    return Image.open(path).convert('RGBA').resize((B, B), Image.LANCZOS)


def keyed(path, global_white=False):
    """RGB prop on white background -> RGBA, cropped to content.
    BFS-clears the border-connected light background; global_white additionally
    keys enclosed white regions (needed for the bench's backrest gaps)."""
    im = Image.open(path).convert('RGBA')
    a = np.asarray(im).copy()
    minrgb = a[..., :3].min(axis=2).astype(int)
    h, w = minrgb.shape
    if global_white:
        a[..., 3] = np.where(minrgb > 205, 0, a[..., 3])
    else:
        bg = minrgb > 200
        mask = np.zeros((h, w), bool)
        dq = deque()
        for x in range(w):
            for y in (0, h - 1):
                if bg[y, x] and not mask[y, x]:
                    mask[y, x] = True
                    dq.append((y, x))
        for y in range(h):
            for x in (0, w - 1):
                if bg[y, x] and not mask[y, x]:
                    mask[y, x] = True
                    dq.append((y, x))
        while dq:
            y, x = dq.popleft()
            for ny, nx in ((y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)):
                if 0 <= ny < h and 0 <= nx < w and bg[ny, nx] and not mask[ny, nx]:
                    mask[ny, nx] = True
                    dq.append((ny, nx))
        a[..., 3] = np.where(mask, 0, a[..., 3])
    out = Image.fromarray(a)
    return out.crop(out.split()[3].getbbox())


def cropped(path):
    im = Image.open(path).convert('RGBA')
    return im.crop(im.split()[3].getbbox())


def fit(im, cw, ch):
    """Fit prop into cw x ch, aspect kept, bottom-center anchored."""
    s = min(cw / im.width, ch / im.height)
    nw, nh = max(1, round(im.width * s)), max(1, round(im.height * s))
    im = im.resize((nw, nh), Image.LANCZOS)
    cell = Image.new('RGBA', (cw, ch), (0, 0, 0, 0))
    cell.alpha_composite(im, ((cw - nw) // 2, ch - nh))
    return cell


# ── floor atlas: 8 macro blocks side by side (1024x128) ──────────────────────
# blocks 0-2 grass a/b/c | 3 tufts | 4 flowers | 5 slabs | 6 shadow strong | 7 soft
# (shadow blocks duplicate grass-a; RoomBuilder darkens them via modulate)
floor_names = ['floor-grass-a', 'floor-grass-b', 'floor-grass-c',
               'floor-grass-tufts', 'floor-grass-flowers', 'floor-slabs',
               'floor-grass-a', 'floor-grass-a']
floor = Image.new('RGBA', (len(floor_names) * B, B), (0, 0, 0, 0))
for i, n in enumerate(floor_names):
    floor.alpha_composite(block(f'{SRC}/{n}.png'), (i * B, 0))
floor.save(f'{OUT}/erba_floor.png')

# ── wall atlas: 2 macro blocks (256x128) — face-a, face-b ────────────────────
# One block = one full brick texture across the 2-cells-wide, 2-rows-high wall.
wall = Image.new('RGBA', (2 * B, B), (0, 0, 0, 0))
wall.alpha_composite(block(f'{SRC}/wall-face-a.png'), (0, 0))
wall.alpha_composite(block(f'{SRC}/wall-face-b.png'), (B, 0))
wall.save(f'{OUT}/erba_wall.png')

# ── props atlas: 7x2 tiles (448x128) ─────────────────────────────────────────
# (0,0)-(1,1) rock pile 2x2 | (2,0) rock single | (3,0) pebbles | (4,0) stump
# (2,1) flowerpatch | (3,1) bush | (5,0)+(6,0) bench 2x1
props = Image.new('RGBA', (7 * T, 2 * T), (0, 0, 0, 0))
rocks = keyed(f'{SRC}/obstacle-rocks.png')
props.alpha_composite(fit(rocks, 2 * T, 2 * T), (0, 0))
props.alpha_composite(fit(rocks, T, T), (2 * T, 0))
props.alpha_composite(fit(cropped(f'{SRC}/prop-pebbles.png'), T, T), (3 * T, 0))
props.alpha_composite(fit(keyed(f'{SRC}/prop-stump.png'), T, T), (4 * T, 0))
props.alpha_composite(fit(cropped(f'{SRC}/prop-flowerpatch.png'), T, T), (2 * T, T))
props.alpha_composite(fit(cropped(f'{SRC}/prop-bush.png'), T, T), (3 * T, T))
props.alpha_composite(fit(keyed(f'{SRC}/prop-bench.png', global_white=True), 2 * T, T), (5 * T, 0))
props.save(f'{OUT}/erba_props.png')

# ── road: one macro block (128x128) ──────────────────────────────────────────
block(f'{SRC}/floor-connector.png').save(f'{OUT}/erba_road.png')

print('erba atlases built (macro blocks of %dpx tiles)' % T)
