---
phase: 02-player-movement-and-sync
plan: 01
subsystem: gameplay
tags: [multiplayer, movement, spawning, room]
dependency_graph:
  requires: [01-01, 01-02]
  provides: [player-movement, room-geometry, player-spawning]
  affects: [Player.tscn, Player.gd, Game.tscn, Game.gd]
tech-stack:
  added: [CharacterBody2D, MultiplayerSynchronizer, MultiplayerSpawner, TileMap]
  patterns: [host-authoritative-spawning, authority-guarded-input]
key-files:
  created: [scenes/Player.tscn, scenes/Player.gd]
  modified: [scenes/Game.tscn, scenes/Game.gd]
decisions:
  - "CharacterBody2D root for player (not Node2D) — required for move_and_slide()"
  - "CapsuleShape2D for collision — prevents edge-catching on walls"
  - "Host-only spawning in Game.gd — clients receive via MultiplayerSpawner"
  - "Removed BackButton from Game.tscn — game ends via host disconnect only (D-16)"
metrics:
  duration: "ongoing"
  completed: "2026-05-09"
---

# Phase 02 Plan 01: Player Movement & Collision Summary

**One-liner:** CharacterBody2D player with WASD movement, wall collision via TileMap, and host-authoritative spawning with MultiplayerSynchronizer at 20 Hz.

## Tasks Completed

| Task | Description | Commit | Status |
|------|-------------|--------|--------|
| 1 | Create Player scene with movement and collision | 3bb04fd | ✓ |
| 2 | Wire Game scene with room geometry and local player spawn | 651d64e | ✓ |

## What Was Built

**Player scene (Player.tscn + Player.gd):**
- CharacterBody2D root with CapsuleShape2D collision (radius 12, height 32)
- WASD movement via `Input.get_vector()` at 200 px/sec
- `is_multiplayer_authority()` guard prevents non-owning peers from reading input (P3)
- `set_multiplayer_authority(peer_id)` in `_ready()` establishes ownership
- MultiplayerSynchronizer with `replication_interval = 0.05` (20 Hz position sync)
- Collision layer 2 (players), mask includes layer 1 (world)

**Game scene (Game.tscn + Game.gd):**
- Room1 container with TileMap (wall collision on layer 1)
- 3 Marker2D spawn points spread horizontally (350, 400, 450 at Y=300)
- Entities Node2D as spawn parent for MultiplayerSpawner
- CanvasLayer HUD (layer=1) with PlayerLabel
- MultiplayerSpawner with `spawn_path = "Room1/Entities"`
- Host-authoritative spawning: `_spawn_all_players()` iterates `Lobby.players`
- `_spawn_player_at()` sets peer_id, role_label, unique name, force_readable_name
- Player scene registered in spawnable_scenes before any spawns (P7)
- Removed placeholder BackButton — game ends via host disconnect only

## Deviations from Plan

None - plan executed exactly as written.

## Known Stubs

- TileSet has no actual collision tiles defined — needs tile images and collision polygons in Godot editor
- Room1 TileMap has no tiles placed — needs room layout built in editor
- Player sprite is a ColorRect placeholder — needs actual sprite in later phase

## Threat Flags

| Flag | File | Description |
|------|------|-------------|
| threat_flag:authority | scenes/Player.gd | `is_multiplayer_authority()` guard on input — mitigates T-02-01 spoofing |
| threat_flag:sync | scenes/Player.tscn | MultiplayerSynchronizer replicates position from authority only — mitigates T-02-02 tampering |

## Self-Check: PASSED

- [x] scenes/Player.gd exists with `extends CharacterBody2D`
- [x] scenes/Player.tscn exists with CharacterBody2D root
- [x] scenes/Game.gd exists with spawning logic
- [x] scenes/Game.tscn exists with room structure
- [x] All acceptance criteria verified via grep
