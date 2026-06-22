---
phase: 08-rooms-2-3-boss
plan: 02
subsystem: boss-fight
tags: [boss, state-machine, phase-transition, multiplayer, gdscript]
dependency_graph:
  requires: [Enemy.gd, EliteEnemy.gd, GameState.loop_number, BulletSpawner]
  provides: [Boss.tscn, Boss.gd, _enter_phase, _notify_phase_change, take_damage]
  affects: [Game.gd (_spawn_mob_swarm called via call_deferred), BulletSpawner (boss volleys)]
tech_stack:
  added: []
  patterns: [extends-enemy-gd, host-authoritative-ai, rpc-authority-call-local-reliable, call_deferred-physics-safe-spawn]
key_files:
  created:
    - scenes/enemies/Boss.tscn
    - scenes/enemies/Boss.gd
  modified: []
decisions:
  - "Boss bullets reuse Bullet.tscn via BulletSpawner with owner_id=-1 (Bullet.gd owner_peer_id only used for element proc attribution — Lobby.players.get(-1) returns empty dict, element='' — no friendly-fire issue since collision_mask 17 excludes players)"
  - "Boss overrides take_damage (not receive_damage) because Bullet.gd line 55 calls enemy.take_damage(BULLET_DAMAGE)"
  - "Phase 3 ranged volley fires 5 bullets at 0 +/-15 +/-30 degrees; Phase 2 fires 4 bullets at +/-20 +/-40 degrees"
  - "2-second attack pause on phase entry (Claude Discretion in CONTEXT) — boss still chases but does not fire during pause"
  - "_chase_player helper extracted from _physics_process to avoid duplicating NavigationAgent2D chase logic in the charge-burst path"
metrics:
  duration: 15m
  completed: "2026-06-22"
  tasks_completed: 2
  files_created: 2
status: complete
---

# Phase 8 Plan 02: Boss Scene and State Machine Summary

**One-liner:** Host-authoritative 3-phase Boss extending Enemy.gd — HP-threshold-gated phase logic, per-phase color RPC, mob-swarm request via call_deferred, ranged volley via BulletSpawner with owner_id=-1.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Create Boss.tscn scene | 114811b | scenes/enemies/Boss.tscn |
| 2 | Implement Boss.gd state machine | 9b0e5c8 | scenes/enemies/Boss.gd |

## What Was Built

### Boss.tscn (Task 1)
Scene following Enemy.tscn's exact node structure at boss scale:
- **Root:** `CharacterBody2D` named `Boss`, `collision_layer = 4`, `collision_mask = 3`
- **Sprite:** `ColorRect` with offsets -48/-48/48/48 (96x96 footprint), `Color(0.15, 0.05, 0.05, 1)` dark near-black red
- **CollisionShape2D:** `RectangleShape2D` size (80, 80)
- **NavigationAgent2D:** for host pathfinding (required by inherited Enemy._physics_process pattern)
- **HurtboxArea:** `Area2D` with `collision_layer = 16`, `collision_mask = 34`, child `CollisionShape2D` with `CircleShape2D radius = 48`
- **HealthBar:** `ProgressBar` positioned 64px above boss, `show_percentage = false`
- **MultiplayerSynchronizer:** replicates `position`, `current_hp`, AND `phase` at 0.05s interval

### Boss.gd (Task 2)
Host-authoritative state machine `extends "res://scenes/enemies/Enemy.gd"`:

**HP and Scaling (D-11):**
- `_ready()` calls `super._ready()` (adds to group, wires hurtbox, sets P6 AI guard)
- `mult = 1.0 + (GameState.loop_number - 1) * 0.25` — same formula as regular enemies
- `_boss_max_hp = int(1000 * mult)` — Loop 1: 1000, Loop 2: 1250, Loop 3: 1500
- `CONTACT_DAMAGE = int(25 * mult)` — 2.5x normal base, scaled per loop

**Phase Logic (D-12, ROOM-04):**
- `take_damage(amount)` overrides Enemy.gd's `take_damage` (matching Bullet.gd call at line 55)
- Authority guard: `if not is_multiplayer_authority(): return`
- Double-fire-safe checks (RESEARCH Pitfall 4): `if phase == 1 and current_hp <= _boss_max_hp * 0.66` → `elif phase == 2 and current_hp <= _boss_max_hp * 0.33`
- Zero HP: `died.emit(global_position)` then `queue_free()`

