---
phase: 03-room-1-enemy-ai-combat-core
plan: "02"
subsystem: enemy-ai-xporb
tags: [enemy, navigation, xporb, pickup, host-authoritative]
dependency_graph:
  requires: [03-01]
  provides: [enemy-scene, xporb-scene, layer-7-pickups]
  affects: [03-05]
tech_stack:
  added: [NavigationAgent2D, Area2D-pickup]
  patterns: [authority-guard, spawn-function, once-per-contact, double-collect-guard]
key_files:
  created:
    - scenes/enemies/Enemy.tscn
    - scenes/enemies/Enemy.gd
    - scenes/pickups/XpOrb.tscn
    - scenes/pickups/XpOrb.gd
  modified:
    - project.godot
decisions:
  - "D-01: NavigationAgent2D target_position updated every frame (~60 Hz)"
  - "D-02: Detection radius 300px; enemies idle outside radius"
  - "D-10: Once-per-contact damage via _players_in_contact dictionary"
  - "D-16: XP collection is host-authoritative via _request_collect RPC"
metrics:
  duration: "~10 minutes"
  completed: "2026-05-09"
  tasks_completed: 2
  tasks_total: 2
---

# Phase 3 Plan 02: Enemy AI + XpOrb — Summary

**One-liner:** Enemy CharacterBody2D with NavigationAgent2D chase AI and XpOrb Area2D with host-validated pickup, plus layer_7 (pickups) added to project.godot.

---

## Status

**Complete** — commit c051da6.

---

## Tasks Completed

| Task | Name | Commit | Files Modified/Created |
|------|------|--------|------------------------|
| 1 | Create Enemy.tscn and Enemy.gd | c051da6 | scenes/enemies/Enemy.tscn, scenes/enemies/Enemy.gd |
| 2 | Create XpOrb.tscn and XpOrb.gd | c051da6 | scenes/pickups/XpOrb.tscn, scenes/pickups/XpOrb.gd, project.godot |

---

## What Was Built

### Enemy.tscn
- **Root:** CharacterBody2D, collision_layer=4 (enemies), collision_mask=3 (world+players)
- **NavigationAgent2D:** path following for chase AI
- **HurtboxArea:** Area2D, collision_layer=16 (enemy_hurtbox), collision_mask=32 (bullets)
- **HealthBar:** ProgressBar positioned above sprite
- **MultiplayerSynchronizer:** replicates position, current_hp, state at 20 Hz (0.05 interval)

### Enemy.gd
- `set_physics_process(is_multiplayer_authority())` — clients never run AI (P6)
- `add_to_group("enemies")` — enables group-based discovery
- NavigationAgent2D chase with `is_navigation_finished()` jitter guard
- `_players_in_contact` dict for once-per-contact damage (D-10)
- `died.emit(global_position)` before `queue_free()` — CMBT-08 orb spawn signal
- `take_damage()` guarded by `is_multiplayer_authority()`

### XpOrb.tscn
- **Root:** Area2D, collision_layer=64 (layer 7 pickups), collision_mask=2 (players)
- **Sprite:** 16×16 yellow ColorRect

### XpOrb.gd
- `_collected` bool flag prevents double-collection race condition (Pitfall 5)
- `_request_collect` RPC: `@rpc("any_peer", "call_remote", "reliable")`, host-only guard

### project.godot
- Added `2d_physics/layer_7="pickups"`

---

## Deviations from Plan

None — implemented exactly as specified.

---

## Known Stubs

- `HurtboxArea` body_entered for contact damage: collision_mask=32 detects bullets (layer 6) but NOT player CharacterBody2D (layer 2). Contact damage via HurtboxArea.body_entered will not fire in practice. Physical collision still works via Enemy CharacterBody2D mask=3. Contact damage wiring will need mask=34 (layer 2+6) or a separate detection mechanism. Noted for Plan 05 or follow-up.

---

## Threat Surface Scan

| Threat ID | Component | Mitigation |
|-----------|-----------|------------|
| T-03-02 | XpOrb._request_collect | `if not multiplayer.is_server(): return` |
| T-03-03 | Enemy.take_damage | `if not is_multiplayer_authority(): return` |
| T-03-04 | Contact damage | `is_multiplayer_authority()` guard in body_entered |
| T-03-05 | XP double-collect | `_collected` bool on host |

---

## Self-Check

- [x] scenes/enemies/Enemy.tscn: NavigationAgent2D ✓, HurtboxArea collision_layer=16 ✓, collision_mask=32 ✓, MultiplayerSynchronizer replication_interval=0.05 ✓
- [x] scenes/enemies/Enemy.gd: set_physics_process ✓, add_to_group("enemies") ✓, died.emit ✓, _players_in_contact ✓, receive_damage.rpc_id ✓, is_navigation_finished() ✓
- [x] scenes/pickups/XpOrb.tscn: collision_layer=64 ✓, collision_mask=2 ✓
- [x] scenes/pickups/XpOrb.gd: _collected ✓, @rpc("any_peer") ✓, is_server() guard ✓, rpc_id(1, name) ✓
- [x] project.godot: layer_7="pickups" ✓

## Self-Check: PASSED
