---
phase: 07-carhud-loop-timer-difficulty-scaling
plan: "03"
subsystem: game, player, enemies
tags: [carhud-integration, elite-spawn, difficulty-scaling, revive-gate, suspension-rpc, hud-wiring]
status: complete

dependency_graph:
  requires:
    - "07-01-PLAN.md (GameEvents.emit_hud as authority RPC, GameState.loop_number=1, Enemy const→var)"
    - "07-02-PLAN.md (CarHUD.tscn scene, EliteEnemy.tscn scene)"
  provides:
    - "CarHUD instantiated as CanvasLayer child of Game root — visible on all peers (HUD-01)"
    - "Old text-label _on_hud_event handler retired; CarHUD is sole HUD-event consumer (HUD-10)"
    - "Elite enemy spawn timer (45-90s host timer) + LIDAR broadcast (HUD-07, D-13)"
    - "Difficulty scaling at spawn time: normal enemies scale in _do_spawn_enemy; elite in EliteEnemy._ready() (LOOP-04, D-19/D-20)"
    - "Initial spawn count scales with loop_number via pow(1.5) formula (LOOP-04, D-19)"
    - "Revive-once-per-loop gate enforced via GameState.revives_used in attempt_revive (HLTH-07, D-22)"
    - "notify_significant_hit RPC: host-routed SUSPENSION trigger for 15+ damage hits (HUD-06, D-09)"
  affects:
    - "All peers: CarHUD visible during gameplay"
    - "Phase 8: start_next_loop() resets revives_used (already provided by Plan 01)"

tech_stack:
  added: []
  patterns:
    - "Float accumulator host-only timer pattern (mirrors _tick_engineer_passive) for elite spawn"
    - "call_deferred on EnemySpawner.spawn inside _process (physics-safe)"
    - "@rpc('any_peer','call_remote','reliable') + is_server() guard for host-routed client→host→all RPC (notify_significant_hit)"
    - "EliteEnemy._ready() self-applies difficulty scaling after super._ready() base-stat assignment"
    - "Difficulty scaling: 1.0 + (loop_number - 1) * 0.25 for HP/damage; pow(1.5, loop_number-1) for spawn count"

key_files:
  modified:
    - scenes/Game.gd
    - scenes/Player.gd
    - scenes/enemies/EliteEnemy.gd
  created: []

decisions:
  - "Elite enemy difficulty scaling moved into EliteEnemy._ready() after super._ready(): EliteEnemy._ready() runs when Spawner calls add_child (after _do_spawn_enemy returns), so any scaling applied in _do_spawn_enemy for elite type would be overwritten. Moving scaling to _ready() ensures final effective values = base(100/15) × mult."
  - "Normal enemy scaling stays in _do_spawn_enemy: Enemy._ready() does not reset MAX_HP/CONTACT_DAMAGE, so setting them before add_to_tree is safe and final."
  - "notify_significant_hit uses has_method() guard in Player.gd for robustness: if method not present (scene reloads, testing), call is silently skipped rather than crashing."
  - "SUSPENSION threshold = 15 exactly per D-09; normal enemy CONTACT_DAMAGE=10 safely below; elite base CONTACT_DAMAGE=15 triggers at loop 1."

metrics:
  duration: "~5 minutes"
  completed: "2026-06-19"
  tasks_completed: 3
  tasks_total: 3
  files_modified: 3
  files_created: 0
---

# Phase 7 Plan 03: Game Integration Summary

**One-liner:** CarHUD wired into Game root, old text-label HUD handler retired, elite spawn timer + LIDAR added, per-loop difficulty scaling applied at spawn time, revive-once-per-loop gate enforced, and SUSPENSION routed from owning peer to host via new notify_significant_hit RPC.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Instantiate CarHUD, register EliteEnemy, add elite spawn timer + LIDAR, retire old HUD handler | f7d9b59 | scenes/Game.gd |
| 2 | Add elite dispatch + difficulty scaling in _do_spawn_enemy and scale initial spawn count | 7f9c5fa | scenes/Game.gd, scenes/enemies/EliteEnemy.gd |
| 3 | Wire revive-once-per-loop gate and host-routed SUSPENSION trigger | 7cdf743 | scenes/Game.gd, scenes/Player.gd |

## What Was Built

