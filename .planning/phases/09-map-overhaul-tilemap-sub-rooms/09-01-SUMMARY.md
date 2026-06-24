---
phase: 09-map-overhaul-tilemap-sub-rooms
plan: "01"
subsystem: tilemap-geometry
status: complete
tags:
  - tilemap
  - geometry
  - sub-rooms
  - room-layouts
  - godot4
dependency_graph:
  requires:
    - phase-07 (Game.gd structure, spawner paths, entity containers)
  provides:
    - scenes/RoomLayouts.gd (SUB_ROOM_DATA dictionary for all 17 sub-rooms)
    - scenes/Game.tscn Room1/TileMap (TileSetModern, collision_layer=1)
    - scenes/Game.tscn Room2/TileMap (TileSetModern, collision_layer=0)
    - scenes/Game.tscn Room3/TileMap (TileSetDungeon, collision_layer=0)
  affects:
    - scenes/Game.gd (spawner path now points to root Entities, not Room1/Entities)
    - Plan 02 (Camera2D — parallel, no dependency)
    - Plan 03 (RoomBuilder.gd — depends on SUB_ROOM_DATA shape from this plan)
tech_stack:
  added:
    - RoomLayouts.gd (class_name RoomLayouts, extends RefCounted, static data only)
    - TileSetAtlasSource sub-resources in Game.tscn for 3 Kenney tileset PNGs
    - TileSetModern sub-resource (physics_layer_0 + Roguelike Modern City atlas source)
    - TileSetDungeon sub-resource (physics_layer_0 + Tiny Dungeon + 1-Bit Pack atlas sources)
  patterns:
    - D-04: code-generated geometry via RoomBuilder.set_cell() (data layer established here)
    - D-21: single const per tileset path for swap-friendly asset replacement
    - Pitfall 4: Room2/3 TileMaps start with collision_layer=0 (hidden room safety)
key_files:
  created:
    - scenes/RoomLayouts.gd
  modified:
    - scenes/Game.tscn
decisions:
  - "TileSetAtlasSource texture_region_size=Vector2i(17,17): 16px tile + 1px spacing per Kenney Tilesheet.txt"
  - "Room1/Entities removed; spawners redirected to root-level Entities node — aligns with Phase 9 plan spec"
  - "Room2 and Room3 added as complete hidden nodes (not just TileMap addition) to enable full 3-room game flow from Phase 9 baseline"
  - "Two TileSet resources created (TileSetModern for R1+R2, TileSetDungeon for R3) rather than one shared resource — each room has distinct tileset visual identity"
  - "exit_tile_coords covers both x=width-2 and x=width-1 columns (2 columns wide for 2-tile-thick wall) per plan spec"
metrics:
  duration: "12 minutes"
  completed: "2026-06-24"
  tasks_completed: 2
  tasks_total: 2
  files_created: 1
  files_modified: 1
---

# Phase 09 Plan 01: TileMap Infrastructure — RoomLayouts.gd + Game.tscn Summary

TileMap infrastructure foundation: 17-sub-room static data dictionary in RoomLayouts.gd, and Game.tscn restructured with 3 clean TileMap-based Room nodes (all old StaticBody2D walls, Polygon2D floors removed).

## Tasks Completed

| Task | Name | Commit | Key Files |
|------|------|--------|-----------|
| 1 | Create RoomLayouts.gd — all 17 sub-room layout dictionaries | b1ffcc8 | scenes/RoomLayouts.gd (854 lines) |
| 2 | Restructure Game.tscn — TileMap for all 3 rooms, remove old geometry | 00d64a8 | scenes/Game.tscn |

## What Was Built

### Task 1: RoomLayouts.gd

A pure data file with `class_name RoomLayouts extends RefCounted`. Contains:

- `const TILE_SIZE: int = 16`
- `const TILESET_MODERN_PATH`, `TILESET_DUNGEON_PATH`, `TILESET_1BIT_PATH` (D-21 swap-friendly)
- Source ID constants: `SRC_MODERN = 0`, `SRC_DUNGEON = 1`, `SRC_1BIT = 2`
- Atlas coordinate constants for both tilesets (all marked [ASSUMED] — visual estimates from PNG inspection; swappable 1-line)
- `static var SUB_ROOM_DATA: Dictionary` with all 17 sub-room entries:
  - Room 1 ERBA: SR-1 (50×35) through SR-5 (65×44), plus SR-6 connector (80×10 road tiles)
  - Room 2 Altstadt: SR-1 (55×38) through SR-5 (65×45), plus SR-6 connector (80×10 stone path, SRC_DUNGEON for transitional feel)
  - Room 3 Burg Altenburg: SR-1 (55×40) through SR-4 (65×44), plus SR-5 boss arena (70×50, `exit_dir=Vector2i(0,0)`)

Each sub-room entry carries the full D-06 extended shape: `floor`, `walls`, `obstacles`, `exit_dir`, `exit_tile_coords`, `spawn_points`, `enemy_spawns`, `width_tiles`, `height_tiles`, `tileset_src`, `floor_tile`, `wall_tile`, `obstacle_tile`.

### Task 2: Game.tscn Restructure

Complete restructure of Game.tscn:

**Removed from Room1:**
- `Room1/Floor` (Polygon2D)
- `Room1/WallTop`, `WallBottom`, `WallLeft`, `WallRight` (StaticBody2D × 4)
- `Room1/DividerTop`, `DividerBottom` (StaticBody2D × 2)
- `Room1/ObstNW`, `ObstSW`, `ObstNE`, `ObstSE`, `ObstCL`, `ObstCR` (StaticBody2D × 6)
- `Room1/ObstPassN`, `ObstPassS` (StaticBody2D × 2)
- `Room1/CoverL1`, `CoverL2`, `CoverR1`, `CoverR2` (StaticBody2D × 4)
- `Room1/Entities` (room-scoped Node2D — moved to root level)

