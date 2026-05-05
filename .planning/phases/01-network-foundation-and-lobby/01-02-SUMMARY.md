# Phase 1 Plan 02 — Summary

**Plan:** 01-02 — Lobby UI (Role/Element Pick, Ready-Up, Player List)
**Status:** Complete
**Date:** 2026-05-05

## What was built

Complete lobby UI that 1–3 players can navigate end-to-end before the game starts:

- **LobbyScreen.tscn + LobbyScreen.gd** — Single-screen lobby with:
  - Role buttons (Tank/Speedster/Engineer) — taken roles grayed out with "Taken" label (D-08)
  - Element buttons (Fire/Ice/Earth) — independent of role pick (D-07)
  - Ready button — locks picks, can un-ready to change (D-02)
  - Start button (host only) — enabled when all connected players are ready (D-01)
  - Live player list panel on right — shows role/placeholder, element, ready status per peer (D-09)
  - Host IP displayed prominently (NET-01)

- **Lobby.gd extended** with 4 new RPCs:
  - `set_player_role()` — validates role not taken by another peer before accepting
  - `set_player_element()` — independent element pick
  - `set_player_ready()` — only allows ready when both role + element chosen
  - `start_game()` — host-only, transitions to Game.tscn
  - `all_players_ready()` — helper for Start button enable/disable
  - `get_local_ip()` — returns LAN IP for display

- **MainMenu.gd updated** — connection status feedback (NET-03):
  - "Connecting to..." during join attempt
  - "Connected!" → transitions to LobbyScreen
  - "Connection failed. Check IP and try again." → re-enables buttons
  - Host clicks "Host Game" → transitions directly to LobbyScreen (D-03: solo start)

## Requirements covered

| Req | Status | Where |
|-----|--------|-------|
| NET-03 | ✅ | MainMenu.gd connection status labels |
| LOBB-01 | ✅ | LobbyScreen role buttons |
| LOBB-02 | ✅ | Role validation in `set_player_role` + "Taken" label |
| LOBB-03 | ✅ | LobbyScreen element buttons |
| LOBB-04 | ✅ | Live player list panel in `_refresh_ui` |
| LOBB-05 | ✅ | Start button enabled when `all_players_ready()` |

## Acceptance criteria

All 15 acceptance criteria verified via grep:
- ✅ 4 new RPCs in Lobby.gd (set_player_role, set_player_element, set_player_ready, start_game)
- ✅ 2 helpers (all_players_ready, get_local_ip)
- ✅ All @rpc functions have annotations on preceding line
- ✅ LobbyScreen.gd has _on_role_pressed, _refresh_ui, _on_ready_pressed, _on_start_pressed
- ✅ LobbyScreen.gd references Lobby.set_player_role and Lobby.all_players_ready
- ✅ MainMenu.gd has _on_connected_to_server, transitions to LobbyScreen, shows "Connecting to"

## Self-Check: PASSED
