---
phase: 04-weapons-and-item-pickups
plan: "01"
subsystem: pickups
tags: [pickups, multiplayer, weapons, rpc, godot4]
dependency_graph:
  requires:
    - "scenes/pickups/XpOrb.gd (collected guard pattern replicated)"
    - "scenes/Game.gd _on_enemy_died and _do_spawn_pickup (extended)"
    - "scenes/Game.tscn PickupSpawner node (already existed)"
  provides:
    - "scenes/pickups/CarPartPickup.tscn — Area2D weapon pickup with collision_layer=64"
    - "scenes/pickups/CarPartPickup.gd — host-authoritative collection, weapon_unlocked RPC trigger"
    - "Game.gd weapon_unlocked RPC — host sends weapon ID to collecting peer's WeaponManager"
    - "Game.gd 25% enemy death drop branch — PickupSpawner.spawn.call_deferred with type dispatch"
  affects:
    - "04-02 WeaponManager scaffold — depends on weapon_unlocked RPC and WeaponManager.add_weapon() call signature"
    - "04-03 through 04-05 — all weapon plans depend on the RPC chain established here"
tech_stack:
  added:
    - "CarPartPickup.gd — Area2D pickup with exported weapon_id, _collected guard, @rpc any_peer"
    - "CarPartPickup.tscn — Area2D scene, collision_layer=64 (pickups), collision_mask=2 (players)"
  patterns:
    - "_collected bool guard on host (exact XpOrb replication)"
    - "add_spawnable_scene in _ready() before enemy spawning (P7 pattern)"
    - "call_deferred on spawn inside physics callback (_on_enemy_died)"
    - "@rpc(authority, call_remote, reliable) for host→peer weapon grant"
    - "match data.get(type, xp_orb) dispatch in _do_spawn_pickup"
key_files:
  created:
    - scenes/pickups/CarPartPickup.gd
    - scenes/pickups/CarPartPickup.tscn
  modified:
    - scenes/Game.gd
decisions:
  - "weapon_unlocked RPC lives on Game.gd (not Player.gd) with @rpc(authority) to avoid changing Player RPC checksum"
  - "CarPartPickup spawns at pos + Vector2(10, 0) offset from XpOrb drop to avoid exact overlap on death"
  - "add_spawnable_scene registers both XpOrb and CarPartPickup in _ready() to guarantee P7 compliance"
metrics:
  duration: "2 minutes"
  completed: "2026-05-31"
  tasks_completed: 2
  tasks_total: 2
  files_created: 2
  files_modified: 1
  lines_added: 120
---

# Phase 4 Plan 01: CarPartPickup Scene + PickupSpawner Wiring + 25% Drop Summary

**One-liner:** Area2D CarPartPickup with host-authoritative _collected guard wired into PickupSpawner; enemy death has 25% chance to drop a weapon-tagged car part that triggers weapon_unlocked RPC to collecting peer.

## What Was Built

Created `CarPartPickup.tscn` and `CarPartPickup.gd` as a new Area2D pickup scene that mirrors the `XpOrb._collected` guard pattern exactly. When a player steps on it, their peer sends `_request_collect.rpc_id(1, name, peer_id)` to the host; the host validates the `_collected` flag (W1 double-collect prevention), calls `game.weapon_unlocked.rpc_id(collector_peer_id, weapon_id)`, then calls `queue_free()` — which propagates to all clients via PickupSpawner.

Extended `Game.gd` with:
1. `CAR_PART_SCENE` preload and `CAR_PART_IDS` constant (all 5 weapon IDs)
2. `add_spawnable_scene` for both XpOrb and CarPartPickup in `_ready()` (P7 registration before any enemy can die)
3. `_on_enemy_died` now always drops `xp_orb` + 25% chance drops `car_part` (uniformly random from 5 IDs)
4. `_do_spawn_pickup` uses `match data.get("type", "xp_orb")` to dispatch xp_orb and car_part instantiation
5. `weapon_unlocked` RPC with `@rpc("authority", "call_remote", "reliable")` — host sends weapon ID to collecting peer → routes to `WeaponManager.add_weapon(weapon_id)`

## Commits

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Create CarPartPickup scene and script | b47997f | scenes/pickups/CarPartPickup.gd, scenes/pickups/CarPartPickup.tscn |
| 2 | Wire CarPartPickup into Game.gd and PickupSpawner | ad402fc | scenes/Game.gd |

## Deviations from Plan

None — plan executed exactly as written.

## Security / Trust Surface

| Trust Boundary | Mitigation | Implemented |
|----------------|------------|-------------|
| client body_entered → host _request_collect | `_collected` bool guard on host; only host runs queue_free() (T-04-01) | ✓ |
| host weapon_unlocked → client WeaponManager | `@rpc("authority")` ensures only host (peer 1) can grant weapons (T-04-02) | ✓ |

## Known Stubs

- `weapon_unlocked` RPC body routes to `WeaponManager.add_weapon(weapon_id)` — WeaponManager does not exist yet. This is intentional: Plan 04-02 creates WeaponManager scaffold. The `has_node("WeaponManager")` guard in `weapon_unlocked` prevents a crash if called before 04-02 lands.

## Self-Check: PASSED

- [x] `scenes/pickups/CarPartPickup.gd` exists
- [x] `scenes/pickups/CarPartPickup.tscn` exists
- [x] `scenes/Game.gd` contains `CAR_PART_SCENE`, `CAR_PART_IDS`, `randf() < 0.25`, `match data.get("type"`, `add_spawnable_scene`, `weapon_unlocked`
- [x] Commits b47997f and ad402fc exist in git log
