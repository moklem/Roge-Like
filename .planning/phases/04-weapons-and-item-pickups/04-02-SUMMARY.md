---
phase: 04-weapons-and-item-pickups
plan: 02
subsystem: weapons
tags: [godot, gdscript, multiplayer, weapon-manager, screws-and-bolts, airbag-shield]

# Dependency graph
requires:
  - phase: 04-01
    provides: weapon_unlocked RPC on Game.gd; CarPartPickup scene; PickupSpawner wiring
  - phase: 03-room-1-enemy-ai-combat-core
    provides: Player.gd with _try_fire/_fire_cooldown, receive_damage RPC, multiplayer authority pattern
provides:
  - WeaponManager.gd — weapon unlock API (add_weapon, reset), ScrewsAndBolts fire logic, airbag charge state
  - Player.tscn — WeaponManager as child Node (D-06)
  - Player.gd — delegates to WeaponManager.tick(delta); airbag intercept in receive_damage (D-13)
affects:
  - 04-03
  - 04-04
  - 04-05
  - 05-gamestate-death-reset

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "WeaponManager as child Node of Player — all weapon logic isolated from Player.gd (D-06/D-08)"
    - "tick(delta) pattern — WeaponManager driven by Player._physics_process, not its own _process"
    - "Authority-guarded tick — early return if not get_parent().is_multiplayer_authority() (W2)"
    - "Silent caps — add_weapon returns false without error for full slots (D-15) or duplicates (D-01)"
    - "airbag_active flag — passive charge; lethal hit intercept before health -= amount (D-13)"

key-files:
  created:
    - scenes/weapons/WeaponManager.gd
  modified:
    - scenes/Player.tscn
    - scenes/Player.gd

key-decisions:
  - "WeaponManager.tick() receives delta from Player._physics_process — no separate _process hook needed"
  - "add_weapon() silently caps at MAX_WEAPONS=6 (D-15) and silently ignores duplicates (D-01) — returns bool only"
  - "airbag_shield can be re-armed after charge consumption via second pickup (D-13)"
  - "weapon_level dict initialized at 1 on unlock — Phase 6 card picks will increment (D-02)"
  - "Player.gd fire logic fully removed — _try_fire, _fire_cooldown, FIRE_INTERVAL gone; WeaponManager owns these"

patterns-established:
  - "WeaponManager.tick(delta): weapons use delta-countdown cooldown inside tick, not Timer nodes"
  - "Authority guard in tick(): single early return at top prevents non-owning peers from firing"
  - "ScrewsAndBolts fire path: same as former Player._try_fire — is_server() direct or rpc_id(1)"

requirements-completed: [WEAP-03, WEAP-04, WEAP-05, WEAP-07, WEAP-08]

# Metrics
duration: 12min
completed: 2026-05-31
---

# Phase 04 Plan 02: WeaponManager Scaffold + ScrewsAndBolts Migration + Player.gd Refactor Summary

**WeaponManager child Node with ScrewsAndBolts auto-fire, 6-slot weapon unlock API, and airbag lethal-hit intercept wired into Player.gd receive_damage**

## Performance

- **Duration:** ~12 min
- **Started:** 2026-05-31T13:55:00Z
- **Completed:** 2026-05-31T14:07:42Z
- **Tasks:** 2
- **Files modified:** 3 (1 created, 2 modified)

## Accomplishments
- Created `scenes/weapons/WeaponManager.gd` — full weapon scaffold with add_weapon/reset/tick API, ScrewsAndBolts fire logic (migrated from Player.gd), authority guard, and airbag_active charge flag
- Added WeaponManager as child Node in `Player.tscn` (load_steps bumped to 5, ExtResource added)
- Refactored `Player.gd` — removed FIRE_INTERVAL, _fire_cooldown, _try_fire, _find_nearest_enemy; delegated to `$WeaponManager.tick(delta)`; extended `receive_damage` with D-13 airbag lethal-hit intercept

## Task Commits

Each task was committed atomically:

1. **Task 1: Create WeaponManager.gd with ScrewsAndBolts and full weapon API** - `0a552e8` (feat)
2. **Task 2: Add WeaponManager to Player.tscn and refactor Player.gd** - `d031a82` (feat)

**Plan metadata:** _(docs commit follows)_

## Files Created/Modified
- `scenes/weapons/WeaponManager.gd` — WeaponManager node: MAX_WEAPONS=6, WEAPON_IDS registry, unlocked_weapons/weapon_level/airbag_active state, tick()/add_weapon()/reset()/_fire_screws()/_find_nearest_enemy()
- `scenes/Player.tscn` — Added `[ext_resource ...WeaponManager.gd]` and `[node name="WeaponManager" type="Node" parent="."]`
- `scenes/Player.gd` — Removed _try_fire, _find_nearest_enemy, FIRE_INTERVAL, _fire_cooldown; added WeaponManager delegation and airbag intercept

## Decisions Made
- Tick delegation via `if has_node("WeaponManager"): $WeaponManager.tick(delta)` — defensive guard protects scene editor / solo test without WeaponManager present
- Authority guard inside `tick()` (not in Player.gd call site) — keeps the guard closest to the action for clarity and correctness
- Airbag re-arm works even at MAX_WEAPONS cap (check runs before cap check) — allows re-arm even with 6 weapons already unlocked

## Deviations from Plan

None — plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness
- WeaponManager scaffold complete; Wave 3 (04-03) can add ExhaustFlames and SpinningTires weapon entries via `add_weapon()` and `_activate_weapon_node()` placeholder comment
- `weapon_level` dict is established at unlock=1, ready for Phase 6 card pick upgrades
- `reset()` stub comment in place for Wave 3 timer deactivation wiring
- Wave 3 weapons (Exhaust, SpinningTires, Antenna, Shockwave) will call `_activate_weapon_node()` in `add_weapon()` — comment placeholder is in WeaponManager.gd

## Known Stubs
- `add_weapon()` in WeaponManager.gd has comment `# Wave 3 weapons ... wire their activation here` — no activation called for non-ScrewsAndBolts weapons yet (intentional; Wave 3 plan wires these)
- `reset()` has comment `# Wave 3 weapons deactivate their timers in reset` — timer deactivation not yet needed (intentional; Wave 3 plan adds timer nodes)

## Self-Check
- [x] `scenes/weapons/WeaponManager.gd` exists and contains all required elements (MAX_WEAPONS, add_weapon, reset, tick, _fire_screws, _find_nearest_enemy, airbag_active, weapon_level)
- [x] `scenes/Player.tscn` contains WeaponManager node entry with script reference
- [x] `scenes/Player.gd` does NOT contain FIRE_INTERVAL, _fire_cooldown, _try_fire, _find_nearest_enemy
- [x] `scenes/Player.gd` contains `$WeaponManager.tick(delta)` and airbag intercept in receive_damage
- [x] Commits `0a552e8` and `d031a82` exist in git log

## Self-Check: PASSED

---
*Phase: 04-weapons-and-item-pickups*
*Completed: 2026-05-31*
