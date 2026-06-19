---
phase: 07-carhud-loop-timer-difficulty-scaling
verified: 2026-06-19T13:55:00Z
status: human_needed
score: 13/14 must-haves verified
behavior_unverified: 1
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 12/14
  gaps_closed:
    - "ENGINE indicator now broadcasts to all clients — Player.gd:306, Bullet.gd:62,71 changed to GameEvents.emit_hud.rpc(\"engine\") in commit f3aed1f"
  gaps_remaining: []
  regressions: []
behavior_unverified_items:
  - truth: "Second loop visibly has more enemies with higher HP than first loop (LOOP-04, SC3)"
    test: "Start a game, play through an initial wave, trigger start_next_loop(), then spawn enemies and observe count and HP"
    expected: "At loop 2, spawn count increases (pow(1.5) formula yields ~12 vs 8) and enemies have 25% more HP (mult=1.25)"
    why_human: "The scaling formulas are code-verified, but runtime confirmation that spawned enemies actually reflect the higher HP and that the count is visibly different requires in-game observation"
human_verification:
  - test: "Verify ENGINE indicator fires on all screens in a 2-player session after fix"
    expected: "When a Fire player uses the fire ability or a bullet procs fire, ENGINE lights on BOTH screens simultaneously"
    why_human: "Fix (commit f3aed1f) is code-verified as .rpc(); runtime confirmation with two peers closes the human verification loop"
  - test: "Verify second loop has visibly more enemies with higher HP"
    expected: "At loop 2, approximately 12 enemies spawn (vs 8 at loop 1) and each takes more hits to kill (25% more HP)"
    why_human: "Runtime behavior of pow(1.5) spawn scaling and 1.25x HP multiplier — presence confirmed, runtime behavior unverified"
  - test: "Verify revive-once-per-loop gate works in a 2-player session"
    expected: "Reviving a downed teammate succeeds once; a second revive attempt silently fails (player stays downed, no error shown); counter resets after start_next_loop() is called"
    why_human: "State-transition invariant across revive states; loop reset path involves start_next_loop() which Phase 8 calls — full end-to-end cannot be exercised without boss defeat"
---

# Phase 7: CarHUD, Loop Timer & Difficulty Scaling — Verification Report

**Phase Goal:** Deliver the CARIAD car HUD side panel, Loop infrastructure, elite enemy, difficulty scaling, and revive-once-per-loop limit.
**Verified:** 2026-06-19T13:55:00Z
**Status:** human_needed
**Re-verification:** Yes — after gap closure (commit f3aed1f)

---

## Re-Verification Summary

The single blocker gap from the initial verification has been closed:

**Gap closed:** `scenes/Player.gd:306` and `scenes/projectiles/Bullet.gd:62,71` previously called `GameEvents.emit_hud("engine")` as bare local calls. Commit `f3aed1f` changed all three ENGINE callsites and one additional AC callsite in Bullet.gd to `GameEvents.emit_hud.rpc("engine"/"ac")`. A codebase-wide scan confirms zero remaining bare `emit_hud("...")` calls anywhere in `scenes/` or `autoloads/` — all 9 active callsites now use `.rpc()`.

No regressions detected in previously verified items.

