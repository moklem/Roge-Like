---
phase: 02-player-movement-and-sync
plan: 02
subsystem: gameplay
tags: [multiplayer, role-labels, cross-peer-spawning]
dependency_graph:
  requires: [02-01]
  provides: [role-labels, all-players-visible]
  affects: [Player.tscn, Player.gd, Game.gd]
tech-stack:
  added: [Label node, _process sync]
  patterns: [property-sync-via-process, host-authoritative-spawning]
key-files:
  created: []
  modified: [scenes/Player.tscn, scenes/Player.gd, scenes/Game.gd]
decisions:
  - "RoleLabel as direct child of CharacterBody2D — moves with player, visible to all peers"
  - "_process() for label sync — lightweight, keeps label updated if role_label changes"
metrics:
  duration: "ongoing"
  completed: "2026-05-09"
---

# Phase 02 Plan 02: Role Labels & Cross-Peer Spawning Summary

**One-liner:** Role labels visible above each player character, all connected players spawned on all peers via host-authoritative MultiplayerSpawner.

## Tasks Completed

| Task | Description | Commit | Status |
|------|-------------|--------|--------|
| 1 | Add role label rendering to Player scene | 66e76bc | ✓ |
| 2 | Spawn all players on all peers via host RPC | e6b9e66 | ✓ |

## What Was Built

**Role Label (Player.tscn + Player.gd):**
- Label node named "RoleLabel" as child of CharacterBody2D root
- Positioned above character (offset_top = -50, offset_bottom = -30)
- Centered horizontally (horizontal_alignment = 1)
- Text set from `role_label` property in `_ready()`
- `_process()` keeps label in sync if role_label changes at runtime
- Label visible to ALL peers — moves with CharacterBody2D position sync

**Cross-Peer Spawning (Game.gd):**
- Host-only spawning: `if multiplayer.is_server(): _spawn_all_players()`
- `_spawn_all_players()` iterates all entries in `Lobby.players` dict
- Sequential spawn position assignment from SpawnPoints Marker2D nodes
- `_spawn_player_at()` sets peer_id, role_label, unique name ("Player_%s")
- `add_child(player, true)` with force_readable_name for RPC path matching
- MultiplayerSpawner auto-replicates host spawns to all clients
- No client-side spawning (no else branch) — P3, P12 compliance

## Deviations from Plan

**Task 2: No changes needed — already implemented by Plan 02-01 Task 2**

The Game.gd host-authoritative spawning pattern was already correct from the previous plan. The `_spawn_all_players()` function, `add_spawnable_scene()` registration, and `multiplayer.is_server()` guard were all in place. Verified acceptance criteria and committed confirmation.

## Known Stubs

- Role label text defaults to "Player" until populated from Lobby.players at spawn time
- No actual role differentiation yet (Tank/Speedster/Engineer) — labels show whatever Lobby assigns

## Threat Flags

| Flag | File | Description |
|------|------|-------------|
| threat_flag:spawn | scenes/Game.gd | Only `multiplayer.is_server()` branch spawns — mitigates T-02-04 spoofing |
| threat_flag:role | scenes/Player.gd | Role label from Lobby.players (server-authoritative) — mitigates T-02-05 tampering |

## Self-Check: PASSED

- [x] scenes/Player.tscn contains RoleLabel node
- [x] scenes/Player.gd sets $RoleLabel.text from role_label
- [x] scenes/Game.gd has host-only spawning with MultiplayerSpawner
- [x] No client-side spawning path exists
- [x] All acceptance criteria verified via grep
