# Phase 3: Room 1, Enemy AI, Combat Core — Context

**Gathered:** 2026-05-09
**Status:** Ready for planning

<domain>
## Phase Boundary

Deliver a playable combat loop for Room 1: enemies spawn and chase the nearest player within detection range, players fire screws/bolts to damage enemies, enemies die and drop XP orbs, players can take damage and enter a downed state where teammates revive them. The core mechanic — "kill enemies, dodge contact, revive teammates" — must feel solid enough to test in a 3-player session. No weapons beyond screws/bolts, no evolution, no HUD events yet.

</domain>

<locked_requirements>
## Requirements (From ROADMAP.md Phase 3)

**Combat Core (CMBT-01–09):**
- CMBT-01: At least one basic enemy type chases and attacks the nearest player
- CMBT-02: Enemy pathfinds around room walls (does not walk through obstacles)
- CMBT-03: Enemies are spawned and controlled by the host; clients see the synced result
- CMBT-04: Starter weapon: screws and bolts fly outward automatically from the player
- CMBT-05: Bullets/projectiles despawn on enemy or wall contact
- CMBT-06: Bullet hits apply damage to the struck enemy (host-authoritative)
- CMBT-07: Enemy death removes the enemy from all clients simultaneously
- CMBT-08: Enemy death drops an XP orb pickup at the enemy's position
- CMBT-09: Player walking over XP orb collects it; orb despawns from all clients

**Health System (HLTH-01–08):**
- HLTH-01: Each player has a visible health bar shown to all players
- HLTH-02: Enemies deal damage to players on contact or projectile hit
- HLTH-03: Player health is synced to all clients in real time
- HLTH-04: Player reaching 0 HP enters a downed state (cannot act, visible downed indicator)
- HLTH-05: A teammate can walk near a downed player and hold a key to revive them
- HLTH-06: Revive has a visible hold-progress bar (not instant)
- HLTH-08: If all players are simultaneously downed, the run ends (game over)

</locked_requirements>

<decisions>
## Implementation Decisions

### Enemy AI & Pathfinding

- **D-01:** Enemy pathfinding updates **every frame (~60 Hz)**. Host recalculates NavigationAgent2D target position continuously while chasing. Ensures responsive enemy pursuit, snappy feel even with network latency.

- **D-02:** Enemies use **field-of-view detection** with a configurable detection radius. Outside that radius, enemies idle. Once a player enters the radius, the enemy begins chasing. More game-like than always-knows-player-position.

- **D-03:** Room 1 geometry uses **simple rectangular placeholder colliders** (StaticBody2D + CollisionShape2D). Later, when Google Maps data for ERBA island arrives, a dedicated "Map Data Import" phase will replace these with actual building footprints and street geometry. Keeps Phase 3 focused on combat mechanics.

- **D-04:** NavigationAgent2D navmesh bakes against TileMap + StaticBody2D geometry automatically in Godot 4.6. Before committing final Room 1 geometry, perform a 30-minute code spike to validate navmesh baking works correctly (ROADMAP note: Navmesh spike).

### Projectile System

- **D-05:** Bullets (screws/bolts) are spawned via **MultiplayerSpawner**. Host spawns, all peers receive identical bullet instantiation with initial velocity baked in. All clients see bullets from creation, ensuring no visual pop-in. Bullets must be pre-registered in the spawner's `add_spawnable_scene()` list.

- **D-06:** **Aimed at nearest enemy.** When the player (any authority) fires, the bullet fires in the direction of the nearest detected enemy within range. More tactical than 360° spray — uses fewer bullets, can be dodged, focuses fire.

- **D-07:** Bullet hit detection is **host-only and authoritative**. Host watches all bullets against enemy/wall collisions, detects hits, and broadcasts a despawn RPC to all clients. Single source of truth prevents desync.

- **D-08:** Players are **immune to their own bullets**. No self-damage from accidentally firing into a group. Standard behavior.

### Damage & Hit Detection

- **D-09:** Enemy contact damage is **host-only and authoritative**. Host detects when an enemy collides with a player, applies damage once per contact, syncs updated health to all clients via MultiplayerSynchronizer.

- **D-10:** Damage from enemy contact is **once per contact**. Enemy touches player → one hit of damage. Player must move away to avoid the next hit. Encourages kiting and dodging over standing still. No damage-over-time while touching.

### Health & UI

- **D-11:** Health bars are displayed as **world-space bars above all characters** (players and enemies) + optional HUD corner summary showing all teammate health. Gives full information at a glance, familiar roguelike feel.

- **D-12:** Downed state appearance: **color shift (grayscale or red tint)**. Player sprite desaturates or turns red when downed. Simplest, placeholder-friendly, instantly recognizable. No rotation or layering needed.

- **D-13:** Revive hold duration is **3–4 seconds**. Meaningful penalty without being brutal. Reviving teammate is vulnerable during the hold; others must protect them. No instant revives.

- **D-14:** When all players are simultaneously downed, the run ends with **immediate game over**. No grace period, no last-second revival window. Clean and unambiguous.

### Network & Authority

- **D-15:** Enemy spawning follows the same **spawn_function pattern** as Player spawning (Phase 2). Host spawns enemies via `$MultiplayerSpawner.spawn(data)` with authority, all peers instantiate with correct peer_id authority baked in.

- **D-16:** XP orbs dropped by enemies use **MultiplayerSpawner** (orb scene pre-registered). Orb collection is host-authoritative: client steps on orb, host validates proximity and player authority, broadcasts despawn RPC.

