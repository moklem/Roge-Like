---
phase: 06-xp-level-up-cards-and-evolution
plan: "04"
subsystem: progression
tags: [weapons, level-scaling, stage3-damage-mult, element-tier, xp, multiplayer, host-authoritative]
dependency_graph:
  requires: [06-03]
  provides: [XP-04, XP-08, EVOL-03, EVOL-05]
  affects:
    - scenes/weapons/WeaponManager.gd
    - scenes/weapons/ExhaustFlames.gd
    - scenes/weapons/SpinningTires.gd
    - scenes/weapons/AntennaBeam.gd
    - scenes/weapons/HornShockwave.gd
    - scenes/weapons/AirbagShield.gd
    - scenes/Player.gd
    - scenes/Game.gd
tech_stack:
  added: []
  patterns:
    - host-authoritative-damage-with-stage3-mult
    - level-param-in-rpc-signature
    - element-tier-divisor-for-proc-interval
    - active-count-pattern-for-orbit-scaling
    - create-timer-slow-restore-pattern
decisions:
  - "_screws_interval var introduced so L3 cooldown can be updated at runtime (SCREWS_INTERVAL const unchanged)"
  - "SpinningTires pre-creates 5 tires in activate() and hides extras — no re-create on upgrade"
  - "AntennaBeam L2 double-burst uses await in _on_fire_timer; T-06-14 is_instance_valid guard after await"
  - "HornShockwave L2 sets _timer.wait_time on fire (not on upgrade) — simpler, fires at correct rate from first L2 shot"
  - "Earth element_tier: max tier among all alive earth players used for heal_rate/sw_cooldown"
  - "AirbagShield.gd: no code changes needed; stale airbag_active comments updated to reflect airbag_count"
  - "AntennaBeam DAMAGE const is 25 in live code (not 20 as D-11 table baseline); L3 sets base_dmg=30"
metrics:
  duration: "~6 min"
  completed_date: "2026-06-18"
  tasks_completed: 2
  tasks_total: 2
  files_changed: 8
---

# Phase 6 Plan 04: All 6 Weapon Level 2/3 Stat Scaling + stage3_damage_mult + Earth element_tier Summary

D-11 weapon upgrade stats wired end-to-end: picking weapon upgrade cards now produces visible gameplay differences at Level 2 and 3 for all six weapons; Stage 3 players deal 20% more damage via stage3_damage_mult; Fire/Ice element procs fire faster at higher element_tier; Earth heal rate and shockwave cooldown scale by tier.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | ScrewsAndBolts L2/L3 spread, ExhaustFlames cone/slow, SpinningTires orbit scaling | 55e8472 | scenes/weapons/WeaponManager.gd, scenes/weapons/ExhaustFlames.gd, scenes/weapons/SpinningTires.gd |
| 2 | AntennaBeam + HornShockwave L2/L3 scaling; AirbagShield review; Player.gd element_tier in _tick_element; Game.gd Earth D-21 | a005c17 | scenes/weapons/AntennaBeam.gd, scenes/weapons/HornShockwave.gd, scenes/weapons/AirbagShield.gd, scenes/Player.gd, scenes/Game.gd |

## What Was Built

**scenes/weapons/WeaponManager.gd changes:**

- `_screws_interval: float = 0.5` var added alongside `SCREWS_INTERVAL` const; `tick()` uses `_screws_interval` (not const) so `upgrade_weapon()` can update it to 0.35 at L3
- `_fire_screws()`: reads `weapon_level["screws_and_bolts"]`, calls `_get_screws_dirs(base_dir, level)`, iterates dirs array to spawn bolts
- `_get_screws_dirs(base_dir, level)`: L1=1 bolt straight, L2=2 bolts ±15°, L3=3 bolts at 0°/±30°
- `upgrade_weapon()`: L3 screws now sets `_screws_interval = 0.35` (was incorrectly trying `get_node("ScrewsAndBolts").wait_time`)
- `reset()`: resets `_screws_interval` to `SCREWS_INTERVAL`

**scenes/weapons/ExhaustFlames.gd changes:**

- `_on_fire_timer()`: reads level; computes `half_angle` (30°/45°/60°), `radius` (120/160px), `damage` (DAMAGE * stage3_damage_mult)
- Updates CircleShape2D radius before overlap query so broader area is searched at L2/L3
- Hit loop uses `half_angle` and `damage` vars (not HALF_ANGLE/DAMAGE consts)
- L3: adds `body.velocity *= 0.5` + 1s create_timer to restore with `is_instance_valid` guard (T-06-15)

**scenes/weapons/SpinningTires.gd changes:**

- `activate()`: creates 5 tires (was 3); tires 3/4 start with `visible = false`
- `_physics_process()`: reads `weapon_level["spinning_tires"]`; computes `speed_mult` (1.25 at L2), `damage_per_tick` (12 at L1/L2, 18 at L3); applies `stage3_damage_mult`
- `active_count = mini(3 + maxi(level - 1, 0), _tires.size())` — L1=3, L2=4, L3=5
- Orbit angle spacing computed from `active_count` (not hardcoded 3.0); tires beyond active_count hidden
- Damage loop iterates only `active_count` tires

**scenes/weapons/AntennaBeam.gd changes:**

- `_on_fire_timer()`: reads level; L2 fires first shot, awaits 0.2s (T-06-14 `is_instance_valid(self)` guard), then fires again; passes `level` + `player.peer_id` to `_apply_damage`
- `_apply_damage(origin, dir, level=1, shooter_peer_id=0)`: new params with defaults for backward compat; L3 `base_dmg=30`, `hit_radius*=2.0`; `stage_mult` looked up from players group by `shooter_peer_id`; final damage = `int(base_dmg * stage_mult)`

