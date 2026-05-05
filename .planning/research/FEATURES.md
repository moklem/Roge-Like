# Feature Landscape — Co-op Top-Down LAN Roguelike

**Project:** Roge-Like (CARIAD university demo)
**Domain:** Co-op top-down action roguelike with LAN multiplayer
**Researched:** 2026-05-05
**Confidence:** HIGH — core roguelike and Godot multiplayer patterns verified via official docs and established genre references (Hades, Deep Rock Galactic, Risk of Rain 2, Enter the Gungeon, Vampire Survivors)

---

## Reference Games

The following well-regarded co-op roguelikes inform this feature landscape:

| Game | Relevance to This Project |
|------|---------------------------|
| **Deep Rock Galactic** | 4-class asymmetric co-op, all-or-nothing host evac, class lock-in per mission, revive mechanic |
| **Risk of Rain 2** | Top-down→3D scaling, looping runs, difficulty ramps over time, shared loot economy |
| **Enter the Gungeon** | Top-down co-op, simultaneous revive mechanic, role parity (no forced asymmetry), room clearing |
| **Vampire Survivors** | Single-session scaling, mob density as difficulty, timer-loop structure, minimal UI |
| **Hades** | Boss phase design, per-run card upgrades (Boons), clean run-reset without meta-progression loss |
| **Synthetik** | Top-down host-authoritative co-op, HP sharing variants, elemental synergies |

---

## Table Stakes

