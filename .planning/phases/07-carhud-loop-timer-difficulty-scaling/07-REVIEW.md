---
phase: 07-carhud-loop-timer-difficulty-scaling
reviewed: 2026-06-19T00:00:00Z
depth: standard
files_reviewed: 10
files_reviewed_list:
  - autoloads/GameEvents.gd
  - autoloads/GameState.gd
  - scenes/enemies/EliteEnemy.gd
  - scenes/enemies/EliteEnemy.tscn
  - scenes/enemies/Enemy.gd
  - scenes/Game.gd
  - scenes/pickups/XpOrb.gd
  - scenes/Player.gd
  - scenes/ui/CarHUD.gd
  - scenes/ui/CarHUD.tscn
findings:
  critical: 4
  warning: 5
  info: 3
  total: 12
status: issues_found
---

# Phase 07: Code Review Report

**Reviewed:** 2026-06-19T00:00:00Z
**Depth:** standard
**Files Reviewed:** 10
**Status:** issues_found

## Summary

Phase 7 added the CarHUD dashboard, EliteEnemy variant, per-loop difficulty scaling, an elite spawn timer, XP-per-orb scaling, and a revive-once-per-loop gate. The multiplayer authority model is applied correctly in most places, but four blockers were found: (1) the host player can never be revived because `receive_revive` is `call_remote` and no host-local path exists; (2) `GameState.loop_number` and `revives_used` are never reset when the game ends — they persist into the next run; (3) several `GameEvents.emit_hud()` calls on the host are made without `.rpc()`, so client CarHUDs never see those events; and (4) `Enemy.current_hp` is initialised at class-field declaration time — before `_ready()` applies difficulty scaling — so `current_hp` is always 50 even after `MAX_HP` is raised. Warnings cover a SUSPENSION double-trigger risk, a revive-limit silent-fail that leaves the progress bar stuck, a debug-test comment shipping in production, orphaned debug `print()` statements, and the `_hud_event_label` dead variable. Info items cover `loop_timer` having no writer, hardcoded sequential `unique_id` values in the elite tscn, and a leftover German TODO comment.

---

## Critical Issues

### CR-01: Host player can never be revived (`call_remote` no-op to self)

**File:** `scenes/Game.gd:345`

**Issue:** `target.receive_revive.rpc_id(target.peer_id)` is always used to revive the target. `receive_revive` is declared `@rpc("any_peer", "call_remote", "reliable")`. In Godot 4, `call_remote` means the RPC is never executed on the sender. When the host (peer_id = 1) player is downed and another player stands over them, the host calls `rpc_id(1, …)` to itself — which is a documented no-op for `call_remote`. The host player stays permanently downed. The existing pattern in `_tick_engineer_passive` (line 526) and `_tick_earth_effects` (line 656) correctly guards this case with `if target.peer_id == multiplayer.get_unique_id(): target.receive_heal(…) else: target.receive_heal.rpc_id(…)`. The revive path is missing that guard.

**Fix:**
```gdscript
# Game.gd — replace line 345
if target.peer_id == multiplayer.get_unique_id():
    target.receive_revive()   # host player: call directly (call_remote is a no-op to self)
else:
    target.receive_revive.rpc_id(target.peer_id)
```

---

### CR-02: `GameState.loop_number` and `revives_used` not reset on game-over

**File:** `autoloads/GameState.gd:6-8`, `autoloads/GameState.gd:63-77`

**Issue:** `_broadcast_game_over()` resets player stats and then calls `get_tree().change_scene_to_file("res://scenes/ui/GameOver.tscn")`, but it never resets `GameState.loop_number` or `GameState.revives_used`. Because `GameState` is an autoload it persists across scene changes. On the next run, difficulty scaling (enemy HP/damage, XP per orb, initial spawn count) starts from whatever loop was reached last game rather than loop 1. A player who was blocked from reviving in a previous run also retains that block indefinitely. `_ready()` only runs once at program startup so the `loop_number = 1` there does not help.

**Fix:**
```gdscript
# autoloads/GameState.gd — add a reset function and call it from _broadcast_game_over
func reset_for_new_run() -> void:
    loop_number = 1
    loop_timer  = 0.0
    revives_used = {}

# Then in _broadcast_game_over(), before change_scene_to_file:
reset_for_new_run()
get_tree().change_scene_to_file("res://scenes/ui/GameOver.tscn")
```

---

### CR-03: `GameEvents.emit_hud()` called without `.rpc()` on host — client CarHUDs receive no event

**File:** `scenes/Game.gd:609, 658, 684`

