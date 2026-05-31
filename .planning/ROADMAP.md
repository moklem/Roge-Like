# Roadmap: Roge-Like

**8 phases** | **84 v1 requirements** | **Granularity:** Coarse

---

## Phase Summary

| # | Phase | Goal | Requirements | UI |
|---|-------|------|--------------|-----|
| 1 | Network Foundation & Lobby | Working LAN session — host/join, role+element selection, connection feedback, host-disconnect handling | NET-01–05, LOBB-01–05 | no |
| 2 | Player Movement & Sync | All players see each other moving correctly over LAN; solo-testable | MOVE-01–04 | no |
| 3 | Room 1, Enemy AI, Combat Core | Core combat loop — Room 1 playable, enemies chase and damage players, players can die and be revived | CMBT-01–09, HLTH-01–08 | no |
| 4 | Weapons & Item Pickups | Vampire Survivors weapon loop — enemies drop car-part pickups, player collects to unlock/upgrade weapons | WEAP-01–08 | no |
| 5 | Roles & Elements | Three mechanically distinct roles with Stage-2 signature abilities; Fire/Ice/Earth element modifiers; element actions trigger HUD | ROLE-01–10, ELEM-01–07 | no |
| 6 | XP, Level-Up Cards & Evolution | Per-player progression loop — kill enemies to earn XP, level up triggers card pick, stage transforms appearance and unlocks ability | XP-01–09, EVOL-01–06 | yes |
| 7 | CarHUD, Loop Timer & Difficulty Scaling | CARIAD HUD side panel always visible and firing on game events; 15-min loop timer; difficulty increases per loop | HUD-01–10, LOOP-01–06, HLTH-07 | yes |
| 8 | Rooms 2 & 3, Boss | Full 3-room run playable end-to-end; boss with multiple attack phases and mob swarms | ROOM-01–07 | no |

---

## Phase Details

### Phase 1: Network Foundation & Lobby

**Goal:** Working LAN session — host/join, role+element selection, connection feedback, host-disconnect handling
**UI hint:** no

**Requirements:**
- NET-01: Host can create a LAN session; their IP is displayed for others to enter
- NET-02: Client can join by entering the host's IP address
- NET-03: Connection status is visible during join (connecting / failed / success)
- NET-04: Host disconnect immediately ends the session for all clients with a "Host Left" screen
- NET-05: Game supports 1–3 players (solo host usable without additional machines)
- LOBB-01: Player picks one of 3 roles (Tank, Speedster, Engineer) before game starts
- LOBB-02: Roles are exclusive — a role chosen by one player is locked for others
- LOBB-03: Player independently picks one element (Fire, Ice, Earth) — separate from role
- LOBB-04: All players see every other player's confirmed role + element before game starts
- LOBB-05: Host can start the game once at least 1 player is in the lobby

**Success Criteria:**
1. Host creates session; clients see and join via IP within 30 seconds
2. Role + element selections visible to all players before start; no duplicates allowed
3. Host closing the game immediately shows "Host Left" on all client screens

**Pitfall watch:**
- P1 (RPC signature mismatch) — establish RPC discipline here before any gameplay code; one mismatch breaks all RPCs in a script silently
- P2 (RPC before peer connected) — gate all initial state broadcasts on `peer_connected` signal, never in `_ready()`
- P9 (host disconnect unhandled) — wire `peer_disconnected(1)` → scene change in `Lobby` autoload and test explicitly in this phase

---

### Phase 2: Player Movement & Sync

**Goal:** All players see each other moving correctly over LAN; solo-testable
**UI hint:** no

**Requirements:**
- MOVE-01: Each player moves with WASD in top-down view
- MOVE-02: Player positions are visible on all connected clients in real time
- MOVE-03: Players cannot walk through room walls
- MOVE-04: Each player's role label is visible above their character

**Success Criteria:**
1. Player moves on one laptop; position updates visibly on all other laptops in real time
2. Players cannot walk through room walls
3. Solo host (1 player) can launch and navigate without errors

**Pitfall watch:**
- P3 (missing authority guards) — all Player `_physics_process` movement and input handling must check `is_multiplayer_authority()` before acting
- P4 (over-syncing) — MultiplayerSynchronizer interval set to 0.05s (20 Hz); only sync `position`, `health`, `is_downed`; never sync velocity or animation state
- P7 (spawnable list gaps) — register all player scene variants in MultiplayerSpawner from the start; add comment listing registered scenes
- P12 (input authority) — only the owning peer handles its player's input; never expose `take_damage` as a client-callable RPC