Features players expect from a co-op top-down roguelike. Missing = product feels broken or incomplete.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| **WASD top-down movement** | Genre standard — anything else is jarring | Low | All players move independently; no camera coupling between players |
| **Visible health bars for all players** | Core readability — how is my teammate doing? | Low | Requires syncing HP values across peers; label with role name |
| **Room-clearing combat with auto-attack** | Core loop — kill, progress, repeat | Med | Host-authoritative bullets; clients see visual result via sync |
| **Distinct player roles with different abilities** | Co-op only works if roles complement each other (DRG's Gunner/Scout/Driller/Engineer model) | Med | Tank, Speedster, Engineer already specified |
| **Role lock-in screen before game starts** | Co-op contract — you pick a role, you keep it; prevents duplicate role confusion | Med | Lobby screen; roles greyed out once taken; host starts game when all ready |
| **Enemy that chases and attacks** | Basic threat pressure; without it there's nothing to co-op against | Med | Chase nearest player; host simulates AI, broadcasts position/action to clients |
| **Damage feedback (hit flash, HP drop)** | Essential game feel — did I hit that? Am I dying? | Low | Both visual (flash) and numerical (HP bar update) |
| **Death / downed state** | Players expect consequence without instant game-over; downed-not-dead is genre standard | Med | Crawling, begging for revive; revive window creates co-op tension |
| **Revive mechanic** | Core co-op tension loop (seen in every co-op roguelike) | Med | Proximity check + hold-to-revive; depends on downed state |
| **Run ends on team wipe** | The roguelike contract: failure = restart | Low | Trigger when all players dead simultaneously; broadcast to all clients |
| **Post-death upgrade screen** | Mandatory roguelike loop beat: die → pick upgrade → try again | Med | Card-pick UI; one of 3 random upgrades; upgrade applies to next loop |
| **Upgrades stack per session, reset on death** | Roguelite feel; no meta-progression = clean classic roguelike | Low | In-memory only; no disk persistence |
| **Difficulty scales each loop** | Run must get harder or becomes trivially easy after upgrades accumulate | Low | Scalar on enemy HP/damage/density; increases each loop iteration |
| **A boss encounter** | Genre expectation: skill check at end of area | High | Boss with multiple phases; mixing patterns |

---

## Multiplayer-Specific Table Stakes

Features that are *specifically* expected from LAN multiplayer — not present in singleplayer equivalents.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| **Host/Join screen with IP entry** | LAN multiplayer has no matchmaking; manual IP is the only option; users expect a clear flow | Low | Host shows IP visually; client enters IP string; join button; error state on failure |
| **Connection status feedback** | "Is it connecting?" — without feedback, users just stare and wonder | Low | Connecting → Connected → Failed states; server_disconnected signal available in Godot |
| **Lobby waiting room** | Players need to see who's connected before starting | Low | Lists connected players + their chosen role; host sees "Start Game" button |
| **Host disconnect = game over for all** | Expected behavior when there's no host migration | Low | `server_disconnected` signal → show "Host Left" overlay → return to main menu |
| **Player name labels** | Tells teammates who is who in a chaotic fight | Low | Display over player characters; synced at lobby join via RPC |
| **Solo testable (1-player mode)** | Dev team needs to test without 3 machines | Low | Host-only mode; all multiplayer code paths present, just 0 remote peers |
| **Visible remote player positions** | Fundamental sync requirement — you have to see where teammates are | Med | MultiplayerSynchronizer on position, rotation, animation state |
| **Team shared run state** | All players on same loop number, same upgrade pool available | Low | Canonical state lives on host; broadcast at scene transitions |

---

## Differentiators

Features that make this specific game interesting and novel vs. a generic co-op roguelike. These are this project's identity features.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| **Car HUD side panel (CARIAD integration)** | The entire demo concept — gameplay events fire vehicle sensor indicators in real time; nothing else in the room does this | High | Always-visible panel; event bus pattern; 6 distinct HUD states specified; this must fire convincingly on every significant event |
| **Element × Role matrix (3×3 combinations)** | Same Tank played as Fire vs Ice is a different experience; adds replayability without content cost | Med | Fire/Ice/Earth are independent picks from role; visual and ability effects differ; UI needs to show both picks |
| **Named rooms with physical-world themes** | ERBA / Bamberg Altstadt / Burg Altenburg rooms ground the game in a real place — unusual for roguelikes | Med | Hand-crafted layouts with distinct geometry that reflects real locations (open island, tight corridors, castle arena) |
| **Automatic driver NPC** | Unique framing: your car is driving itself, you are combat units protecting/responding to it | Low | NPC character on screen that reacts; no extra laptop needed; fires HUD events automatically |
| **Boss multi-phase with mob swarms between phases** | More interesting than a health-bar sponge; creates rhythm of "survive the swarm, then deal with the boss" | High | Phase 1 → mob wave → Phase 2 → mob wave → Phase 3 |
| **Elemental combo effects** | Fire+Ice = Steam area, Ice+Earth = Frozen shockwave — team has to coordinate elements | High | Cross-player element interactions; requires tracking elemental state on enemies |
| **Loop timer + run clock visible to all** | Real-time tension; 15-minute loops make runs feel bounded and presentable to a demo audience | Low | Shared timer shown to all clients; loop reset synced from host |

---

## Anti-Features

Things to explicitly **not build** in the demo/prototype. Time spent on these is time not spent on the CARIAD HUD or core combat loop.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| **Meta-progression (unlocks across sessions)** | Requires save system, unlock gating, and balance passes across multiple sessions — scope creep for a demo | Upgrades only within a single session; full reset on death is explicitly correct here |
| **Host migration** | Godot ENet host migration requires re-electing a new peer as authority, re-spawning all authoritative entities, and resyncing all game state — prohibitive complexity for a demo | Host disconnect = game over; show a "Host Left" screen and return to lobby |
| **Chat / voice / text communication** | Demo is played in person at a table; teammates can just talk to each other | None needed; proximity revive and shared HUD events provide implicit communication |
| **Random level generation** | 3 hand-crafted rooms is already specified and correct for a demo; proc-gen adds art budget and level quality control issues | Static hand-crafted rooms; variety comes from enemy scaling and upgrades |
| **Tutorial / onboarding screens** | Demo is played with a human facilitator present; inline tooltips are sufficient | Role descriptions in the character select screen; elemental icons are self-evident |
| **Controller / gamepad support** | Out of scope; keyboard-only; controllers add input binding complexity and "are we testing keyboard or controller?" confusion | WASD + mouse only |
| **Custom sprites / animations** | Art polish is not the demo goal; placeholder colored shapes convey enough | Colored geometric shapes; labels and HUD carry the demo's identity |
| **Inventory management / item picking** | Deep progression systems don't fit a 15-minute demo loop; they slow down the pace | Card upgrades at loop end only; no mid-run item menu |
| **Difficulty settings slider** | Difficulty ramps automatically by loop number; manual slider adds design decisions | Per-loop scaling is sufficient and automatic |
| **Leaderboards / scoring** | No persistent state, no online infrastructure | Not needed for LAN demo |
| **4th human player slot for Driver** | Only 3 laptops available; Driver is NPC | NPC auto-driver already specified |

---

## Multiplayer-Specific Features (Detailed)

### Lobby & Connection Flow

```
Main Menu
  ├── Host Game → shows local IP → creates ENet server → enters lobby
  └── Join Game → IP input field → connect button → enters lobby (or shows error)

Lobby Screen (all players see)
  ├── Player list: [Slot 1: Tank ✓] [Slot 2: Speedster ✓] [Slot 3: Empty]
  ├── Role selection: click to claim a role (greyed out once taken)
  ├── Host sees: [Start Game] button (enabled when ≥1 player ready)
  └── All clients see: "Waiting for host to start..."

In-Game
  ├── Player labels (name/role) above each character
  ├── Shared loop timer (top of screen)
  ├── All player HP bars in HUD
  └── Car HUD panel (always visible, right side)

Disconnect Events
  ├── Client disconnects → other players see "[Name] disconnected" toast
  └── Host disconnects → all clients see "Host Left" overlay → return to menu
```

| Multiplayer Feature | Complexity | Godot Implementation Pattern |
|--------------------|------------|------------------------------|
| Host/Join with IP entry | Low | `ENetMultiplayerPeer.create_server()` / `create_client()` |
| Connection error feedback | Low | `multiplayer.connection_failed` signal |
| Lobby player list sync | Low | `@rpc("any_peer")` to register player info on connect |
| Role selection + lock | Med | Server validates no duplicate roles; broadcasts locked state |
| Scene change (start game) | Low | `@rpc("call_local", "reliable") func load_game(path)` |
| Player position sync | Med | `MultiplayerSynchronizer` on position + rotation |
| Enemy position sync (host auth) | Med | Enemy nodes set authority to host (peer 1); sync to clients |
| Bullet/hit sync | Med | RPC from host to all clients announcing hit events |
| HP bar updates | Low | `MultiplayerSynchronizer` on HP float |
| Downed state sync | Low | `@rpc` to broadcast downed → triggers client-side overlay |
| Revive sync | Low | Host validates proximity + hold time; broadcasts revive complete |
| Upgrade card pick sync | Low | Host broadcasts chosen upgrade; all clients apply |
| HUD event broadcast | Low | `@rpc("call_local")` from host; all clients fire HUD indicator |
| Host disconnect handling | Low | `multiplayer.server_disconnected` signal |

### Sync Indicators (What the Player Sees)

| Event | Visual Feedback | Network Source |
|-------|-----------------|----------------|
| Teammate takes damage | Their HP bar drops + hit flash | Host → RPC to all clients |
| Teammate downed | "DOWNED" label over them + pulsing overlay | Host → RPC broadcasts state |
| Revive in progress | Progress bar appears above downed player | Client holds key → sends RPC to host → host validates → broadcasts progress |
| Enemy spawns | Spawn animation + LIDAR HUD indicator | Host fires spawn event → RPC to all |
| Boss phase change | Boss health threshold crossed → roar animation | Host broadcasts phase change |
| Loop ends | Timer runs out → host triggers upgrade screen | Host → RPC loads upgrade scene |
| Host disconnects | "Host Left" modal overlay | `server_disconnected` signal |
| Join failed | "Could not connect" error label | `connection_failed` signal |

---

## Feature Dependencies

```
WASD Movement
  └─→ Player Position Sync (requires movement to exist)
      └─→ Player Label Display (needs to follow position)

Role Selection Screen
  └─→ In-Game Role Abilities (Tank/Speedster/Engineer logic)
      └─→ Element Modifier System (stacks on top of role ability)
          └─→ HUD Events (elemental abilities fire HUD indicators)

ENet Host/Join Flow
  └─→ Lobby Screen (needs connection established)
      └─→ Role Selection Lock (needs player registry)
          └─→ Game Start RPC (host triggers after all ready)

Enemy AI (host only)
  └─→ Enemy Position Sync → client visual
  └─→ Bullet/Collision → damage calculation (host only)
      └─→ HP sync to clients
          └─→ Downed State
              └─→ Revive System (proximity + hold)

Boss Encounter
  └─→ Phase System (requires health threshold tracking)
      └─→ Mob Swarm Waves (waves spawn between phases)
          └─→ HUD V2X/LIDAR indicators (swarms trigger HUD)

Loop Timer
  └─→ Upgrade Card Screen (timer expiry triggers this)
      └─→ Difficulty Scaling (each completed loop increments scalar)
```

---

## MVP Recommendation

For the CARIAD university demo, prioritize this order:

**Phase 1 — Core Combat (validate that the game is fun at all)**
1. WASD movement for all players (host + clients)
2. Auto-attack / bullet system with damage
3. Basic enemy that chases and attacks
4. HP bars for all players (synced)
5. Death / run-end condition

**Phase 2 — Multiplayer Infrastructure**
6. Host/Join screen with IP entry
7. Role selection lobby
8. Player position + HP sync
9. Enemy sync (host authoritative)
10. Host disconnect = game over

**Phase 3 — Roguelike Loop**
11. Downed + revive system
12. Loop timer + upgrade card screen
13. Difficulty scaling per loop
14. 3 distinct rooms (hand-crafted)

**Phase 4 — CARIAD Hook + Boss**
15. Car HUD side panel + event bus
16. Boss with 2–3 phases + mob swarms
17. All HUD events connected to game events
18. Element system + elemental HUD events

**Defer to post-MVP (if time permits):**
- Elemental combo cross-player interactions (Fire + Ice → Steam)
- Named room visual identity polish
- Loop timer shown on spectator/audience projection

---

## Sources

| Source | Confidence | Used For |
|--------|------------|----------|
| Godot 4 docs — `high_level_multiplayer.rst` | HIGH (official) | ENet patterns, RPC modes, lobby implementation |
| Godot 4 docs — `MultiplayerSynchronizer` class | HIGH (official) | Position/HP sync patterns |
| Hades (2020, Supergiant Games) — Wikipedia | HIGH (verifiable) | Boss phase design, per-run upgrade cards, run-reset loop |
| Deep Rock Galactic (2020, Ghost Ship Games) — PC Gamer review | MEDIUM (review) | Asymmetric class co-op, revive mechanic, solo testability (Bosco analogy) |
| Enter the Gungeon, Vampire Survivors, Risk of Rain 2 | MEDIUM (training data) | Genre table stakes for co-op top-down roguelikes |
| PROJECT.md (feature requirements) | HIGH (primary source) | All specific feature descriptions tied directly to project spec |
