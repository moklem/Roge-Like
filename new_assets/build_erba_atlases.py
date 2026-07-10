#!/usr/bin/env python3
"""Build the ERBA tile atlases in assets/active/tilesets/erba/ from the
Lovable-generated flat-cartoon textures in new_assets/erba/.

Each floor/wall/road texture becomes a 2x2 MACRO BLOCK of 64px tiles (128px
per texture). RoomBuilder places the quadrant matching the cell position
(posmod(x,2), posmod(y,2)), so the art reads at double size (32 world px per
texture) while the 16px collision/layout grid stays untouched.

Cartoon-set specifics (Lovable delivery, 2026-07):
  - Only floor-grass-b is a calm plain tile; the a/c variants carry loud
    accents (cyan circuit line, drain grate) and are therefore placed in the
    RARE category alongside the stone slabs (each ~1/48 of floor cells).
  - Plain variants a/b/c are one base texture with +-4% brightness shifts.
  - floor-grass-tufts / floor-grass-flowers are SYNTHESIZED: prop-tufts and
    prop-flowers (white-bg props) composited onto the plain grass base.
  - Some deliveries have white margins (not full-bleed) -> unwhite() crops.
  - The connector road is cut as a square crop from the cobble side of the
    grass-to-cobble transition texture floor-connector.png.

Run from the repo root:  python3 new_assets/build_erba_atlases.py
"""
from PIL import Image
import numpy as np
from collections import deque

SRC = 'new_assets/erba'
OUT = 'assets/active/tilesets/erba'
T = 64        # tile size in the atlas (drawn at 16 world px -> 4x texel density)
B = 2 * T     # macro block: one texture spans 2x2 tiles

FACE_DARK = 0.55   # face brightness relative to the raw texture
FACE_DESAT = 0.85  # shadow surfaces lose a bit of saturation
CAP_DIM = 0.88     # caps slightly dimmed — brightest surface, but not glaring


def unwhite(path):
    """Open and crop away near-white margins (non-full-bleed generations)."""
    im = Image.open(path).convert('RGB')
    a = np.asarray(im)
    ys, xs = np.where(a.min(axis=2) < 235)
    return im.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1)).convert('RGBA')


def block(path):
    """Full-bleed (after margin crop) texture -> one 128px macro block."""
    return unwhite(path).resize((B, B), Image.LANCZOS)


def bright(im, f):
    a = np.asarray(im).astype(float)
    a[..., :3] = np.clip(a[..., :3] * f, 0, 255)
    return Image.fromarray(a.astype('uint8'))


def darkened(im, f=FACE_DARK, desat=FACE_DESAT, keep_glow=True):
    """Darken + slightly desaturate (shadowed vertical surface). Saturated
    cyan pixels (the cyber accents) keep their full glow."""
    orig = np.asarray(im).copy()
    a = orig.astype(float)
    rgb = a[..., :3] * f
    g = rgb.mean(axis=2, keepdims=True)
    a[..., :3] = g + (rgb - g) * desat
    out = np.clip(a, 0, 255).astype('uint8')
    if keep_glow:
        glow = (orig[..., 2] > 140) & (orig[..., 1] > 140) & (orig[..., 0] < 130)
        out[glow] = orig[glow]
    return Image.fromarray(out)


def keyed(path, global_white=False):
    """RGB prop on white background -> RGBA, cropped to content.
    BFS-clears the border-connected light background; global_white additionally
    keys enclosed white regions. Enclosed whites (flower petals) survive the
    default BFS mode."""
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


