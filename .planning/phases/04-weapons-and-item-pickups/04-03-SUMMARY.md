---
phase: 04-weapons-and-item-pickups
plan: 03
subsystem: weapons
tags: [godot, gdscript, multiplayer, exhaust-flames, spinning-tires, weapon-manager, area2d]

# Dependency graph
requires:
  - phase: 04-02
    provides: WeaponManager scaffold with add_weapon/reset/tick API and placeholder activation comment
affects:
  - 04-04
  - 04-05

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "cone Area2D fire: full-circle Area2D + get_overlapping_bodies() + angle_to() filter for 60° arc (D-09)"
    - "Timer-based weapon node: autostart Timer child, bound weapon_manager passed via .bind(), authority guard at top of handler"
    - "Orbit weapon node: _physics_process updates all 3 tire positions on ALL peers; host-only guard before damage loop (D-14)"
    - "_hit_times Dictionary: enemy node path key → last-hit unix timestamp; prevents damage faster than HIT_COOLDOWN"
    - "call_deferred add_child + call_deferred activate: physics-safe weapon node instantiation from add_weapon() (anti-pattern W4)"
    - "Deactivation loop in reset(): iterates known weapon IDs, checks has_node by name, calls deactivate then queue_free"

key-files:
  created:
    - scenes/weapons/ExhaustFlames.gd
    - scenes/weapons/SpinningTires.gd
  modified:
    - scenes/weapons/WeaponManager.gd

key-decisions:
  - "ExhaustFlames uses -aim_dir (rear cone) matching D-09: exhaust fires backward behind car"
  - "SpinningTires visual orbit (position update) runs on all peers; only host applies damage via is_multiplayer_authority()"
  - "call_deferred used for both add_child and activate to avoid physics state mutation from pickup collection path"
  - "WeaponManager.reset() deactivates ExhaustFlames/SpinningTires/AntennaBeam/HornShockwave by name — includes Plan 04 placeholders (no-op for non-existent nodes via has_node guard)"

requirements-completed: [WEAP-04, WEAP-06, WEAP-06a, WEAP-06b]

# Metrics
duration: 2min
completed: 2026-05-31
---

# Phase 04 Plan 03: ExhaustFlames + SpinningTires Weapon Implementations Summary

**Cone Area2D exhaust weapon (1.5s timer, 60° rear arc, 120px radius) and 3-orbit spinning tires (50px orbit, 2 rad/s, 0.5s per-enemy cooldown) wired into WeaponManager via physics-safe deferred activation dispatch**

## Performance

- **Duration:** ~2 min
- **Started:** 2026-05-31T14:11:23Z
- **Completed:** 2026-05-31T14:13:27Z
- **Tasks:** 2
- **Files modified:** 3 (2 created, 1 modified)

## Accomplishments

- Created `scenes/weapons/ExhaustFlames.gd` — Area2D cone weapon with 1.5s autostart Timer, W2 authority guard, host-only damage detection, 60° rear arc filter using `cone_dir.angle_to()`, orange visual that flashes briefly on fire
- Created `scenes/weapons/SpinningTires.gd` — 3 orbiting Area2D tires, orbit position runs on all peers for visual sync, D-14 host-only damage via `is_multiplayer_authority()` guard, `_hit_times` Dictionary prevents per-enemy spam below 0.5s
- Extended `scenes/weapons/WeaponManager.gd` — added `_activate_weapon_node()` dispatch (exhaust_flames + spinning_tires with call_deferred add_child + activate), wired call into `add_weapon()`, replaced stub comment in `reset()` with real deactivation loop covering all 4 timer weapons

## Task Commits

1. **Task 1: Implement ExhaustFlames weapon script** — `45b1459` (feat)
2. **Task 2: Implement SpinningTires and wire both into WeaponManager dispatch** — `bde4191` (feat)

**Plan metadata:** _(docs commit follows)_

## Files Created/Modified

- `scenes/weapons/ExhaustFlames.gd` — COOLDOWN=1.5s, RADIUS=120px, HALF_ANGLE=deg_to_rad(30), collision_mask=4, authority+server guards, cone_dir=-aim_dir filter, deactivate() with timer+area queue_free
- `scenes/weapons/SpinningTires.gd` — ORBIT_RADIUS=50, ORBIT_SPEED=2.0, DAMAGE=15, HIT_COOLDOWN=0.5, 3 Area2D tires, _hit_times Dictionary, is_multiplayer_authority() guard on damage path, deactivate() clears all
- `scenes/weapons/WeaponManager.gd` — added _activate_weapon_node() function, _deferred_activate_exhaust/tires helpers, call_deferred chain in add_weapon(); reset() now deactivates named weapon nodes; placeholder comment replaced

## Decisions Made

- ExhaustFlames cone direction is `-aim_dir` (rear arc) matching D-09 "exhaust fires backward"
- W2 guard is placed in `_on_fire_timer` (authority check) AND `_try_fire` (server check for damage) — two levels: owning-peer check then host-only check
- SpinningTires uses `_tires: Array[Area2D]` instead of iterating `get_children()` — more explicit and safer during deactivation
- `reset()` covers all 4 timer weapons by name including AntennaBeam/HornShockwave (Plan 04) — `has_node()` guard ensures no error if those aren't added yet

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

- `_activate_weapon_node` in WeaponManager.gd has no case for `antenna_beam` or `horn_shockwave` — these are commented as "added by Plan 04". No stubs that block this plan's goal; both ExhaustFlames and SpinningTires activate correctly.
- `reset()` deactivation includes AntennaBeam/HornShockwave entries — harmless since `has_node()` guards prevent errors; will be used by Plan 04 output without further changes to reset().

## Self-Check

- [x] `scenes/weapons/ExhaustFlames.gd` exists with COOLDOWN=1.5, RADIUS=120, HALF_ANGLE=deg_to_rad(30), authority guard, server guard, cone filter, take_damage, deactivate()
- [x] `scenes/weapons/SpinningTires.gd` exists with ORBIT_RADIUS=50, ORBIT_SPEED=2.0, HIT_COOLDOWN=0.5, _hit_times dict, is_multiplayer_authority() guard, take_damage, deactivate()
- [x] `scenes/weapons/WeaponManager.gd` contains `func _activate_weapon_node(weapon_id: String) -> void:`
- [x] `scenes/weapons/WeaponManager.gd` contains `_activate_weapon_node(weapon_id)` call in add_weapon
- [x] `scenes/weapons/WeaponManager.gd` reset() calls deactivate/queue_free on weapon nodes
- [x] `scenes/weapons/WeaponManager.gd` contains `call_deferred("add_child", wep)`
- [x] Commits `45b1459` and `bde4191` exist in git log

## Self-Check: PASSED

---
*Phase: 04-weapons-and-item-pickups*
*Completed: 2026-05-31*