- **D-17:** Health sync uses **MultiplayerSynchronizer** at 20 Hz replication interval (same as Phase 2 position sync). Each player node replicates `health` property to all clients. Downed state is a `bool downed` property that syncs with health.

### Enemy Behavior

- **D-18:** Basic enemy behavior (chase + attack): Navigate toward detected player using NavigationAgent2D at every frame, attack when adjacent (deal damage on contact). Single enemy type in Phase 3; more types deferred to Phase 8.

- **D-19:** Enemy spawn pattern: Fixed spawn points in Room 1 (e.g., corners, edges). Host spawns enemies at game start or in waves. Spawn count configurable but not tuned yet (Phase 6 will scale per loop). Start with 3–5 enemies for testing.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Prior Phase Decisions (Phase 1 & 2)

- `.planning/phases/01-network-foundation-and-lobby/01-CONTEXT.md` — Host-authoritative model, three autoload pattern (Lobby / GameEvents / GameState), RPC discipline rules.
- `.planning/phases/02-player-movement-and-sync/02-CONTEXT.md` — Player spawning via spawn_function, MultiplayerSynchronizer at 20 Hz, authority guards.

### Technical Foundation

- `.planning/research/STACK.md` — Godot 4.6.2 multiplayer stack, ENet, @rpc modes, MultiplayerSynchronizer/Spawner config.
- `.planning/research/ARCHITECTURE.md` — Scene tree structure, host-authoritative patterns, RPC data flow.
- `.planning/research/PITFALLS.md` — P3 (authority guards), P4 (sync interval), P5 (bullet sync), P6 (NavigationAgent2D on clients).

### Project Requirements

- `.planning/REQUIREMENTS.md` §Combat (CMBT-01–09), §Health (HLTH-01–08) — the 17 requirements this phase must satisfy.
- `.planning/PROJECT.md` — Core value (CARIAD HUD concept), key decisions (host-authoritative, no host migration).
- `.planning/ROADMAP.md` §Phase 3 — goal, success criteria, pitfall watch (esp. navmesh spike).

### Godot Documentation

- **NavigationAgent2D + TileMap navmesh baking** — Godot 4.6 docs for setting target_position and path following in multiplayer contexts.
- **MultiplayerSynchronizer** — Replication config and property selection.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- **Player.tscn & Player.gd** (from Phase 2) — Authority-guarded input handling, MultiplayerSynchronizer setup pattern. Can copy for enemies (guard navigation updates with `is_multiplayer_authority()`).
- **Game.gd spawn_function pattern** — Custom spawner with data dictionary (peer_id, role, pos). Reuse for enemies and orbs.
- **GameState autoload** — Already initialized, ready for health tracking and revive counter per loop.

### Established Patterns

- **Three-autoload architecture:** Lobby (peer registry), GameEvents (signal bus for HUD, deferred until Phase 6), GameState (authoritative state).
- **Host-authoritative gameplay:** All authority checks use `multiplayer.is_server()` or `multiplayer.get_unique_id()`.
- **MultiplayerSynchronizer at 20 Hz:** Replication interval = 0.05s. Only replicate essential properties (position, health, downed state).
- **Authority-guarded input:** Only owning peer reads input; others ignore it (`is_multiplayer_authority()` check at top of input handler).

### Integration Points

- **Player health:** Add `health` property to Player.gd, replicate via existing MultiplayerSynchronizer. Add downed state machine.
- **Enemy scene:** New Enemy.tscn with CharacterBody2D, NavigationAgent2D, and synced position. Register in Game.gd spawner.
- **Bullet scene:** New Bullet.tscn with Area2D, linear velocity, collision detection. Pre-register in spawner.
- **GameState:** Add `get_player_health(id)`, `apply_damage(id, amount)`, `revive_player(id)` methods. Track revive counter.

</code_context>

<specifics>
## Specific Ideas & Clarifications

- **Room 1 placeholder:** Use a simple layout — open area with a few rectangular walls/obstacles in the center. Enemy detection radius should be large enough that they chase across the room, but small enough that players can have moments of safety if they run far from spawn.
- **Enemy starting position:** Spawn 3–5 enemies at fixed points around the room edges or center. No wave logic yet; just initial spawn at game start.
- **Screws/bolts visual:** No sprite needed — just small rectangles or circles with a velocity vector. Direction/rotation can indicate travel direction.
- **Revive hold key:** Use "E" as the revive input (same as many games). Teammate holds E while adjacent to downed player; progress bar fills over 3–4 seconds.
- **XP orb pickup:** When player walks over an XP orb, host validates proximity and triggers despawn on all clients. No "magnet" range yet; direct contact required.

</specifics>

<deferred>
## Deferred Ideas

- **Map Data Import:** Currently using placeholder rectangles. Plan a dedicated "Map Data Import" phase when Google Maps data for ERBA island is available. That phase will parse map data and auto-generate collision geometry.
- **Multiple enemy types:** Phase 3 uses one basic enemy type. Phase 8 or later can add ranged enemies, fast enemies, armored enemies.
- **Enemy wave spawning:** Phase 3 spawns enemies at game start. Phase 6 (loop timer) will handle wave spawning per loop with scaling difficulty.
- **Damage feedback (VFX):** Phase 3 has no particle effects or screen shake. Visual feedback (flash, knockback direction) deferred to Phase 7+ polish.
- **HUD event firing:** CARIAD HUD indicators (LIDAR, SUSPENSION) only fire in Phase 6+. Combat events don't wire to GameEvents yet.

</deferred>

---

*Phase: 3 — Room 1, Enemy AI, Combat Core*
*Context gathered: 2026-05-09*