**Plans:** 2 plans

Plans:
- [x] 02-01-PLAN.md — Player scene with WASD movement, wall collision, MultiplayerSynchronizer, Game room wiring
- [x] 02-02-PLAN.md — Role label rendering, host-authoritative player spawning across all peers

Wave 1 *(autonomous)*
- 02-01: Player.tscn + Player.gd (movement + collision + sync), Game.tscn (room + spawn points)

Wave 2 *(blocked on Wave 1 — depends on Player scene existing)*
- 02-02: RoleLabel on Player, Game.gd host-only spawn logic, MultiplayerSpawner registration

---

### Phase 3: Room 1, Enemy AI, Combat Core

**Goal:** Core combat loop working — Room 1 playable, enemies chase and damage players, players can die and be revived
**UI hint:** no

**Requirements:**
- CMBT-01: At least one basic enemy type chases and attacks the nearest player
- CMBT-02: Enemy pathfinds around room walls (does not walk through obstacles)
- CMBT-03: Enemies are spawned and controlled by the host; clients see the synced result
- CMBT-04: Starter weapon: screws and bolts fly outward automatically from the player
- CMBT-05: Bullets/projectiles despawn on enemy or wall contact
- CMBT-06: Bullet hits apply damage to the struck enemy (host-authoritative)
- CMBT-07: Enemy death removes the enemy from all clients simultaneously
- CMBT-08: Enemy death drops an XP orb pickup at the enemy's position
- CMBT-09: Player walking over XP orb collects it; orb despawns from all clients
- HLTH-01: Each player has a visible health bar shown to all players
- HLTH-02: Enemies deal damage to players on contact or projectile hit
- HLTH-03: Player health is synced to all clients in real time
- HLTH-04: Player reaching 0 HP enters a downed state (cannot act, visible downed indicator)
- HLTH-05: A teammate can walk near a downed player and hold a key to revive them
- HLTH-06: Revive has a visible hold-progress bar (not instant)
- HLTH-08: If all players are simultaneously downed, the run ends (game over)

**Success Criteria:**
1. Enemy chases nearest player around walls; players can kill it with auto-attack (screws/bolts)
2. Player reaches 0 HP → enters downed state; teammate revives with hold key
3. All players downed simultaneously → "Game Over" screen on all clients

**Pitfall watch:**
- P5 (bullet sync) — use MultiplayerSpawner for bullet instantiation + initial velocity; clients simulate locally; host sends RPC on hit to despawn and apply damage; do NOT add MultiplayerSynchronizer per bullet
- P6 (NavigationAgent2D on clients) — set `set_physics_process(is_multiplayer_authority())` on enemy `_ready()`; only host calls `navigation_agent.target_position`; clients render synced position only
- P7 (spawnable list gaps) — enemy and XP orb scenes must be pre-registered in spawner before testing; add to list now even if only one type exists
- Navmesh spike — validate NavigationAgent2D navmesh baking against TileMap in Godot 4.6 with a 30-minute code spike before committing room geometry

**Plans:** 5 plans

Plans:
- [x] 03-01-PLAN.md — Navmesh spike: central obstacle + enemy spawn points + NavigationPolygon bake (checkpoint)
- [x] 03-02-PLAN.md — Enemy.tscn + Enemy.gd + XpOrb.tscn + XpOrb.gd (new combat scenes)
- [x] 03-03-PLAN.md — Player health + downed state machine + revive input + GameOver scene
- [x] 03-04-PLAN.md — Bullet.tscn + Bullet.gd + Player auto-fire wiring
- [x] 03-05-PLAN.md — Game.gd/Game.tscn spawner wiring + GameState game-over detection

---

### Phase 4: Weapons & Item Pickups

**Goal:** Vampire Survivors weapon loop — enemies drop car-part pickups, player collects to unlock weapons; 5 car-themed weapons implemented; WeaponManager is child of Player. Phase 4 = unlock only (Level 1); upgrades come in Phase 6.
**UI hint:** no

**Requirements:**
- WEAP-01: Enemies occasionally drop a car-part item pickup on death (random chance)
- WEAP-02: Player walking over an item pickup collects it; triggers weapon unlock or upgrade
- WEAP-03: Collecting a new car-part unlocks the corresponding weapon (added to WeaponManager)
- WEAP-04: Active weapons fire automatically on independent cooldown timers
- WEAP-05: Player can hold up to 6 active weapons simultaneously
- WEAP-06: Minimum weapon set includes at least 5 car-themed weapons:
  - WEAP-06a: Exhaust Flames — fire cone behind the player
  - WEAP-06b: Spinning Tires — orbiting projectiles that deflect enemies
  - WEAP-06c: Antenna Beam — long-range piercing laser
  - WEAP-06d: Horn Shockwave — close-range area burst
  - WEAP-06e: Airbag Shield — brief damage-absorbing shell
