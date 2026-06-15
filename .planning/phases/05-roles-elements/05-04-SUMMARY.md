---
phase: 05-roles-elements
plan: "04"
subsystem: fire-ice-element-procs
tags: [fire-burn, ice-slow, fire-burst, ice-trail, element-proc, hud-emit, bullet, player]
dependency_graph:
  requires: [05-01, 05-02]
  provides: [force_burn-export, element-proc-on-hit, _tick_element-body, _fire_burst, _find_nearest_enemy_global, request_ice_trail-call]
  affects: [scenes/projectiles/Bullet.gd, scenes/Player.gd]
tech_stack:
  added: []
  patterns: [host-only-proc-inside-authority-guard, randf-proc-chance, rpc_id-ice-trail-request, delta-decrement-fire-burst-timer, has_method-guard, hud-emit-server-only]
key_files:
  created: []
  modified:
    - scenes/projectiles/Bullet.gd
    - scenes/Player.gd
decisions:
  - "force_burn export on Bullet.gd bypasses 25% gate for Fire Burst projectiles (D-17)"
  - "Element proc placed after take_damage and before queue_free inside existing authority guard (Pitfall 5 compliance)"
  - "fire_burst=true passed in spawn dict; Plan 05 _do_spawn_bullet extension wires b.force_burn"
  - "Ice Trail guard: velocity.length() < 10 skips trail when idle (D-18)"
  - "request_ice_trail guarded by has_method so safe before Plan 05 adds it to Game.gd"
  - "HUD emit always wrapped in multiplayer.is_server() (T-05-14 mitigation)"
  - "_find_nearest_enemy_global cloned from WeaponManager._find_nearest_enemy — operates on self.global_position"
metrics:
  duration: "2 minutes"
  completed: "2026-06-15T13:50:00Z"
  tasks_completed: 2
  files_modified: 2
---

# Phase 05 Plan 04: Fire/Ice Element Procs Summary

Fire and Ice element procs implemented: Bullet.gd gains `force_burn` flag, on-hit element proc (25% chance fire burn / ice slow), and HUD emit; Player.gd `_tick_element` stub filled with Fire Burst auto-fire timer (every 4s, 3-5 burst) and Ice Trail spawn request (every 0.3s while moving).

## What Was Built

**Task 1 — Bullet.gd element proc + force_burn flag:**

Export added: `@export var force_burn: bool = false` (D-17: Fire Burst projectiles bypass 25% gate).

Element proc block added inside `_on_area_entered`, after `enemy.take_damage(BULLET_DAMAGE)` and before `queue_free()` — correctly inside the existing `if not is_multiplayer_authority(): return` guard (Pitfall 5 compliance).

Proc logic:
- `force_burn = true` path: calls `enemy.apply_burn()` (has_method guard) + `GameEvents.emit_hud("engine")` (server-only). Returns via fall-through to `queue_free()`. Implements ELEM-02 (100% burn for Fire Burst).
- `fire` element + `randf() < 0.25`: calls `enemy.apply_burn()` + `emit_hud("engine")` (ELEM-01, ELEM-07).
- `ice` element + `randf() < 0.25`: calls `enemy.apply_slow()` + `emit_hud("ac")` (ELEM-03, ELEM-07).
- Empty element `""`: match falls through — no proc, no action.

Trust boundaries:
- Proc only runs on host (inside existing authority guard) — T-05-11 double-proc prevention.
- HUD emit wrapped `if multiplayer.is_server():` — T-05-14 HUD dedup.

**Task 2 — Player.gd `_tick_element` body + `_fire_burst` + `_find_nearest_enemy_global`:**

`_tick_element(delta)` stub replaced with a `match element` block:

Fire branch (D-17, ELEM-02):
- Decrements `_fire_burst_timer` each tick (initialized to 4.0 in `_ready()` — no immediate burst on spawn).
- When timer ≤ 0 → reset to 4.0 → call `_fire_burst()`.

`_fire_burst()`:
- Calls `_find_nearest_enemy_global()` — returns null if no enemies, early returns.
- Computes base direction toward nearest enemy.
- Loops `randi_range(3, 5)` times with `randf_range(-0.3, 0.3)` spread per projectile.
- Host: `game.get_node("BulletSpawner").spawn({..., "fire_burst": true})`.
- Client: `game.request_fire.rpc_id(1, ...)`. NOTE: `request_fire` ignores extra dict keys; `fire_burst` flag is in the BulletSpawner spawn dict (for host path) only. Plan 05 extends `_do_spawn_bullet` to read `fire_burst` and set `b.force_burn`.
- After loop: `if multiplayer.is_server(): GameEvents.emit_hud("engine")` (ELEM-07).

