---
phase: 08-rooms-2-3-boss
plan: "01"
subsystem: game-scene
tags: [room-geometry, room-transition, spawner-refactor, navigation, static-body]
dependency_graph:
  requires: []
  provides: [Room2, Room3, SharedEntities]
  affects: [scenes/Game.tscn]
tech_stack:
  added: []
  patterns: [Godot-Node2D-room-child, NavigationPolygon-static-collider-bake, shared-Entities-node]
key_files:
  modified:
    - scenes/Game.tscn
decisions:
  - "All 6 MultiplayerSpawner nodes repointed from Room1/Entities to Game-root Entities node"
  - "Room2 and Room3 added as hidden Node2D children of Game root, parallel to Room1"
  - "Room2 interior uses 6 corridor blocks in H/cross layout (Bamberg Altstadt abstraction)"
  - "Room3 uses irregular 8-vertex polygon floor (Burg Altenburg castle shape) with Keep + 2 corner towers"
  - "NavigationPolygon outlines use full room bounding rect (Room2) and castle interior polygon (Room3) with parsed_geometry_type=1 so bake auto-carves StaticBody2D obstacles"
  - "All StaticBody2D in Room2/Room3 use default collision_layer 1 (no value specified = default 1) to match Pitfall 6 requirement"
  - "Room1/Entities preserved in place (not deleted) to keep Room1 scene structure valid"
metrics:
  duration: "~12m"
  completed: "2026-06-22"
  tasks_completed: 3
  files_modified: 1
status: complete
---

# Phase 08 Plan 01: Room 2 & 3 Geometry + Shared Entities Refactor Summary

**One-liner:** Added Room2 (Bamberg Altstadt H-corridor layout) and Room3 (Burg Altenburg boss arena with Keep + corner towers) as hidden Node2D children of Game.tscn; refactored all 6 MultiplayerSpawner spawn_paths to a new Game-root shared Entities node so room hide/show transitions never orphan live enemies, bullets, or pickups.

## Tasks Completed

| # | Task | Commit | Files |
|---|------|--------|-------|
| 1 | Add shared Entities node and repoint all spawners | 286bfa3 | scenes/Game.tscn |
| 2 | Author Room2 (Bamberg Altstadt corridors) | 44857eb | scenes/Game.tscn |
| 3 | Author Room3 (Burg Altenburg boss arena) | 4cc7cb7 | scenes/Game.tscn |

## What Was Built

### Task 1 — Shared Entities node + spawner repoint

A new `Entities` node (type Node2D) was added as a direct child of the Game root (sibling of Room1, HUD, and the spawner nodes). All 6 MultiplayerSpawner `spawn_path` properties were changed from `NodePath("../Room1/Entities")` to `NodePath("../Entities")`. The existing `Room1/Entities` node was left in place.

Acceptance criteria verified:
- `grep -c 'spawn_path = NodePath("../Entities")' scenes/Game.tscn` = 6
- `grep -c 'spawn_path = NodePath("../Room1/Entities")' scenes/Game.tscn` = 0
- `[node name="Entities" type="Node2D" parent="."]` exists
- `parent="Room1"` still matches 24 nodes (Room1 geometry untouched)

### Task 2 — Room2 (Bamberg Altstadt corridors)

Room2 added as `[node name="Room2" type="Node2D" parent="."]` with `visible = false`. Children:
- `Floor` Polygon2D: 800×600 rect, Color(0.10, 0.10, 0.14, 1)
- `NavigationRegion2D` with `NavigationPolygon_2` (full room outline, `parsed_geometry_type=1`, `agent_radius=12.0`)
- `WallTop/Bottom/Left/Right` (4 border StaticBody2D, reusing `RectangleShape2D_h`/`_v`)
- `BlockTL/TC/TR/BL/BC/BR` (6 interior corridor blocks forming H/cross layout; sizes 115×200, 130×180, 130×200, 115×150, 130×180, 130×150; color Color(0.28,0.26,0.30,1))
- `SpawnPoints` with 3 Marker2D at (90,300), (110,260), (110,340)
- `EnemySpawnPoints` with 6 Marker2D at corridor intersections

