# Project Research Summary

**Project:** Roge-Like (Godot 4 LAN Co-op Roguelike)
**Domain:** Co-op top-down action roguelike — LAN multiplayer, CARIAD university demo
**Researched:** 2026-05-05
**Confidence:** HIGH

---

## Executive Summary

This is a 3-player LAN co-op top-down roguelike built in Godot 4.6.2 using GDScript and the built-in ENet transport — no addons required. The canonical architecture is **host-authoritative**: the host (peer 1) runs all AI, physics, collision, and game-state logic; clients own only their own player's movement input; everything else reaches clients via `MultiplayerSynchronizer` (continuous state) and `MultiplayerSpawner` (spawn/despawn events). This is a well-documented pattern with official Godot support, high confidence, and zero unsolved technical questions.

The project's identity is the **CARIAD HUD side panel**: gameplay events (ability use, damage type, boss phase changes) fire vehicle-sensor indicators in real time. This is implemented via a `GameEvents` autoload signal bus — game systems emit events anywhere in the scene tree; the HUD listens on the same bus on every peer via an `@rpc("call_local")` broadcast. All other design decisions (3 hand-crafted rooms, placeholder art, 15-minute loops, card upgrades on loop end) are explicitly scoped to keep development focused on this differentiator.

The two highest risks are **RPC signature discipline** (a single mismatch breaks all RPC calls in a script with cryptic errors) and **authority guard omission** (missing `is_multiplayer_authority()` on host-only systems causes divergent state across peers). Both are preventable by convention and must be established in Phase 1 before any gameplay code is written.

---

## Key Findings

### Recommended Stack

All required capabilities exist in Godot 4.6.2's built-in API. No addons needed.

- **Godot 4.6.2-stable + GDScript** — confirmed latest stable; GDScript matches all official LAN examples and has zero external runtime requirements
- **Compatibility (OpenGL) renderer** — top-down 2D has no need for Vulkan/Forward+; OpenGL runs on all demo laptops without driver issues
- **`ENetMultiplayerPeer`** — built-in reliable-UDP transport; the only correct choice for LAN-only; no STUN/TURN complexity
- **`MultiplayerSynchronizer`** — continuous property replication (position, health, state enum) from authority peer to all others; set `replication_interval = 0.05` (20 Hz, not per-frame)
- **`MultiplayerSpawner`** — automatic scene instantiation on all peers when host spawns/despawns; required for enemies and bullets; **all scene variants must be pre-registered** or spawns silently fail on clients
- **`CharacterBody2D` + `NavigationAgent2D`** — standard top-down movement and wall-aware enemy pathfinding; NavigationAgent2D is "experimental" in label only — runtime-stable per community consensus
- **3 Autoloads: `Lobby`, `GameEvents`, `GameState`** — the three singletons cover connection lifecycle, decoupled HUD event bus, and authoritative run state respectively; this split is mandatory for clean scene transitions
- **`@rpc` annotations** — explicit one-shot events (damage, downed, HUD trigger, scene change); `"any_peer"` for client→host, `"authority"` + `"call_local"` for host→all

*See [STACK.md](STACK.md) for code patterns, collision layer assignments, and full scene templates.*

### Expected Features

**Must have — table stakes (demo fails without these):**
- WASD top-down movement, independent per player
- Visible synced HP bars for all players
- Auto-attack bullet system with host-authoritative damage
- 3 distinct player roles with different abilities (Tank / Speedster / Engineer)
- Role lock-in lobby screen before game starts
- Enemy that chases and attacks (host-simulated, position synced)
- Hit feedback — flash + HP bar drop
- Downed state + proximity revive mechanic
- Run ends on full team wipe
- Post-loop upgrade card screen (3 random cards, pick 1)
- Difficulty scaling each loop (enemy HP/damage/density multiplier)
- Boss encounter with multiple phases
- Host/Join screen with IP entry and connection status feedback
- Host disconnect → "Host Left" screen → return to menu

**Should have — this project's differentiators:**
- CARIAD car HUD side panel (the entire demo concept — must fire convincingly)
- 3 named hand-crafted rooms (ERBA island / Bamberg Altstadt / Burg Altenburg)
- Element modifier system (Fire / Ice / Earth stacked on role)
- Boss multi-phase with mob swarms between phases
- Loop timer visible to all players
- Automatic driver NPC (no 4th human needed)

