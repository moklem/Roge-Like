---
phase: 03-room-1-enemy-ai-combat-core
plan: "03"
subsystem: player-health-downed-revive
tags: [player, health, downed, revive, gameover]
dependency_graph:
  requires: [03-01]
  provides: [receive-damage-rpc, downed-state, revive-system, gameover-scene]
  affects: [03-05]
tech_stack:
  added: [ProgressBar-world-space, RPC-any_peer]
  patterns: [authority-guard, any-peer-rpc, synced-property-visual-update]
key_files:
  created: []
  modified:
    - scenes/Player.tscn
    - scenes/Player.gd
    - scenes/ui/GameOver.tscn
    - project.godot
decisions:
  - "D-12: Downed visual tint (grayscale 0.4) applied in _process on ALL peers from synced is_downed"
  - "D-13: Revive duration 3.5 seconds"
  - "D-17: health and is_downed replicated via MultiplayerSynchronizer from owning peer"
  - "Pitfall 3: receive_damage uses @rpc('any_peer') because host is not node authority"
metrics:
  duration: "~10 minutes"
  completed: "2026-05-09"
  tasks_completed: 3
  tasks_total: 3
---

# Phase 3 Plan 03: Player Health/Downed/Revive + GameOver — Summary

**One-liner:** Player.gd extended with health state machine, downed visual, revive hold input, and two any_peer RPCs (receive_damage, set_revive_progress); Player.tscn updated with HealthBar/ReviveBar and expanded SceneReplicationConfig.

---

## Status

**Complete** — commit c051da6.

---

## Tasks Completed

| Task | Name | Commit | Files Modified |
|------|------|--------|----------------|
| 1 | Extend Player.tscn — HealthBar, ReviveBar, SceneReplicationConfig | c051da6 | scenes/Player.tscn |
| 2 | Extend Player.gd — health, downed, revive, RPCs + project.godot revive action | c051da6 | scenes/Player.gd, project.godot |
| 3 | GameOver.tscn — already existed; fixed duplicate script attribute | c051da6 | scenes/ui/GameOver.tscn |

---

## What Was Built

### Player.tscn Changes
- SceneReplicationConfig now replicates position, health, is_downed (properties 0/1/2)
- HealthBar ProgressBar at offset_top=-40 (above sprite)
- ReviveBar ProgressBar at offset_top=-50, visible=false by default

### Player.gd Changes
- `var health: int = MAX_HP` and `var is_downed: bool = false` — synced via MultiplayerSynchronizer
- `add_to_group("players")` in _ready() — required for enemy group discovery
- `_process`: downed tint (Color(0.4,0.4,0.4)) + HealthBar value update on all peers
- `_physics_process`: downed movement block, _check_revive(delta) call, fire cooldown stub
- `receive_damage(amount)` RPC: `@rpc("any_peer", "call_remote", "reliable")` — host calls rpc_id(peer_id); owning peer decrements and enters downed state
- `_enter_downed()`: sets is_downed=true, calls GameState.track_downed if method exists
- `revive()`: restores 50% HP, clears is_downed
- `set_revive_progress(progress)` RPC: `@rpc("any_peer", "call_remote", "reliable")` — host pushes revive bar updates to owning peer
- `_check_revive`: detects E-key press near downed teammate, sends attempt_revive.rpc_id(1) to Game.gd

### project.godot Changes
- Added `revive` input action (E key, physical_keycode=69)

### GameOver.tscn
- Existing scene was already functional (GameOver.gd with auto-return). Fixed duplicate `script` attribute on root node.

---

## Deviations from Plan

- Task 3: GameOver.tscn already existed from a prior implementation; it contains a script (GameOver.gd) with auto-return behavior, which is a superset of the minimal static scene the plan required. Used existing implementation and fixed the duplicate script bug.

---

## Known Stubs

- `_try_fire()` not called yet — fire cooldown ticks but no bullet spawn until Plan 04 adds BulletSpawner
- `GameState.track_downed(peer_id)` guarded by `has_method("track_downed")` — wired in Plan 05
- `Game.gd.attempt_revive` guarded by `has_method("attempt_revive")` — wired in Plan 05

---

## Threat Surface Scan

| Threat ID | Component | Mitigation |
|-----------|-----------|------------|
| T-03-07 | Player.receive_damage RPC | `@rpc("any_peer")` — host calls rpc_id(peer_id); damage applied on owning peer only |
| T-03-08 | Player health manipulation | Damage flows host→owning peer via rpc_id; not amplified |
| T-03-09 | is_downed state | Only set in _enter_downed (from receive_damage on owning peer); cleared by revive() (Plan 05 host RPC) |
| T-03-10 | Revive request spoofing | attempt_revive.rpc_id(1) goes to host only; Plan 05 validates proximity + is_downed |

---

## Self-Check

- [x] Player.tscn: HealthBar ✓, ReviveBar ✓, properties/1 = health ✓, properties/2 = is_downed ✓
- [x] Player.gd: var health ✓, var is_downed ✓, @rpc("any_peer") before receive_damage ✓, receive_damage func ✓, _enter_downed ✓, revive() ✓, @rpc("any_peer") before set_revive_progress ✓, set_revive_progress func ✓, add_to_group("players") ✓, is_downed check in _physics_process ✓, _check_revive call ✓, $Sprite.modulate = Color(0.4,0.4,0.4) ✓
- [x] project.godot: revive action (E key, physical_keycode=69) ✓
- [x] GameOver.tscn: exists, loadable, duplicate script fixed ✓

## Self-Check: PASSED
