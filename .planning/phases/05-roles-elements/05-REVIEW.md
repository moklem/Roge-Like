---
phase: "05"
plan: "review"
status: issues
files_reviewed: 10
files_reviewed_list:
  - scenes/Game.gd
  - scenes/Game.tscn
  - scenes/Player.gd
  - scenes/Player.tscn
  - scenes/elements/IceTrailZone.gd
  - scenes/elements/IceTrailZone.tscn
  - scenes/enemies/Enemy.gd
  - scenes/projectiles/Bullet.gd
  - scenes/roles/HealDrone.gd
  - scenes/roles/HealDrone.tscn
findings:
  critical: 5
  warning: 3
  info: 3
  total: 11
---

# Phase 05: Code Review Report

**Reviewed:** 2026-06-15T00:00:00Z
**Depth:** standard
**Files Reviewed:** 10
**Status:** issues_found

## Summary

Ten source files covering roles (Tank, Speedster, Engineer), elements (Fire, Ice, Earth), and the supporting multiplayer infrastructure were reviewed at standard depth. Five critical bugs were found: a broken "max 1 drone" constraint caused by a wrong node path in the cleanup search; a missing `force_burn` argument on the client Fire Burst RPC path that silently disables burn procs for non-host Fire players; a `call_local` annotation on `weapon_unlocked` that causes the host to run weapon-add logic it was never meant to execute locally; a wrong delta source inside the revive-accumulator RPC handler that makes revive timing unreliable; and a freed-object dereference in `_spawn_dash_shockwave` where `enemy.velocity` is written after `take_damage()` may have already freed the node. Three warnings and three informational issues round out the review.

---

## Critical Issues

### CR-001: Drone "max 1" cleanup searches wrong node tree

**File:** `scenes/Game.gd:298-300`
**Severity:** CRITICAL
**Issue:** `request_deploy_drone` removes the previous drone by iterating `get_children()` on the `Game` node itself. However all six spawners (including `DroneSpawner`) have `spawn_path = NodePath("../Room1/Entities")` in `Game.tscn` (line 314), so drones are placed under `Room1/Entities`, not as direct children of `Game`. The name comparison `child.name == "HealDrone_%d" % requester_peer_id` therefore never matches, and the old drone is never freed. Every engineer ability activation spawns an additional drone, unboundedly stacking heal pulses.

```gdscript
# Bug (Game.gd line 298-300):
for child in get_children():          # searches Game's direct children
    if child.name == "HealDrone_%d" % requester_peer_id:
        child.queue_free()

# Fix — search the actual spawn container:
var entities := get_node_or_null("Room1/Entities")
if entities:
    for child in entities.get_children():
        if child.name == "HealDrone_%d" % requester_peer_id:
            child.queue_free()
            break
```

---

### CR-002: Client Fire Burst drops `force_burn` — burn never procs for non-host Fire players

**File:** `scenes/Player.gd:276-277`
**Severity:** CRITICAL
**Issue:** `_fire_burst()` has two code paths. The host path (lines 268-274) correctly passes `"fire_burst": true` in the spawn dict, which `_do_spawn_bullet` maps to `b.force_burn = true`. The client path (line 277) calls `game.request_fire.rpc_id(1, global_position, spread, peer_id)` — it omits the fifth `force_burn` parameter entirely. `request_fire`'s signature has `force_burn: bool = false` as a default, so the host spawns all Fire Burst bullets from non-host players with `force_burn=false`, meaning they fall through to the 25%-chance regular fire proc instead of the guaranteed burn. The Fire Burst ability is silently broken for every non-host Fire-element player.

```gdscript
# Bug (Player.gd line 277):
game.request_fire.rpc_id(1, global_position, spread, peer_id)
# force_burn not passed — host receives false, no guaranteed burn

# Fix:
game.request_fire.rpc_id(1, global_position, spread, peer_id, true)
```

---

### CR-003: `weapon_unlocked` annotated `call_local` — host double-executes weapon grant