- WEAP-07: Each weapon can be upgraded to level 3 (via card picks); each level improves damage, speed, or area
- WEAP-08: All active weapons and their levels reset on death

**Success Criteria:**
1. Enemy death occasionally drops a car-part pickup visible on all clients
2. Player collecting pickup unlocks the corresponding weapon which begins firing automatically
3. Player can have at least 3 different active weapons firing simultaneously on independent timers

**Pitfall watch:**
- W1 (pickup double-collect) — pickup collection must be host-authoritative; client sends RPC to host, host validates and despawns; never let clients despawn pickups locally
- W2 (weapon timers fire on clients) — weapon `fire()` method must guard with authority check; timers run on all peers but only host executes the actual spawn logic
- P7 (spawnable list gaps) — all 5 weapon projectile scenes and all car-part pickup scenes must be pre-registered in MultiplayerSpawner before testing any of them
- P8 (GameState not authoritative) — weapon loadout changes must flow through host; client sends pick selection RPC to host, host confirms and broadcasts loadout update to all peers

**Plans:** 5 plans

Plans:
- [x] 04-01-PLAN.md — CarPartPickup scene + PickupSpawner wiring + Game.gd 25% drop branch
- [x] 04-02-PLAN.md — WeaponManager scaffold + ScrewsAndBolts migration + Player.gd refactor + airbag interception
- [x] 04-03-PLAN.md — ExhaustFlames + SpinningTires weapons + WeaponManager activation dispatch
- [x] 04-04-PLAN.md — AntennaBeam + HornShockwave weapons (parallel to Plan 03)
- [x] 04-05-PLAN.md — AirbagShield visual ring + GameState game-over reset integration

Wave 1 *(autonomous)*
- 04-01: CarPartPickup.tscn + CarPartPickup.gd + Game.gd pickup drop + weapon_unlocked RPC

Wave 2 *(blocked on Wave 1 — weapon_unlocked RPC must exist)*
- 04-02: WeaponManager.gd + Player.tscn + Player.gd refactor + airbag receive_damage

Wave 3 *(parallel — blocked on Wave 2, no file overlap between 03 and 04)*
- 04-03: ExhaustFlames.gd + SpinningTires.gd + WeaponManager _activate_weapon_node (exhaust, tires)
- 04-04: AntennaBeam.gd + HornShockwave.gd + WeaponManager dispatch (antenna, shockwave)

Wave 4 *(blocked on Wave 3 — WeaponManager _activate_weapon_node must be fully wired)*
- 04-05: AirbagShield.gd + WeaponManager airbag wiring + GameState._broadcast_game_over reset

---

### Phase 5: Roles & Elements

**Goal:** Three mechanically distinct roles with Stage-2 signature abilities; Fire/Ice/Earth element modifiers; element actions trigger HUD
**UI hint:** no

**Requirements:**
- ROLE-01: Tank has noticeably higher max HP than other roles
- ROLE-02: Tank has a melee aura ability that damages nearby enemies
- ROLE-03: Tank's Stage 2 signature ability: sustained aura burst (larger radius, short duration)
- ROLE-04: Speedster moves faster than other roles
- ROLE-05: Speedster has a dash ability (brief burst of speed / invincibility frames)
- ROLE-06: Speedster's Stage 2 signature ability: afterimage dash (leaves damaging trail)
- ROLE-07: Engineer has a passive heal that periodically restores HP to nearby teammates
- ROLE-08: Engineer deploys a drone that targets nearby enemies
- ROLE-09: Engineer's Stage 2 signature ability: repair pulse (burst heal to all teammates)
- ROLE-10: Each role feels mechanically distinct in a 3-player session
- ELEM-01: Fire element adds a burn damage-over-time effect to enemies hit by the player
- ELEM-02: Fire element has a periodic area ring that damages enemies in range
- ELEM-03: Ice element applies a slow effect to enemies hit by the player
- ELEM-04: Ice element periodically creates a ground trail that blocks / slows enemy movement
- ELEM-05: Earth element provides passive healing per second to the whole team
- ELEM-06: Earth element has a shockwave ability that pushes enemies back
- ELEM-07: Element abilities trigger the appropriate CARIAD HUD indicator when activated