**Defer to post-MVP:**
- Elemental combo cross-player interactions (Fire + Ice → Steam area)
- Named room visual identity polish
- Spectator/audience loop timer projection
- Meta-progression, host migration, chat, controller support, inventory

*See [FEATURES.md](FEATURES.md) for full dependency graph and multiplayer sync indicators.*

### Architecture Approach

The game uses three Autoload singletons (Lobby, GameEvents, GameState) that persist across scene changes, plus a Game.tscn root that holds the World (RoomManager + MultiplayerSpawner nodes), a Players container (each Player.tscn owned by its peer), and a HUD CanvasLayer. The host-authoritative split is strict: enemy AI, bullet physics, game timer, upgrade logic, and spawn events run only on the host and replicate outward; clients own only their own player's input and movement. The CARIAD HUD wiring is entirely event-driven — `GameEvents.fire_hud_event.rpc("AC_COLD")` broadcasts from any game system, reaches every peer via `@rpc("call_local")`, and fires a local tween animation on each screen, adding zero extra sync state.

**Major components:**
1. **Lobby (Autoload)** — ENet peer creation/teardown, player registry dict, host-disconnect handler; established first, used by everything else
2. **GameState (Autoload)** — loop timer, loop number, upgrade selections, revive counts; canonical state lives here (host writes, MultiplayerSynchronizer replicates read-only view to clients)
3. **GameEvents (Autoload)** — pure signal bus; game systems emit, HUD listens; signals cross scene boundaries without node reference wiring
4. **MultiplayerSpawner nodes** — one for enemies, one for bullets; all spawnable scene variants pre-registered at build time
5. **Room scenes (TileMap + NavigationRegion2D)** — 3 hand-crafted rooms; collision from TileMap tiles; navmesh baked once in editor; room transitions via `@rpc("call_local")` to move all peers simultaneously

*See [ARCHITECTURE.md](ARCHITECTURE.md) for full scene tree, data flow diagrams, and state machine.*

### Critical Pitfalls

1. **RPC signature mismatch (P1)** — Every `@rpc` function must have identical annotation + signature on both host and client at the same NodePath; one mismatch silently breaks every RPC in the script. Establish RPC conventions in Phase 1; never add `@rpc` to only one branch.

2. **Missing `is_multiplayer_authority()` guards (P3)** — Any host-only system (enemy AI, bullet spawner, GameState timer, upgrade trigger) without this guard runs on all peers, causing divergent state and double-triggered events. Rule: if it changes game state, guard it.

3. **Bullets: do NOT use MultiplayerSynchronizer per-bullet (P5)** — Syncing fast bullet positions per-frame creates lag spikes. Use MultiplayerSpawner to instantiate bullets on clients with initial velocity; clients simulate movement locally; host sends RPC on hit to despawn and apply damage.

4. **Scene spawnable list gaps (P7)** — Every scene variant a MultiplayerSpawner might spawn must be pre-registered. New enemy types added later and not registered spawn on host but are invisible on clients with no error log. Register all scene variants from the start.

5. **GameState must be the single source of truth (P8)** — Upgrades, revive counts, and loop timer stored locally per-client will desync. Clients never write to GameState directly; they RPC to host, host validates and updates, MultiplayerSynchronizer distributes.

*Additional pitfalls: RPC calls before peer connected (P2), NavigationAgent2D running on clients (P6), host disconnect not handled (P9), room transition desync (P10), upgrade cards not broadcast to all clients (P13). See [PITFALLS.md](PITFALLS.md) for full prevention code.*

---

## Implications for Roadmap

Based on combined research, the build order from ARCHITECTURE.md is the correct phase sequence — each phase depends on the previous and can be tested in isolation.

### Phase 1: Lobby + Network Foundation
**Rationale:** Everything in the game depends on a working peer connection. Establishes RPC discipline before any gameplay code exists — the single most effective pitfall prevention.
**Delivers:** Host/Join screen with IP entry, player registry, connection status feedback, host-disconnect handler
**Features:** Host/Join screen, connection feedback, lobby waiting room, host disconnect → game over (FEATURES.md multiplayer table stakes)
**Must avoid:** P1 (RPC signatures), P2 (RPC before peer connected), P9 (host disconnect unhandled)
**Research flag:** Standard pattern — skip research phase