### Task 1 — CarHUD instantiation, EliteEnemy registration, elite spawn timer, old HUD handler retirement

**`scenes/Game.gd`**

New preload consts:
- `ELITE_ENEMY_SCENE := preload("res://scenes/enemies/EliteEnemy.tscn")` (D-13)
- `CAR_HUD_SCENE := preload("res://scenes/ui/CarHUD.tscn")` (D-01, HUD-01)

New accumulator vars:
- `_elite_spawn_timer: float = 0.0` and `_elite_spawn_interval: float = 0.0` (D-13)

In `_ready()`:
- `$EnemySpawner.add_spawnable_scene("res://scenes/enemies/EliteEnemy.tscn")` — pre-registers before any elite spawn (Pitfall 5)
- `CAR_HUD_SCENE.instantiate()` + `add_child(_car_hud)` on Game root directly — separate CanvasLayer, NOT inside `$HUD` (Pitfall 3, D-01)
- `_elite_spawn_interval = randf_range(45.0, 90.0)` — first interval set at startup (D-13)

In `_setup_player_hud()`:
- `_hud_event_label` Label node creation removed
- `GameEvents.hud_event.connect(_on_hud_event)` line removed (comment retained for traceability)
- CarHUD.gd connects to `GameEvents.hud_event` in its own `_ready()` — sole HUD-event consumer (HUD-10)

`_on_hud_event()` neutralized to `pass` no-op (CarHUD handles all indicator events).

In `_process(delta)`:
- `_tick_elite_spawn(delta)` added inside `if multiplayer.is_server():` block alongside engineer/earth ticks

New methods:
- `_tick_elite_spawn(delta)`: accumulates into `_elite_spawn_timer`; on reaching `_elite_spawn_interval`: resets timer, randomizes new interval, calls `_spawn_elite_enemy()`
- `_spawn_elite_enemy()`: picks random `$Room1/EnemySpawnPoints` child, calls `$EnemySpawner.spawn.call_deferred({"type": "elite", "pos": pos})`, then `GameEvents.emit_hud.rpc("lidar")` (D-10, D-13, HUD-07)

### Task 2 — Elite dispatch + difficulty scaling + spawn count scaling

**`scenes/Game.gd`**

`_do_spawn_enemy(data)`:
- Scene selection: `var scene = ELITE_ENEMY_SCENE if data.get("type","") == "elite" else ENEMY_SCENE`
- For normal enemies only: compute `mult = 1.0 + (GameState.loop_number - 1) * 0.25`, apply to `e.MAX_HP`, `e.CONTACT_DAMAGE`, `e.current_hp` (D-19, D-20)
- Elite enemies excluded from this block — scaling handled in EliteEnemy._ready() (see ordering decision below)

`_spawn_enemies()`:
- Replace `INITIAL_ENEMY_COUNT` loop bound with `roundi(INITIAL_ENEMY_COUNT * pow(1.5, GameState.loop_number - 1))`
- Clamped by `points.size()` as before
- Loop 1 = 8 (unchanged), Loop 2 ≈ 12, Loop 3 ≈ 18

**`scenes/enemies/EliteEnemy.gd`**

In `_ready()`, after setting base stats (MAX_HP=100, CONTACT_DAMAGE=15):
- Apply `mult = 1.0 + (GameState.loop_number - 1) * 0.25` to MAX_HP and CONTACT_DAMAGE
- Set `current_hp = MAX_HP` after scaling
- Loop 1: mult=1.0, values stay 100/15 (unchanged baseline)

**Ordering decision documented:**
`_do_spawn_enemy` calls `scene.instantiate()` (no _ready yet), then returns the node. The MultiplayerSpawner calls `add_child` after return, which triggers `_ready()`. Therefore, for EliteEnemy, any scaling set in `_do_spawn_enemy` would be overwritten by `EliteEnemy._ready()` which reassigns MAX_HP=100 and CONTACT_DAMAGE=15. The fix: EliteEnemy._ready() self-applies the scaling formula after setting its own base stats — this is the final, authoritative value.

### Task 3 — Revive-once-per-loop gate and host-routed SUSPENSION trigger

**`scenes/Game.gd`**

