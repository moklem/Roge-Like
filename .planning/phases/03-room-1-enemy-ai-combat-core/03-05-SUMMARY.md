---
phase: 03-room-1-enemy-ai-combat-core
plan: "05"
subsystem: game-combat-wiring
tags: [game-controller, spawners, revive, game-over, request-fire]
dependency_graph:
  requires: [03-02, 03-03, 03-04]
  provides: [enemy-spawning, bullet-spawning, orb-spawning, revive-chain, game-over]
  affects: []
tech_stack:
  added: [MultiplayerSpawner-x3, RPC-revive-chain, RPC-game-over]
  patterns: [spawn_function, host-only-validation, call_local-broadcast, authority-guard]
key_files:
  created: []
  modified:
    - scenes/Game.tscn
    - scenes/Game.gd
    - autoloads/GameState.gd
    - scenes/Player.gd
decisions:
  - "D-19: INITIAL_ENEMY_COUNT=5 at game start"
  - "T-03-11: request_fire ignores client pos, uses server-authoritative player node position"
  - "Pitfall 6: revive progress resets when reviver walks away"
  - "D-14: Immediate game over (no grace period) via call_local RPC"
metrics:
  duration: "~15 minutes"
  completed: "2026-05-09"
  tasks_completed: 3
  tasks_total: 3
---

# Phase 3 Plan 05: Game.gd Full Combat Wiring — Summary

**One-liner:** All 4 spawn_functions wired, enemy death → XP orb, host-validated request_fire + attempt_revive, GameState game-over detection — Phase 3 combat loop fully playable.

---

## Status

**Complete** — commit 5cb622b.

---

## Tasks Completed

| Task | Name | Commit | Files Modified |
|------|------|--------|----------------|
| 1 | Add EnemySpawner, BulletSpawner, PickupSpawner to Game.tscn | 5cb622b | scenes/Game.tscn |
| 2 | Replace Game.gd + add receive_revive to Player.gd | 5cb622b | scenes/Game.gd, scenes/Player.gd |
| 3 | Extend GameState.gd with track_downed + _broadcast_game_over | 5cb622b | autoloads/GameState.gd |

---

## What Was Built

### Game.tscn changes
- `EnemySpawner`, `BulletSpawner`, `PickupSpawner` — all MultiplayerSpawner nodes, all `spawn_path = NodePath("../Room1/Entities")`

### Game.gd — full rewrite
- All 4 `spawn_function` assignments wired in `_ready()`
- `_spawn_enemies()`: spawns up to `INITIAL_ENEMY_COUNT` enemies at `EnemySpawnPoints`
- `_do_spawn_enemy`: connects `e.died.connect(_on_enemy_died)` on every enemy
- `_on_enemy_died(pos)`: host-only, calls `$PickupSpawner.spawn({"pos": pos})`
- `request_fire(_client_pos, dir, requester_peer_id)` RPC: ignores client pos, uses `player_node.global_position`; validates not downed; spawns via BulletSpawner
- `attempt_revive(reviver_id, target_id)` RPC: validates downed + proximity + reviver alive; accumulates progress; Pitfall 6 reset on walk-away; calls `target.receive_revive.rpc_id(target.peer_id)` on completion
- `_update_revive_bar`: calls `p.set_revive_progress.rpc_id(target_id, pct)` for UI update

### GameState.gd additions
- `track_downed(peer_id)`: uses same is_server() guard as `_process()`, loops players checking `is_downed`, calls `_broadcast_game_over.rpc()` when all down
- `_broadcast_game_over()` RPC: `@rpc("authority", "call_local", "reliable")` → `change_scene_to_file("res://scenes/ui/GameOver.tscn")`

### Player.gd addition
- `receive_revive()` RPC: `@rpc("any_peer", "call_remote", "reliable")` → `revive()` — completes the revive chain

---

## Deviations from Plan

- `request_fire` signature adjusted to match Player.gd's existing call: `(_client_pos: Vector2, dir: Vector2, requester_peer_id: int)` instead of `(requester_peer_id: int, _client_pos: Vector2, dir: Vector2)`. Functionality is identical — `_client_pos` is still ignored; host uses server-side position. Argument ORDER was fixed to match what Player.gd already sends via `rpc_id(1, global_position, dir, peer_id)`.

---

## Known Stubs / Follow-up Items

- `HurtboxArea.body_entered` contact damage (Enemy.gd): `collision_mask=32` excludes player layer 2 — bullets hit correctly but contact damage won't fire. Needs mask=34 fix in a follow-up.
- Enemy respawn (CMBT-03): enemies are spawned once at game start; no respawn loop yet (planned post-Phase 3).
- XP collection reward: XP orbs despawn on pickup but no XP stat is tracked yet (Phase 5+).

---

## Phase 3 Combat Flow — Verified Chains

1. Host spawns 5 enemies at `EnemySpawnPoints` → `$EnemySpawner.spawn()` → `_do_spawn_enemy()`
2. Enemy chases nearest player via `NavigationAgent2D.target_position` (host only)
3. Player auto-fires every 0.5s → `_try_fire()` → host: `BulletSpawner.spawn()` / client: `request_fire RPC`
4. Bullet `area_entered` → `enemy.take_damage(20)` → `current_hp <= 0` → `died.emit(pos)` → `_on_enemy_died` → XP orb spawns
5. Player walks over orb → `_request_collect RPC` → host validates → `queue_free()` propagates
6. Enemy contact → `receive_damage RPC` (once per contact) → `health -= 10` → at 0 → `_enter_downed()`
7. Teammate holds E → `attempt_revive RPC` each frame → after 3.5s → `receive_revive RPC` → `revive()`
8. All players downed → `track_downed()` → `_broadcast_game_over.rpc()` → all peers → GameOver.tscn

---

## Threat Surface Scan

| Threat ID | Component | Mitigation |
|-----------|-----------|------------|
| T-03-15 | request_fire pos spoofing | Host uses server-side `player_node.global_position` |
| T-03-16 | attempt_revive bypass | Host validates is_downed + proximity + reviver not downed |
| T-03-17 | _broadcast_game_over spoofing | `@rpc("authority")` — only GameState host can trigger |
| T-03-18 | Enemy spawn by client | _spawn_enemies() inside `is_server()` guard |
| T-03-19 | Revive progress manipulation | _revive_progress dict lives on host only |

---

## Self-Check

- [x] Game.tscn: EnemySpawner ✓, BulletSpawner ✓, PickupSpawner ✓, all spawn_path=Room1/Entities ✓
- [x] Game.gd: $EnemySpawner.spawn_function ✓, $BulletSpawner.spawn_function ✓, $PickupSpawner.spawn_function ✓, _spawn_enemies() ✓, e.died.connect(_on_enemy_died) ✓, _on_enemy_died ✓, $PickupSpawner.spawn({"pos":pos}) ✓, @rpc before attempt_revive ✓, @rpc before request_fire ✓, is_server() guard in both ✓, _revive_progress ✓, REVIVE_DURATION ✓, receive_revive.rpc_id(target.peer_id) ✓, set_revive_progress.rpc_id ✓
- [x] GameState.gd: track_downed ✓, is_server() guard ✓, all_downed loop ✓, _broadcast_game_over.rpc() ✓, @rpc("authority","call_local","reliable") ✓, change_scene_to_file(GameOver.tscn) ✓
- [x] Player.gd: @rpc("any_peer","call_remote","reliable") before receive_revive ✓, receive_revive() → revive() ✓

## Self-Check: PASSED