**Success Criteria:**
1. Tank, Speedster, and Engineer feel distinctly different to play in a 3-player session
2. Every element modifier produces a visible gameplay effect (burn DOT, enemy slow, team heal)
3. Using an elemental ability fires the correct CARIAD HUD indicator on all screens

**Pitfall watch:**
- P3 (authority guards) — all role ability logic that changes game state (aura damage, heal pulses, drone targeting) must be host-authoritative; ability input captured on owning client, sent to host via RPC, host executes and syncs result
- P12 (input authority) — ability activation RPC must route client input → host validation → broadcast result; never let clients apply ability effects directly
- Design pass required — per-role ability specs (range, cooldown, AoE shape), Stage 2 signature mechanics, and element modifier tuning need a design document before planning this phase

---

### Phase 6: XP, Level-Up Cards & Evolution

**Goal:** Per-player progression loop — kill enemies to earn XP, level up triggers card pick, stage transforms appearance and unlocks ability
**UI hint:** yes

**Requirements:**
- XP-01: Collecting XP orbs fills a visible XP bar on the player's HUD
- XP-02: On level-up, a card selection overlay appears for that player
- XP-03: Card selection shows 3 random cards drawn from an eligible pool
- XP-04: Card types include: weapon unlock, weapon upgrade (level 1→2→3), element upgrade, stat boost (speed / max HP / damage / cooldown reduction)
- XP-05: Card pool is filtered: weapon unlock cards removed if player already has that weapon; upgrade cards removed if weapon is at max level
- XP-06: A fallback card is always available (e.g., +10% damage) so the pool never runs dry
- XP-07: Card selection is per-player and non-blocking — other players continue playing during one player's card pick
- XP-08: Selected cards take effect immediately and stack for the rest of the session
- XP-09: Level number is visible on the player's screen
- EVOL-01: Every player starts Stage 1 (Normal Car) — moves and fights like a car, basic attacks, starter stats
- EVOL-02: Reaching Stage 2 XP threshold triggers full transformation to Proto-Bot — now moves and fights like a robot; raw skeletal appearance (no armor, exposed parts); one new signature ability unlocked
- EVOL-03: Reaching Stage 3 XP threshold transforms to Full AutoBot — same robot movement as Stage 2, but fully armored and complete; all abilities active, max power (Stage 2→3 difference is visual completeness and strength, not locomotion)
- EVOL-04: Stage is visible on the player's own and teammates' characters
- EVOL-05: Stage thresholds are the same for all roles (universal arc)
- EVOL-06: Stage resets to 1 (Normal Car) at the start of each new run

**Success Criteria:**
1. Killing enemies fills the XP bar; bar completing opens a 3-card selection overlay for that player while others continue playing
2. Selecting a card immediately applies the effect (new weapon fires, stat increases, element upgrades)
3. Reaching Stage 2 XP threshold transforms the player into a robot (locomotion and combat style change); Stage 3 keeps robot movement but adds full armor and unlocks all abilities

**Pitfall watch:**
- W3 (card pool empty crash) — always ensure at least one fallback card (+10% damage) exists; test edge case where player has all weapons at max level
- W4 (card UI blocks all input) — card overlay is local UI only; it must NOT pause `SceneTree` or block other players' `_process`; use `CanvasLayer` with local show/hide
- W5 (XP sync lag) — per-player XP lives on Player node synced via MultiplayerSynchronizer; level-up trigger fires via `@rpc("call_local")` from host to avoid double-triggering
- P8 (GameState not authoritative) — XP totals and level thresholds authoritative on host; card selection sent to host via RPC, host validates and broadcasts confirmed card effect

---

### Phase 7: CarHUD, Loop Timer & Difficulty Scaling

**Goal:** CARIAD HUD side panel always visible and firing on game events; 15-min loop timer; difficulty increases per loop
**UI hint:** yes

