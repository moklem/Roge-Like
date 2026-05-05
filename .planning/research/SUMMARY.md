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

Based on combined research (including WEAPONS_XP.md), the build order from ARCHITECTURE.md is the correct phase sequence.

### Phase 1: Lobby + Network Foundation
**Rationale:** Everything depends on working peer connections. Establishes RPC discipline first.
**Delivers:** Host/Join screen, IP entry, role + element select (two independent picks), player registry, host-disconnect handler
**Must avoid:** P1 (RPC signatures), P2 (RPC before peer connected), P9 (host disconnect unhandled)
**Research flag:** Standard pattern — skip research phase

### Phase 2: Player Scene + Sync
**Rationale:** The fundamental LAN loop must be validated before combat is built on top.
**Delivers:** WASD movement, MultiplayerSynchronizer (position, health, stage, level), player labels, solo testable
**Must avoid:** P3 (authority guards), P4 (over-syncing), P12 (input authority)
**Research flag:** Standard pattern — skip research phase

### Phase 3: Room 1 + Enemy + Combat Core
**Rationale:** Core combat loop including health + downed + revive. All in one phase — these are tightly coupled and testing requires all three to be present.
**Delivers:** Room 1 tilemap, enemy chase AI, starter weapon (screws/bolts), hit detection, health bars, downed state, proximity revive
**Must avoid:** P5 (bullet sync), P6 (NavigationAgent2D on clients), P7 (spawner scene list gaps), P9 (host disconnect handling)
**Research flag:** NavigationAgent2D navmesh baking against TileMap — worth a 30-min code spike

### Phase 4: Weapons + Item Pickups
**Rationale:** Vampire Survivors weapon loop — depends on working enemies that drop items.
**Delivers:** PickupSpawner, car-part drop system, WeaponManager, 5 car-themed weapon scenes, weapon upgrade to level 3
**Must avoid:** W1 (pickup double-collect), W2 (weapon timers fire on clients), P7 (all weapon scenes registered in spawner)
**Research flag:** Weapon system patterns documented in WEAPONS_XP.md — no additional research needed

### Phase 5: XP + Level-Up Cards + Evolution
**Rationale:** The per-player progression loop. Depends on working pickups and enemy deaths from Phase 3+4.
**Delivers:** XP orbs, level threshold system, per-player card selection overlay (non-blocking), 3 stage transformations
**Must avoid:** W3 (card pool empty crash), W4 (card UI blocks all input), W5 (XP sync lag), P8 (GameState as source of truth for shared state; per-player XP lives on Player node)
**Research flag:** Patterns documented in WEAPONS_XP.md — no additional research needed

### Phase 6: CarHUD + Loop Timer + Difficulty Scaling
**Rationale:** The demo's identity. Build after combat events exist so HUD triggers fire from real gameplay.
**Delivers:** GameEvents signal bus, CarHUD side panel, all 6 indicators, V2X auto-timer, 15-min loop timer, difficulty scalar, loop number display
**Must avoid:** P11 (HUD events before peer connected), P8 (loop timer authoritative on host)
**Research flag:** CARIAD indicator → event mapping is designed — no unknowns

### Phase 7: Roles + Elements
**Rationale:** Distinct class feels depend on stable combat. Element modifiers wire into HUD events.
**Delivers:** Tank/Speedster/Engineer ability sets with Stage 2 signature abilities, Fire/Ice/Earth modifiers, elemental HUD triggers
**Must avoid:** Role / element abilities must route through host authority for any enemy-state changes
**Research flag:** Per-role ability definitions need design pass before Phase 7 planning

### Phase 8: Rooms 2 + 3 + Boss
**Rationale:** Final content. Boss phases are highest complexity — build last when all systems stable.
**Delivers:** Bamberg Altstadt room, Burg Altenburg boss arena, multi-phase boss AI, mob swarm waves
**Must avoid:** P10 (room transition desync), P7 (boss/new enemy scenes registered in spawner)
**Research flag:** Boss phase state machine and mob wave schedule need a design pass

### Phase Ordering Rationale

- **Foundation before combat:** Wrong order = debugging gameplay on top of broken multiplayer.
- **Combat + health + revive together (Phase 3):** These are inseparable for a testable build.
- **Weapons before XP:** XP level-up can offer weapon upgrade cards — weapon system must exist first.
- **HUD after combat events exist:** Build CarHUD after enemies fire real events, not stubs.
- **Roles after combat solid:** Class abilities built on unstable combat get rewritten.
- **Boss last:** All its dependencies (AI, spawner, rooms, phases) exist by Phase 7.

### Research Flags

**Needs a design pass (not research — design decisions):**
- Phase 7: Per-role ability definitions, Stage 2 signature abilities, element modifier specs
- Phase 8: Boss phase thresholds, mob wave counts and composition

**Skip research phase (standard Godot patterns):**
- Phases 1, 2, 3 (health/revive part), 6

**Worth a 30-min code spike:**
- Phase 3: NavigationAgent2D navmesh baking against TileMap in Godot 4.6

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