**Issue:** Three call sites invoke `GameEvents.emit_hud("ac")`, `GameEvents.emit_hud("seat_massage")` (twice) directly instead of `GameEvents.emit_hud.rpc(…)`. `emit_hud` is declared `@rpc("authority", "call_local", "reliable")`. Calling a method directly rather than via `.rpc()` only executes locally on the host — it does not broadcast to clients. As a result, the AC, SEAT MASSAGE indicators in client CarHUDs never light up. The two elite/suspension call sites (lines 357, 554) correctly use `.rpc()`. The ice-trail and earth-effect sites do not.

Affected lines:
- `request_ice_trail` — line 609: `GameEvents.emit_hud("ac")` should be `GameEvents.emit_hud.rpc("ac")`
- `_tick_earth_effects` heal — line 658: `GameEvents.emit_hud("seat_massage")` should use `.rpc()`
- `_tick_earth_effects` shockwave — line 684: same fix

**Fix:**
```gdscript
# scenes/Game.gd line 609
GameEvents.emit_hud.rpc("ac")

# scenes/Game.gd line 658
GameEvents.emit_hud.rpc("seat_massage")

# scenes/Game.gd line 684
GameEvents.emit_hud.rpc("seat_massage")
```

---

### CR-04: `Enemy.current_hp` initialised before `_ready()` runs — always starts at 50

**File:** `scenes/enemies/Enemy.gd:11,14` / `scenes/Game.gd:209-211`

**Issue:** `Enemy.gd` declares at class level:
```gdscript
var MAX_HP: int = 50
var current_hp: int = MAX_HP   # ← evaluated at parse time, = 50
```
`_do_spawn_enemy()` then does:
```gdscript
e.MAX_HP = int(e.MAX_HP * mult)
e.CONTACT_DAMAGE = int(e.CONTACT_DAMAGE * mult)
e.current_hp = e.MAX_HP          # ← this line re-syncs correctly
```
The spawn function does re-assign `current_hp` at line 211, which corrects the value before the node enters the tree. However, `EliteEnemy._ready()` sets `current_hp = MAX_HP` at line 25 *after* the initial spawn-function call completes (because `_ready` fires when `add_child` is executed, not when `spawn_function` returns). For EliteEnemy this is actually intentional and works. For *normal* enemies the `e.current_hp = e.MAX_HP` in `_do_spawn_enemy` at line 211 fires before `add_child`, so it is the effective value — this is correct at loop > 1.

The underlying risk is that the class-level `var current_hp: int = MAX_HP` at line 14 of Enemy.gd relies on `MAX_HP` being evaluated at the time the class field is initialised (GDScript evaluates these expressions at instantiation, not at compile time). This is actually fine in GDScript — both fields are initialised left-to-right in declaration order at instantiation. `current_hp` will be 50 at instantiation, then overwritten by `_do_spawn_enemy` before the node enters the tree. The real correctness risk is: if any code path instantiates `Enemy.tscn` without going through `_do_spawn_enemy` (e.g. a future test or editor placement), `current_hp` will be 50 regardless of any `MAX_HP` override.

Reclassified: this is a latent correctness risk, not a present bug, because the spawn path does set `current_hp`. Downgraded to WARNING — see WR-03.

---

## Warnings

### WR-01: Revive-limit silent block leaves ReviveBar stuck at 100%

**File:** `scenes/Game.gd:337-338`

**Issue:** When `GameState.revives_used.get(target_id, 0) >= 1`, the code returns early after erasing `_revive_progress` but **never calls `_update_revive_bar(target_id, 0.0)`**. The reviving peer's ReviveBar widget reached 100% (pct=1.0 was sent at line 330 on the same frame `progress >= REVIVE_DURATION` was first true), and no reset is sent after the silent block. The bar stays filled on screen, giving false feedback that a revive succeeded or is in progress.

**Fix:**
```gdscript
# Game.gd — after line 337
if GameState.revives_used.get(target_id, 0) >= 1:
    _update_revive_bar(target_id, 0.0)   # ← reset bar so reviver sees failure
    return
```

---

### WR-02: SUSPENSION fires on any hit ≥ 15, including Tier-2+ scaled normal enemies

**File:** `scenes/Player.gd:472`

**Issue:** The threshold `if amount >= 15` is chosen to match elite enemy base contact damage. At loop 2 the normal enemy multiplier is 1.25, so `CONTACT_DAMAGE = int(10 * 1.25) = 12` — still below threshold. At loop 3 multiplier is 1.5, giving `int(10 * 1.5) = 15` — exactly at threshold. At loop 4+ it exceeds 15. This means that from loop 3 onwards, every normal enemy contact hit triggers the SUSPENSION indicator, defeating its purpose of signalling elite contacts specifically. The design comment at lines 468-469 explicitly states "Normal enemy CONTACT_DAMAGE=10 is safely below threshold" — this is only true for loop 1 and 2.

