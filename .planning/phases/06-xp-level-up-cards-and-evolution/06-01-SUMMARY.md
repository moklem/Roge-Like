---
phase: 06-xp-level-up-cards-and-evolution
plan: "01"
subsystem: progression
tags: [xp, level-up, replication, multiplayer, evolution]
dependency_graph:
  requires: [05-05]
  provides: [XP-01, XP-09, EVOL-01, EVOL-05, EVOL-06]
  affects: [scenes/Player.gd, scenes/Player.tscn, scenes/pickups/XpOrb.gd, autoloads/GameState.gd]
tech_stack:
  added: []
  patterns: [rpc-any_peer-call_remote-reliable, MultiplayerSynchronizer-replication, host-authoritative-grant, while-loop-multi-levelup]
key_files:
  created: []
  modified:
    - scenes/Player.gd
    - scenes/Player.tscn
    - scenes/pickups/XpOrb.gd
    - autoloads/GameState.gd
decisions:
  - "XP_PER_ORB=15 (tuned from D-01 default 5 to hit Stage 2 in 8-12 min per planner calc)"
  - "receive_xp uses while-loop for multi-level-up in one grant; guarded has_method calls for Plans 02/05/06 hooks"
  - "XpOrb host edge case: get_remote_sender_id()==0 fallback to get_unique_id() for host-direct collection"
  - "GameState game-over reset uses has_method guard for set_evolution_stage so plan is self-contained"
metrics:
  duration: "~3 min"
  completed_date: "2026-06-18"
  tasks_completed: 3
  tasks_total: 3
  files_changed: 4
---

# Phase 6 Plan 01: XP State Foundation Summary

Per-player XP/progression state vars added to Player.gd with MultiplayerSynchronizer replication; XP grant wired into XpOrb collection path; game-over resets all progression fields back to Stage 1 defaults.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Add Phase 6 vars, constants, receive_xp RPC to Player.gd | dc0b279 | scenes/Player.gd |
| 2 | Extend Player.tscn — replicate new vars, Stage containers, LevelUpLabel | 164799d | scenes/Player.tscn |
| 3 | Grant XP on orb collection (XpOrb.gd) and reset progression on game-over (GameState.gd) | d0021f4 | scenes/pickups/XpOrb.gd, autoloads/GameState.gd |

## What Was Built

**Player.gd additions:**
- Three progression constants: `XP_PER_ORB=15`, `STAGE2_LEVEL=5`, `STAGE3_LEVEL=10`
- Five state vars: `xp: int`, `level: int`, `element_tier: int`, `is_picking_card: bool`, `stage3_damage_mult: float`
- `receive_xp(amount: int)` RPC — mirrors `receive_heal` pattern, uses while-loop for multi-level-up in single grant, has_method guards for Plans 02/05/06 hooks
- `_xp_threshold(lvl: int) -> int` — formula: `100 + (lvl-1) * 50` per D-02

**Player.tscn additions:**
- SceneReplicationConfig properties/6-10 (xp/level/element_tier/is_picking_card/stage3_damage_mult) with `replication_mode = 2` (ALWAYS)
- Stage1Container (empty Node2D wrapper)
- Stage2Container (hidden Node2D with 3 grey ColorRects: body + left arm + right arm)
- Stage3Container (hidden Node2D with body + 4 cyan armor plate ColorRects)
- LevelUpLabel (hidden Label, offset -70/-54 above RoleLabel at -50)

**XpOrb.gd extension:**
- `_request_collect` now identifies collector via `multiplayer.get_remote_sender_id()`
- Host edge case: sender_id == 0 falls back to `multiplayer.get_unique_id()` (host collected directly)
- Grants `p.XP_PER_ORB` XP: direct call for host peer, `rpc_id` for remote peers
- `_collected` guard still runs before XP grant (no double-grant possible)

**GameState.gd extension:**
- `_broadcast_game_over` resets `xp=0 / level=1 / element_tier=1 / stage3_damage_mult=1.0 / is_picking_card=false`
- Calls `set_evolution_stage(1)` via `has_method` guard (back to Normal Car)

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

- `receive_xp` calls `_trigger_card_pick()` and `_check_stage_threshold()` via `has_method` guards — these methods do not exist yet; added in Plans 05/06. The has_method guard is intentional and documented.
- `_update_xp_hud()` guarded by `has_method` — wired in Plan 02.
- These stubs are intentional per the plan design and do not prevent Plan 01's goals (XP state data substrate).

## Threat Surface

T-06-01 through T-06-04 mitigations implemented as designed:
- Collector identified by `get_remote_sender_id()` (not client-supplied) — spoofing mitigated
- XP amount hardcoded as `p.XP_PER_ORB` on host — tampering mitigated
- `_collected` guard before XP grant — double-grant race mitigated
- `receive_xp` runs only on owning peer after host-initiated `rpc_id` — client-side XP increment impossible

## Self-Check: PASSED

Files exist:
- scenes/Player.gd — FOUND (modified)
- scenes/Player.tscn — FOUND (modified)
- scenes/pickups/XpOrb.gd — FOUND (modified)
- autoloads/GameState.gd — FOUND (modified)

Commits:
- dc0b279 — FOUND
- 164799d — FOUND
- d0021f4 — FOUND