Ice branch (D-18, ELEM-04):
- Early return if `velocity.length() < 10.0` (idle — no trail).
- Decrements `_ice_trail_timer`; when ≤ 0 → reset to 0.3 → request trail.
- Host: `game.request_ice_trail(global_position)` direct.
- Client: `game.request_ice_trail.rpc_id(1, global_position)`.
- `has_method("request_ice_trail")` guard ensures safe operation before Plan 05 adds `request_ice_trail` to Game.gd.

`_find_nearest_enemy_global()`:
- Clones `WeaponManager._find_nearest_enemy` but uses `self.global_position` instead of a player param.
- Iterates group "enemies", returns closest node or null.

## Commits

| Task | Commit | Description |
|------|--------|-------------|
| Task 1 | 7a50a24 | feat(05-04): Bullet.gd element proc — force_burn flag, fire/ice 25% proc, HUD emit |
| Task 2 | 32c4a96 | feat(05-04): Player.gd _tick_element — Fire Burst auto-timer + Ice Trail spawn request |

## Known Stubs / Dependencies for Plan 05

| Dependency | File | What Plan 05 must add | Why deferred |
|------------|------|-----------------------|--------------|
| `force_burn` wiring for client Fire Burst | `scenes/Game.gd` `_do_spawn_bullet` | Read `data.get("fire_burst", false)` and set `b.force_burn = data["fire_burst"]` | Game.gd owned by Plan 05 in this wave; cross-plan edits avoided |
| Orange modulate on Fire Burst bullets | `scenes/Game.gd` `_do_spawn_bullet` | Set `b.modulate = Color(1.0, 0.5, 0.0)` when `fire_burst == true` | Same as above |
| `request_ice_trail` RPC in Game.gd | `scenes/Game.gd` | Add `@rpc("any_peer","call_remote","reliable") func request_ice_trail(pos: Vector2)` + `$IceTrailSpawner.spawn.call_deferred({"pos": pos})` | Plan 05 adds IceTrailSpawner and IceTrailZone scene |
| `IceTrailZone.tscn` spawnable scene | `scenes/elements/IceTrailZone.tscn` | Create IceTrailZone scene + register in IceTrailSpawner | Plan 05 scope (ELEM-04 spawner half) |

Fire Burst fires real damaging projectiles now (correct behavior). Without `force_burn` wiring in `_do_spawn_bullet`, the burst projectiles use the standard 25% proc chance from Bullet.gd's `force_burn=false` default — still functional burn on proc, just not guaranteed. This is acceptable degradation per plan spec.

## Deviations from Plan

None — plan executed exactly as written. The "client Fire Burst does not pass fire_burst to request_fire" behavior matches the plan note: `request_fire` takes a fixed signature; the host-path BulletSpawner dict carries `fire_burst: true` and Plan 05 `_do_spawn_bullet` extension reads it.

## Threat Surface Scan

No new network endpoints beyond what plan's threat model documents.

- T-05-11 (double-proc): Element proc is inside existing authority guard, never on clients. PASS.
- T-05-12 (authority abuse): `apply_burn` / `apply_slow` only reached from host-only Bullet.gd proc site. PASS.
- T-05-14 (HUD spam): All `GameEvents.emit_hud()` calls wrapped in `if multiplayer.is_server():`. PASS.
- `request_ice_trail`: Guarded by `has_method` on Player side. Game.gd Plan 05 guard: `if not multiplayer.is_server(): return`.

## Self-Check: PASSED

Files verified:
- `/Users/bistl/Documents/RogeLike/Roge-Like/scenes/projectiles/Bullet.gd` — contains `force_burn`, `apply_burn`, `apply_slow`, `emit_hud("engine")`, `emit_hud("ac")`, `Lobby.players.get(owner_peer_id`
- `/Users/bistl/Documents/RogeLike/Roge-Like/scenes/Player.gd` — contains `func _tick_element`, `func _fire_burst`, `_fire_burst_timer`, `request_ice_trail`, `"fire_burst": true`, `func _find_nearest_enemy_global`

Commits verified: 7a50a24, 32c4a96 — both present in git log.
