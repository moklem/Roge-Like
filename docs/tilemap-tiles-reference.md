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

---

## Roguelike Modern City (source 0)

Used in **Room 1 (ERBA)** and **Room 2 (Altstadt)**.

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
Room 1 (ERBA):
  mix_idx % 3 == 0  →  MC_FLOOR_CRACK      (0, 17)
  mix_idx % 3 == 1  →  MC_FLOOR_GRASS_ALT  (3, 16)
  mix_idx % 3 == 2  →  MC_FLOOR_GRASS      (0, 16)  ← base

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
| 1 — ERBA | SR 1–5 | Modern City (0) | `(0,16)` + mix | `(0,0)` | `(3,0)` |
| 1 — Connector | SR 6 | Modern City (0) | `(0,15)` | `(0,0)` | — |
| 2 — Altstadt | SR 1–5 | Modern City (0) | `(0,13)` + mix | `(0,0)` | `(3,0)` |
| 2 — Connector | SR 6 | Modern City (0) | `(0,15)` | `(0,0)` | — |
| 3 — Burg Altenburg | SR 1–4 | Tiny Dungeon (1) | `(0,1)` | `(0,0)` | `(2,0)` |
| 3 — Boss Arena | SR 5 | Tiny Dungeon (1) | `(0,1)` | `(0,0)` | `(2,0)` |

---

*Source files: `scenes/RoomLayouts.gd` (tile constants + layout data), `scenes/RoomBuilder.gd` (placement + mix logic)*
