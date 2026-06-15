---
phase: 05-roles-elements
plan: "02"
subsystem: role-abilities
tags: [tank-shield, speedster-dash, engineer-drone, reflect-rpc, shockwave, i-frames, roles, abilities]
dependency_graph:
  requires: [05-01]
  provides: [_use_stage1_ability, _use_stage2_ability, _use_second_dash, _activate_shield, _show_shield_ring, _hide_shield_ring, _request_reflect, request_reflect-rpc, _do_dash, _spawn_dash_shockwave, _show_dash_shockwave-rpc, shield-constants, dash-constants]
  affects: [scenes/Player.gd]
tech_stack:
  added: []
  patterns: [role-match-ability-dispatch, shield-intercept-receive_damage, host-reflect-rpc, expanding-ring-visual-rpc, dash-i-frames, host-only-shockwave-damage, has_method-guard]
key_files:
  created: []
  modified:
    - scenes/Player.gd
decisions:
  - "attacker_path optional param added to receive_damage (Open Question 3 resolution) — callers may omit; reflection skipped when empty (best-effort)"
  - "dash_invincible checked before airbag check in receive_damage (D-11 i-frames ignore ALL damage)"
  - "shield_active checked after airbag check — airbag still absorbs lethal hits on non-downed Tank"
  - "request_reflect RPC guards multiplayer.is_server() (T-05-04 mitigation); enemy.take_damage only runs on host"
  - "_spawn_dash_shockwave splits into visual RPC (call_local, unreliable_ordered) and host-only damage loop (T-05-05)"
  - "Engineer ability re-deploy guard = 1.0s cooldown (plan spec); has_method guard makes build safe pre-Plan-03"
  - "_shield_ring created once and reused via visible toggle (AirbagShield pattern)"
metrics:
  duration: "12 minutes"
  completed: "2026-06-15T13:30:00Z"
  tasks_completed: 2
  files_modified: 1
---

# Phase 05 Plan 02: Role Abilities Summary

Tank shield (Stage-1: 3s block; Stage-2: 6s + 50% reflection), Speedster dash with i-frames (Stage-1) and double-dash shockwave landing (Stage-2), and Engineer Space → `request_deploy_drone` RPC to host — all implemented in `scenes/Player.gd` filling Plan 01 stubs.

## What Was Built

**Task 1 — Tank shield Stage-1/Stage-2 + receive_damage intercept + host reflection RPC:**

Constants added to Player.gd:
- `TANK_SHIELD_S1 = 3.0`, `TANK_SHIELD_S2 = 6.0`, `TANK_SHIELD_COOLDOWN = 8.0`
- `TANK_REFLECT_PCT = 0.5`, `TANK_REFLECT_MIN = 5`

State vars added: `_shield_timer`, `_shield_ring`, `_last_attacker_path`

`_use_stage1_ability()` Tank branch: calls `_activate_shield(TANK_SHIELD_S1)`, sets `_ability_cooldown = 11.0` (3+8)

`_use_stage2_ability()` Tank branch: calls `_activate_shield(TANK_SHIELD_S2)`, sets `_ability_cooldown = 14.0` (6+8)

`_activate_shield(duration)`: sets `shield_active = true`, `_shield_timer = duration`, calls `_show_shield_ring()`

`_show_shield_ring()`: creates blue hollow ring (`Color(0.3, 0.6, 1.0, 0.85)`) via two nested ColorRects — outer colored + transparent inner cutout, mirrors AirbagShield.gd pattern exactly but blue instead of yellow. Ring node created once and reused via `.visible` toggle.

`_hide_shield_ring()`: sets `_shield_ring.visible = false`

`_tick_ability()` extended: counts down `_shield_timer`; on expiry sets `shield_active = false` and calls `_hide_shield_ring()`; also counts down `_dash_timer`, clears `dash_invincible` on expiry.

`receive_damage(amount, attacker_path = "")`: Signature extended with optional `attacker_path: String = ""` (Open Question 3). Order of checks: (1) `dash_invincible` → return immediately; (2) airbag lethal intercept; (3) `shield_active` → record `_last_attacker_path`, optionally call `_request_reflect`, return — blocks all damage regardless of stage.

`_request_reflect(amount, attacker_path)`: computes `maxi(int(amount * 0.5), 5)`, routes to `request_reflect` RPC on host if client, or calls directly if already host.