### Phase 2: Player Scene + Sync
**Rationale:** The fundamental LAN loop — a player moving on one machine appearing correctly on another — must be validated before building combat or enemies on top.
**Delivers:** WASD movement, MultiplayerSynchronizer on position/health/downed, player labels, solo testable (1-player mode)
**Features:** WASD movement, visible remote player positions, player name labels
**Must avoid:** P3 (authority guards), P4 (over-syncing — sync position + health only, not velocity), P12 (input authority)
**Research flag:** Standard pattern — skip research phase

### Phase 3: Room + Enemy + Bullet System
**Rationale:** Core combat loop — the gameplay that makes this worth playing. NavigationAgent2D navmesh must bake correctly against TileMap collision, and bullet spawner strategy (Spawner, not per-bullet Synchronizer) must be established before enemy count scales up.
**Delivers:** Room 1 tilemap, enemy chase AI, auto-attack bullets, hit detection, damage + HP sync
**Features:** Room-clearing combat, enemy that chases and attacks, damage feedback
**Must avoid:** P5 (bullet sync strategy), P6 (NavigationAgent2D on clients), P7 (spawner scene list gaps)
**Research flag:** NavigationAgent2D navmesh baking against TileMap may need a quick test-spike — official docs confirm it works but the exact workflow is worth verifying in code

### Phase 4: Health, Downed, Revive
**Rationale:** Co-op contract features — without downed/revive the game has no social tension. Depends on a working HP sync from Phase 3.
**Delivers:** Downed state, revive proximity mechanic, revive progress bar, team wipe → game over
**Features:** Death/downed state, revive mechanic, run ends on team wipe
**Must avoid:** P3 (guard revive validation on host), P12 (revive RPC must route through host, not peer-to-peer)
**Research flag:** Standard pattern — skip research phase

### Phase 5: GameEvents Signal Bus + CARIAD HUD
**Rationale:** The demo's identity feature. Build it after core combat is stable so there are real events to fire. The signal bus architecture is straightforward but must be wired before the roguelike loop adds more event sources.
**Delivers:** GameEvents autoload, CarHUD side panel, 6 indicator states, HUD event broadcast via `@rpc("call_local")`
**Features:** Car HUD side panel (the differentiator), HUD event feedback for all game events
**Must avoid:** P11 (HUD events fired before client connects — gate on `Lobby.all_players_ready`)
**Research flag:** The specific CARIAD indicator states (AC_COLD, ENGINE_OVERHEAT, etc.) and their trigger mapping need a brief design pass — all of the Godot wiring is straightforward, the design is the unknown

### Phase 6: Roguelike Loop (Timer + Upgrades + Difficulty)
**Rationale:** Ties everything together into a repeatable run structure. Depends on combat being fun and the HUD having events to fire.
**Delivers:** Loop timer (all peers synced), upgrade card screen (host generates, all clients show and select), difficulty scalar per loop, loop state machine
**Features:** Loop timer, upgrade cards, difficulty scaling, team shared run state
**Must avoid:** P8 (GameState is single source of truth), P13 (upgrade cards must broadcast to all clients)
**Research flag:** Standard pattern — skip research phase

### Phase 7: Roles + Element System
**Rationale:** Distinct roles are table stakes but depend on a complete combat system to test meaningfully. Element modifiers layer on top of roles — build roles first, then add elements.
**Delivers:** Role select screen (lobby-integrated), Tank/Speedster/Engineer ability sets, Fire/Ice/Earth element modifiers, elemental HUD events
**Features:** Distinct player roles, role lock-in screen, element × role matrix
**Must avoid:** Role abilities that bypass host-authority (abilities that modify enemy state must RPC to host, not run locally)
**Research flag:** Per-role ability design is under-specified — needs a brief design pass before implementation

