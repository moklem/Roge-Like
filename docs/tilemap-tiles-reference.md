# Tilemap Tiles Reference

All atlas coordinates are **[col, row]**, 0-indexed from top-left.
Tile size: **16 px**. Spacing: **16+1 px** (1 px gap between tiles in packed sheets).

---

## Tilesets

| Source ID | Name | File | Grid |
|-----------|------|------|------|
| 0 | Roguelike Modern City | `assets/kenney/roguelike-modern-city/Tilemap/tilemap_packed.png` | 37 cols × 28 rows |
| 1 | Tiny Dungeon | `assets/kenney/tiny-dungeon/Tilemap/tilemap_packed.png` | 12 cols × 11 rows |
| 2 | 1-Bit Pack *(unused)* | `assets/kenney/1-bit-pack/Tilemap/tileset_legacy.png` | 49 cols × 22 rows |
| 3 | ERBA Grass (Cainos) | `assets/cainos/TX Tileset Grass.png` | 8 × 8 @ 32 px |
| 4 | ERBA Wall (Cainos) | `assets/cainos/TX Tileset Wall.png` | 16 × 16 @ 32 px |
| 5 | ERBA Props (Cainos) | `assets/cainos/TX Props.png` | 16 × 16 @ 32 px |
| 6 | ERBA Stone (Cainos) | `assets/cainos/TX Tileset Stone Ground.png` | 8 × 8 @ 32 px |
| 10–15 | Altstadt (janv2, custom art) | `assets/janv2/modern-city/*.png` | 1 tile @ 32 px each |

Altstadt sources (on `TileSetAltstadt`, Room2/TileMap at scale 0.5, all coords `(0,0)`):
10 asphalt floor · 11 mossy grass patch (~1/10 hash mix) · 12 connector road ·
13 wall face · 14 roof obstacle (layer 1, transparent corners) · 15 wall cap
(same wall texture, modulate 0.55 — 2.5D top). Face/cap rule identical to ERBA.
To swap art: overwrite the PNGs in `assets/janv2/modern-city/` (same names/32 px).

---

## ERBA sources 3–6 (Cainos "Pixel Art Top Down - Basic")

Used in **Room 1 (ERBA)** only. The ORIGINAL 32 px sheets are registered directly —
`Room1/TileMap` has its own `TileSetErba` (tile_size 32) at **node scale 0.5**, so tile
grid coords and every pixel position stay identical to the 16 px rooms while the art
keeps its full resolution. Sources 3–6 live on `TileSetErba`, not on `TileSetModern`.

Tile picks (constants in `RoomLayouts.gd`, opacity verified by sheet scan):

| Constant | Source | Coords | Role |
|----------|--------|--------|------|
| `ERBA_GRASS_PLAIN` | 3 | 6 variants | Base floor |
| `ERBA_GRASS_DETAIL` | 3 | 6 variants | Flowers/tufts (~3/16 of cells) |
| `ERBA_GRASS_SLABS` | 3 | 4 variants | Stone slabs (~1/16 of cells) |
| `ERBA_FLOOR_SHADOW` | 3 | `(1, 2)` | Contact shadow (modulate 0.66) |
| `ERBA_WALL_FACES` | 4 | 4 variants (row 7) | South-facing wall cells |
| `ERBA_WALL_CAPS` | 4 | 4 variants (row 10) | Other wall cells (modulate 0.32) |
| `ERBA_ROCK_ORIGIN` | 5 | `(0, 13)` 2×2 pile | Obstacle rects, tiled by `(x%2, y%2)` |
| `ERBA_PEBBLES` | 5 | 4 variants (row 15) | Deco scatter (~1/29, no collision) |
| `ERBA_CONNECTOR_ROAD` | 6 | `(1, 1)` | Connector SR-6 floor (no mixing) |

Placement rules (RoomBuilder):
- **2.5D depth** (Enter-the-Gungeon look): wall cell with floor directly below → FACE;
  every other wall cell → dark CAP; grass under a face → `ERBA_FLOOR_SHADOW`.
  Faces, caps, and rock tiles carry the full-cell collision polygon (32 px half-extent).
- **Layers:** props (rocks, pebbles) go on TileMap **layer 1** above the grass floor,
  since they have transparent edges.
- **Variation:** all picks use `_cell_hash()` (xor-shift scramble) — a plain linear hash
  like `(x*31 + y*17) % 16` degenerates to diagonal stripes.

---

