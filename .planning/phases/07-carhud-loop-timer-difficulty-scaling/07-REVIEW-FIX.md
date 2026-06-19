---
phase: 07-carhud-loop-timer-difficulty-scaling
fixed_at: 2026-06-19T00:00:00Z
review_path: .planning/phases/07-carhud-loop-timer-difficulty-scaling/07-REVIEW.md
iteration: 1
findings_in_scope: 8
fixed: 8
skipped: 0
status: all_fixed
---

# Phase 07: Code Review Fix Report

**Fixed at:** 2026-06-19
**Source review:** `.planning/phases/07-carhud-loop-timer-difficulty-scaling/07-REVIEW.md`
**Iteration:** 1

**Summary:**
- Findings in scope: 8 (4 Critical, 4 Warning — Info findings excluded per fix_scope)
- Fixed: 8
- Skipped: 0

---

## Fixed Issues

### CR-01: Host player can never be revived (`call_remote` no-op to self)

**Files modified:** `scenes/Game.gd`
**Commit:** `09163f3`
**Applied fix:** Added an `if target.peer_id == multiplayer.get_unique_id()` guard around the `receive_revive` call at line 345. When the host player is the revive target the method is now called directly (bypassing the no-op RPC); for remote peers `rpc_id(target.peer_id)` is used as before. Mirrors the pattern already used in `_tick_engineer_passive` and `_tick_earth_effects`.

---

### CR-02: `GameState.loop_number` and `revives_used` not reset on game-over

**Files modified:** `autoloads/GameState.gd`
**Commit:** `f4b3f17`
**Applied fix:** Added `reset_for_new_run()` function that sets `loop_number = 1`, `loop_timer = 0.0`, and clears `revives_used`. Called it at the end of `_broadcast_game_over()` just before `change_scene_to_file(...)` so every new run starts at loop 1 with no residual revive blocks.

---

### CR-03: `GameEvents.emit_hud()` called without `.rpc()` — client CarHUDs receive no event

**Files modified:** `scenes/Game.gd`
**Commit:** `530be64`
**Applied fix:** Changed three bare `GameEvents.emit_hud(...)` calls to `GameEvents.emit_hud.rpc(...)`:
- Line 612 (`request_ice_trail`): `emit_hud("ac")` → `emit_hud.rpc("ac")`
- Line 661 (`_tick_earth_effects` heal): `emit_hud("seat_massage")` → `emit_hud.rpc("seat_massage")`
- Line 687 (`_tick_earth_effects` shockwave): same fix

---

### WR-01: Revive-limit silent block leaves ReviveBar stuck at 100%

**Files modified:** `scenes/Game.gd`
**Commit:** `b425dc6`
**Applied fix:** Added `_update_revive_bar(target_id, 0.0)` call on the blocked-revive early-return path (before the `return` at line 338). This resets the reviver's progress bar to 0 so the stuck-at-100% visual feedback is eliminated when a second revive attempt is silently blocked.

---

### WR-02: SUSPENSION fires on scaled normal enemy hits at loop 3+

**Files modified:** `scenes/enemies/Enemy.gd`, `scenes/enemies/EliteEnemy.gd`, `scenes/Player.gd`
**Commit:** `46bddf0`
**Applied fix:**
- Added `is_elite: bool = false` property to `Enemy.gd`.
- Set `is_elite = true` in `EliteEnemy._ready()`.
- Updated `_on_hurtbox_body_entered` in `Enemy.gd` to pass `is_elite` as the third argument to `receive_damage` (both the direct call and `rpc_id` call paths).
- Changed `receive_damage` signature in `Player.gd` to `func receive_damage(amount: int, attacker_path: String = "", from_elite: bool = false)`.
- Replaced the `if amount >= 15` SUSPENSION guard with `if from_elite`. This ensures the SUSPENSION indicator only fires for elite enemy contacts regardless of how high normal-enemy damage scales in later loops.

---

### WR-03: `current_hp` latent mis-sync — bare instantiation bypasses spawn scaling

**Files modified:** `scenes/enemies/Enemy.gd`
**Commit:** `77533e2`
**Applied fix:** Removed `= MAX_HP` initialiser from the class-level `current_hp` declaration. Added `current_hp = MAX_HP` as the first statement in `Enemy._ready()`. This means any bare instantiation of Enemy.tscn will still get a correct `current_hp` that reflects the actual `MAX_HP` value at the time `_ready()` runs. The spawn path (`_do_spawn_enemy`) and `EliteEnemy._ready()` continue to overwrite `current_hp` after setting their respective `MAX_HP` values, so the existing spawn behaviour is unchanged.

---

### WR-04: Debug `print()` statements and test comment left in production code

**Files modified:** `scenes/enemies/Enemy.gd`, `scenes/Game.gd`
**Commit:** `6d03a23`
**Applied fix:**
- Removed `print("Hurtbox body_entered: ...")` (Enemy.gd line 121) from `_on_hurtbox_body_entered`.
- Removed `print("Contact damage to player ...")` (Enemy.gd line 132) from the same function.
- Replaced `# TEST: Sofort neuen Feind spawnen damit immer Gegner da sind` (Game.gd line 226) with `# D-03 (design): respawn one enemy immediately on death to keep pressure constant.` — the gameplay mechanic is intentional; only the debug annotation is removed.

---

### WR-05: `_hud_event_label` is a declared but always-null dead variable

**Files modified:** `scenes/Game.gd`
**Commit:** `390dae0`
**Applied fix:**
- Replaced the `var _hud_event_label: Label = null` declaration with a single explanatory comment noting that CarHUD is now the sole HUD-event consumer.
- Removed the `_on_hud_event(_event_name: String)` method and its preceding comment block entirely. The existing comment inside `_setup_player_hud` (lines 118-121) already documents the migration from the label to CarHUD, so no replacement comment is needed at the removed method site.

---

## Skipped Issues

None — all in-scope findings were fixed.

---

_Fixed: 2026-06-19_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
