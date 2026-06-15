---
phase: 05-roles-elements
plan: "05"
subsystem: ice-trail-earth-element-force-burn
tags: [ice-trail, earth-element, force-burn, hud, multiplayer-spawner, host-authoritative, elements]
dependency_graph:
  requires: [05-01, 05-03, 05-04]
  provides: [IceTrailZone.gd, IceTrailZone.tscn, IceTrailSpawner, request_ice_trail, _do_spawn_ice_trail, _tick_earth_effects, _show_earth_shockwave, force_burn-wiring]
  affects: [scenes/elements/IceTrailZone.gd, scenes/elements/IceTrailZone.tscn, scenes/Game.gd, scenes/Game.tscn]
tech_stack:
  added: []
  patterns: [MultiplayerSpawner-spawn_function, host-only-process, call_deferred-physics-spawn, rpc-any_peer-call_local-unreliable_ordered, receive_heal-rpc-routing, expanding-ring-tween, force_burn-export-wiring]
key_files:
  created:
    - scenes/elements/IceTrailZone.gd
    - scenes/elements/IceTrailZone.tscn
  modified:
    - scenes/Game.gd
    - scenes/Game.tscn
decisions:
  - "IceTrailZone _slow_timer overridden to 1.5s after apply_slow() call (apply_slow sets 2.0s; trail slow is shorter per D-18)"
  - "request_ice_trail emits emit_hud('ac') on host after spawn — ELEM-07 ice HUD direct in RPC (not in IceTrailZone)"
  - "_tick_earth_effects called from existing host-guarded _process alongside _tick_engineer_passive (no new _process needed)"
  - "_show_earth_shockwave uses call_local so host also renders the visual ring"
  - "force_burn default=false in request_fire signature ensures backward compatibility with all existing screws/bolts callers"
  - "Knockback applied before take_damage(15) result — uses is_instance_valid + is_queued_for_deletion guard to avoid post-death write"
metrics:
  duration: "8 minutes"
  completed: "2026-06-15T14:00:00Z"
  tasks_completed: 2
  files_modified: 4
---

# Phase 05 Plan 05: IceTrailZone + Earth Heal/Shockwave + force_burn Wiring Summary

IceTrailZone frost patch system (ELEM-04), Earth team heal +2 HP/sec (ELEM-05), Earth 8s shockwave knockback +15 dmg (ELEM-06), SEAT MASSAGE HUD (ELEM-07), and Fire Burst force_burn flag wired end-to-end through Game.gd bullet spawn path (Plan 04 dependency resolved).

## What Was Built

**Task 1 — IceTrailZone scene + script; Game.gd IceTrailSpawner + request_ice_trail + force_burn wiring:**

`IceTrailZone.gd` (new, extends Node2D):
- Consts: `SLOW_DURATION=1.5`, `LIFETIME=2.0`, `ZONE_RADIUS=20.0`
- `_setup_area()`: Area2D with `collision_mask=4` (enemies), CircleShape2D radius 20px, `body_entered` → `_on_enemy_entered`
- `_physics_process(delta)`: host-only guard (`is_multiplayer_authority()`); accumulates `_elapsed`; `queue_free()` at 2.0s (T-05-16)
- `_on_enemy_entered(body)`: host-only guard; `apply_slow()` + `body._slow_timer = 1.5` override (1.5s trail vs 2.0s direct slow per D-18)
- `_draw_visual()`: light-blue ColorRect 40x40, `Color(0.6, 0.85, 1.0, 0.5)`, centered via position/pivot

`IceTrailZone.tscn` (new): Node2D root with IceTrailZone.gd script — spawnable scene registered with IceTrailSpawner.

`Game.tscn`: `IceTrailSpawner` MultiplayerSpawner node added as sibling of DroneSpawner with `spawn_path = Room1/Entities`.

`Game.gd` additions:
- `ICE_TRAIL_SCENE` preload const
- `$IceTrailSpawner` registration in `_ready()`: `spawn_function = _do_spawn_ice_trail` + `add_spawnable_scene` (P7 compliance)
- `request_ice_trail(pos)` `@rpc("any_peer","call_remote","reliable")`: server guard; `$IceTrailSpawner.spawn.call_deferred({"pos": pos})` (Pitfall 4); `GameEvents.emit_hud("ac")` (ELEM-07)
- `_do_spawn_ice_trail(data)`: instantiates zone, sets position, random-suffix name
- `request_fire(...)`: extended to `force_burn: bool = false` optional 4th param; `"fire_burst": force_burn` passed in spawn dict (T-05-19: defaults false, backward compatible)
- `_do_spawn_bullet(data)`: reads `data.get("fire_burst", false)` → `b.force_burn`; sets `b.modulate = Color(1.0, 0.5, 0.0)` when true (D-17 orange Fire Burst)

