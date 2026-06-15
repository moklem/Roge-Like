---
phase: 05-roles-elements
plan: "01"
subsystem: roles-elements-foundation
tags: [input-map, player-scaffold, enemy-status-effects, replication, roles, elements]
dependency_graph:
  requires: [04-05]
  provides: [role_ability-input, receive_heal-rpc, set_evolution_stage-rpc, apply_burn, apply_slow, speed_multiplier, evolution_stage, element, shield_active, dash_invincible]
  affects: [scenes/Player.gd, scenes/Player.tscn, scenes/enemies/Enemy.gd, project.godot]
tech_stack:
  added: []
  patterns: [role-stat-match, rpc-any_peer-call_remote, MultiplayerSynchronizer-property-extension, delta-decrement-timer, host-only-status-tick]
key_files:
  created: []
  modified:
    - project.godot
    - scenes/Player.gd
    - scenes/Player.tscn
    - scenes/enemies/Enemy.gd
decisions:
  - "revive action rebound to R (physical_keycode=82); role_ability action added on Space (physical_keycode=32)"
  - "const SPEED/MAX_HP converted to var so role match block can mutate them (Pitfall 1)"
  - "evolution_stage/shield_active/dash_invincible added to Player MultiplayerSynchronizer SceneReplicationConfig (T-05-03)"
  - "ability/element stubs (pass bodies) allow project to compile; Plans 02 and 04 fill them"
  - "apply_burn/apply_slow called host-only from Bullet.gd; Enemy._tick_status_effects runs under P6 physics_process guard"
metrics:
  duration: "7 minutes"
  completed: "2026-06-15T12:59:45Z"
  tasks_completed: 3
  files_modified: 4
---

# Phase 05 Plan 01: Foundation Scaffold Summary

Phase 5 foundation established: input bindings updated (revive E→R, Space role_ability), Player.gd extended with mutable stats, role stat application, evolution_stage gate, element tracking, ability/element tick skeletons with safe stubs, receive_heal + set_evolution_stage RPCs, Player.tscn replication config extended, and Enemy.gd burn/slow status effects with visible tint.

## What Was Built

**Task 1 — InputMap changes (project.godot):**
- `revive` action: physical_keycode changed from 69 (E) to 82 (R) per D-01
- `role_ability` action added with physical_keycode 32 (Space) per D-02
- No Player.gd code changes needed — `_check_revive` references action name "revive" which is unchanged

**Task 2 — Enemy.gd status effects:**
- Added fields: `speed_multiplier: float = 1.0`, `_slow_timer`, `_burn_timer`, `_burn_tick_timer`
- Chase velocity updated to `SPEED * speed_multiplier` (ELEM-03 backing for ice slow)
- `_tick_status_effects(delta)` called from `_physics_process` (host-only via P6 guard): slow countdown resets multiplier + clears blue tint; burn countdown ticks `take_damage(5)` per 1.0s and clears orange tint on expiry
- `apply_burn()`: refreshes 3s duration, sets orange tint `Color(1.0, 0.6, 0.2)` — no stack per D-17
- `apply_slow()`: sets `speed_multiplier = 0.5`, 2s duration, blue tint `Color(0.5, 0.7, 1.0)` per D-18

**Task 3 — Player.gd scaffold + Player.tscn replication:**
- `const SPEED/MAX_HP` → `var SPEED/MAX_HP` (Pitfall 1 fix — role stats must mutate)
- Phase 5 vars added: `evolution_stage`, `element`, `shield_active`, `dash_invincible`, all 7 timer floats
- `_ready()`: calls `_apply_role_stats()`, reads `element` from `Lobby.players`, initializes timers to first-interval values (burst/shockwave don't fire on frame 1)
- `_apply_role_stats()`: Tank → MAX_HP=150/health=150 (ROLE-01); Speedster → SPEED=280 (ROLE-04); Engineer → pass
- `_physics_process`: `_tick_ability(delta)` and `_tick_element(delta)` inserted before `_check_revive`
- `_tick_ability(delta)`: decrements cooldown + dash window; dispatches `_use_role_ability()` or `_use_second_dash()`
- `_use_role_ability()`: `evolution_stage >= 2` gate to Stage-2 vs Stage-1 (D-20)
- Safe stubs: `_use_stage1_ability`, `_use_stage2_ability`, `_use_second_dash`, `_tick_element` — all `pass`; Plans 02/04 fill them
- `receive_heal(amount: int)` RPC: `@rpc("any_peer","call_remote","reliable")`, downed guard, clamps to MAX_HP (Pattern 6)
- `set_evolution_stage(stage: int)` RPC: same annotation, sets `evolution_stage = stage` (Phase 6 caller)
- Player.tscn SceneReplicationConfig: appended `.:shield_active`, `.:dash_invincible`, `.:evolution_stage` at indices 3/4/5 with `allow_spawn=true, replication_mode=2` (T-05-03 mitigation)

## Commits

| Task | Commit | Description |
|------|--------|-------------|
| Task 1 | 173119f | feat(05-01): rebind revive E→R and add role_ability on Space |
| Task 2 | 43abd98 | feat(05-01): add Enemy.gd status-effect fields, apply_burn/apply_slow, _tick_status_effects |
| Task 3 | 7c2f979 | feat(05-01): Player.gd scaffold — mutable stats, role stats, evolution_stage, element, RPCs; Player.tscn replication |

## Known Stubs

These stubs are intentional and planned — they allow the project to compile while later plans fill the implementations:

| Stub | File | Line | Filled By |
|------|------|------|-----------|
| `_use_stage1_ability()` | scenes/Player.gd | ~144 | Plan 05-02 (Tank/Speedster/Engineer Stage-1) |
| `_use_stage2_ability()` | scenes/Player.gd | ~148 | Plan 05-02 (Tank/Speedster/Engineer Stage-2) |
| `_use_second_dash()` | scenes/Player.gd | ~152 | Plan 05-02 (Speedster double-dash) |
| `_tick_element(_delta)` | scenes/Player.gd | ~157 | Plan 05-04 (Fire/Ice/Earth element timers) |

These stubs do NOT prevent the plan goal — the plan's objective is to establish callable contracts, not implement ability bodies. The project compiles and role stats apply correctly.

## Deviations from Plan

None — plan executed exactly as written.

## Threat Surface Scan

No new network endpoints, auth paths, file access patterns, or schema changes beyond what the plan's threat model documents. The `receive_heal` and `set_evolution_stage` RPCs are documented in T-05-02 with accepted disposition (spoofed client call only heals itself — no cross-peer effect). The replication config extension addresses T-05-03.

## Self-Check: PASSED

Files verified:
- `/Users/bistl/Documents/RogeLike/Roge-Like/project.godot` — contains `physical_keycode":82` for revive and `role_ability` with physical_keycode 32
- `/Users/bistl/Documents/RogeLike/Roge-Like/scenes/enemies/Enemy.gd` — contains `var speed_multiplier`, `func apply_burn`, `func apply_slow`, `func _tick_status_effects`, `SPEED * speed_multiplier`
- `/Users/bistl/Documents/RogeLike/Roge-Like/scenes/Player.gd` — contains `var SPEED`, `var MAX_HP`, `var evolution_stage`, `func _apply_role_stats`, `func _tick_ability`, `func _use_role_ability`, `func receive_heal`, `func set_evolution_stage`
- `/Users/bistl/Documents/RogeLike/Roge-Like/scenes/Player.tscn` — SceneReplicationConfig contains `shield_active`, `dash_invincible`, `evolution_stage`

Commits verified: 173119f, 43abd98, 7c2f979 — all present in git log.
