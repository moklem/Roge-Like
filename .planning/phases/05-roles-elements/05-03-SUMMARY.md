---
phase: 05-roles-elements
plan: "03"
subsystem: engineer-healdrone
tags: [engineer, heal-drone, multiplayer-spawner, passive-heal, host-authoritative, role-abilities]
dependency_graph:
  requires: [05-01, 05-02]
  provides: [HealDrone.gd, HealDrone.tscn, DroneSpawner, request_deploy_drone, _do_spawn_drone, _tick_engineer_passive]
  affects: [scenes/roles/HealDrone.gd, scenes/roles/HealDrone.tscn, scenes/Game.gd, scenes/Game.tscn]
tech_stack:
  added: []
  patterns: [MultiplayerSpawner-spawn_function, host-only-process, rpc-any_peer-call_remote, receive_heal-rpc-routing, Stage2-follow-physics_process]
key_files:
  created:
    - scenes/roles/HealDrone.gd
    - scenes/roles/HealDrone.tscn
  modified:
    - scenes/Game.gd
    - scenes/Game.tscn
decisions:
  - "DroneSpawner spawn_path set to Room1/Entities matching all other MultiplayerSpawner siblings"
  - "HealDrone authority stays on host (Pitfall 2 — no set_multiplayer_authority call); owning_peer is data only"
  - "_tick_engineer_passive in Game.gd _process (host-guarded) rather than Player.gd — keeps all drone/spawn logic co-located in Game.gd"
  - "Engineer passive heals OTHER players only (not the Engineer themselves) matching D-13 intent — 200px proximity"
  - "Placeholder visual: green 20x20 ColorRect — intentional per project art policy"
metrics:
  duration: "3 minutes"
  completed: "2026-06-15T13:14:00Z"
  tasks_completed: 2
  files_modified: 4
---

# Phase 05 Plan 03: Engineer HealDrone Scene + Game.gd Drone Spawn + Engineer Passive Heal Summary

Engineer Heal Drone implemented as a host-spawned, MultiplayerSpawner-replicated scene with pulse heal every 3s; Stage-2 drone follows the Engineer and heals +25 HP over 200px; Engineer passive heals nearby teammates +10 HP every 5s from Game.gd host-only timer.

## What Was Built

**Task 1 — HealDrone scene + script (scenes/roles/HealDrone.gd, scenes/roles/HealDrone.tscn):**
- `HealDrone.gd`: extends Node2D with `@export owning_peer: int` and `@export stage: int`
- Consts: `PULSE_INTERVAL=3.0`, `PULSE_HEAL_S1=15`, `PULSE_RADIUS_S1=150.0`, `PULSE_HEAL_S2=25`, `PULSE_RADIUS_S2=200.0`
- `_ready()` calls `_setup_area()`, `_setup_timer()`, `_draw_visual()` — mirrors HornShockwave.gd structure
- `_setup_timer()`: Timer with wait_time=3.0, autostart=true, one_shot=false, timeout→`_on_pulse`
- `_on_pulse()`: authority guard; selects S2 radius/heal when `stage >= 2`; iterates "players" group; distance check; `receive_heal` via host→peer routing (Enemy.gd lines 91-94 pattern)
- `_physics_process()`: authority guard; if `stage < 2` returns; otherwise finds owning Engineer by peer_id and sets `global_position` (Stage-2 follow, host-authoritative)
- `_setup_area()`: Area2D with collision_mask=2 (players), CircleShape2D radius=PULSE_RADIUS_S2
- `_draw_visual()`: green ColorRect 20x20, pivot center — placeholder art per project policy
- `HealDrone.tscn`: Node2D root + HealDrone.gd script + MultiplayerSynchronizer replicating `.:position` at 20 Hz so Stage-2 follow syncs to all clients
- Drone authority stays on host — never calls `set_multiplayer_authority(owning_peer)` (Pitfall 2 compliance)

**Task 2 — Game.tscn DroneSpawner + Game.gd drone spawn RPC + Engineer passive (scenes/Game.gd, scenes/Game.tscn):**
- `Game.tscn`: `DroneSpawner` MultiplayerSpawner node added as sibling of PickupSpawner with `spawn_path = NodePath("../Room1/Entities")`
- `Game.gd`: `HEAL_DRONE_SCENE` preload const added at top
- `Game.gd _ready()`: `$DroneSpawner.spawn_function = _do_spawn_drone` + `$DroneSpawner.add_spawnable_scene("res://scenes/roles/HealDrone.tscn")` (P7 pre-register)
- `Game.gd _engineer_passive_accum: float = 0.0` module-level var for passive tick tracking
- `Game.gd _process(delta)`: host-guarded (`if not multiplayer.is_server(): return`), calls `_tick_engineer_passive(delta)`
- `Game.gd _tick_engineer_passive(delta)`: every 5.0s, finds all Engineer players not downed; heals all OTHER players within 200px by +10 via receive_heal rpc_id routing (Pitfall 6 pattern)
- `Game.gd request_deploy_drone(requester_peer_id)`: `@rpc("any_peer","call_remote","reliable")`; guards `multiplayer.is_server()`; removes existing `HealDrone_<peer>` (max 1, D-14); validates player exists and not downed; spawns via `$DroneSpawner.spawn({pos, peer_id, stage})`
- `Game.gd _do_spawn_drone(data)`: instantiates HEAL_DRONE_SCENE, sets position/owning_peer/stage, names node `HealDrone_<peer_id>`

## Commits

| Task | Commit | Description |
|------|--------|-------------|
| Task 1 | b1753f2 | feat(05-03): HealDrone scene + script — pulse heal, Stage-2 follow, area, visual |
| Task 2 | e7e2217 | feat(05-03): Game.tscn DroneSpawner + Game.gd drone spawn RPC + Engineer passive heal |

## Known Stubs

None — all data flows are wired. The drone visual (green ColorRect) is intentional placeholder art per PROJECT.md policy; it is rendered and visible, not a missing-data stub.

## Deviations from Plan

None — plan executed exactly as written.

## Threat Surface Scan

No new network endpoints or auth paths beyond the plan's threat model:
- `request_deploy_drone` — documented as T-05-07 (elevation) and T-05-08 (spoofing); mitigations applied: `multiplayer.is_server()` guard, player validation, peer_id-keyed cleanup
- `_tick_engineer_passive` — documented as T-05-10; mitigation applied: host-only `_process` guard, heals sent via `receive_heal.rpc_id`
- Drone pulse heal (`_on_pulse`) — documented as T-05-10; mitigation applied: `is_multiplayer_authority()` guard

## Self-Check: PASSED

Files verified:
- `/Users/bistl/Documents/RogeLike/Roge-Like/scenes/roles/HealDrone.gd` — exists, contains `func _on_pulse`, `PULSE_HEAL_S2`, `receive_heal`, no `set_multiplayer_authority(owning_peer)` call
- `/Users/bistl/Documents/RogeLike/Roge-Like/scenes/roles/HealDrone.tscn` — exists, contains `MultiplayerSynchronizer`
- `/Users/bistl/Documents/RogeLike/Roge-Like/scenes/Game.gd` — contains `HEAL_DRONE_SCENE`, `func request_deploy_drone`, `func _do_spawn_drone`, `func _tick_engineer_passive`, `add_spawnable_scene("res://scenes/roles/HealDrone.tscn")`
- `/Users/bistl/Documents/RogeLike/Roge-Like/scenes/Game.tscn` — contains `DroneSpawner`

Commits verified: b1753f2, e7e2217 — both present in git log.