**Updated in Room1:**
- `Room1/TileMap`: TileSet changed from empty `TileSet_1` to `TileSetModern` (with `TileSetAtlasSource_modern`), `collision_layer=1`

**Added:**
- `Room2` (Node2D, `visible=false`) with TileMap (`TileSetModern`, `collision_layer=0`), NavigationRegion2D, SpawnPoints, EnemySpawnPoints
- `Room3` (Node2D, `visible=false`) with TileMap (`TileSetDungeon`, `collision_layer=0`), NavigationRegion2D, SpawnPoints, EnemySpawnPoints
- 3 new sub-resources: `TileSetAtlasSource_modern`, `TileSetAtlasSource_dungeon`, `TileSetAtlasSource_1bit`
- 2 new TileSet sub-resources: `TileSetModern` (R1+R2), `TileSetDungeon` (R3)
- 2 new NavigationPolygon sub-resources: `NavigationPolygon_2` (R2), `NavigationPolygon_3` (R3)
- Root-level `Entities` node; spawner spawn_paths updated to `../Entities`

**Final Room structure:**
```
Room1 (Node2D, visible=true)
├── TileMap (TileSetModern, collision_layer=1) — empty at startup, RoomBuilder fills
├── NavigationRegion2D
├── SpawnPoints → Spawn1/2/3
└── EnemySpawnPoints → ESpawn1–8

Room2 (Node2D, visible=false)
├── TileMap (TileSetModern, collision_layer=0)
├── NavigationRegion2D
├── SpawnPoints → Spawn1/2/3
└── EnemySpawnPoints → ESpawn1–6

Room3 (Node2D, visible=false)
├── TileMap (TileSetDungeon, collision_layer=0)
├── NavigationRegion2D
├── SpawnPoints → Spawn1/2/3
└── EnemySpawnPoints → ESpawn1–8
```

## Deviations from Plan

### Auto-handled Context Differences

**[Rule 3 - Blocking] Phase 7 worktree missing Room2/Room3 nodes**
- **Found during:** Task 2 — the worktree was branched at Phase 7 (commit a6a5004); Game.tscn had only Room1 with spawners pointing to `Room1/Entities`
- **Issue:** The plan assumed Game.tscn was at Phase 8 state (Room2/Room3 already present), but the worktree was at Phase 7 state
- **Fix:** Created Room2 and Room3 nodes from scratch (not "added TileMap to existing nodes") and redirected spawners from `Room1/Entities` to the root-level `Entities` node
- **Files modified:** scenes/Game.tscn
- **Commit:** 00d64a8

**[Rule 2 - Missing Critical] Root-level Entities node**
- The Phase 7 worktree had `Room1/Entities` and spawners pointing there. Phase 9 plan requires `Entities` at root level (consistent with the plan's architecture and what the main repo has). Added `[node name="Entities" type="Node2D" parent="."]` at root and updated all 6 MultiplayerSpawner `spawn_path` values.

## Verification Results

| Check | Expected | Result | Status |
|-------|----------|--------|--------|
| `grep -c 'type="TileMap"' scenes/Game.tscn` | 3 | 3 | PASS |
| `grep -c "StaticBody2D" scenes/Game.tscn` | 0 | 0 | PASS |
| `grep -c "Polygon2D" scenes/Game.tscn` | 0 | 0 | PASS |
| `grep -c "SUB_ROOM_DATA" scenes/RoomLayouts.gd` | >= 1 | 3 | PASS |
| `grep "TILESET_MODERN_PATH" scenes/RoomLayouts.gd` | shows const | shows const | PASS |
| `grep "OSMRoomGenerator" scenes/Game.tscn` | empty | empty | PASS |
| Room2/Room3 TileMaps have collision_layer=0 | yes | yes | PASS |
| Room1 TileMap has collision_layer=1 | yes | yes | PASS |
| TileSet sub-resources reference Kenney asset paths | yes | yes | PASS |

## Known Stubs

**Atlas coordinate constants in RoomLayouts.gd are visual estimates:**
- `MC_FLOOR_ASPHALT`, `MC_FLOOR_GRASS`, etc. — all marked `[ASSUMED]`
- Actual visual accuracy depends on Kenney tilemap PNG layout; wrong coords = wrong tile visual but no crash
- These are swappable 1-line constant changes per D-21

**TileSet physics collision requires per-tile shape assignment:**
- Per RESEARCH.md Pitfall 1 (A8): TileSet has `physics_layer_0/collision_layer=1` set but individual tile shapes must be assigned in Godot's TileSet editor before TileMap tiles generate collision bodies
- This is editor configuration, not code — Plan 03 (RoomBuilder) will verify collision works at runtime; if tiles don't collide, the Godot TileSet editor step is needed

## Threat Flags

No new security-relevant surface introduced. RoomLayouts.gd is pure static GDScript data (no network endpoints, no user input, no file access). Game.tscn restructure removes the OSMRoomGenerator HTTP dependency, reducing the attack surface.

## Self-Check: PASSED

- scenes/RoomLayouts.gd: EXISTS (commit b1ffcc8)
- scenes/Game.tscn: MODIFIED (commit 00d64a8)
- All verification grep checks: PASSED
- No OSMRoomGenerator references remain in either file
- 17 sub-room entries in SUB_ROOM_DATA (confirmed by width_tiles count = 17 + 1 comment line)