**Task 2 — Earth element +2 HP/sec team heal + 8s shockwave + SEAT MASSAGE HUD:**

`Game.gd` additions:
- Module-level vars: `_earth_heal_accum: float = 0.0`, `_earth_shock_accum: float = 0.0`
- `_process(delta)`: appended `_tick_earth_effects(delta)` call (host-guarded block already present from Plan 03)
- `_tick_earth_effects(delta)`: detects alive Earth players; if none → early return
  - ELEM-05 (heal): `_earth_heal_accum` every 1.0s → `receive_heal(2)` to ALL non-downed players via rpc_id routing (T-05-17); `emit_hud("seat_massage")` (T-05-18)
  - ELEM-06 (shockwave): `_earth_shock_accum` every 8.0s → `_show_earth_shockwave.rpc(earth_pos)` for visual; host-only `take_damage(15)` + velocity knockback `* 350.0` for enemies within 120px (T-05-15); `emit_hud("seat_massage")` (T-05-18)
- `_show_earth_shockwave(pos)` `@rpc("any_peer","call_local","unreliable_ordered")`: green ColorRect ring RADIUS=120, `Color(0.4, 0.8, 0.2, 0.8)`, Tween scale 0.1→2.0 + alpha fade, `queue_free` on complete — cloned from HornShockwave._show_visual pattern

## Commits

| Task | Commit | Description |
|------|--------|-------------|
| Task 1 | 9e312ba | feat(05-05): IceTrailZone scene + Game.gd IceTrailSpawner + request_ice_trail + force_burn wiring |
| Task 2 | f6559d2 | feat(05-05): Earth element — team heal +2/sec + 8s shockwave + SEAT MASSAGE HUD (ELEM-05/06/07) |

## Known Stubs

None — all data flows are wired. All element effects (ice trail, earth heal, earth shockwave, force_burn) are fully implemented end-to-end.

## Deviations from Plan

None — plan executed exactly as written.

**Implementation notes aligned with plan:**
- `_slow_timer` override to 1.5s after `apply_slow()` matches plan task action exactly (apply_slow sets 2.0s, trail overrides to SLOW_DURATION=1.5)
- `emit_hud("ac")` placed in `request_ice_trail` RPC (host-side, after spawn confirm) — correct per ELEM-07 and T-05-18
- Earth shockwave checks `is_instance_valid(enemy)` before writing velocity to prevent post-death writes (Rule 2 auto-add: missing null check)

## Threat Surface Scan

No new network endpoints beyond what the plan's threat model documents. All mitigations applied:

- T-05-15 (Earth authority abuse): `_tick_earth_effects` inside `_process` which guards `is_server()`. PASS.
- T-05-16 (request_ice_trail spoofing): RPC guards `is_server()`. PASS.
- T-05-17 (Earth heal desync): `receive_heal` via `rpc_id` routing for remote players. PASS.
- T-05-18 (seat_massage HUD spam): Both HUD emits inside host-only `_tick_earth_effects` (already under `_process` is_server guard). PASS.
- T-05-19 (force_burn forge): `force_burn` defaults false in `request_fire`; only Fire Burst host-path sets `fire_burst=true` in spawn dict. PASS.

## Self-Check: PASSED

Files verified:
- `/Users/bistl/Documents/RogeLike/Roge-Like/scenes/elements/IceTrailZone.gd` — exists, contains `func _on_enemy_entered`, `_slow_timer = SLOW_DURATION`, `queue_free()`, `_draw_visual`
- `/Users/bistl/Documents/RogeLike/Roge-Like/scenes/elements/IceTrailZone.tscn` — exists, Node2D root with IceTrailZone.gd
- `/Users/bistl/Documents/RogeLike/Roge-Like/scenes/Game.tscn` — contains `IceTrailSpawner`
- `/Users/bistl/Documents/RogeLike/Roge-Like/scenes/Game.gd` — contains `ICE_TRAIL_SCENE`, `func request_ice_trail`, `spawn.call_deferred`, `emit_hud("ac")`, `force_burn = data.get("fire_burst"`, `func _tick_earth_effects`, `func _show_earth_shockwave`, `receive_heal`, `emit_hud("seat_massage")`, `_earth_shock_accum`

Commits verified: 9e312ba, f6559d2 — both present in git log.
