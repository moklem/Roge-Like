---
phase: 04-weapons-and-item-pickups
plan: 05
subsystem: weapons
tags: [godot, gdscript, multiplayer, airbag-shield, weapon-manager, game-state, colorect, visual-ring]

# Dependency graph
requires:
  - phase: 04-02
    provides: WeaponManager with airbag_active flag, add_weapon("airbag_shield"), reset() stub; Player.gd receive_damage airbag intercept already wired
  - phase: 04-04
    provides: WeaponManager with all 4 timer weapon branches in _activate_weapon_node; reset() with node_names dict for exhaust/tires/antenna/shockwave
provides:
  - AirbagShield.gd visual ring node with activate/show_ring/hide_ring/deactivate
  - WeaponManager.consume_airbag() method wired to Player.gd receive_damage
  - WeaponManager._activate_weapon_node("airbag_shield") branch creating AirbagShield child node
  - WeaponManager.reset() covers all 5 car weapons including AirbagShield cleanup
  - GameState._broadcast_game_over resets all players' WeaponManagers before GameOver scene transition
affects:
  - 05-hud-and-game-events
  - 06-card-picks-and-upgrades

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "AirbagShield passive charge: not a timer weapon — ring visual node child of WeaponManager, hidden on consume_airbag()"
    - "Yellow ring via two overlapping ColorRects: outer yellow rect + transparent inner rect to create hollow ring effect"
    - "consume_airbag() as single entry point: sets airbag_active=false AND hides ring — Player.gd delegates here instead of direct flag write"
    - "GameState._broadcast_game_over loops players group before scene change — call_local ensures each peer resets its own WeaponManager"
    - "has_node guard before WeaponManager.reset() call in _broadcast_game_over — safe for players without WeaponManager (editor testing)"

key-files:
  created:
    - scenes/weapons/AirbagShield.gd
  modified:
    - scenes/weapons/WeaponManager.gd
    - autoloads/GameState.gd
    - scenes/Player.gd

key-decisions:
  - "AirbagShield ring positioned relative to AirbagShield node (child of WeaponManager → Player) so position=(-outer/2, -outer/2) centers on player"
  - "consume_airbag() encapsulates both flag clear and ring hide — prevents Player.gd from needing knowledge of AirbagShield node internals"
  - "Re-arm path (pick up again after consuming) only sets airbag_active=true in add_weapon re-arm branch — no new visual node; existing hidden ring shown via show_ring() would need separate wiring if needed (acceptable stub per D-13)"
  - "WeaponManager reset() loop extended with 'airbag_shield': 'AirbagShield' in node_names dict — deactivate() + queue_free() matches all other weapon nodes"
  - "_broadcast_game_over reset loop uses get_nodes_in_group('players') — works on any peer without host authority needed (call_local already guarantees per-peer execution)"

requirements-completed: [WEAP-06e, WEAP-07, WEAP-08]

# Metrics
duration: 5min
completed: 2026-05-31
---

# Phase 04 Plan 05: AirbagShield Visual + GameState Death Reset Summary

**AirbagShield yellow ring visual wired into WeaponManager via consume_airbag() callback, plus WeaponManager.reset() hooked into GameState._broadcast_game_over to clear all 5 weapons on game-over across all peers**

## Performance

- **Duration:** ~5 min
- **Started:** 2026-05-31T14:25:00Z
- **Completed:** 2026-05-31T14:30:00Z
- **Tasks:** 2
- **Files modified:** 4 (1 created, 3 modified)

## Accomplishments

- Created `scenes/weapons/AirbagShield.gd` — yellow ring visual (RING_RADIUS=28px, RING_THICKNESS=4px) built from two ColorRects, with activate/show_ring/hide_ring/deactivate methods; ring shows on activate, hides on consume, freed on reset
- Extended `scenes/weapons/WeaponManager.gd` — added "airbag_shield" branch to _activate_weapon_node with deferred add_child + activate; added _deferred_activate_airbag helper; added consume_airbag() method; extended reset() node_names dict to include AirbagShield
- Updated `scenes/Player.gd` — replaced `$WeaponManager.airbag_active = false` with `$WeaponManager.consume_airbag()` to trigger ring hide via encapsulated method
- Extended `autoloads/GameState.gd` — _broadcast_game_over now loops over "players" group and calls WeaponManager.reset() on each before scene change; @rpc annotation unchanged; reset loop before change_scene_to_file (WEAP-08)

