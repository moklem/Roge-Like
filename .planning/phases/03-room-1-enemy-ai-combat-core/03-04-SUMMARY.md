---
phase: 03-room-1-enemy-ai-combat-core
plan: "04"
subsystem: bullet-autofire
tags: [bullet, projectile, auto-fire, host-authoritative]
dependency_graph:
  requires: [03-02, 03-03]
  provides: [bullet-scene, player-autofire]
  affects: [03-05]
tech_stack:
  added: [Area2D-projectile, local-peer-simulation]
  patterns: [host-only-hit-detection, no-synchronizer-projectile, authority-guard]
key_files:
  created:
    - scenes/projectiles/Bullet.tscn
    - scenes/projectiles/Bullet.gd
  modified:
    - scenes/Player.gd
decisions:
  - "D-07: Only host runs hit detection (body_entered / area_entered)"
  - "D-08: Player immunity guaranteed geometrically via collision_mask=17 (excludes layer 2)"
  - "P5: No MultiplayerSynchronizer on bullets — clients simulate locally from baked direction"
metrics:
  duration: "~8 minutes"
  completed: "2026-05-09"
  tasks_completed: 2
  tasks_total: 2
---

# Phase 3 Plan 04: Bullet Projectile + Player Auto-Fire — Summary

**One-liner:** Bullet Area2D with host-only hit detection and local-peer simulation, wired to Player _try_fire() auto-fire loop aimed at nearest enemy.

---

## Status

**Complete** — commit fa19ced.

---

## Tasks Completed

| Task | Name | Commit | Files Modified/Created |
|------|------|--------|------------------------|
| 1 | Create Bullet.tscn and Bullet.gd | fa19ced | scenes/projectiles/Bullet.tscn, scenes/projectiles/Bullet.gd |
| 2 | Add _try_fire() to Player.gd | fa19ced | scenes/Player.gd |

---

## What Was Built

### Bullet.tscn
- **Root:** Area2D, collision_layer=32 (layer 6 bullets), collision_mask=17 (layer 1 walls + layer 5 enemy_hurtbox)
- **NO MultiplayerSynchronizer** (P5 anti-pattern avoided; clients simulate locally)
- **Sprite:** 8×4 yellow ColorRect

### Bullet.gd
- `@export var direction: Vector2` and `@export var owner_peer_id: int` — set by BulletSpawner spawn_function
- `_physics_process`: all peers simulate `position += direction * SPEED * delta` for smooth visuals
- `_on_body_entered`: host-only wall despawn (`is_multiplayer_authority()` guard)
- `_on_area_entered`: host-only enemy hit → `enemy.take_damage(BULLET_DAMAGE)` → `queue_free()`
- D-08 player immunity: collision_mask=17 excludes layer 2 (players) — bullets physically cannot overlap player collision shapes

### Player.gd additions
- Replaced fire stub with actual `_try_fire()` call in `_physics_process`
- `_try_fire()`: finds nearest enemy, computes normalized direction
  - If host: calls `BulletSpawner.spawn({pos, dir, owner_id})` directly
  - If client: sends `game.request_fire.rpc_id(1, pos, dir, peer_id)` — both guarded by `has_node`/`has_method`
- `_find_nearest_enemy()`: iterates `get_tree().get_nodes_in_group("enemies")`

---

## Deviations from Plan

None — implemented exactly as specified.

---

## Known Stubs

- `BulletSpawner` node does not exist in Game.tscn yet — added in Plan 05. `has_node("BulletSpawner")` guard prevents crash.
- `request_fire` RPC does not exist in Game.gd yet — added in Plan 05. `has_method("request_fire")` guard prevents crash.

---

## Threat Surface Scan

| Threat ID | Component | Mitigation |
|-----------|-----------|------------|
| T-03-11 | Client request_fire pos spoofing | Plan 05 uses server-side player position, ignores client pos |
| T-03-12 | Bullet damage trigger | `is_multiplayer_authority()` guard in _on_area_entered |
| T-03-14 | Bullet spam | FIRE_INTERVAL=0.5s on owning peer; Plan 05 can add host-side rate limit |

---

## Self-Check

- [x] Bullet.tscn: Area2D ✓, collision_layer=32 ✓, collision_mask=17 ✓, no MultiplayerSynchronizer ✓
- [x] Bullet.gd: @export direction ✓, @export owner_peer_id ✓, is_multiplayer_authority guard in body_entered ✓, is_multiplayer_authority guard in area_entered ✓, enemy.take_damage(BULLET_DAMAGE) ✓, position += direction * SPEED * delta ✓, D-08 comment ✓
- [x] Player.gd: _try_fire() func ✓, _find_nearest_enemy() func ✓, get_node_or_null("/root/Game") ✓, BulletSpawner ✓, request_fire.rpc_id(1,...) ✓, _try_fire() called in _physics_process ✓

## Self-Check: PASSED