**Requirements:**
- HUD-01: A Car HUD side panel is always visible on all players' screens during gameplay
- HUD-02: Panel contains labeled indicator boxes: AC, ENGINE, SEAT MASSAGE, SUSPENSION, LIDAR, V2X
- HUD-03: Ice ability used → "AC ❄️ COLD" lights up on all screens
- HUD-04: Fire ability used → "ENGINE 🔥 OVERHEAT" lights up on all screens
- HUD-05: Earth healing active → "SEAT MASSAGE 🌿 ACTIVE" lights up on all screens
- HUD-06: Any player takes a significant hit → "SUSPENSION ⚡ IMPACT" lights up on all screens
- HUD-07: Enemy spawns in the current room → "LIDAR 🔴 OBJECT DETECTED" lights up on all screens
- HUD-08: Random interval auto-trigger → "V2X 📡 SIGNAL SENT" lights up on all screens
- HUD-09: Each indicator fades out after a few seconds (not permanently lit)
- HUD-10: HUD event broadcasts via RPC — all clients see the same indicator fire simultaneously
- LOOP-01: A visible 15-minute countdown timer is shown on all players' screens
- LOOP-02: After the current room is cleared, all players transition to the next room simultaneously
- LOOP-03: Run ends when the boss is defeated or the timer expires — next loop starts, harder
- LOOP-04: Each successive loop increases enemy HP, damage, and spawn density
- LOOP-05: Loop number is visible to all players
- LOOP-06: Weapons, XP level, and evolution stage carry over between rooms within a session; reset only on full death (team wipe)
- HLTH-07: Each player may be revived at most once per 15-minute loop; counter resets at loop end

**Success Criteria:**
1. Each of the 6 HUD indicators (AC, ENGINE, SEAT MASSAGE, SUSPENSION, LIDAR, V2X) lights up on its trigger event on all screens simultaneously
2. 15-minute timer counts down and is visible to all players; loop ends and next loop starts harder
3. Second loop visibly has more enemies with higher HP than first loop

**Pitfall watch:**
- P11 (HUD events before client connects) — gate `GameEvents` HUD RPCs behind `Lobby.all_players_ready`; V2X auto-timer starts only after Game.tscn fully loaded on all peers
- P8 (loop timer not authoritative) — loop timer lives in `GameState` autoload, host is sole writer; MultiplayerSynchronizer distributes read-only view; clients never tick the timer locally
- P10 (room transition desync) — LOOP-02 room clear transition must use `@rpc("call_local", "reliable")` so all peers change scene in the same call; host waits one frame before spawning next room enemies

---

### Phase 8: Rooms 2 & 3, Boss

**Goal:** Full 3-room run playable end-to-end; boss with multiple attack phases and mob swarms
**UI hint:** no

**Requirements:**
- ROOM-01: Room 1 (ERBA) — open, wide space; tutorial-level enemy density; teaches movement + combat
- ROOM-02: Room 2 (Bamberg Altstadt) — narrow corridors; higher enemy density; punishes clustering
- ROOM-03: Room 3 (Burg Altenburg) — large arena; boss fight
- ROOM-04: Boss has at least 2 distinct attack phases with different behavior per phase
- ROOM-05: Random mob swarms spawn between boss attack phases (harder each loop)
- ROOM-06: Enemy or mob spawns during boss fight trigger LIDAR HUD indicator
- ROOM-07: All room transitions are simultaneous across all clients

**Success Criteria:**
1. Full run navigates Room 1 → Room 2 → Room 3/Boss with all clients transitioning simultaneously
2. Boss enters at least 2 distinct attack phases with different behavior; mob swarms spawn between phases
3. Defeating the boss ends the loop; next loop starts from Room 1 with higher difficulty

**Pitfall watch:**
- P10 (room transition desync) — all transitions use `@rpc("call_local", "reliable")`; Room 2 transition tested with 2 players before Room 3 is built
- P7 (spawnable list gaps) — boss scene, boss projectile variants, and all mob swarm enemy types must be pre-registered in MultiplayerSpawner before boss fight is testable
- Design pass required — boss phase thresholds, HP values per loop, mob wave counts and composition need a design document before planning this phase
- ROOM-01 note — ERBA room geometry established in Phase 3; Phase 8 finalises density tuning and confirms it fits the full run flow

---

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Network Foundation & Lobby | 2/2 | Complete | 2026-05-09 |
| 2. Player Movement & Sync | 2/2 | Complete | 2026-05-09 |
| 3. Room 1, Enemy AI, Combat Core | 5/5 | Complete | 2026-05-09 |
| 4. Weapons & Item Pickups | 5/5 | Complete | 2026-05-31 |
| 5. Roles & Elements | 0/? | Not started | — |
| 6. XP, Level-Up Cards & Evolution | 0/? | Not started | — |
| 7. CarHUD, Loop Timer & Difficulty Scaling | 0/? | Not started | — |
| 8. Rooms 2 & 3, Boss | 0/? | Not started | — |
