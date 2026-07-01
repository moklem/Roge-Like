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
| 3 | ERBA Atlas (Cainos) | `assets/cainos/erba_atlas.png` | 4 cols × 2 rows |

---

## ERBA Atlas (source 3)

Used in **Room 1 (ERBA)** — replaces the Modern City tiles there. Purpose-built 16 px
atlas composed from the Cainos "Pixel Art Top Down - Basic" pack (source PNGs in
`assets/cainos/`, 32 px tiles halved with nearest-neighbor). No spacing, exact coords.

| Constant | Atlas Coord | Visual | Used in |
|----------|------------|--------|---------|
| `ERBA_FLOOR_GRASS` | `(0, 0)` | Plain grass | Room 1 primary floor |
| `ERBA_FLOOR_FLOWER` | `(1, 0)` | Grass with flower | Room 1 scatter (~2/9 of tiles) |
| `ERBA_FLOOR_SLABS` | `(2, 0)` | Stone slabs on grass | Room 1 scatter (~1/9 of tiles) |
| `ERBA_CONNECTOR_ROAD` | `(3, 0)` | Seamless stone road | Connector SR-6 (no mixing) |
| `ERBA_WALL_BRICK` | `(0, 1)` | Brick wall face | Wall cells with floor directly below (south-facing) |
| `ERBA_OBSTACLE_ROCK` | `(1, 1)` | Rock pile on grass | Room 1 obstacle blocks |
| `ERBA_WALL_CAP` | `(2, 1)` | Near-black brick top | All other wall cells (2.5D depth) |
| `ERBA_FLOOR_SHADOW` | `(3, 1)` | Darkened grass | Floor row under each wall face (contact shadow) |

2.5D rule (RoomBuilder step 6/6b, Enter-the-Gungeon look): a wall cell whose south
neighbor is floor renders the FACE; every other wall cell renders the CAP; the floor cell
under a face is swapped to `ERBA_FLOOR_SHADOW` (grass variants only — connector road
stays clean). Both wall tiles get the full-cell collision polygon.

Scatter rule (RoomBuilder, coordinate hash — no diagonal stripes):
```
scatter = (coords.x * 31 + coords.y * 17) % 9
scatter == 0   →  ERBA_FLOOR_SLABS
scatter <= 2   →  ERBA_FLOOR_FLOWER
else           →  ERBA_FLOOR_GRASS (base)
```
Regenerate the atlas with `assets/cainos/build_erba_atlas.gd` (run instructions in its
header). Tile picks from the pack: grass (1,1), flower (4,0), slabs (1,5), stone (1,1),
wall (1,7), rocks from props region (0,13)–(1,14) composited over grass.

---

## Roguelike Modern City (source 0)

Used in **Room 2 (Altstadt)** only (Room 1 switched to the ERBA Atlas, source 3).

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
Room 1 (ERBA):  see ERBA Atlas section above (scatter hash, source 3)

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
| 1 — ERBA | SR 1–5 | ERBA Atlas (3) | `(0,0)` + scatter | `(0,1)` | `(1,1)` |
| 1 — Connector | SR 6 | ERBA Atlas (3) | `(3,0)` | `(0,1)` | — |
| 2 — Altstadt | SR 1–5 | Modern City (0) | `(0,13)` + mix | `(0,0)` | `(3,0)` |
| 2 — Connector | SR 6 | Modern City (0) | `(0,15)` | `(0,0)` | — |
| 3 — Burg Altenburg | SR 1–4 | Tiny Dungeon (1) | `(0,1)` | `(0,0)` | `(2,0)` |
| 3 — Boss Arena | SR 5 | Tiny Dungeon (1) | `(0,1)` | `(0,0)` | `(2,0)` |

---

*Source files: `scenes/RoomLayouts.gd` (tile constants + layout data), `scenes/RoomBuilder.gd` (placement + mix logic)*
