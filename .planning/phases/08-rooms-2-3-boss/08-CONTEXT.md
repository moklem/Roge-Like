# Phase 8: Rooms 2 & 3, Boss - Context

**Gathered:** 2026-06-22
**Status:** Ready for planning

<domain>
## Phase Boundary

Build Room 2 (Bamberg Altstadt — narrow corridors) and Room 3 (Burg Altenburg — boss arena) as OSM-derived placeholder geometry, wire the full 3-room run flow (Room1 → Room2 → Room3/Boss), and implement a 3-phase boss fight with mob swarms between phases. All room transitions synchronise across all clients simultaneously. Defeating the boss ends the loop and calls `GameState.start_next_loop()`.

**Not in Phase 8 scope:**
- New weapon types or card upgrades
- New role or element abilities
- Visual polish or sprites — placeholder colored shapes throughout
- Any further HUD indicators beyond ROOM-06 (LIDAR fires on mob swarm spawns — already wired per existing pattern)

</domain>

<decisions>
## Implementation Decisions

### Room Transition Architecture

- **D-01:** All 3 rooms are **child nodes of Game.tscn** (`Room1`, `Room2`, `Room3`). The active room is visible and has physics enabled; inactive rooms are hidden (`visible = false`) and have their collision layers disabled. No scene reload needed.
- **D-02:** Room clear trigger is **all enemies dead, auto-triggered**. After every enemy death, the host checks remaining enemy count (in `$EnemySpawner`'s tracked nodes or a counter). When count reaches 0, the transition fires automatically.
- **D-03:** On room transition: host broadcasts an RPC (`@rpc("call_local", "reliable")`) that hides the current room, shows the next room, and teleports all players to the new room's `SpawnPoints` children. Leftover pickups and XP orbs are `queue_free()`d before the transition completes.
- **D-04:** A `current_room: int` variable in `Game.gd` (or `GameState`) tracks which room is active (1, 2, or 3). Transition logic reads this to know which room comes next. Room 3 triggers boss spawn immediately on enter.

### Room 2 Geometry (Bamberg Altstadt)

- **D-05:** Room 2 geometry is **OSM-derived from Bamberg Altstadt**. Researcher fetches OpenStreetMap data for the Bamberg Altstadt district. Streets become walkable corridor floor polygons; building footprints become `StaticBody2D` wall obstacles. The exact abstraction (direct trace vs. simplified interpretation) is decided by the researcher/planner after inspecting the data.
- **D-06:** A single `NavigationRegion2D` is baked over Room 2's full layout (same pattern as Room 1). Enemy spawn points are placed at corridor intersections and room edges.
- **D-07:** Room 2 has **higher enemy density** than Room 1 — spawn count formula: `INITIAL_ENEMY_COUNT_R2 × 1.5^(loop_number - 1)` where `INITIAL_ENEMY_COUNT_R2` is 1.5× the Room 1 baseline. Planner tunes exact value.

### Room 3 Geometry (Burg Altenburg — Boss Arena)

- **D-08:** Room 3 geometry is **OSM-derived from Burg Altenburg castle**. Researcher fetches map data for Burg Altenburg. Castle walls and tower footprints translate to `StaticBody2D` boundaries. Interior courtyard/open areas become the walkable boss arena.
- **D-09:** Boss spawns at the center of Room 3 when Room 3 becomes active. No normal enemy wave in Room 3 — boss fight only (mob swarms handled separately per D-14).
- **D-10:** Room 3 has boss-fight-appropriate enemy spawn points around the arena perimeter (for mob swarm spawning, not initial enemies).

### Boss Design

- **D-11:** Boss baseline HP: **1000 HP** (Loop 1). Scales per loop using the same formula as regular enemies: `1000 × (1.0 + (loop_number - 1) × 0.25)`. Loop 2: 1250 HP. Loop 3: 1500 HP.
- **D-12:** **3-phase boss fight** triggered by HP thresholds:
  - **Phase 1 (100–66% HP):** Slow movement, melee charge — boss rushes the nearest player and deals contact damage. Basic attack pattern.
  - **Phase 2 (66–33% HP):** Faster movement, adds ranged projectile volleys — boss fires 3–5 bullets in a spread pattern. Mob swarm spawns at the Phase 1→2 transition.
  - **Phase 3 (33–0% HP):** Enrage — both melee charge and ranged volleys simultaneously, speed boost (~1.5× Phase 2 speed). Mob swarm spawns at the Phase 2→3 transition.
- **D-13:** Phase transitions fire an RPC notification to all clients (visual/audio cue — at minimum, boss changes color to indicate phase). Phase thresholds are checked host-side in `Boss.gd receive_damage()`.

### Mob Swarm Composition

- **D-14:** Mob swarms spawn **at boss phase transitions** (at 66% and 33% HP). Two swarms total per boss fight (more in Phase 3 enrage if needed — planner decides).
- **D-15:** Swarm composition: **mix of normal enemies + 1 elite enemy per swarm** (2 elites in the Phase 3 swarm). Reuses existing `Enemy.tscn` and `EliteEnemy.tscn`. Each elite spawn triggers the LIDAR HUD indicator (ROOM-06 already satisfied by existing pattern).
- **D-16:** Swarm count scales with `loop_number`: `5 + (loop_number × 3)` normal enemies + 1 elite (2 elites in Phase 3 swarm). Loop 1: 8 normal + 1 elite per swarm. Loop 2: 11 normal + 1 elite. Loop 3: 14 normal + 2 elites.
- **D-17:** Boss fight ends when boss HP reaches 0. Host calls `GameState.start_next_loop()` (already implemented in Phase 7), which increments `loop_number`, resets `revives_used`, and applies difficulty. Then all clients return to Room 1 (new loop).

### Claude's Discretion

- Boss placeholder visual: Claude picks a shape that is clearly larger and more visually distinct than normal enemies (dark rectangle, 3× normal size) and the elite enemy (purple/dark-red). Suggest ~96×96px for the boss ColorRect vs. 32×32 for normal enemies.
- Boss melee charge distance and speed (Phase 1): Claude tunes for playability.
- Boss ranged projectile spread angle and speed (Phase 2): Claude tunes from Enemy bullet patterns as a baseline.
- Whether boss briefly pauses attacks (~2s) when a mob swarm spawns at each phase transition.
- Exact Room 2 and Room 3 geometry — derived from OSM data by researcher/planner.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Architecture & Patterns

- `.planning/phases/07-carhud-loop-timer-difficulty-scaling/07-CONTEXT.md` — D-17: `GameState.start_next_loop()` hook for boss defeat; D-19/D-20: difficulty scaling formula; D-13: EliteEnemy spawn pattern and LIDAR trigger
- `.planning/phases/01-network-foundation-and-lobby/01-CONTEXT.md` — RPC discipline rules (three-autoload pattern, `@rpc("call_local", "reliable")` for simultaneous transitions)
- `.planning/phases/03-room1-enemy-ai-combat-core/03-CONTEXT.md` (if exists) — Room 1 geometry decisions and NavMesh bake approach

### Live Code (read before modifying)

- `scenes/Game.gd` — Current Room1 node management, `_spawn_enemies()`, `_do_spawn_enemy()`, `attempt_revive()`, `_spawn_all_players()` (all must be extended for multi-room). Lines 150–156: player spawn point lookup via `$Room1/SpawnPoints`. Lines 178–220: enemy spawn logic and difficulty scaling.
- `scenes/Game.tscn` — Existing Room1 child structure (Floor, TileMap, NavigationRegion2D, SpawnPoints, EnemySpawnPoints, Entities, Walls). Room2 and Room3 must follow the same child structure.
- `autoloads/GameState.gd` — `loop_number`, `start_next_loop()` (line 50+), `revives_used`. Phase 8 adds `current_room: int` or similar tracking.
- `autoloads/GameEvents.gd` — `emit_hud.rpc("lidar")` is the LIDAR trigger for mob swarm elite spawns (ROOM-06).
- `scenes/enemies/Enemy.gd` — Base HP/damage/speed; difficulty scaling formula reads these. Boss.gd will use same receive_damage/died signal pattern.
- `scenes/enemies/EliteEnemy.tscn` — Pre-registered in EnemySpawner; used for mob swarm elite components.

### OSM Map Data (researcher must fetch)

- OpenStreetMap data for **Bamberg Altstadt** — streets as corridors, buildings as wall obstacles for Room 2
- Map data for **Burg Altenburg** (castle/fortress near Bamberg) — courtyard/castle layout for Room 3 boss arena

### Project Requirements

- `.planning/ROADMAP.md` §Phase 8 — ROOM-01–07 (7 requirements); pitfall watch: P10 (room transition desync), P7 (spawnable list gaps for boss + boss projectiles + mob enemies), design-pass requirement
- `.planning/REQUIREMENTS.md` §Rooms — ROOM-01–07 full text
- `.planning/PROJECT.md` — Core Value: "CARIAD HUD must always fire convincingly"; mob swarm elite spawns must trigger LIDAR

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- **`$EnemySpawner` + `_do_spawn_enemy(data)` pattern** — Room 2 and mob swarm spawning reuses this exact pattern with a `type` key in the data dict. Boss scene needs pre-registration: `$EnemySpawner.add_spawnable_scene("res://scenes/enemies/Boss.tscn")`.
- **`$Room1/SpawnPoints` marker pattern** — Room 2 and Room 3 need `SpawnPoints` and `EnemySpawnPoints` child nodes following the same structure. Player teleport on transition reads `get_children()` from the active room's `SpawnPoints`.
- **`GameState.start_next_loop()`** — Already implemented (Phase 7). Boss defeat → call this → all clients return to Room 1 with higher difficulty.
- **`EliteEnemy.tscn`** — Already registered in EnemySpawner. Mob swarms spawn elites by type key without re-registration.
- **Difficulty scaling at spawn time** — `_do_spawn_enemy()` applies `1.0 + (GameState.loop_number - 1) × 0.25` multiplier to HP and damage. Boss and mob swarm enemies use the same formula.

### Established Patterns

- **P7 (spawnable list pre-registration):** Boss.tscn, boss projectile scenes, and mob swarm enemy types must ALL be pre-registered in `EnemySpawner` before the boss fight becomes testable.
- **P10 (room transition desync):** Use `@rpc("call_local", "reliable")` for ALL room transitions. Host waits one frame after showing next room before spawning enemies.
- **Host-authoritative spawning:** Only host calls `spawner.spawn()`; clients receive via replication. All game state changes (boss HP phases, room transitions) flow host → all clients via RPC.
- **`call_deferred` for physics-safe spawns:** Mob swarm spawning during boss phase transition uses `call_deferred()` if triggered from within a physics callback.
- **CanvasLayer for UI:** Boss health bar (if shown to all players) should be a separate CanvasLayer element, not a world-space node.

### Integration Points

- **`Game.gd`:** Add `current_room: int = 1`. Add `_transition_to_room(next: int)` method — hides old room, shows new room, teleports players, despawns pickups. Hook into enemy death count check (`_on_enemy_died`). Add `_spawn_boss()` called when Room 3 becomes active. Add `_spawn_mob_swarm(phase: int)` called on boss phase transitions.
- **`GameState.gd`:** Optionally add `current_room: int` here if it needs to be synced to clients.
- **`Boss.gd` (new):** Extends the Enemy pattern. Has `receive_damage()` that tracks HP and calls `_enter_phase(2)` / `_enter_phase(3)` at thresholds. Has `_on_phase_enter(phase)` that changes attack behavior and calls `Game._spawn_mob_swarm(phase)` via signal or direct call.
- **`scenes/enemies/Boss.tscn` (new):** Must be pre-registered in EnemySpawner. Larger ColorRect visual. Contains boss logic node.

</code_context>

<specifics>
## Specific Ideas

- **OSM data for rooms:** User specifically wants rooms derived from real-world map data of Bamberg Altstadt (Room 2) and Burg Altenburg (Room 3). Researcher should fetch OSM data and determine the best way to abstract streets/castle walls into Godot StaticBody2D geometry. The spirit is geographic authenticity, not 1:1 accuracy.
- **Boss 3-phase design:** Phase 1 = slow melee charge. Phase 2 (66% HP) = adds ranged projectile volley. Phase 3 (33% HP) = both simultaneously + speed boost. Mob swarm spawns at Phase 1→2 and Phase 2→3 transitions.
- **Mob swarm mix:** Normal enemies + 1 elite per swarm (2 elites in Phase 3 swarm). Each elite triggers LIDAR HUD. Count scales: `5 + (loop_number × 3)` normal enemies.
- **Boss HP:** 1000 base, scales 1.25×/loop.

</specifics>

<deferred>
## Deferred Ideas

- **Visible boss phase transition cutscene/animation** — A brief full-screen flash or dramatic effect on phase change would add polish. Out of scope for placeholder build.
- **Per-phase music or audio cues** — Phase 3 enrage deserves distinct audio. Deferred to post-demo polish.
- **Room 2 mid-corridor ambush trigger** — A scripted enemy swarm that spawns when players reach a certain point in the corridor. Would add drama but is its own feature.
- **Boss projectile element types** — Boss using fire/ice projectiles that trigger HUD indicators would be a nice CARIAD tie-in. Deferred; base boss uses neutral projectiles for now.

</deferred>

---

*Phase: 8-rooms-2-3-boss*
*Context gathered: 2026-06-22*