`request_reflect(attacker_path, reflect_amount)` `@rpc("any_peer","call_remote","reliable")`: server guard, resolves `get_node_or_null(attacker_path)`, calls `enemy.take_damage(reflect_amount)` (T-05-04 mitigation).

**Task 2 — Speedster dash/double-dash shockwave + Engineer drone deploy:**

Constants added: `DASH_DURATION = 0.3`, `DASH_MULT = 3.0`, `DASH_COOLDOWN = 4.0`, `DASH_WINDOW = 0.8`, `DASH_SHOCK_RADIUS = 80.0`, `DASH_SHOCK_DAMAGE = 25`

State var: `_dash_timer`

`_use_stage1_ability()` Speedster branch: `_do_dash()` + `_ability_cooldown = 4.0`

`_use_stage2_ability()` Speedster branch: `_do_dash()` + `_dash_window_timer = 0.8` + `_ability_cooldown = 4.0` (normal cooldown if window lapses)

`_use_second_dash()`: `_do_dash()` + `_spawn_dash_shockwave(global_position)` + `_dash_window_timer = 0.0`

`_do_dash()`: sets `dash_invincible = true`, `_dash_timer = 0.3`, applies `velocity = dir * SPEED * 3.0` + `move_and_slide()`; falls back to `Vector2.RIGHT` if no input.

`_spawn_dash_shockwave(pos)`: broadcasts `_show_dash_shockwave.rpc(pos)` (call_local visual on all peers), then host-only loop over "enemies" group — `take_damage(25)` + velocity knockback `+= (dir * 300.0)` for enemies within 80px (T-05-05 mitigation).

`_show_dash_shockwave(pos)` `@rpc("any_peer","call_local","unreliable_ordered")`: yellow (`Color(1.0, 1.0, 0.0, 0.8)`) expanding ring, 80px radius, added to `/root/Game`, animated with Tween then freed — mirrors HornShockwave._show_visual exactly.

Engineer Stage-1 and Stage-2 branches: `game.request_deploy_drone(peer_id)` direct (host) or `rpc_id(1, peer_id)` (client); `has_method("request_deploy_drone")` guard ensures no crash before Plan 03 ships. `_ability_cooldown = 1.0`.

## Commits

| Task | Commit | Description |
|------|--------|-------------|
| Task 1 + Task 2 | cc8eeaa | feat(05-02): Tank shield, Speedster dash/shockwave, Engineer drone dispatch |

Both tasks were implemented together in a single file editing session; committed as one atomic unit.

## Known Stubs

| Stub | File | Line | Filled By |
|------|------|------|-----------|
| `_tick_element(_delta)` | scenes/Player.gd | ~229 | Plan 05-04 (Fire/Ice/Earth element timers) |

This stub is carried over from Plan 01 and is not this plan's responsibility. It does not affect the Plan 02 objective.

## Deviations from Plan

None — plan executed exactly as written.

Plan specified: "Make `receive_damage` tolerate missing attacker_path (reflection simply skipped when empty)" — implemented exactly as specified with `if attacker_path == "": return` in `_request_reflect`.

Plan specified: "Enemy.gd passing `get_path()` as attacker is a follow-on — reflection is best-effort per deferred scope" — no Enemy.gd callers updated (correct per plan scope).

## Threat Surface Scan

No new network endpoints, auth paths, or schema changes beyond what the plan's threat model documents.

- `request_reflect` RPC (T-05-04): `multiplayer.is_server()` guard present; only host calls `enemy.take_damage`. Enemy.take_damage also self-guards with `is_multiplayer_authority()`.
- `_show_dash_shockwave` RPC (T-05-05): pure visual, `call_local` — no state mutation. Actual damage wrapped in `if not multiplayer.is_server(): return`.
- `receive_damage` signature change: optional param with default `""` — backward-compatible; all existing callers (Enemy.gd, Bullet.gd) continue working without modification.

## Self-Check: PASSED

Files verified:
- `/Users/bistl/Documents/RogeLike/Roge-Like/scenes/Player.gd` — contains `func _activate_shield`, `TANK_SHIELD_S1`, `if shield_active`, `func request_reflect`, `func _show_shield_ring`, `func _do_dash`, `DASH_DURATION`, `if dash_invincible`, `func _use_second_dash`, `func _spawn_dash_shockwave`, `request_deploy_drone`

Commit verified: cc8eeaa present in git log.