**Phase Transitions (D-13, D-14):**
- `_enter_phase(new_phase)`: sets `phase`, calls `_notify_phase_change.rpc(new_phase)`, resets timers, sets 2s pause, calls `game._spawn_mob_swarm.call_deferred(new_phase)` guarded by `has_method("_spawn_mob_swarm")`
- `@rpc("authority", "call_local", "reliable") _notify_phase_change(new_phase)`: changes `$Sprite.color` on all peers — Phase 2 dark red `Color(0.4, 0.05, 0.05, 1)`, Phase 3 bright red `Color(0.6, 0.0, 0.0, 1)`

**Attack Patterns (D-12):**
- Phase 1 movement: 80 px/s chase
- Phase 2 movement: 110 px/s
- Phase 3 movement: 165 px/s (1.5x Phase 2 enrage)
- Melee charge (Phase 1+): every 2.5s (Phase 3: 1.8s), 300 px/s burst for 0.8s toward nearest player
- Ranged volley (Phase 2+): every 1.8s (Phase 3: 1.2s); Phase 2 = 4 bullets ±20°/±40°, Phase 3 = 5 bullets 0°/±15°/±30°
- All attacks paused 2s after phase transition; boss continues to chase

**Boss Projectiles:**
- Reuse `BulletSpawner` with data keys `pos`, `dir`, `owner_id = -1`, `fire_burst = false`
- `owner_id = -1` is safe: Bullet.gd only uses `owner_peer_id` for element proc (`Lobby.players.get(-1, {})` returns `{}`, element `""`, no proc fires — intended behavior)
- Guard: `if not multiplayer.is_server(): return` before spawning

## Decisions Made

1. **Bullet reuse vs. BossProjectile.tscn:** Reused `Bullet.tscn` via the existing `BulletSpawner`. `Bullet.gd` does not perform player-friendly-fire checks via `owner_peer_id` — its `collision_mask = 17` (walls layer 1 + enemy_hurtbox layer 16) excludes players (layer 2) geometrically. `owner_peer_id` is only used for element attribution; `-1` gracefully returns no element for boss bullets. **No BossProjectile.tscn was created.** Plan 08-03 does not need to register a boss projectile scene.

2. **take_damage override (not receive_damage):** Bullet.gd calls `enemy.take_damage(BULLET_DAMAGE)` (line 55). Boss must override `take_damage` to intercept the damage path and insert phase logic before calling inherited death behavior.

3. **_chase_player helper:** Extracted from `_physics_process` to avoid duplicating NavigationAgent2D logic during the charge-burst branch. Clean pattern following existing Enemy.gd conventions.

## Deviations from Plan

None — plan executed exactly as written.

## Verification

- `grep -c 'Boss.gd' scenes/enemies/Boss.tscn` → 1 (references confirmed)
- `grep -c 'func _enter_phase\|func _notify_phase_change\|func take_damage' scenes/enemies/Boss.gd` → 3 (all functions present)
- Boss.gd line count: 201 (meets >90 minimum)
- Phase threshold guards use `phase == N` before HP comparison (Pitfall 4 double-fire prevention confirmed)
- No `change_scene` or `get_tree().paused` calls in Boss.gd (confirmed via grep)
- `multiplayer.is_server()` guard on `_fire_volley` (confirmed)
- `_spawn_mob_swarm.call_deferred(new_phase)` with `has_method` guard (confirmed)

## Known Stubs

None — Boss.gd is fully implemented with all behavior wired. Plan 08-03 must call `$EnemySpawner.add_spawnable_scene("res://scenes/enemies/Boss.tscn")` in `Game.gd._ready()` to satisfy P7 pre-registration before the boss fight is testable.

## Threat Flags

None — no new network endpoints or auth paths introduced. All RPCs follow existing project patterns (`@rpc("authority", "call_local", "reliable")` for boss phase color, consistent with room transition pattern). Boss AI is host-only (inherited P6 guard).

## Self-Check: PASSED

- [x] `scenes/enemies/Boss.tscn` exists
- [x] `scenes/enemies/Boss.gd` exists
- [x] Commit `114811b` exists (Boss.tscn)
- [x] Commit `9b0e5c8` exists (Boss.gd)