---

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|---------|
| 1 | emit_hud is an authority RPC that fires hud_event on all peers (D-07, HUD-10) | VERIFIED | `autoloads/GameEvents.gd` line 16: `@rpc("authority", "call_local", "reliable")` directly above `func emit_hud` |
| 2 | GameState.loop_number reads 1 at game start (D-16) | VERIFIED | `autoloads/GameState.gd` line 7: `var loop_number: int = 1`; line 12: `loop_number = 1` in `_ready()` |
| 3 | GameState.start_next_loop() increments loop_number and clears revives_used, host-guarded (D-17, D-22) | VERIFIED | `autoloads/GameState.gd` lines 50–59: `func start_next_loop()` with three-line multiplayer host guard, `loop_number += 1`, `revives_used = {}` |
| 4 | Enemy MAX_HP and CONTACT_DAMAGE can be overwritten on an instance (D-19, D-20) | VERIFIED | `scenes/enemies/Enemy.gd` lines 10–11: `var CONTACT_DAMAGE: int = 10`, `var MAX_HP: int = 50` (changed from const) |
| 5 | XP granted per orb scales up with loop_number (D-19) | VERIFIED | `scenes/pickups/XpOrb.gd` line 41: `var xp_amount: int = roundi(float(PLAYER_SCRIPT.XP_PER_ORB) * (1.0 + (GameState.loop_number - 1) * 0.25))`; both `receive_xp` callsites pass `xp_amount` |
| 6 | A right-side vertical CarHUD panel is visible with 5 labeled indicator boxes and a Loop label (HUD-01, HUD-02, LOOP-05) | VERIFIED | `scenes/ui/CarHUD.tscn`: layer=3 CanvasLayer; right-anchored ColorRect; 5 indicator PanelContainers with emoji labels character-exact; LoopLabel text="Loop: 1" |
| 7 | Each indicator lights to its assigned color when activated, then fades out after ~2.5s (HUD-09) | VERIFIED | `scenes/ui/CarHUD.gd` lines 93–98: tween_interval(2.0) then tween_property(panel, "modulate:a", 0.0, 0.5); StyleBoxFlat bg_color set on activation; restore_idle callback resets style |
| 8 | CarHUD lights the matching indicator when GameEvents.hud_event fires (HUD-03..07, HUD-10) | VERIFIED | All 5 indicators wired in CarHUD listener. ENGINE fix (commit f3aed1f): `Player.gd:306` and `Bullet.gd:62,71` now use `GameEvents.emit_hud.rpc("engine")`. Zero bare `emit_hud("...")` calls remain in codebase. All 5 indicators broadcast correctly to all peers. |
| 9 | CarHUD Loop label reflects GameState.loop_number (LOOP-05) | VERIFIED | `scenes/ui/CarHUD.gd` lines 30–32: polling in `_process`; updates only when `GameState.loop_number != _last_loop_number` |
| 10 | EliteEnemy is a larger purple enemy with 2x HP and 1.5x damage (D-12) | VERIFIED | `scenes/enemies/EliteEnemy.gd`: `extends "res://scenes/enemies/Enemy.gd"`, `super._ready()`, `MAX_HP = 100`, `CONTACT_DAMAGE = 15`, `Color(0.55, 0.1, 0.55, 1)` visual, 48x48 |
| 11 | CarHUD appears on screen during gameplay on all peers (HUD-01) | VERIFIED | `scenes/Game.gd` lines 67–68: `CAR_HUD_SCENE.instantiate()` + `add_child(_car_hud)` on Game root; CarHUD `_ready()` connects to hud_event |
| 12 | The old top-right text-label HUD event handler no longer responds to hud_event (HUD-10) | VERIFIED | `scenes/Game.gd` lines 118–121: connection removed from `_setup_player_hud()`; `_hud_event_label` var removed; `_on_hud_event` method removed (WR-05 fix commit 390dae0) |
| 13 | An elite enemy spawns on a host timer every 45–90s and fires the LIDAR indicator on all screens (HUD-07, D-13) | VERIFIED | `scenes/Game.gd`: `_tick_elite_spawn(delta)` in `if multiplayer.is_server():` block; `_spawn_elite_enemy()` uses `spawn.call_deferred({"type":"elite",...})` + `GameEvents.emit_hud.rpc("lidar")` |
| 14 | A downed player can be revived at most once per loop; further revives silently fail (HLTH-07, D-22) | VERIFIED | `scenes/Game.gd` lines 330–334: `if GameState.revives_used.get(target_id, 0) >= 1: return` (silent); increment before `receive_revive` call; `start_next_loop()` resets `revives_used = {}` |
| 15 | Second loop visibly has more enemies with higher HP than first loop (LOOP-04, SC3) | PRESENT_BEHAVIOR_UNVERIFIED | Scaling formulas verified in code: `pow(1.5, loop_number-1)` for count, `1.0 + 0.25*(loop_number-1)` for HP/damage. Runtime observation requires in-game play. |

**Score:** 13/14 truths verified (1 PRESENT_BEHAVIOR_UNVERIFIED — see Human Verification)