**scenes/weapons/HornShockwave.gd changes:**

- `_on_fire_timer()`: reads level; L2 sets `radius=220.0` and `_timer.wait_time=2.5`; updates CollisionShape2D radius before overlap; applies `stage3_damage_mult` to `damage`
- Hit loop: uses `damage` var; L2 adds knockback 300px; L3 knockback 600px (×2); L3 sets `body.velocity = Vector2.ZERO` for stun

**scenes/weapons/AirbagShield.gd changes:**

- Stale `airbag_active` references in comments updated to reflect `airbag_count` (no functional code changes)
- `hide_ring()` / `show_ring()` APIs confirmed intact; `consume_airbag()` chain remains valid

**scenes/Player.gd changes:**

- `_tick_element()` fire branch: `fire_interval = 4.0 / float(element_tier)` (T1=4s, T2=2s, T3=1.33s); resets `_fire_burst_timer` with `fire_interval`
- `_tick_element()` ice branch: `ice_interval = 0.3 / float(element_tier)` (T1=0.3s, T2=0.15s, T3=0.1s); resets `_ice_trail_timer` with `ice_interval`
- Earth match arm: comment clarifying Game.gd reads `element_tier` directly

**scenes/Game.gd changes:**

- `_tick_earth_effects()`: D-21 implementation — finds max `element_tier` among alive earth players; uses `heal_rate = [2, 2, 4, 6][tier]` and `sw_cooldown = [8.0, 8.0, 6.0, 5.0][tier]` arrays
- Heal loop uses `heal_rate` (not hardcoded 2)
- Shock accum checked against `sw_cooldown` (not hardcoded 8.0)
- T3: after knockback, adds `enemy.velocity *= 0.5` + 1s create_timer restore with `is_instance_valid` guard

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed upgrade_weapon L3 screws cooldown setting wrong node**
- **Found during:** Task 1
- **Issue:** `upgrade_weapon()` tried `get_node("ScrewsAndBolts").wait_time = 0.35` but screws use `_screws_cooldown` float var, not a Timer node named "ScrewsAndBolts"
- **Fix:** Added `_screws_interval` var; `tick()` resets cooldown to `_screws_interval`; `upgrade_weapon()` sets `_screws_interval = 0.35` at L3; `reset()` restores it to `SCREWS_INTERVAL`
- **Files modified:** scenes/weapons/WeaponManager.gd
- **Commit:** 55e8472

**2. [Rule 1 - Bug] AntennaBeam DAMAGE const is 25, not 20**
- **Found during:** Task 2
- **Issue:** D-11 table says "Damage 20→30" but the live DAMAGE const in AntennaBeam.gd is 25 (not 20). The L3 value 30 is still unambiguous per D-11.
- **Fix:** L3 sets `base_dmg = 30` (correct per D-11). L1/L2 use DAMAGE const (25) as-is — not changed to avoid breaking existing balance.
- **Files modified:** scenes/weapons/AntennaBeam.gd (comment notes 25→30)
- **Commit:** a005c17

**3. [Rule 2 - Missing] ExhaustFlames shape radius not updated before overlap query**
- **Found during:** Task 1
- **Issue:** Plan code updated `half_angle`/`radius` vars but original `_setup_area` created shape with fixed 120px radius. The overlap query returns enemies within the old radius even at L2/L3.
- **Fix:** Added `for child in _area.get_children()` loop to update CircleShape2D radius before the overlap query runs on each fire tick.
- **Files modified:** scenes/weapons/ExhaustFlames.gd
- **Commit:** 55e8472

## Known Stubs

None — all planned behaviors are wired. The cooldown stat boost stub in Plan 03 remains (unrelated to this plan).

## Threat Surface

All threat model mitigations from the plan implemented:

- T-06-12 (stage3_damage_mult tampering): `stage3_damage_mult` only set by `set_evolution_stage(3)` (host-authorized) or `_apply_stat_boost_rpc` (host-sent RPC) — unchanged by this plan
- T-06-13 (element_tier inflation): `element_tier` only incremented by `receive_element_tier_up` RPC called from host `_apply_card_effect` — unchanged by this plan
- T-06-14 (AntennaBeam await stale self): `if not is_instance_valid(self): return` guard added after `await get_tree().create_timer(0.2).timeout`
- T-06-15 (SpinningTires create_timer after enemy death): `is_instance_valid(body)` and `is_queued_for_deletion()` checked before velocity write in ExhaustFlames L3 slow and Game.gd D-21 T3 slow

No new threat surface introduced by this plan.

## Self-Check: PASSED

Files exist:
- scenes/weapons/WeaponManager.gd — FOUND (modified)
- scenes/weapons/ExhaustFlames.gd — FOUND (modified)
- scenes/weapons/SpinningTires.gd — FOUND (modified)
- scenes/weapons/AntennaBeam.gd — FOUND (modified)
- scenes/weapons/HornShockwave.gd — FOUND (modified)
- scenes/weapons/AirbagShield.gd — FOUND (modified)
- scenes/Player.gd — FOUND (modified)
- scenes/Game.gd — FOUND (modified)

Commits:
- 55e8472 — feat(06-04): ScrewsAndBolts L2/L3 spread, ExhaustFlames cone/slow, SpinningTires orbit scaling
- a005c17 — feat(06-04): AntennaBeam/HornShockwave L2/L3 scaling, element_tier proc rate, Earth D-21