**File:** `scenes/Game.gd:246-251`
**Severity:** CRITICAL
**Issue:** The `weapon_unlocked` RPC is declared `@rpc("authority", "call_local", "reliable")`. `call_local` means the function body runs on the **calling peer** (the host) **in addition** to the remote peer. So when the host calls `weapon_unlocked(weapon_id, collector_peer_id)` to notify a client, the host also immediately executes the function body itself. If the host's own `Player` node happens to have the matching `peer_id` (i.e., the host player collected the weapon), or if another frame triggers a re-call, `add_weapon` is invoked twice. The correct annotation for a server-to-specific-client grant is `@rpc("authority", "call_remote", "reliable")`.

```gdscript
# Bug:
@rpc("authority", "call_local", "reliable")
func weapon_unlocked(weapon_id: String, collector_peer_id: int) -> void:

# Fix:
@rpc("authority", "call_remote", "reliable")
func weapon_unlocked(weapon_id: String, collector_peer_id: int) -> void:
```

---

### CR-004: `attempt_revive` uses `get_physics_process_delta_time()` inside an RPC handler

**File:** `scenes/Game.gd:216`
**Severity:** CRITICAL
**Issue:** `attempt_revive` is an RPC handler. It is invoked by the Godot multiplayer system when a network packet arrives, which happens during the network polling step — not inside `_physics_process`. Calling `get_physics_process_delta_time()` in this context returns the *last cached* physics step delta (fixed at ~0.01667s for 60 Hz physics), not the actual wall-clock time elapsed since the previous RPC call arrived. If the client sends RPCs at a rate different from physics_fps (e.g., due to jitter, lag, or `_physics_process` running at a different rate than the RPC polling rate), the revive accumulator will drift. In the worst case — a lagging client that batches RPCs — multiple calls arrive in the same poll cycle, each adding only one physics delta, causing severe undercount and making revive take far longer than `REVIVE_DURATION`. The fix is to use `get_process_delta_time()` (which matches the `_process` loop where RPC dispatch occurs) or, better, track wall-clock time with `Time.get_ticks_msec()`.

```gdscript
# Bug (Game.gd line 216):
var dt: float = get_physics_process_delta_time()

# Fix — use process delta (matches RPC dispatch loop):
var dt: float = get_process_delta_time()

# Robust fix — record real elapsed time per target:
# Store Time.get_ticks_msec() alongside the accumulated seconds and
# compute dt = (Time.get_ticks_msec() - _revive_last_tick[target_id]) / 1000.0
```

---

### CR-005: `_spawn_dash_shockwave` dereferences freed enemy after `take_damage`

**File:** `scenes/Player.gd:381-383`
**Severity:** CRITICAL
**Issue:** `_spawn_dash_shockwave` calls `enemy.take_damage(DASH_SHOCK_DAMAGE)` (line 381), which may call `queue_free()` on the enemy if it dies from that hit. Line 383 then immediately accesses `enemy.global_position` and `enemy.velocity` on a potentially freed object without an `is_instance_valid` guard. This is the same pattern the Earth shockwave correctly handles in `Game.gd` (lines 392-395), but the Speedster's shockwave in `Player.gd` skips the check.

```gdscript
# Bug (Player.gd lines 380-383):
if enemy.has_method("take_damage"):
    enemy.take_damage(DASH_SHOCK_DAMAGE)
# Knockback: push enemy away from shockwave origin
enemy.velocity += (enemy.global_position - pos).normalized() * 300.0

# Fix — mirror the Game.gd Earth shockwave pattern:
if enemy.has_method("take_damage"):
    enemy.take_damage(DASH_SHOCK_DAMAGE)
if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
    enemy.velocity += (enemy.global_position - pos).normalized() * 300.0
```

---

## Warnings

### WR-001: Dead variables — `_earth_heal_timer`, `_earth_shockwave_timer`, `_engineer_passive_timer` never used

**File:** `scenes/Player.gd:45-47, 70-72`
**Severity:** WARNING
**Issue:** Three timer variables are declared and initialized in `_ready()` but are never decremented or read in `_tick_element()`. Earth heal/shockwave and Engineer passive are implemented entirely in `Game.gd`'s `_tick_earth_effects` and `_tick_engineer_passive`. The Player-side variables are dead code that mislead future maintainers into thinking per-player element ticking is still in Player.gd, and they waste memory on every player instance.