---

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `autoloads/GameEvents.gd` | emit_hud as @rpc authority broadcast | VERIFIED | `@rpc("authority", "call_local", "reliable")` on line 16, directly above `func emit_hud` |
| `autoloads/GameState.gd` | loop_number=1 default + start_next_loop() hook | VERIFIED | `var loop_number: int = 1` (line 7); `func start_next_loop()` (line 50) with host guard |
| `scenes/enemies/Enemy.gd` | Writable MAX_HP and CONTACT_DAMAGE | VERIFIED | Both changed from `const` to `var` |
| `scenes/pickups/XpOrb.gd` | Loop-scaled XP grant | VERIFIED | `xp_amount` computed using `GameState.loop_number`; both callsites updated |
| `scenes/ui/CarHUD.tscn` | Global CanvasLayer layer=3 with 5 indicators + Loop label | VERIFIED | Exact node tree matches spec; all 5 emoji labels present character-exact |
| `scenes/ui/CarHUD.gd` | hud_event listener, fade tween, loop-label polling | VERIFIED | Connects to `GameEvents.hud_event`, tween_interval(2.0), `_process` polling |
| `scenes/enemies/EliteEnemy.tscn` | Elite enemy scene with purple visual | VERIFIED | CharacterBody2D root, Sprite Color(0.55,0.1,0.55,1), MultiplayerSynchronizer |
| `scenes/enemies/EliteEnemy.gd` | Enemy subclass with 2x HP / 1.5x damage | VERIFIED | `extends "res://scenes/enemies/Enemy.gd"`, super._ready(), MAX_HP=100, CONTACT_DAMAGE=15, plus loop scaling |
| `scenes/Game.gd` | CarHUD instantiation, elite spawn timer, difficulty scaling, revive gate | VERIFIED | All present and correctly wired; ENGINE emitter gap closed by commit f3aed1f |
| `scenes/Player.gd` | ENGINE fires via .rpc() (HUD-04) | VERIFIED | Line 306: `GameEvents.emit_hud.rpc("engine")` — confirmed post-fix |
| `scenes/projectiles/Bullet.gd` | ENGINE and AC fire via .rpc() (HUD-03, HUD-04) | VERIFIED | Lines 62, 71: `.rpc("engine")`; line 77: `.rpc("ac")` — confirmed post-fix |

---

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `scenes/pickups/XpOrb.gd` | `autoloads/GameState.gd` | Reads `GameState.loop_number` to compute scaled XP | WIRED | Line 41 reads `GameState.loop_number` |
| `autoloads/GameEvents.gd` | All peers | `@rpc("authority","call_local","reliable")` annotation | WIRED | Annotation present; all callsites use `.rpc()` |
| `scenes/ui/CarHUD.gd` | `autoloads/GameEvents.gd` | Connects to `hud_event` in `_ready()` | WIRED | Line 17: `GameEvents.hud_event.connect(_on_hud_event)` |
| `scenes/ui/CarHUD.gd` | `autoloads/GameState.gd` | Polls `loop_number` in `_process` | WIRED | Lines 30–31: polling with dirty-flag |
| `scenes/enemies/EliteEnemy.gd` | `scenes/enemies/Enemy.gd` | `extends Enemy.gd`, `super._ready()` | WIRED | Line 1 extends; line 10 calls super |
| `scenes/Game.gd` | `scenes/ui/CarHUD.tscn` | Preload + instantiate + add_child in `_ready()` | WIRED | Lines 20, 67–68 |
| `scenes/Game.gd` | `scenes/enemies/EliteEnemy.tscn` | add_spawnable_scene + _do_spawn_enemy dispatch + emit_hud.rpc("lidar") | WIRED | Lines 18, 64, 190, 551 |
| `scenes/Game.gd` | `autoloads/GameState.gd` | Reads loop_number for scaling; reads/writes revives_used in attempt_revive | WIRED | Lines 201, 330–334 |
| `scenes/Player.gd` -> ENGINE -> all peers | `autoloads/GameEvents.gd` | `emit_hud.rpc("engine")` | WIRED | Line 306: `.rpc()` call confirmed post-fix (commit f3aed1f) |
| `scenes/projectiles/Bullet.gd` -> ENGINE/AC -> all peers | `autoloads/GameEvents.gd` | `emit_hud.rpc("engine"/"ac")` | WIRED | Lines 62, 71, 77: all `.rpc()` calls confirmed post-fix (commit f3aed1f) |

---

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|-------------------|--------|
| `scenes/ui/CarHUD.gd` | `_last_loop_number` | `GameState.loop_number` (autoload, host-authoritative) | Yes — written by GameState._ready() and start_next_loop() | FLOWING |
| `scenes/ui/CarHUD.gd` | `_indicators[event_name]` | `GameEvents.hud_event` signal (RPC-synced from host) | Yes — all 5 indicators (AC, ENGINE, SEAT_MASSAGE, SUSPENSION, LIDAR) now use `.rpc()` | FLOWING |
| `scenes/enemies/EliteEnemy.gd` | `MAX_HP`, `CONTACT_DAMAGE` | `GameState.loop_number` in `_ready()` scaling formula | Yes — real multiplier applied at spawn time | FLOWING |