**Fix:** Gate the SUSPENSION signal on a separate flag on the enemy rather than on damage amount, or pass an `is_elite: bool` parameter through the damage call chain:
```gdscript
# Option A — simplest: pass source flag through receive_damage
func receive_damage(amount: int, attacker_path: String = "", from_elite: bool = false) -> void:
    ...
    if from_elite:
        # notify suspension
```

---

### WR-03: `current_hp` latent mis-sync — bare instantiation bypasses spawn scaling

**File:** `scenes/enemies/Enemy.gd:14`

**Issue:** `var current_hp: int = MAX_HP` is set at instantiation time (= 50). The `_do_spawn_enemy` function correctly overwrites this before `add_child`. However, the design is fragile: any code path that instantiates `Enemy.tscn` via `ENEMY_SCENE.instantiate()` directly (without going through the Spawner) will produce an enemy with `current_hp = 50` even when `MAX_HP` is then set to a higher value. This is a silent correctness trap for future development.

**Fix:** Remove `= MAX_HP` from the class-level `current_hp` declaration and set it in `_ready()` instead:
```gdscript
var current_hp: int  # ← no initialiser; _ready() sets it

func _ready() -> void:
    current_hp = MAX_HP  # safe because MAX_HP is already set by spawn_function before add_child
    ...
```

---

### WR-04: Debug `print()` statements and test comment left in production code

**File:** `scenes/enemies/Enemy.gd:121, 132` / `scenes/Game.gd:226`

**Issue:** Two `print()` calls fire on every enemy contact event (every frame the player touches an enemy), producing high-frequency log spam that degrades performance readability in networked sessions. `scenes/Game.gd:226` has an explicit `# TEST:` comment in German acknowledging a debug spawn behaviour that was never removed.

Lines:
- `Enemy.gd:121` — `print("Hurtbox body_entered: …")` — fires on every body_entered event
- `Enemy.gd:132` — `print("Contact damage to player …")` — fires on every contact damage
- `Game.gd:226` — `# TEST: Sofort neuen Feind spawnen damit immer Gegner da sind` — intentional debug mechanic left in production path

**Fix:** Remove all three. The respawn-on-death mechanic in `_on_enemy_died` (line 227-230) may be intentional for gameplay, but the comment should be replaced with a design decision comment if so.

---

### WR-05: `_hud_event_label` is a declared but always-null dead variable

**File:** `scenes/Game.gd:35`

**Issue:** `var _hud_event_label: Label = null` is declared at line 35. The comment at lines 118-121 explicitly states "The label node is no longer created." `_on_hud_event` at line 128 is also a no-op (`pass`). Neither the variable nor the function is removed — they create confusion about whether the old HUD path is still live. `_hud_event_label` is also never read after being declared, so the variable has no effect and just misleads future readers.

**Fix:** Remove `_hud_event_label` declaration, `_on_hud_event`, and its comment block. Leave a single short comment in `_setup_player_hud` explaining CarHUD replaced the label.

---

## Info

### IN-01: `GameState.loop_timer` is decremented but never set — always 0

**File:** `autoloads/GameState.gd:6, 23-24`

**Issue:** `loop_timer` is declared as `0.0` and decremented in `_process()` when `> 0.0`. No code anywhere in the reviewed files ever sets `loop_timer` to a positive value. The decrement block is dead code. `GameEvents.loop_ended` signal is also declared but never emitted. The phase description says "loop timer" is part of Phase 7 scope, but neither the timer initialisation nor the expiry trigger is implemented.

This is an incomplete feature stub, not a bug (the `if loop_timer > 0.0` guard prevents underflow). Flag for Phase 8.

---

### IN-02: Hardcoded sequential `unique_id` values in `EliteEnemy.tscn` risk Godot editor conflicts

**File:** `scenes/enemies/EliteEnemy.tscn:23-55`

**Issue:** All node `unique_id` values are manually assigned as sequential integers starting at `111111001`. These IDs are supposed to be globally unique within the project. Godot normally generates random large integers. If the Godot editor ever opens and re-saves this file it will regenerate IDs, but any other `.tscn` or `.tres` file that was manually authored with these same IDs would cause node lookup failures or silent collisions. The `Enemy.tscn` uses auto-generated large random IDs (e.g. `969772550`).

No other file in the reviewed set uses these IDs so there is no present collision. This is a maintainability risk if the file is hand-edited further.

**Fix:** Let the Godot editor regenerate these IDs by opening and re-saving the scene file. Avoid hand-authoring `unique_id` values.

---

### IN-03: `GameState.start_next_loop()` prints to stdout unconditionally

**File:** `autoloads/GameState.gd:59`

**Issue:** `print("Loop %d started" % loop_number)` is an unconditional debug log that fires every loop transition in production builds. This is low severity but adds log noise.

**Fix:** Replace with `if OS.is_debug_build(): print(…)` or remove entirely.

---

_Reviewed: 2026-06-19T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