## Roguelike Modern City (source 0)

Used in **Room 2 (Altstadt)** only (Room 1 switched to the Cainos sources 3–6).

| Constant | Atlas Coord | Visual | Used in |
|----------|------------|--------|---------|
| `MC_FLOOR_GRASS` | `(0, 16)` | Green grass | Room 1 primary floor; Room 2 floor mix (every 10th tile) |
| `MC_FLOOR_GRASS_ALT` | `(3, 16)` | Lighter grass variant | Room 1 floor mix (`mix_idx % 3 == 1`) |
| `MC_FLOOR_CRACK` | `(0, 17)` | Darker cracked ground | Room 1 floor mix (`mix_idx % 3 == 0`) |
| `MC_FLOOR_ASPHALT` | `(0, 13)` | Dark gray asphalt | Room 2 primary floor |
| `MC_CONNECTOR_ROAD` | `(0, 15)` | Pure dark road surface | Connector SR-6 for Room 1 & 2 |
| `MC_WALL_BRICK` | `(0, 0)` | Dark brick building wall | Room 1 & 2 all perimeter walls |
| `MC_OBSTACLE_ROOF` | `(3, 0)` | Building rooftop | Room 1 & 2 all obstacle blocks |

### Floor mix rules (Room 1 & 2, computed per tile from `x_off + y_off`)

```
Room 1 (ERBA):  see ERBA sources section above (hash-weighted variants, sources 3-6)

Room 2 (Altstadt):
  mix_idx % 10 == 0  →  MC_FLOOR_GRASS   (0, 16)
  all other tiles    →  MC_FLOOR_ASPHALT (0, 13)  ← base

Room 3 (Burg):
  no mixing — pure stone TD_FLOOR_STONE (0, 1)
```

### Defined but not currently used

| Constant | Atlas Coord | Note |
|----------|------------|------|
| `MC_WALL_BRICK_ALT` | `(1, 0)` | Lighter brick variant |
| `MC_OBSTACLE_ROOF_ALT` | `(4, 0)` | Lighter rooftop variant |
| `MC_CONNECTOR_CENTER` | `(5, 15)` | Road center marking stripe |

---

## Tiny Dungeon (source 1)

Used in **Room 3 (Burg Altenburg)**.

| Constant | Atlas Coord | Visual | Used in |
|----------|------------|--------|---------|
| `TD_FLOOR_STONE` | `(0, 1)` | Gray cobblestone floor | Room 3 all floors (SR 1–5) |
| `TD_WALL_CASTLE` | `(0, 0)` | Castle stone wall block | Room 3 all perimeter walls |
| `TD_OBSTACLE_TOWER` | `(2, 0)` | Tower / turret top | Room 3 all obstacle blocks |

### Defined but not currently used

| Constant | Atlas Coord | Note |
|----------|------------|------|
| `TD_FLOOR_STONE_DARK` | `(1, 1)` | Darker stone variant |
| `TD_WALL_CASTLE_ALT` | `(1, 0)` | Darker wall block |

---

## 1-Bit Pack (source 2) — fully unused

Defined in `RoomLayouts.gd` as fallback constants but no sub-room sets `tileset_src: 2`.

| Constant | Atlas Coord |
|----------|------------|
| `BIT_WALL_FILL` | `(2, 0)` |
| `BIT_FLOOR_FILL` | `(0, 4)` |

---

## Per-room summary

| Room | Sub-rooms | Tileset | Floor | Wall | Obstacle |
|------|-----------|---------|-------|------|----------|
| 1 — ERBA | SR 1–5 | Cainos (3–5) | grass variants | faces/caps (4) | rock pile (5, layer 1) |
| 1 — Connector | SR 6 | Cainos (4/6) | stone `(1,1)` (6) | faces/caps (4) | — |
| 2 — Altstadt | SR 1–5 | Modern City (0) | `(0,13)` + mix | `(0,0)` | `(3,0)` |
| 2 — Connector | SR 6 | Modern City (0) | `(0,15)` | `(0,0)` | — |
| 3 — Burg Altenburg | SR 1–4 | Tiny Dungeon (1) | `(0,1)` | `(0,0)` | `(2,0)` |
| 3 — Boss Arena | SR 5 | Tiny Dungeon (1) | `(0,1)` | `(0,0)` | `(2,0)` |

---

*Source files: `scenes/RoomLayouts.gd` (tile constants + layout data), `scenes/RoomBuilder.gd` (placement + mix logic)*
