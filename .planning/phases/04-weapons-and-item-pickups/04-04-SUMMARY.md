---
phase: 04-weapons-and-item-pickups
plan: 04
subsystem: weapons
tags: [godot, gdscript, multiplayer, antenna-beam, horn-shockwave, weapon-manager, area2d, tween]

# Dependency graph
requires:
  - phase: 04-03
    provides: WeaponManager with _activate_weapon_node dispatch for exhaust_flames/spinning_tires; reset() already covers antenna_beam/horn_shockwave placeholders
affects:
  - 04-05

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Long thin Area2D beam (500px × 8px) with RectangleShape2D offset to player origin — collision_mask=4 makes beam wall-piercing"
    - "Area2D.rotation = dir.angle() to aim beam at nearest enemy each fire"
    - "Tween ColorRect beam flash: tween_property(visible, false, 0.2) on fire"
    - "360° CircleShape2D Area2D radius=150 centered on player each fire — no aiming needed"
    - "Tween expanding ring: scale 0.1→2.0 + modulate:a fade 0→0 over 0.35s + tween_callback(queue_free)"
    - "call_deferred chain for weapon node add_child + activate — physics-safe from pickup collection path"

key-files:
  created:
    - scenes/weapons/AntennaBeam.gd
    - scenes/weapons/HornShockwave.gd
  modified:
    - scenes/weapons/WeaponManager.gd

key-decisions:
  - "AntennaBeam uses long Area2D (not RayCast2D) — collision_mask=4 gets all enemies in one get_overlapping_bodies() call including wall-piercing"
  - "HornShockwave ring visual adds to player.get_parent() (Game scene) for world-space coordinates; null check guards missing parent"
  - "Both weapons pass weapon_manager (self) to activate() and store it via .bind() in Timer.timeout — same pattern as ExhaustFlames"
  - "W2 authority guard in _on_fire_timer PLUS is_server() guard before damage loop — two-level security matching Plan 03 pattern"
  - "WeaponManager reset() already covered antenna_beam/horn_shockwave from Plan 03 — no changes needed"

requirements-completed: [WEAP-04, WEAP-06, WEAP-06c, WEAP-06d]

# Metrics
duration: 2min
completed: 2026-05-31
---

# Phase 04 Plan 04: AntennaBeam + HornShockwave Weapon Implementations Summary

**Piercing 500px beam weapon (2s cooldown, wall-ignoring Area2D, cyan flash) and 360° radial shockwave (3s cooldown, 150px radius, Tween expanding yellow ring) wired into WeaponManager via deferred dispatch — all 4 timer weapons now fully active**

## Performance

- **Duration:** ~2 min
- **Started:** 2026-05-31T14:17:06Z
- **Completed:** 2026-05-31T14:19:05Z
- **Tasks:** 2
- **Files modified:** 3 (2 created, 1 modified)

## Accomplishments

- Created `scenes/weapons/AntennaBeam.gd` — long thin Area2D (500×8px) with collision_mask=4 (wall-piercing), 2s Timer, W2 authority guard, host-only damage via is_server(), null guard for no-enemies case, cyan ColorRect visual flashes via Tween on fire, deactivate() cleans up timer and area
- Created `scenes/weapons/HornShockwave.gd` — full 360° CircleShape2D Area2D (radius=150px), 3s Timer, W2 authority guard, host-only damage, `_spawn_ring_visual()` adds temporary yellow ColorRect to Game scene and uses Tween to scale 0.1→2.0 while fading then queue_free, deactivate() cleans up
- Extended `scenes/weapons/WeaponManager.gd` — added `antenna_beam` and `horn_shockwave` branches to `_activate_weapon_node()` match block with deferred add_child + deferred activate; added `_deferred_activate_antenna` and `_deferred_activate_shockwave` helpers; all 4 timer weapons now dispatched

## Task Commits

1. **Task 1: Implement AntennaBeam weapon script** — `be0c1d1` (feat)
2. **Task 2: Implement HornShockwave and extend WeaponManager dispatch** — `88e2338` (feat)

**Plan metadata:** _(docs commit follows)_

## Files Created/Modified

- `scenes/weapons/AntennaBeam.gd` — COOLDOWN=2.0s, BEAM_LENGTH=500px, BEAM_WIDTH=8px, DAMAGE=25, collision_mask=4, W2 guard, is_server() guard, get_overlapping_bodies() piercing loop, Tween flash visual, deactivate()
- `scenes/weapons/HornShockwave.gd` — COOLDOWN=3.0s, RADIUS=150px, DAMAGE=30, collision_mask=4, W2 guard, is_server() guard, get_overlapping_bodies() 360° loop, _spawn_ring_visual() with Tween, null check for player.get_parent(), deactivate()
- `scenes/weapons/WeaponManager.gd` — added antenna_beam + horn_shockwave match branches in _activate_weapon_node, added _deferred_activate_antenna + _deferred_activate_shockwave helpers

## Decisions Made

- AntennaBeam uses long thin Area2D not RayCast2D — Area2D with collision_mask=4 handles all enemies in one get_overlapping_bodies() call without wall collision (cleaner than RayCast2D for multi-enemy pierce)
- HornShockwave ring visual uses player.get_parent() to add to Game scene for world-space rendering; null check prevents crash if player not yet in tree
- Both weapons follow the same two-level security pattern: W2 authority guard (owning peer check) then is_server() guard (host-only damage)
- WeaponManager reset() already included antenna_beam/horn_shockwave node_names dict entries from Plan 03 — confirmed present, no changes needed

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None — AntennaBeam and HornShockwave are fully wired into the WeaponManager dispatch. Both weapons activate on pickup collection and deactivate cleanly on reset().

## Threat Surface Scan

No new network endpoints or trust boundaries introduced. Both weapons apply the mandatory mitigations from the plan's threat model:
- T-04-10 (AntennaBeam damage): mitigated by `if not multiplayer.is_server(): return` before damage loop
- T-04-11 (HornShockwave damage): mitigated by same pattern
- T-04-12 (ring visual): accepted — local visual node, no state change

## Self-Check

- [x] `scenes/weapons/AntennaBeam.gd` exists with COOLDOWN=2.0, BEAM_LENGTH=500.0, collision_mask=4, W2 guard, is_server() guard, get_overlapping_bodies(), deactivate()
- [x] `scenes/weapons/HornShockwave.gd` exists with COOLDOWN=3.0, RADIUS=150.0, collision_mask=4, W2 guard, is_server() guard, get_overlapping_bodies(), _spawn_ring_visual(), Tween, queue_free callback, deactivate()
- [x] `scenes/weapons/WeaponManager.gd` contains `"antenna_beam":` match branch in _activate_weapon_node
- [x] `scenes/weapons/WeaponManager.gd` contains `"horn_shockwave":` match branch in _activate_weapon_node
- [x] `scenes/weapons/WeaponManager.gd` contains `_deferred_activate_antenna` and `_deferred_activate_shockwave`
- [x] Commits `be0c1d1` and `88e2338` exist in git log

## Self-Check: PASSED

---
*Phase: 04-weapons-and-item-pickups*
*Completed: 2026-05-31*
