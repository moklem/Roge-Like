# Phase 1 Plan 01 — Summary

**Plan:** 01-01 — Autoloads and Project Configuration
**Status:** Complete
**Date:** 2026-05-05

## What was built

Bootstrapped the complete multiplayer foundation for the Roge-Like Godot 4 project:

- **Three autoload scripts** registered in `project.godot`:
  - `Lobby.gd` — ENet host/client init (port 7000), `players: Dictionary` registry, `peer_connected`/`peer_disconnected`/`server_disconnected` signal handlers, host-disconnect → GameOver scene change
  - `GameEvents.gd` — Pure signal bus (`hud_event`, `player_downed`, `player_revived`, `loop_ended`)
  - `GameState.gd` — `loop_timer`, `loop_number`, `revives_used` with `multiplayer.is_server()` guard
- **project.godot** configured with:
  - Autoload registrations for all three singletons
  - Collision layer names (world/players/enemies/player_hurtbox/enemy_hurtbox/bullets)
  - GL Compatibility renderer
  - WASD input actions
  - Main scene → `res://scenes/ui/MainMenu.tscn`
- **Two scene files**: `MainMenu.tscn` (host/join screen) and `GameOver.tscn` (host disconnect screen)

## Key decisions implemented

- D-10: Port 7000 hardcoded in `Lobby.gd`
- D-13: Host is always peer 1, `multiplayer.is_server()` used for authority guards
- D-16/P9: `peer_disconnected` wired in `_ready()`, id==1 → `change_scene_to_file("res://scenes/ui/GameOver.tscn")`
- D-14/P1: All 4 `@rpc` functions in `Lobby.gd` have identical annotations on both peers
- D-15: No RPC calls in `_ready()` — initial state broadcast via `peer_connected` handler

## Acceptance criteria

All 11 acceptance criteria verified via grep:
- ✅ `const PORT: int = 7000`
- ✅ `peer_disconnected.connect(_on_peer_disconnected)`
- ✅ `change_scene_to_file` in disconnect handler (2 occurrences — both `_on_peer_disconnected` and `_on_server_disconnected`)
- ✅ `var players: Dictionary`
- ✅ `signal hud_event(event_name: String)`
- ✅ `signal player_downed(player_id: int)`
- ✅ `multiplayer.is_server()` guard in GameState `_process`
- ✅ 4 `@rpc` functions defined with annotations
- ✅ All 3 autoload registrations in project.godot
- ✅ Collision layers 1-6 named
- ✅ GL Compatibility renderer configured
- ✅ Main scene set to MainMenu.tscn

## Self-Check: PASSED
