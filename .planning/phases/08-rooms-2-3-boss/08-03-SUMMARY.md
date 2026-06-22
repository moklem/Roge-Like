---
phase: 08-rooms-2-3-boss
plan: "03"
subsystem: game-scene
tags: [room-transition, room-clear, boss-spawn, mob-swarm, lidar, loop-advance, rpc, gdscript]
dependency_graph:
  requires: [08-01 (Room2/Room3 geometry + shared Entities), 08-02 (Boss.tscn + Boss.gd)]
  provides: [_transition_to_room, _check_room_clear, _spawn_boss, _spawn_mob_swarm, _on_boss_died, current_room]
  affects: [scenes/Game.gd]
tech_stack:
  added: []
  patterns: [rpc-authority-call-local-reliable, set_meta-room-tag, call_deferred-physics-safe, host-authoritative-spawning]
key_files:
  modified:
    - scenes/Game.gd
decisions:
  - "room_id stored via set_meta (not a property) — keeps Enemy.gd unchanged while allowing Game.gd to filter by room"
  - "Boss spawn position set to Vector2(400,380) — below the Keep obstacle (400,220), open courtyard area"
  - "LIDAR fired per-elite immediately at spawn time via GameEvents.emit_hud.rpc('lidar') inside _spawn_mob_swarm (not deferred)"
  - "Room 1 enemies re-spawned via _spawn_enemies.call_deferred() after _transition_to_room.rpc(1) in _on_boss_died because Room-1 branch of _transition_to_room has no auto-spawn"
  - "Rule 1 auto-fix: request_deploy_drone changed from Room1/Entities to shared Entities node (08-01 refactor not propagated to that function)"
  - "Rule 1 auto-fix: _spawn_elite_enemy updated to use current_room spawn points and skip Room 3 (was hardcoded Room1/EnemySpawnPoints)"
metrics:
  duration: "~18m"
  completed: "2026-06-22"
  tasks_completed: 3
  files_modified: 1
status: complete
---

# Phase 08 Plan 03: Full 3-Room Run Flow Wired into Game.gd Summary

**One-liner:** Wired complete Room1→Room2→Room3/Boss loop into Game.gd with `current_room` tracking, call_local reliable RPC transitions, room-clear auto-detection, boss spawn on Room3 entry, loop-scaled mob swarms with per-elite LIDAR, and boss-death loop advance back to Room 1.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Add current_room state, Boss pre-registration, generalize Room1 references | bd77ebe | scenes/Game.gd |
| 2 | Implement room transition RPC and auto room-clear detection | fb526e5 | scenes/Game.gd |
| 3 | Implement boss spawn, mob swarm spawn with LIDAR, and boss-death loop advance | d24d43e | scenes/Game.gd |

## What Was Built

### Task 1 — State, Pre-registration, Generalization