def fit(im, cw, ch):
    """Fit prop into cw x ch, aspect kept, bottom-center anchored."""
    s = min(cw / im.width, ch / im.height)
    nw, nh = max(1, round(im.width * s)), max(1, round(im.height * s))
    im = im.resize((nw, nh), Image.LANCZOS)
    cell = Image.new('RGBA', (cw, ch), (0, 0, 0, 0))
    cell.alpha_composite(im, ((cw - nw) // 2, ch - nh))
    return cell


def overlay(base, prop, scale, cx=0.5, cy=0.5):
    """Composite a keyed prop onto a copy of a base block, centered at
    (cx, cy) fractions, prop scaled to `scale` * block size."""
    tile = base.copy()
    s = round(B * scale)
    p = fit(prop, s, s)
    tile.alpha_composite(p, (round(B * cx - s / 2), round(B * cy - s / 2)))
    return tile


# ── floor atlas: 10 macro blocks side by side (1280x128) ─────────────────────
# 0-2 plain grass a/b/c | 3 tufts | 4 flowers | 5 slabs | 6 circuit | 7 grate
# | 8 shadow strong | 9 shadow soft  (shadow blocks duplicate plain-a;
# RoomBuilder darkens them via modulate)
plain = block(f'{SRC}/floor-grass-b.png')
tufts_tile = overlay(plain, keyed(f'{SRC}/prop-tufts.png'), 0.72)
flowers_tile = overlay(plain, keyed(f'{SRC}/prop-flowers.png'), 0.5)
floor_blocks = [
    ## +-2% only: on flat cartoon colors any stronger step reads as a
    ## hard-edged checkerboard instead of organic variation.
    plain, bright(plain, 0.98), bright(plain, 1.02),
    tufts_tile, flowers_tile,
    block(f'{SRC}/floor-slabs.png'),      # rare: stone slab patch
    block(f'{SRC}/floor-grass-a.png'),    # rare: cyan circuit line
    block(f'{SRC}/floor-grass-c.png'),    # rare: drain grate
    plain, plain,                         # shadow strong / soft
]
floor = Image.new('RGBA', (len(floor_blocks) * B, B), (0, 0, 0, 0))
for i, bl in enumerate(floor_blocks):
    floor.alpha_composite(bl, (i * B, 0))
floor.save(f'{OUT}/erba_floor.png')

# ── wall atlas: 4 macro blocks (512x128) — face-a, face-b, cap-a, cap-b ──────
# 2.5D wall: the bright CAP (top-down stone slabs) covers every wall cell
# except south edges, which show one row of the FACE. RoomBuilder always uses
# the BOTTOM half of a face block, so that half gets a clean cut of the
# texture's lower brick row + mossy base (the mid-texture cyan stripe of
# face-a sits right at the 50% line and must NOT bleed in). Faces are baked
# darker; cyan accents keep their glow.


def face_block(path):
    im = unwhite(path)
    w, h = im.size
    blk = Image.new('RGBA', (B, B))
    blk.paste(im.crop((0, 0, w, round(h * 0.44))).resize((B, T), Image.LANCZOS), (0, 0))
    blk.paste(im.crop((0, round(h * 0.56), w, h)).resize((B, T), Image.LANCZOS), (0, T))
    return darkened(blk)


wall = Image.new('RGBA', (4 * B, B), (0, 0, 0, 0))
wall.alpha_composite(face_block(f'{SRC}/wall-face-a.png'), (0, 0))
wall.alpha_composite(face_block(f'{SRC}/wall-face-b.png'), (B, 0))
wall.alpha_composite(darkened(block(f'{SRC}/wall-cap-a.png'), CAP_DIM, 1.0), (2 * B, 0))
wall.alpha_composite(darkened(block(f'{SRC}/wall-cap-b.png'), CAP_DIM, 1.0), (3 * B, 0))
wall.save(f'{OUT}/erba_wall.png')

# ── props atlas: 7x2 tiles (448x128) ─────────────────────────────────────────
# (0,0)-(1,1) rock pile 2x2 | (2,0) rock single | (3,0) pebbles | (4,0) stump
# (2,1) flowerpatch | (3,1) bush | (5,0)+(6,0) bench 2x1
props = Image.new('RGBA', (7 * T, 2 * T), (0, 0, 0, 0))
rocks = keyed(f'{SRC}/obstacle-rocks.png')
props.alpha_composite(fit(rocks, 2 * T, 2 * T), (0, 0))
props.alpha_composite(fit(rocks, T, T), (2 * T, 0))
props.alpha_composite(fit(keyed(f'{SRC}/prop-pebbles.png'), T, T), (3 * T, 0))
props.alpha_composite(fit(keyed(f'{SRC}/prop-stump.png'), T, T), (4 * T, 0))
props.alpha_composite(fit(keyed(f'{SRC}/prop-flowerpatch.png'), T, T), (2 * T, T))
props.alpha_composite(fit(keyed(f'{SRC}/prop-bush.png'), T, T), (3 * T, T))
props.alpha_composite(fit(keyed(f'{SRC}/prop-bench.png'), 2 * T, T), (5 * T, 0))
props.save(f'{OUT}/erba_props.png')

# ── road: square cobble crop from the transition texture (128x128) ──────────
road = Image.open(f'{SRC}/floor-connector.png').convert('RGBA') \
    .crop((640, 320, 1024, 704)).resize((B, B), Image.LANCZOS)
road.save(f'{OUT}/erba_road.png')

print('erba atlases built (macro blocks of %dpx tiles)' % T)
