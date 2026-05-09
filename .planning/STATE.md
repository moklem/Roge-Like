# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-05-05)

**Core value:** The CARIAD HUD must always fire convincingly — every major game event triggers the corresponding vehicle sensor indicator, making the gameplay feel like a real in-car system demo

**Current focus:** Phase 4 — next phase (TBD)

---

## Current Phase

**Phase 3: Room 1, Enemy AI, Combat Core**
Status: Complete
Started: 2026-05-09
Completed: 2026-05-09

### Phase Goal

Core combat loop — Room 1 playable, enemies chase and damage players, players can die and be revived

### Plans (all complete)

- 03-01: Navmesh spike + obstacle + spawn points — commit 67ee1db (navmesh baked: human verified)
- 03-02: Enemy.tscn/gd + XpOrb.tscn/gd — commit c051da6
- 03-03: Player health/downed/revive + GameOver scene — commit c051da6
- 03-04: Bullet.tscn/gd + Player auto-fire — commit fa19ced
- 03-05: Game.gd full combat wiring + GameState game-over — commit 5cb622b

### Stopped At

Phase 3 complete. Awaiting Phase 4 planning.

---

## Phase History

### Phase 3: Room 1, Enemy AI, Combat Core
Status: Complete
Started: 2026-05-09
Completed: 2026-05-09

**Plans:** 03-01 through 03-05 (4 waves)
**Commits:** 67ee1db, c051da6, fa19ced, 5cb622b
**Summary:** NavigationAgent2D navmesh baked; Enemy with chase AI + contact damage; XpOrb pickup; Player health/downed/revive state machine; Bullet auto-fire projectiles; Game.gd with all 3 MultiplayerSpawners, enemy death → orb drop, request_fire and attempt_revive RPCs; GameState game-over broadcast.

### Phase 2: Player Movement & Sync
Status: Complete
Started: 2026-05-09
Completed: 2026-05-09

**Plans:** 02-01 (Player movement & collision), 02-02 (Role labels & cross-peer spawning)
**Commits:** 3bb04fd, 651d64e, 66e76bc, e6b9e66
**Summary:** CharacterBody2D player with WASD movement, wall collision, MultiplayerSynchronizer at 20 Hz, host-authoritative spawning, role labels above characters.

### Phase 1: Network Foundation & Lobby
Status: Complete
Started: 2026-05-05
Completed: 2026-05-09

**Plans:** 01-01 (Autoloads + project config), 01-02 (Lobby UI)
**Summary:** ENet multiplayer foundation, Lobby/Game autoloads, lobby UI with role/element pick, ready-up, player list.

---

## Performance Metrics

| Metric | Value |
|--------|-------|
| Phases complete | 3 / 8 |
| v1 requirements shipped | ~20 / 84 |
| Active blockers | 0 |

---

## Active Decisions

See .planning/PROJECT.md → Key Decisions for the full decision log.

**Highlights relevant to Phase 1:**
- Host-authoritative model — ENet, no third-party libs, no host migration
- Driver is NPC auto-system — only 3 human players; HUD fires from game events
- Host disconnect = game over for all clients (no migration)
- Elements are a separate pick from role — chosen in lobby same screen as role

---

## Accumulated Context

### Architectural Conventions (from research)

- **Three autoloads:** `Lobby` (connection lifecycle), `GameEvents` (HUD signal bus), `GameState` (authoritative run state)
- **RPC discipline (P1):** All `@rpc` annotations must be identical on both host and client at same NodePath — establish this in Phase 1 before any gameplay code
- **Authority guard rule (P3):** If it changes game state, guard it with `is_multiplayer_authority()`
- **Bullet sync (P5):** MultiplayerSpawner for instantiation + initial velocity; clients simulate locally; host sends RPC on hit
- **Sync interval:** MultiplayerSynchronizer `replication_interval = 0.05` (20 Hz, not per-frame)
- **Navmesh spike:** Do a 30-min NavigationAgent2D + TileMap baking spike before committing Room 1 geometry in Phase 3

### Pending Design Decisions

- Phase 7: Per-role ability specs (range, cooldown, AoE shape), Stage 2 signature mechanics, element modifier tuning
- Phase 8: Boss phase thresholds, HP scaling per loop, mob wave counts and composition

---

## Blockers

(None)

---

## Run Notes

Project initialized 2026-05-05. Research complete (HIGH confidence). Roadmap written 2026-05-05. Ready for Phase 1 planning.
