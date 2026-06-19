---
phase: 07-carhud-loop-timer-difficulty-scaling
plan: "01"
subsystem: autoloads, enemies, pickups
tags: [rpc, loop-infrastructure, difficulty-scaling, xp-scaling]
status: complete

dependency_graph:
  requires:
    - "06-01-PLAN.md (GameState.revives_used, Player.XP_PER_ORB base)"
    - "03-02-PLAN.md (Enemy.gd const declarations being converted)"
    - "03-02-PLAN.md (XpOrb.gd receive_xp call pattern)"
  provides:
    - "GameEvents.emit_hud as authority RPC (HUD-10) — consumed by 07-02 CarHUD scene"
    - "GameState.loop_number = 1 default — consumed by 07-02 loop label, 07-03 spawn scaling"
    - "GameState.start_next_loop() hook — Phase 8 calls after boss defeat"
    - "Enemy.MAX_HP and Enemy.CONTACT_DAMAGE as var — consumed by 07-03 difficulty scaling"
    - "XpOrb loop-scaled XP grant — active immediately in game"
  affects:
    - "scenes/enemies/EliteEnemy.gd (07-02) reads MAX_HP/CONTACT_DAMAGE"
    - "scenes/Game.gd (07-03) reads GameState.loop_number at spawn time"

tech_stack:
  added: []
  patterns:
    - "@rpc('authority', 'call_local', 'reliable') broadcast pattern (mirrors GameState._broadcast_game_over)"
    - "host-guard multiplayer connection check (three-line pattern from track_downed)"
    - "loop-scaled formula: 1.0 + (loop_number - 1) * 0.25"

key_files:
  modified:
    - autoloads/GameEvents.gd
    - autoloads/GameState.gd
    - scenes/enemies/Enemy.gd
    - scenes/pickups/XpOrb.gd
  created: []

decisions:
  - "XP scaling uses Player.XP_PER_ORB (15) as base, not the abstract 5 from CONTEXT.md D-19 — planner discretion per RESEARCH.md Open Question 3 resolution"
  - "SUSPENSION emit site deferred to 07-02/07-03 per plan scope — Plan 01 only provides the RPC infrastructure (emit_hud annotation)"

metrics:
  duration: "~2 minutes"
  completed: "2026-06-19"
  tasks_completed: 2
  tasks_total: 2
  files_modified: 4
  files_created: 0
---

# Phase 7 Plan 01: Autoload & Data Foundation Summary

**One-liner:** Authority RPC on emit_hud, loop_number=1 with start_next_loop() hook, Enemy const→var for spawn scaling, XP per orb scales with loop_number.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Convert emit_hud to network-synced RPC and wire GameState loop infrastructure | b793b4f | autoloads/GameEvents.gd, autoloads/GameState.gd |
| 2 | Make Enemy stats writable and scale XP per loop | ed0f039 | scenes/enemies/Enemy.gd, scenes/pickups/XpOrb.gd |

## What Was Built

### Task 1 — GameEvents + GameState foundation

**`autoloads/GameEvents.gd`**
- Added `@rpc("authority", "call_local", "reliable")` annotation directly above `func emit_hud` (D-07, HUD-10)
- `hud_event.emit(event_name)` body unchanged
- All existing callers remain host-guarded (D-08) — no call-site changes needed

**`autoloads/GameState.gd`**
- `var loop_number: int` default changed from `0` to `1` (D-16)
- `_ready()` body replaced from `pass` to `loop_number = 1` (Pitfall 6: safety against pre-connection state)
- New `start_next_loop()` method added with three-line host guard copied from `track_downed` (D-17, LOOP-03, HLTH-07): increments `loop_number`, resets `revives_used = {}`, prints log line

### Task 2 — Enemy stats + XP scaling

**`scenes/enemies/Enemy.gd`**
- `const CONTACT_DAMAGE: int = 10` → `var CONTACT_DAMAGE: int = 10` (Pitfall 2, D-19)
- `const MAX_HP: int = 50` → `var MAX_HP: int = 50` (Pitfall 2, D-19)
- `const SPEED` and `const DETECT_RADIUS` remain const — not difficulty-scaled
- `current_hp = MAX_HP` initialization and health bar ratio (`float(MAX_HP)`) work identically with var

**`scenes/pickups/XpOrb.gd`**
- Computed `xp_amount: int = roundi(float(PLAYER_SCRIPT.XP_PER_ORB) * (1.0 + (GameState.loop_number - 1) * 0.25))`
- Both `receive_xp` callsites updated to pass `xp_amount` instead of `PLAYER_SCRIPT.XP_PER_ORB`
- Loop 1 yields 15 XP (unchanged from Phase 6 base), loop 2 ≈ 19, loop 3 ≈ 23

## Deviations from Plan

None — plan executed exactly as written.

The PATTERNS.md recommended site for the SUSPENSION emit (Enemy.gd host-side vs. Player.gd) is an Open Question resolved in Plan 02/03 — this plan's scope is strictly the four modified files listed in the frontmatter.

## Traceability Notes (Requirements Not Producing New Tasks)

| Requirement | Status |
|-------------|--------|
| LOOP-03 (run ends → next loop starts harder) | Satisfied by `start_next_loop()` hook — Phase 8 calls on boss defeat |
| LOOP-06 (weapons/XP/evolution carry over; reset on wipe) | Verified already handled by `_broadcast_game_over` reset path (D-18) — no changes made |
| HUD-08 / V2X indicator | Descoped per D-11 — not implemented |
| LOOP-01 / 15-minute countdown timer | Descoped per D-15 — no countdown UI |
| LOOP-02 / room-clear transition | Out of Phase 7 scope — Phase 8 |

## Known Stubs

None. All changes are fully wired: `emit_hud` is an RPC, `loop_number` defaults to 1, `start_next_loop()` is callable, `MAX_HP`/`CONTACT_DAMAGE` are writable vars, XP scales from live `GameState.loop_number`.

## Threat Flags

No new network surface introduced. `emit_hud` restricted to `"authority"` — client calls are silently rejected by Godot's RPC system (T-07-01 mitigated). `start_next_loop()` is triple-guarded against client calls (T-07-02 mitigated). XP amount is computed host-side inside `_request_collect` which already guards with `if not multiplayer.is_server(): return` (T-07-03 accepted, unchanged surface).

## Self-Check: PASSED

- autoloads/GameEvents.gd: FOUND
- autoloads/GameState.gd: FOUND
- scenes/enemies/Enemy.gd: FOUND
- scenes/pickups/XpOrb.gd: FOUND
- Commit b793b4f: FOUND
- Commit ed0f039: FOUND