Added to `scenes/Game.gd`:
- `const BOSS_SCENE := preload("res://scenes/enemies/Boss.tscn")` — boss scene pre-load
- `const INITIAL_ENEMY_COUNT_R2: int = 12` — Room 2 baseline (1.5× Room 1's 8, D-07)
- `var current_room: int = 1` — active room tracker (D-04)
- `$EnemySpawner.add_spawnable_scene("res://scenes/enemies/Boss.tscn")` in `_ready` (P7)
- `_bake_navigation()` now reads `"Room%d/NavigationRegion2D" % current_room`
- `_spawn_all_players()` now reads `"Room%d/SpawnPoints" % current_room`
- `_spawn_enemies()` now reads `"Room%d/EnemySpawnPoints" % current_room`; uses `INITIAL_ENEMY_COUNT_R2` when `current_room == 2`; tags spawned enemies with `"room_id": current_room`
- `_on_enemy_died()` respawn block uses `"Room%d/EnemySpawnPoints" % current_room`; guarded by `if current_room != 3` (D-09); calls `_check_room_clear.call_deferred()`
- `_do_spawn_enemy()` dispatches `"boss"` type to `BOSS_SCENE`; tags all spawned enemies with `set_meta("room_id", ...)` for room-clear filtering; excludes boss from normal-enemy difficulty multiplier; connects boss `died` to `_on_boss_died` (not `_on_enemy_died` — Pitfall 5)
- `_spawn_elite_enemy()` updated to use `current_room` spawn points and skip Room 3

### Task 2 — Room Transition RPC + Room-Clear Detection

Added:
- `@rpc("authority", "call_local", "reliable") _transition_to_room(next_room: int)` (T-08-01, ROOM-07):
  - Hides old room (`visible = false`), disables all `StaticBody2D` collision layer 1
  - Shows new room (`visible = true`), enables all `StaticBody2D` collision layer 1
  - Sets `current_room = next_room`
  - Teleports all players in group `"players"` to new room's `SpawnPoints` children (fallback: Vector2(400,300))
  - Host-only block: purges `Entities` xp_orbs and car_parts; purges enemies tagged to old room; bakes new room navmesh deferred; calls `_spawn_boss.call_deferred()` for Room 3 or `_spawn_enemies.call_deferred()` for Room 2

- `_check_room_clear()` (D-02, ROOM-07):
  - Host-only, returns early when `current_room == 3` (boss death path — Pitfall 5)
  - Iterates `get_tree().get_nodes_in_group("enemies")`, filters by `room_id` meta (defaults to `current_room` when missing)
  - Fires `_transition_to_room.rpc(current_room + 1)` when alive_count == 0

### Task 3 — Boss Spawn, Mob Swarm, Loop Advance

Added:
- `_spawn_boss()` (D-09): host-only; spawns Boss at Vector2(400,380) in Room 3 with `room_id: 3` via EnemySpawner
- `_spawn_mob_swarm(boss_phase: int)` (D-14, D-15, D-16, ROOM-05, ROOM-06): host-only; reads Room3 swarm points; computes `5 + (GameState.loop_number * 3)` normal enemies + `1` elite (2 in Phase 3); each elite fires `GameEvents.emit_hud.rpc("lidar")` (ROOM-06); all enemies tagged `room_id: 3`
- `_on_boss_died(_pos: Vector2)` (D-17, LOOP-03): host-only; calls `GameState.start_next_loop()`; fires `_transition_to_room.rpc(1)`; calls `_spawn_enemies.call_deferred()` for new Room 1 wave

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed request_deploy_drone using stale Room1/Entities path**
- **Found during:** Task 1 while reading Game.gd
- **Issue:** `request_deploy_drone` was still looking for `"Room1/Entities"` after 08-01 moved all spawner `spawn_path`s to the Game-root `Entities` node. The node `Room1/Entities` still exists but drones spawned via `DroneSpawner` land in `Entities` (Game-root); the count check was inspecting the wrong container.
- **Fix:** Changed `get_node_or_null("Room1/Entities")` to `get_node_or_null("Entities")`
- **Files modified:** scenes/Game.gd
- **Commit:** bd77ebe

**2. [Rule 1 - Bug] Fixed _spawn_elite_enemy using hardcoded Room1/EnemySpawnPoints**
- **Found during:** Task 1 while generalizing hardcoded Room1 references
- **Issue:** The elite enemy timer in `_spawn_elite_enemy()` still read `$Room1/EnemySpawnPoints` regardless of `current_room`. If the elite timer fired in Room 2 or Room 3, elites would spawn at Room 1 positions (invisible, out-of-bounds).
- **Fix:** Replaced with `get_node("Room%d/EnemySpawnPoints" % current_room).get_children()`; added `if current_room == 3: return` guard (boss-only room).
- **Files modified:** scenes/Game.gd
- **Commit:** bd77ebe

## Known Stubs

None — all functions are fully implemented. UAT smoke test (Room 1 clear → Room 2 → Room 3/Boss → loop advance) requires manual multiplayer testing per RESEARCH validation map.

## Threat Flags

| Flag | File | Description |
|------|------|-------------|
| T-08-01 (mitigated) | scenes/Game.gd | `_transition_to_room` decorated `@rpc("authority",...)` — only host can invoke; clients cannot trigger room transitions |
| T-08-02 (mitigated) | scenes/Game.gd | `_spawn_boss` and `_spawn_mob_swarm` guard `if not multiplayer.is_server(): return` — host-only spawning |
| T-08-03 (accepted) | scenes/Game.gd | `room_id` tag via `set_meta` is host-set at spawn; clients never write it |

## Self-Check: PASSED

- scenes/Game.gd modified and committed (bd77ebe, fb526e5, d24d43e)
- `const BOSS_SCENE := preload("res://scenes/enemies/Boss.tscn")` present ✓
- `var current_room: int = 1` present ✓
- `$EnemySpawner.add_spawnable_scene("res://scenes/enemies/Boss.tscn")` in _ready ✓
- `@rpc("authority", "call_local", "reliable")` on `_transition_to_room` ✓
- `_transition_to_room` hides/shows rooms with `visible = false/true` ✓
- `_transition_to_room` toggles `StaticBody2D` collision layer 1 ✓
- `_transition_to_room` teleports players in group "players" ✓
- `_transition_to_room` purges Entities pickups/orbs host-only ✓
- `_check_room_clear` returns early for `current_room == 3` ✓
- `_check_room_clear` filters enemies by `room_id` meta ✓
- `_check_room_clear` fires `_transition_to_room.rpc(current_room + 1)` when alive_count == 0 ✓
- `_on_enemy_died` calls `_check_room_clear.call_deferred()` ✓
- `_spawn_enemies` tags with `"room_id": current_room` and uses INITIAL_ENEMY_COUNT_R2 for Room 2 ✓
- `_spawn_boss` spawns via `$EnemySpawner.spawn({"type":"boss","pos":boss_center,"room_id":3})` ✓
- `_do_spawn_enemy` connects boss `died` to `_on_boss_died` (not `_on_enemy_died`) ✓
- `_spawn_mob_swarm` computes `5 + (GameState.loop_number * 3)` normals and `2 if boss_phase == 3 else 1` elites ✓
- `_spawn_mob_swarm` fires `GameEvents.emit_hud.rpc("lidar")` once per elite ✓
- `_on_boss_died` calls `GameState.start_next_loop()` and `_transition_to_room.rpc(1)` ✓
- No `change_scene_to_file` used for room transitions ✓
- No `$Room1/` hardcoded references remain in generalized functions ✓