## Task Commits

1. **task 1: implement AirbagShield visual ring and wire into WeaponManager** — `d951fa6` (feat)
2. **task 2: hook WeaponManager.reset into GameState game-over broadcast** — `1dc72dd` (feat)

**Plan metadata:** _(docs commit follows)_

## Files Created/Modified

- `scenes/weapons/AirbagShield.gd` — RING_RADIUS=28.0, RING_THICKNESS=4.0, yellow ColorRect outer + transparent inner ring, activate/show_ring/hide_ring/deactivate methods
- `scenes/weapons/WeaponManager.gd` — airbag_shield branch in _activate_weapon_node, _deferred_activate_airbag helper, consume_airbag() method, "airbag_shield":"AirbagShield" in reset() node_names, loop list extended to include "airbag_shield"
- `autoloads/GameState.gd` — _broadcast_game_over extended with players group loop calling WeaponManager.reset() before change_scene_to_file
- `scenes/Player.gd` — airbag_active = false replaced with consume_airbag() call

## Decisions Made

- AirbagShield ring is a child of the AirbagShield node (itself child of WeaponManager → Player), so position centered with negative half-size offset for correct player-centered rendering
- consume_airbag() as single entry point for charge consumption — encapsulates both state clear and visual update, keeps Player.gd decoupled from AirbagShield internals
- GameState reset loop uses has_node("WeaponManager") guard to remain safe in editor/solo testing where Player may not have WeaponManager
- WeaponManager.reset() existing structure (loop + node_names dict) simply extended — no structural changes needed

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

- Re-arm visual: when airbag is consumed and player picks up airbag again, add_weapon's re-arm path only sets airbag_active=true — it does NOT call show_ring() on the existing (hidden) AirbagShield node. The ring stays hidden on re-arm until a fix is added. This is acceptable in Phase 4 per D-13 (re-arm is a pickup scenario, not common). Fix: add_weapon re-arm branch should call get_node("AirbagShield").show_ring() if has_node("AirbagShield"). This can be resolved in a follow-up or Phase 5 polish.

## Threat Surface Scan

No new network endpoints or trust boundaries introduced. Mitigations from plan's threat model applied:
- T-04-13 (WeaponManager.reset race): accepted — _broadcast_game_over is reliable RPC; all peers reset before scene change
- T-04-14 (consume_airbag spoofing): accepted — consume_airbag() is local method on owning peer's WeaponManager; no RPC
- T-04-15 (weapon_level persistence): mitigated — reset() clears weapon_level = {}; confirmed in WeaponManager.gd line 110

## Self-Check

- [x] `scenes/weapons/AirbagShield.gd` exists
- [x] Contains `func show_ring() -> void:` with `_ring.visible = true`
- [x] Contains `func hide_ring() -> void:` with `_ring.visible = false`
- [x] Contains `func deactivate() -> void:` that calls `_ring.queue_free()`
- [x] `scenes/weapons/WeaponManager.gd` contains `"airbag_shield":` branch in `_activate_weapon_node`
- [x] `scenes/weapons/WeaponManager.gd` contains `func consume_airbag() -> void:`
- [x] `consume_airbag()` calls `get_node("AirbagShield").hide_ring()`
- [x] `reset()` node_names dict includes `"airbag_shield": "AirbagShield"`
- [x] `scenes/Player.gd` contains `$WeaponManager.consume_airbag()` (not direct airbag_active = false)
- [x] `autoloads/GameState.gd` `_broadcast_game_over` contains `p.get_node("WeaponManager").reset()`
- [x] `autoloads/GameState.gd` contains `if p.has_node("WeaponManager"):` guard
- [x] `@rpc("authority", "call_local", "reliable")` annotation unchanged in GameState.gd
- [x] Reset loop comes BEFORE `change_scene_to_file` in _broadcast_game_over
- [x] Commits `d951fa6` and `1dc72dd` exist in git log

## Self-Check: PASSED

---
*Phase: 04-weapons-and-item-pickups*
*Completed: 2026-05-31*