### Phase 8: Rooms 2 + 3 + Boss
**Rationale:** Final content. Boss multi-phase system is the highest complexity single feature in the project — build it last when all supporting systems are solid.
**Delivers:** Bamberg Altstadt room, Burg Altenburg boss room, boss AI phases, mob swarm waves between phases, room transition flow
**Features:** 3 named rooms, boss encounter, multi-phase boss, mob swarms
**Must avoid:** P10 (room transition desync — `@rpc("call_local")` for all scene changes), P7 (new enemy/boss variants registered in spawner)
**Research flag:** Boss phase design and mob swarm scheduling need a design spike — the Godot implementation is standard but the state machine logic for phases is complex enough to warrant a planning doc

### Phase Ordering Rationale

- **Foundation before combat:** Network must work before there's anything to sync. Wrong order = debugging gameplay on top of broken multiplayer.
- **Combat before loop:** Fun-per-minute must exist before wrapping it in a loop structure. A broken combat loop wrapped in timer + upgrades is still broken.
- **HUD after combat events exist:** CarHUD needs real events to fire; building it before enemies and abilities means testing with stubs, which masks wiring issues.
- **Roles after combat is solid:** Class abilities built on unstable combat will need to be rewritten. Establish the base combat feel first.
- **Boss last:** Highest complexity, lowest risk to critical path. All its dependencies (AI, spawner, room transitions, HP phases) exist by Phase 7.

### Research Flags

**Needs a design spike (not a research phase — these are design decisions, not technical unknowns):**
- **Phase 5:** CARIAD indicator → game event mapping (which 6 states, which triggers)
- **Phase 7:** Per-role ability definitions and element modifier effects
- **Phase 8:** Boss phase state machine and mob wave schedule

**Standard patterns — skip research phase:**
- Phases 1, 2, 4, 6 — all covered by official Godot docs with high confidence

**Worth a quick code spike (30 min, not a full research phase):**
- Phase 3: NavigationAgent2D navmesh baking against TileMap collision in Godot 4.6 — the pattern is documented but the exact editor workflow is worth verifying before committing to it in the build plan

---

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | **HIGH** | Every technology verified against official Godot 4.6 docs; GitHub Releases API confirmed version |
| Features | **HIGH** | Table stakes from genre analysis (6 reference games) + primary source PROJECT.md; multiplayer features from official Godot docs |
| Architecture | **HIGH** | Official docs pattern (high_level_multiplayer tutorial); host-authoritative model is documented and community-validated |
| Pitfalls | **HIGH** | P1/P3/P5/P9/P10 explicitly documented in official Godot docs; P2/P4/P6/P7/P8/P12/P13 from community consensus across multiple sources |

**Overall confidence: HIGH**

### Gaps to Address

- **CARIAD indicator design (Phase 5):** The 6 HUD states are named but their precise trigger conditions and visual behavior are not fully specified. Needs a design decision before Phase 5 implementation — the Godot wiring is clear, the content is not.
- **Role ability specifics (Phase 7):** Tank/Speedster/Engineer are named but ability mechanics (range, cooldown, AoE shape, interaction with elements) are not defined. Need a design pass at Phase 7 planning time.
- **Boss phase thresholds and wave counts (Phase 8):** Multi-phase boss is specified as "2–3 phases" with "mob swarms between phases" — exact counts and wave composition need a design document. Technical implementation is clear.
- **NavigationAgent2D + TileMap navmesh workflow (Phase 3):** The API is confirmed stable but the exact editor baking workflow for 2D TileMap-based rooms is worth validating with a 30-minute spike before committing room geometry.

---

## Sources

### Primary (HIGH confidence)
- Godot 4.6 high_level_multiplayer docs — ENet patterns, RPC modes, lobby flow
- Godot class reference: ENetMultiplayerPeer, MultiplayerSynchronizer, MultiplayerSpawner, NavigationAgent2D, CanvasLayer
- GitHub Releases API — Godot 4.6.2-stable confirmed (2026-04-01)
- PROJECT.md — all project-specific feature requirements

### Secondary (MEDIUM confidence)
- Deep Rock Galactic, Hades, Enter the Gungeon, Risk of Rain 2, Vampire Survivors, Synthetik — genre feature landscape
- Godot community — NavigationAgent2D "experimental" label runtime stability

---

*Research completed: 2026-05-05*
*Ready for roadmap: yes*
