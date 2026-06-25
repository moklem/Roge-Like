# Tilemap Wall/Tile Misalignment Fix

## Problem

In Rooms 2 and 3, walls visually appeared in the wrong place relative to their collision bodies.

## Root Causes

### 1. Wrong floor tile atlas coordinates (Rooms 1 & 2)

All four floor tile constants in `RoomLayouts.gd` pointed to rows 3–6 of the roguelike-modern-city tileset. Those rows are part of the large **building facade sprite** — reddish-brown tiles visually identical to the wall tiles at row 0.

Result: floors and walls rendered with the same graphic. Players walked through tiles that looked exactly like solid walls.

| Constant | Old (wrong) | New (correct) | Why |
|---|---|---|---|
| `MC_FLOOR_ASPHALT` | `(0, 3)` building wall | `(0, 13)` dark asphalt | Row 13 is confirmed dark gray road |
| `MC_FLOOR_GRASS` | `(0, 6)` building wall | `(0, 16)` green grass | Row 16 col 0 is confirmed green |
| `MC_FLOOR_GRASS_ALT` | `(1, 6)` building wall | `(3, 16)` green grass | Row 16 col 3, same hue variant |
| `MC_FLOOR_CRACK` | `(3, 3)` building wall | `(0, 17)` dark green | Row 17, darker ground variety |

Verified by pixel-sampling the PNG (592×448 = 37×28 tiles, no separators).

### 2. Room 2 connector used wrong tileset source

`RoomLayouts.gd` SR-6 (connector) for Room 2 had `tileset_src = 1` (SRC_DUNGEON), but `Room2/TileMap` uses `TileSetModern` which only registers **source ID 0**. Every `set_cell(..., source_id=1, ...)` call silently failed — the corridor had no tiles and no collision.

Fixed by setting `tileset_src = 0` (SRC_MODERN) and `floor_tile = Vector2i(0, 15)` (the confirmed dark road tile).

## Files Changed

- `scenes/RoomLayouts.gd` — atlas coordinate constants + Room 2 SR-6 connector layout