---

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| emit_hud has @rpc annotation above func emit_hud | `grep -A1 '@rpc' autoloads/GameEvents.gd` | `@rpc("authority", "call_local", "reliable")` / `func emit_hud(event_name: String) -> void:` | PASS |
| loop_number=1 at start | `grep 'var loop_number.*= 1' autoloads/GameState.gd` | `var loop_number: int = 1` | PASS |
| start_next_loop() exists and increments | `grep -A10 'func start_next_loop' autoloads/GameState.gd` | Host guard + `loop_number += 1` + `revives_used = {}` | PASS |
| Enemy MAX_HP is var (not const) | `grep 'var MAX_HP' scenes/enemies/Enemy.gd` | `var MAX_HP: int = 50` | PASS |
| XpOrb references loop_number in xp_amount formula | `grep 'GameState.loop_number' scenes/pickups/XpOrb.gd` | Line 41 match | PASS |
| CarHUD.tscn has layer=3 and all 5 emoji labels | `grep -E 'layer = 3\|AC\|LIDAR' scenes/ui/CarHUD.tscn` | All patterns found | PASS |
| CarHUD.gd connects hud_event and uses tween_interval(2.0) | `grep 'GameEvents.hud_event.connect\|tween_interval(2.0)' scenes/ui/CarHUD.gd` | Both present | PASS |
| EliteEnemy extends Enemy.gd and sets MAX_HP=100 | `grep 'extends "res://scenes/enemies/Enemy.gd"\|MAX_HP = 100' scenes/enemies/EliteEnemy.gd` | Both present | PASS |
| Game.gd registers EliteEnemy in spawner | `grep 'add_spawnable_scene.*EliteEnemy' scenes/Game.gd` | Match found (line 64) | PASS |
| ENGINE emit_hud uses .rpc() in Player.gd | `grep 'emit_hud.rpc' scenes/Player.gd` | `GameEvents.emit_hud.rpc("engine")` line 306 | PASS (fixed by f3aed1f) |
| ENGINE emit_hud uses .rpc() in Bullet.gd | `grep 'emit_hud.rpc' scenes/projectiles/Bullet.gd` | Lines 62, 71 `.rpc("engine")`; line 77 `.rpc("ac")` | PASS (fixed by f3aed1f) |
| No bare emit_hud("...") calls remaining in codebase | Codebase-wide grep | No output — zero bare calls | PASS |
| Revive gate checks revives_used >= 1 | `grep 'revives_used.get(target_id, 0) >= 1' scenes/Game.gd` | Match found (line 330) | PASS |
| notify_significant_hit exists in Game.gd | `grep 'func notify_significant_hit' scenes/Game.gd` | Match found (line 350) | PASS |
| Difficulty scaling formula in _do_spawn_enemy | `grep '1.0 + (GameState.loop_number - 1) \* 0.25' scenes/Game.gd` | Match found (line 201) | PASS |
| Initial spawn count uses pow(1.5) scaling | `grep 'pow(1.5, GameState.loop_number - 1)' scenes/Game.gd` | Match found (line 184) | PASS |

