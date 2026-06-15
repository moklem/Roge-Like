---
phase: "05"
plan: "review-fix"
status: all_fixed
findings_in_scope: 8
fixed: 8
skipped: 0
iteration: 1
---

# Phase 05: Code Review Fix Report

**Fixed at:** 2026-06-15T00:00:00Z
**Source review:** .planning/phases/05-roles-elements/05-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 8
- Fixed: 8
- Skipped: 0

## Fixed Issues

### CR-001: Drone "max 1" cleanup searches wrong node tree

**Files modified:** `scenes/Game.gd`
**Commit:** aa0aa57
**Applied fix:** Replaced `get_children()` on the Game node with `get_node_or_null("Room1/Entities")` and iterated its children; added `break` after first match to stop scanning once the old drone is found and freed.

---

### CR-002: Client Fire Burst drops `force_burn` — burn never procs for non-host Fire players

**Files modified:** `scenes/Player.gd`
**Commit:** 025c646
**Applied fix:** Added `true` as the fifth argument to `game.request_fire.rpc_id(1, global_position, spread, peer_id, true)` in the client branch of `_fire_burst()`, matching the host path which already passes `"fire_burst": true` in the spawn dict.

---

### CR-003: `weapon_unlocked` annotated `call_local` — host double-executes weapon grant

**Files modified:** `scenes/Game.gd`
**Commit:** e81208d
**Applied fix:** Changed `@rpc("authority", "call_local", "reliable")` to `@rpc("authority", "call_remote", "reliable")` on `weapon_unlocked` so the host does not execute the function body locally when it sends the RPC to a remote peer.

---

### CR-004: `attempt_revive` uses `get_physics_process_delta_time()` inside an RPC handler

**Files modified:** `scenes/Game.gd`
**Commit:** 960e6f1
**Applied fix:** Replaced `get_physics_process_delta_time()` with `get_process_delta_time()` in `attempt_revive`. RPC dispatch happens during `_process` polling, so `get_process_delta_time()` returns the elapsed wall-clock delta appropriate for this context.

---

### CR-005: `_spawn_dash_shockwave` dereferences freed enemy after `take_damage`

**Files modified:** `scenes/Player.gd`
**Commit:** 19c2fd9
**Applied fix:** Added `if not is_instance_valid(enemy) or enemy.is_queued_for_deletion(): continue` immediately after `enemy.take_damage(DASH_SHOCK_DAMAGE)` and before the knockback velocity write, mirroring the identical guard already present in the Earth shockwave in `Game.gd`.

---

### WR-001: Dead variables — `_earth_heal_timer`, `_earth_shockwave_timer`, `_engineer_passive_timer` never used

**Files modified:** `scenes/Player.gd`
**Commit:** 7e56dda
**Applied fix:** Removed the three variable declarations (`_earth_heal_timer`, `_earth_shockwave_timer`, `_engineer_passive_timer`) from the var block and their three initialization lines from `_ready()`. Only `_fire_burst_timer = 4.0` remains, as it is actively used by `_tick_element()`.

---

### WR-002: Debug 100% car-part drop rate left in shipping code

**Files modified:** `scenes/Game.gd`
**Commit:** 4c9068b
**Applied fix:** Changed `if randf() < 1.0:` to `if randf() < 0.25:` in `_on_enemy_died` and updated the comment to reflect the D-03 design value.

---

### WR-003: Enemy health bar only updates on host — clients see stale/full bar

**Files modified:** `scenes/enemies/Enemy.gd`
**Commit:** fe36a06
**Applied fix:** Added a `_process(_delta)` function that updates `$HealthBar.value` from `current_hp` on all peers (with a `has_node("HealthBar")` guard). Removed the health bar update line from `_physics_process`, which is disabled on non-host peers by the P6 guard in `_ready()`.

---

_Fixed: 2026-06-15T00:00:00Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
