---
phase: 09-map-overhaul-tilemap-sub-rooms
plan: "03"
subsystem: sub-room-state-machine
status: complete
tags:
  - tilemap
  - sub-rooms
  - room-builder
  - state-machine
  - rpc
  - godot4
dependency_graph:
  requires:
    - 09-01 (RoomLayouts.gd SUB_ROOM_DATA, Game.tscn TileMap nodes)
  provides:
    - scenes/RoomBuilder.gd (build_sub_room, build_connector, set_tilemap_collision)
    - scenes/Game.gd (current_sub_room, _transition_to_sub_room RPC, _open_exit_passage RPC, _check_sub_room_clear, _teleport_players_to_spawn)
  affects:
    - scenes/Game.gd (OSMRoomGenerator removed, _bake_navigation updated, _process updated, _on_enemy_died updated)
    - scenes/OSMRoomGenerator.gd (deleted)
tech_stack:
  added:
    - RoomBuilder.gd (class_name RoomBuilder, extends RefCounted, functional style)
  patterns:
    - D-04: TileMap population via set_cell() driven by SUB_ROOM_DATA
    - D-08: host-authoritative exit passage via @rpc("authority","call_local")
    - D-10: current_sub_room state tracker reset on room transition
    - D-12: connector exit detection in _process() with guard flag
    - Pitfall 4: TileMap collision toggle via set_tilemap_collision on room hide/show
    - T-09-03: @rpc("authority") prevents client sub-room transition manipulation
    - T-09-04: @rpc("authority") prevents client exit passage opening
key_files:
  created:
    - scenes/RoomBuilder.gd
  modified:
    - scenes/Game.gd
  deleted:
    - scenes/OSMRoomGenerator.gd
    - scenes/OSMRoomGenerator.gd.uid
decisions:
  - "RoomBuilder extends RefCounted (not Node) — no _ready(), no scene lifecycle, pure functional"
  - "build_sub_room returns Rect2 pixel bounds — Game.gd uses this for camera limit updates"
  - "_bake_navigation awaits process_frame before bake to ensure set_cell() changes register in physics"
  - "_transition_to_room now builds sub-room 1 of the new location via RoomBuilder (not OSMRoomGenerator)"
  - "_check_sub_room_clear and _check_room_clear both called from _on_enemy_died (belt-and-suspenders)"
  - "Connector exit detection uses position.x threshold in _process() with _connector_triggered guard"
  - "Boss arena (Room 3 SR-5) handled: _transition_to_sub_room routes to _spawn_boss.call_deferred()"
  - "Wave 1 merge required: worktree was at Phase 7 state; merged main to get RoomLayouts.gd and TileMap infrastructure"
metrics:
  duration: "~5 minutes"
  completed: "2026-06-24"
  tasks_completed: 2
  tasks_total: 2
  files_created: 1
  files_modified: 1
  files_deleted: 2
---

# Phase 09 Plan 03: RoomBuilder + Sub-Room State Machine Summary

RoomBuilder.gd TileMap population engine and sub-room progression state machine in Game.gd. OSMRoomGenerator.gd deleted. Game loads Room 1 sub-room 1 tiles on startup; clearing enemies opens exit passage; reaching corridor end triggers location transition.

## Tasks Completed

| Task | Name | Commit | Key Files |
|------|------|--------|-----------|
| 1 | Create RoomBuilder.gd — TileMap population engine | 2d73aff | scenes/RoomBuilder.gd (135 lines) |
| 2 | Game.gd sub-room state machine + OSMRoomGenerator removal | dce19cf | scenes/Game.gd (+146/-286), OSMRoomGenerator.gd deleted |

## What Was Built

### Task 1: RoomBuilder.gd

Pure functional class (`class_name RoomBuilder extends RefCounted`) with three methods:

**`build_sub_room(room_id, sub_room_id, game_node) -> Rect2`**
1. Retrieves `RoomLayouts.SUB_ROOM_DATA[room_id][sub_room_id]`
2. Gets `Room{N}/TileMap` node and calls `tilemap.clear()`
3. Places floor tiles with room-specific mix rules:
   - Room 1 ERBA: every 3rd tile cycles crack/grass_alt (ERBA visual identity from UI-SPEC)
   - Room 2 Altstadt: every 10th tile gets grass patch
   - Room 3 Burg: pure stone, no mixing
4. Places wall tiles (nested rect iteration)
5. Places obstacle tiles (nested rect iteration)
6. Repopulates `Room{N}/SpawnPoints` children with new Marker2D nodes from layout
7. Repopulates `Room{N}/EnemySpawnPoints` children with new Marker2D nodes
8. Stores `layout["exit_tile_coords"]` on `game_node._exit_tile_coords`
9. Returns `Rect2(0, 0, width_tiles * TILE_SIZE, height_tiles * TILE_SIZE)`

**`build_connector(room_id, game_node) -> Rect2`** — delegates to `build_sub_room(room_id, 6, game_node)`

**`set_tilemap_collision(room_id, enabled, game_node)`** — toggles `collision_layer` and `collision_mask` on the room's TileMap (Pitfall 4 mitigation)

### Task 2: Game.gd Sub-Room State Machine

New vars added:
- `var current_sub_room: int = 1` — sub-room position within current location
- `var _exit_tile_coords: Array[Vector2i] = []` — set by RoomBuilder, read by _open_exit_passage
- `var _room_builder: RoomBuilder = null` — instantiated in _ready()
- `var _current_sub_room_rect_px: Rect2` — pixel bounds for camera limits
- `var _connector_triggered: bool = false` — prevents double-trigger on connector exit