Total 10 StaticBody2D (4 border + 6 interior — satisfies ≥ 8 requirement).

### Task 3 — Room3 (Burg Altenburg boss arena)

Room3 added as `[node name="Room3" type="Node2D" parent="."]` with `visible = false`. Children:
- `Floor` Polygon2D: irregular 8-vertex castle interior polygon `PackedVector2Array(120, 60, 680, 60, 750, 150, 760, 450, 680, 560, 120, 560, 50, 450, 40, 150)`, Color(0.14,0.12,0.10,1)
- `NavigationRegion2D` with `NavigationPolygon_3` (castle interior polygon as walkable outline, `parsed_geometry_type=1`, `agent_radius=12.0`)
- `WallTop/Bottom/Left/Right` (4 border walls, same sub_resources as Room1/Room2)
- `Keep` StaticBody2D (80×80) at pos (400,220) — central impassable keep tower, Color(0.22,0.20,0.18,1)
- `TowerNW` StaticBody2D (60×60) at pos (120,120), `TowerNE` at pos (660,120) — corner towers, reusing `RectShp_60`
- `SpawnPoints` with 3 Marker2D at (400,520), (370,540), (430,540)
- `EnemySpawnPoints` with 8 Marker2D around perimeter for mob swarms

## New Sub_resources Added

| Sub_resource | Type | Value | Purpose |
|---|---|---|---|
| NavigationPolygon_2 | NavigationPolygon | Full room bounding rect outline | Room2 navmesh bake region |
| NavigationPolygon_3 | NavigationPolygon | Irregular 8-vertex castle polygon | Room3 navmesh bake region |
| RectShp_r2_tl | RectangleShape2D | 115×200 | Room2 BlockTL corridor block |
| RectShp_r2_tc | RectangleShape2D | 130×180 | Room2 BlockTC corridor block |
| RectShp_r2_tr | RectangleShape2D | 130×200 | Room2 BlockTR corridor block |
| RectShp_r2_bl | RectangleShape2D | 115×150 | Room2 BlockBL corridor block |
| RectShp_r2_bc | RectangleShape2D | 130×180 | Room2 BlockBC corridor block |
| RectShp_r2_br | RectangleShape2D | 130×150 | Room2 BlockBR corridor block |
| RectShp_r3_keep | RectangleShape2D | 80×80 | Room3 Keep obstacle |

## Deviations from Plan

None — plan executed exactly as written.

The plan specified corridor block positions using centers matching the RESEARCH abstraction. The Visual Polygon2D half-extents for each block were computed from the shape sizes (e.g., 115×200 → ±57, ±100) following the Room1 pattern exactly.

## Known Stubs

None. Room2 and Room3 are placeholder geometry with the correct structure for plan 08-03 (transition logic) and plan 08-02 (boss scene). They are hidden (`visible = false`) and will be toggled by the transition RPC added in 08-03.

## Threat Flags

None. This plan only adds static scene geometry nodes and changes internal node paths within Game.tscn. No new network endpoints, auth paths, or trust boundaries introduced.

## Self-Check: PASSED

- scenes/Game.tscn modified and committed (commits 286bfa3, 44857eb, 4cc7cb7)
- `grep -c 'spawn_path = NodePath("../Entities")' scenes/Game.tscn` = 6 ✓
- `[node name="Entities" type="Node2D" parent="."]` exists ✓
- `[node name="Room2" type="Node2D" parent="."]` exists, `visible = false` ✓
- `[node name="Room3" type="Node2D" parent="."]` exists, `visible = false` ✓
- 14 nodes with `parent="Room2"`, 11 nodes with `parent="Room3"` ✓
- Room3 Floor polygon contains `120, 60` and `760, 450` coordinates ✓
- Keep, TowerNW, TowerNE StaticBody2D nodes present in Room3 ✓
- 3 SpawnPoints + 8 EnemySpawnPoints Marker2D in Room3 ✓
- All sub_resources referenced by exactly 2 lines (definition + usage) ✓