---

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|---------|
| HUD-01 | 07-02, 07-03 | Car HUD side panel always visible | SATISFIED | CarHUD instantiated in Game._ready(); CanvasLayer layer=3 |
| HUD-02 | 07-02 | Panel contains AC, ENGINE, SEAT MASSAGE, SUSPENSION, LIDAR, V2X | PARTIAL | 5 of 6 indicators present; V2X removed per D-11 (locked decision, not a phase failure) |
| HUD-03 | 07-02, 07-01 | Ice ability -> AC lights on all screens | SATISFIED | Game.gd uses emit_hud.rpc("ac"); Bullet.gd line 77 also uses .rpc("ac") after f3aed1f |
| HUD-04 | 07-02, 07-01 | Fire ability -> ENGINE lights on ALL screens | SATISFIED | Player.gd:306, Bullet.gd:62,71 all use .rpc("engine") after fix commit f3aed1f |
| HUD-05 | 07-02 | Earth healing -> SEAT MASSAGE lights on all screens | SATISFIED | _tick_earth_effects uses emit_hud.rpc("seat_massage") (CR-03 fixed) |
| HUD-06 | 07-03 | Significant hit -> SUSPENSION lights on all screens | SATISFIED | notify_significant_hit via from_elite flag routing; Game.gd uses .rpc("suspension") |
| HUD-07 | 07-03 | Enemy spawns -> LIDAR lights on all screens | SATISFIED | _spawn_elite_enemy uses emit_hud.rpc("lidar") |
| HUD-08 | 07-01 (traceability only) | V2X auto-trigger | DESCOPED | D-11: removed from Phase 7 scope entirely |
| HUD-09 | 07-02 | Indicators fade after a few seconds | SATISFIED | tween_interval(2.0) + fade over 0.5s = 2.5s total; restore_idle callback |
| HUD-10 | 07-01, 07-03 | HUD events broadcast via RPC to all clients simultaneously | SATISFIED | All 5 indicators (AC, ENGINE, SEAT_MASSAGE, SUSPENSION, LIDAR) confirmed using .rpc() |
| LOOP-01 | 07-01 (traceability) | Visible 15-min countdown timer | DESCOPED | D-15: no countdown UI; 15 minutes is a design target not a mechanical timer |
| LOOP-02 | 07-01 (traceability) | Room transition on clear | OUT OF SCOPE | Phase 8 owns room transitions |
| LOOP-03 | 07-01 | Boss defeat/timer expiry -> next loop starts harder | HOOK PROVIDED | `start_next_loop()` hook exists; Phase 8 calls it after boss defeat |
| LOOP-04 | 07-01, 07-03 | Each loop increases enemy HP, damage, spawn density | SATISFIED | Formulas verified: 1.25x per loop for HP/damage; pow(1.5) for spawn count |
| LOOP-05 | 07-02, 07-03 | Loop number visible to all players | SATISFIED | CarHUD LoopLabel polls GameState.loop_number in _process |
| LOOP-06 | 07-01 (traceability) | Weapons/XP/evolution carry over; reset on wipe | VERIFIED UNCHANGED | D-18: existing _broadcast_game_over reset path handles this |
| HLTH-07 | 07-01, 07-03 | Revive at most once per loop; counter resets at loop end | SATISFIED | revives_used gate in attempt_revive; start_next_loop() clears dict |

---

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `scenes/Game.gd` | 473 | `"Cooldown": pass # TODO Phase 7: cooldown reduction not yet wired` | INFO | Introduced by Phase 6 commit 68b3ef2; not a Phase 7 requirement. Informational only — does not block Phase 7 goal. |

No blockers. The two ENGINE bare-call BLOCKERs from the initial verification are resolved by commit f3aed1f.

---

### Human Verification Required

#### 1. ENGINE Indicator Broadcast — Runtime Confirmation

**Test:** In a 2-player LAN session (host + 1 client), have a Fire-element player use the fire ability (or wait for a fire proc on bullet hit). Watch both screens.
**Expected:** ENGINE OVERHEAT lights up on BOTH screens simultaneously.
**Why human:** The fix (commit f3aed1f) is code-verified as `.rpc()`; runtime confirmation with two peers closes the human verification loop opened in the initial verification.

#### 2. Second Loop Enemy Density and HP (LOOP-04 behavior)

**Test:** Complete a room wave (or trigger start_next_loop() from the console), then observe the next wave spawn count and test enemy durability.
**Expected:** Approximately 12 enemies spawn (vs 8 at loop 1); each enemy survives roughly 25% more hits before dying.
**Why human:** The scaling formulas are code-verified (pow(1.5) and 1.0 + 0.25*(loop-1)); runtime confirmation that the formulas produce the expected visible difference requires in-game play.

#### 3. Revive Gate End-to-End (HLTH-07 state transition)

**Test:** In a 2-player session: (a) Down player B; (b) player A revives player B — success; (c) down player B again; (d) player A attempts revive — must silently fail (player B stays downed, no error shown, ReviveBar resets to 0). Then trigger loop increment and verify a third revive succeeds.
**Expected:** Second revive attempt silently blocked; third attempt after loop reset succeeds.
**Why human:** Three-state transition (success, blocked, reset, success again) involves start_next_loop() which is only callable after boss defeat (Phase 8). Full end-to-end cannot be exercised without Phase 8 boss.

---

### Gaps Summary

No code gaps remain. All must-haves are structurally complete and wired in the codebase.

The single blocker from the initial verification (HUD-04/HUD-10: ENGINE emitting without `.rpc()`) is resolved by commit `f3aed1f`. A codebase-wide scan confirms zero remaining bare `emit_hud("...")` calls.

Three human verification items remain — these require in-game runtime observation and cannot be confirmed by static analysis alone. They do not block the phase goal from being structurally complete in code.

---

_Verified: 2026-06-19T13:55:00Z_
_Verifier: Claude (gsd-verifier) — Re-verification after commit f3aed1f_