**Fix:** Remove `_earth_heal_timer`, `_earth_shockwave_timer`, and `_engineer_passive_timer` from `Player.gd` entirely. If per-player tracking is ever needed, reintroduce them alongside actual usage.

---

### WR-002: Debug 100% car-part drop rate left in shipping code

**File:** `scenes/Game.gd:115`
**Severity:** WARNING
**Issue:** The comment on line 114 explicitly states `# D-03: 25% → TEST: 100% drop damit alle Waffen schnell getestet werden können`. The condition `if randf() < 1.0:` is always true — every enemy death drops a car part. This is a test override that was not reverted before shipping.

```gdscript
# Bug (Game.gd line 115):
if randf() < 1.0:   # always true — test override

# Fix — restore intended 25% design value:
if randf() < 0.25:
```

---

### WR-003: Enemy health bar only updates on host — clients see stale/full bar

**File:** `scenes/enemies/Enemy.gd:54-55`
**Severity:** WARNING
**Issue:** `$HealthBar.value` is set inside `_physics_process` (line 55). `_physics_process` is disabled on all non-host peers via `set_physics_process(is_multiplayer_authority())` in `_ready()` (line 32). The `current_hp` field is replicated by `MultiplayerSynchronizer` at 20 Hz, so clients have the correct HP value — but the health bar node is never updated from that synced value on the client side. Every enemy appears to have full health on all client screens.

**Fix:** Move the health bar update to `_process` (which runs on all peers) or connect to a signal on the `MultiplayerSynchronizer`'s property sync event:

```gdscript
func _process(_delta: float) -> void:
    if has_node("HealthBar"):
        $HealthBar.value = float(current_hp) / float(MAX_HP) * 100.0
```

---

## Info

### IN-001: Debug `print()` calls left in production hot paths

**File:** `scenes/Player.gd:414, 422, 432` | `scenes/enemies/Enemy.gd:117, 128`
**Severity:** INFO
**Issue:** Five `print()` calls fire on every damage event and every enemy contact-body-entered event. In a multiplayer session this will generate hundreds of log lines per second per enemy hit, degrading editor output readability and potentially impacting performance in debug builds.

**Fix:** Remove all five calls or replace with `push_warning()` / conditional `if OS.is_debug_build()` guards.

---

### IN-002: `_show_earth_shockwave` is callable by any peer — purely cosmetic but inconsistent

**File:** `scenes/Game.gd:402`
**Severity:** INFO
**Issue:** `_show_earth_shockwave` is annotated `@rpc("any_peer", "call_local", "unreliable_ordered")`. The `any_peer` permission means a malicious or buggy client could invoke this RPC on the host, flooding all clients with spurious green ring animations. Since the function has no game-state side effects this is not exploitable beyond a visual DoS, but it's inconsistent with the project's pattern of using `@rpc("authority")` for host-originated broadcasts.

**Fix:** Change annotation to `@rpc("authority", "call_local", "unreliable_ordered")` to restrict callers to the host only.

---

### IN-003: `IceTrailZone` directly mutates private field `body._slow_timer`

**File:** `scenes/elements/IceTrailZone.gd:50`
**Severity:** INFO
**Issue:** After calling `body.apply_slow()`, `IceTrailZone` directly overwrites `body._slow_timer = SLOW_DURATION` to override the 2.0s that `apply_slow()` sets. Accessing a leading-underscore ("private") field across scene boundaries couples two unrelated scripts and will silently break if `Enemy.gd` renames or restructures its timer.

**Fix:** Add a dedicated `apply_slow(duration: float)` overload or a separate `apply_trail_slow()` method in `Enemy.gd` that sets the desired duration, and call that from `IceTrailZone` instead.

```gdscript
# Enemy.gd — add:
func apply_trail_slow() -> void:
    speed_multiplier = 0.5
    _slow_timer = 1.5   # IceTrail override duration (D-18)
    modulate = Color(0.5, 0.7, 1.0)

# IceTrailZone.gd — replace lines 47-50:
if body.is_in_group("enemies") and body.has_method("apply_trail_slow"):
    body.apply_trail_slow()
```

---

_Reviewed: 2026-06-15T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