In `attempt_revive()`, inside `if progress >= REVIVE_DURATION:` block, after `_revive_progress.erase(target_id)`:
- `if GameState.revives_used.get(target_id, 0) >= 1: return` — silent block (D-22, UI-SPEC)
- `GameState.revives_used[target_id] = GameState.revives_used.get(target_id, 0) + 1` — incremented BEFORE receive_revive (host-side, T-07-08)
- Existing `target.receive_revive.rpc_id(target.peer_id)` unchanged

New method `notify_significant_hit()`:
- `@rpc("any_peer", "call_remote", "reliable")` — any peer (including client) can call this on host
- `if not multiplayer.is_server(): return` — host validates, ignores if somehow reached on client
- `GameEvents.emit_hud.rpc("suspension")` — broadcast SUSPENSION to all peers (HUD-06, T-07-07)

**`scenes/Player.gd`**

In `receive_damage(amount, attacker_path)`, after `health -= amount`:
- `if amount >= 15:` — threshold exactly per D-09 (Pitfall 4)
- Get `/root/Game` node; if present, call `notify_significant_hit()` directly on host or `notify_significant_hit.rpc_id(1)` on client
- Placed after all early-return guards (dash_invincible, is_picking_card, airbag, shield) — only actually-delivered damage triggers SUSPENSION

## Deviations from Plan

### Auto-fixed issues

**1. [Rule 2 - Missing Critical Functionality] Elite enemy difficulty scaling moved to EliteEnemy._ready()**

- **Found during:** Task 2
- **Issue:** Plan said to apply `e.MAX_HP = int(e.MAX_HP * mult)` in `_do_spawn_enemy` for ALL enemy types. But `EliteEnemy._ready()` runs after `_do_spawn_enemy` returns (Spawner calls add_child post-return), so it reassigns `MAX_HP=100, CONTACT_DAMAGE=15, current_hp=MAX_HP`, overwriting any scaling set in `_do_spawn_enemy`.
- **Fix:** Applied scaling formula to EliteEnemy._ready() after base-stat assignments. Normal enemies still scale in `_do_spawn_enemy` (Enemy._ready() does not reset stats). Plan Task 2 explicitly anticipated this: "If the EliteEnemy._ready() base-stat assignment would overwrite the scaled value, apply scaling via the data dict instead, OR set the scaled values and rely on _ready not re-clobbering — confirm by reading EliteEnemy.gd ordering and adjust so the FINAL effective MAX_HP equals base × mult."
- **Files modified:** scenes/enemies/EliteEnemy.gd
- **Commit:** 7f9c5fa

## Known Stubs

None. All integrations are fully wired:
- CarHUD is instantiated and added to Game root; CarHUD.gd connects to GameEvents.hud_event in its own _ready()
- All 5 HUD event emitters confirmed: "ac" (request_ice_trail), "engine" (_fire_burst), "seat_massage" (_tick_earth_effects×2), "suspension" (notify_significant_hit), "lidar" (_spawn_elite_enemy)
- Elite spawn timer active immediately in game
- Difficulty scaling formula live at loop_number=1 (mult=1.0, no change)
- Revive gate: revives_used read/write in attempt_revive; reset by start_next_loop (Plan 01)
- SUSPENSION routing: owning peer → host → all peers

## Threat Surface Scan

All threats in plan's threat register are mitigated:

| Threat | File | Status |
|--------|------|--------|
| T-07-07: notify_significant_hit tampering | Game.gd | Mitigated: @rpc("any_peer","call_remote") + is_server() guard; client requests, host broadcasts |
| T-07-08: revives_used elevation | Game.gd | Mitigated: attempt_revive already guards is_server(); revives_used only read/written host-side |
| T-07-09: elite spawn / scaling elevation | Game.gd | Mitigated: _tick_elite_spawn runs only inside is_server() block; no client-callable RPC |
| T-07-10: SUSPENSION trigger flood | Player.gd, Game.gd | Mitigated: 15-damage threshold; only post-delivery hits trigger; normal enemy contact (10) below |

No new network surface introduced beyond what the plan's threat register covers.

## Self-Check: PASSED

- scenes/Game.gd: FOUND
- scenes/Player.gd: FOUND
- scenes/enemies/EliteEnemy.gd: FOUND
- Commit f7d9b59 (Task 1): FOUND
- Commit 7f9c5fa (Task 2): FOUND
- Commit 7cdf743 (Task 3): FOUND