New methods:

**`_transition_to_sub_room(next: int)` `@rpc("authority","call_local","reliable")`** — builds next sub-room tiles, teleports players, bakes nav; on host spawns enemies or boss (T-09-03).

**`_check_sub_room_clear()`** — host counts alive enemies in current room; when zero, calls `_open_exit_passage.rpc()` (MAP-02).

**`_open_exit_passage()` `@rpc("authority","call_local","reliable")`** — replaces `_exit_tile_coords` wall tiles with floor tiles on all peers simultaneously (T-09-04).

**`_teleport_players_to_spawn()`** — moves all players to updated SpawnPoints children.

Modified methods:
- `_ready()`: OSMRoomGenerator block replaced with `_room_builder = RoomBuilder.new()` + `build_sub_room(1, 1, self)`
- `_bake_navigation()`: added `await get_tree().process_frame` before bake
- `_transition_to_room()`: added TileMap collision toggle, reset `current_sub_room=1`, build sub-room 1 of new location, use `_teleport_players_to_spawn()`
- `_on_enemy_died()`: added `_check_sub_room_clear.call_deferred()`
- `_process()`: added connector exit detection (sub-room 6 x-position threshold)
- Removed `_on_osm_room_ready()` method

Deleted:
- `scenes/OSMRoomGenerator.gd` — network-based room generator (MAP-09)
- `scenes/OSMRoomGenerator.gd.uid`

## Deviations from Plan

### Pre-task deviation: Worktree merge required

**[Rule 3 - Blocking] Worktree was at Phase 7 state without Wave 1 (09-01, 09-02) changes**
- **Found during:** Task 1 read setup — RoomLayouts.gd was absent from the worktree
- **Issue:** The worktree branch `worktree-agent-aceef03036b5c109c` was branched from Phase 7 commit `a6a5004` and didn't have the Wave 1 commits (RoomLayouts.gd, Game.tscn restructure, Player.tscn Camera2D) merged into `main`
- **Fix:** `git merge main --no-edit` — fast-forward merge succeeded cleanly
- **Not a code deviation** — infrastructure setup to reach the correct baseline

### Auto-handled changes

**[Rule 2 - Missing Critical] _teleport_players_to_spawn() factored out**
- Two places needed identical player teleport logic (_transition_to_room and _transition_to_sub_room)
- Factored into a shared `_teleport_players_to_spawn()` helper, eliminating duplication
- Behavior is identical to what the plan specified inline for both callers

## Verification Results

| Check | Expected | Result | Status |
|-------|----------|--------|--------|
| `grep "OSMRoomGenerator" scenes/Game.gd` | empty | empty | PASS |
| `ls scenes/OSMRoomGenerator.gd` | No such file | No such file | PASS |
| `grep -c "func _transition_to_sub_room" scenes/Game.gd` | 1 | 1 | PASS |
| `grep -c "func _open_exit_passage" scenes/Game.gd` | 1 | 1 | PASS |
| `grep -c "func build_sub_room" scenes/RoomBuilder.gd` | 1 | 1 | PASS |
| `grep "set_cell" scenes/RoomBuilder.gd` | floor+wall+obstacle hits | 3 set_cell calls | PASS |
| `grep -rn "http\|HTTPRequest\|fetch_for_room" scenes/` | empty | empty | PASS |
| `grep "tilemap.clear()" scenes/RoomBuilder.gd` | hit | hit | PASS |
| `grep "queue_free" scenes/RoomBuilder.gd` | hits (spawn clearing) | 2 queue_free calls | PASS |
| `grep "_exit_tile_coords" scenes/RoomBuilder.gd` | hit | hit | PASS |
| `grep "await get_tree" scenes/Game.gd` | hit | hit | PASS |
| `@rpc("authority") on _transition_to_sub_room` | present | line 249 | PASS |
| `@rpc("authority") on _open_exit_passage` | present | line 304 | PASS |
| `grep "_on_osm_room_ready" scenes/Game.gd` | empty | empty | PASS |
| `grep "_room_builder" scenes/Game.gd` | hits | 7 usages | PASS |
| `grep "current_sub_room" scenes/Game.gd` | var decl + usages | present | PASS |

## Known Stubs

**_spawn_boss() uses hardcoded boss center (Vector2(400, 380))**
- `_spawn_boss()` was not modified in this plan — it predates Phase 9 and uses a hardcoded center
- Room 3 sub-room 5 (boss arena) repopulates EnemySpawnPoints with `Vector2(35*16, 25*16)` via RoomBuilder
- `_spawn_boss()` bypasses EnemySpawnPoints and uses its own hardcoded position
- Does not prevent plan goal — boss still spawns; minor positional mismatch
- Plan 04 (boss integration) should wire `_spawn_boss()` to use the repopulated EnemySpawnPoints

## Threat Flags

No new security-relevant surface beyond the plan's threat model:
- `_transition_to_sub_room` is `@rpc("authority")` — T-09-03 mitigated
- `_open_exit_passage` is `@rpc("authority")` — T-09-04 mitigated
- OSMRoomGenerator HTTP client removed — T-09-05 accepted (network dependency eliminated)

## Self-Check: PASSED

- scenes/RoomBuilder.gd: EXISTS (commit 2d73aff)
- scenes/Game.gd: MODIFIED (commit dce19cf)
- scenes/OSMRoomGenerator.gd: DELETED (commit dce19cf)
- All verification grep checks: PASSED
- Both @rpc authority decorators present on _transition_to_sub_room and _open_exit_passage
- No OSMRoomGenerator references remain in any .gd file
