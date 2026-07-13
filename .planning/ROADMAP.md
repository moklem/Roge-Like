# Roadmap: Roge-Like

**11 phases** | **84 v1 requirements + 30 v1.1 requirements** | **Granularity:** Coarse

---

## Phase Summary

| # | Phase | Goal | Requirements | UI |
|---|-------|------|--------------|-----|
| 1 | Network Foundation & Lobby | Working LAN session — host/join, role+element selection, connection feedback, host-disconnect handling | NET-01–05, LOBB-01–05 | no |
| 2 | Player Movement & Sync | All players see each other moving correctly over LAN; solo-testable | MOVE-01–04 | no |
| 3 | Room 1, Enemy AI, Combat Core | Core combat loop — Room 1 playable, enemies chase and damage players, players can die and be revived | CMBT-01–09, HLTH-01–08 | no |
| 4 | Weapons & Item Pickups | Vampire Survivors weapon loop — enemies drop car-part pickups, player collects to unlock/upgrade weapons | WEAP-01–08 | no |
| 5 | Roles & Elements | 5/5 | Complete   | 2026-06-15 |
| 6 | XP, Level-Up Cards & Evolution | Per-player progression loop — kill enemies to earn XP, level up triggers card pick, stage transforms appearance and unlocks ability | XP-01–09, EVOL-01–06 | yes |
| 7 | CarHUD, Loop Timer & Difficulty Scaling | 3/3 | Complete    | 2026-06-19 |
| 8 | Rooms 2 & 3, Boss | 3/3 | Complete   | 2026-06-22 |
| 9 | Map Overhaul — TileMap Sub-Rooms | 3/4 | In Progress|  |
| 10 | Juicy Feedback — Visual & Gameplay Polish | 11/12 | In Progress|  |
| 11 | Whole-Game Sound Design Pass & Soak-Test Validation | Full sound pass across the entire game (not just Phase 10 juice — most existing actions are currently silent); audio assets depend on human input from the team, this phase wires the trigger-point plumbing; full-loop soak test and multi-peer swarm playtest validate no leaks/no readability breakdown | SFX-01–03 | no |

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

**Plans:** 5/5 plans complete
Plans:
**Wave 1**

- [x] 05-01-PLAN.md — Foundation: InputMap (R revive, Space ability), Player.gd scaffold (stats, evolution_stage, element, RPCs, tick skeletons), Player.tscn replication, Enemy.gd status fields

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 05-02-PLAN.md — Role abilities: Tank shield + reflection, Speedster dash + double-dash shockwave, Engineer deploy dispatch
- [x] 05-03-PLAN.md — Engineer HealDrone scene + Game.gd drone spawn + Engineer passive heal

**Wave 3** *(blocked on Wave 2 completion)*

- [x] 05-04-PLAN.md — Fire/Ice element procs on Bullet.gd, Fire Burst auto-timer + Ice Trail request in Player._tick_element
- [x] 05-05-PLAN.md — IceTrailZone scene + spawner, Earth team heal + shockwave, force_burn bullet wiring

Wave 1 *(autonomous)*

- 05-01: project.godot + Player.gd + Player.tscn + Enemy.gd foundation scaffold

Wave 2 *(blocked on Wave 1)*

- 05-02: Player.gd role ability bodies (Tank/Speedster/Engineer dispatch)
- 05-03: HealDrone.{gd,tscn} + Game.gd drone spawn + Engineer passive (parallel — no file overlap with 05-02)

Wave 3 *(blocked on Wave 2)*

- 05-04: Bullet.gd element procs + Player.gd _tick_element (depends on 05-02 Player.gd)
- 05-05: IceTrailZone.{gd,tscn} + Game.gd Earth timers + force_burn wiring (depends on 05-03 Game.gd; parallel to 05-04 — no file overlap)

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

**Plans:** 4 plans

Plans:

- [x] 06-01-PLAN.md — XP state vars (xp, level, element_tier, is_picking_card, stage3_damage_mult) + receive_xp RPC + XpOrb grant wiring + Player.tscn MultiplayerSynchronizer extension + GameState reset
- [x] 06-02-PLAN.md — PlayerHUD.tscn/gd (XP bar CanvasLayer, LevelLabel, StageLabel) + CardOverlay.tscn/gd (3-card selection, A/D navigation, Space confirm)
- [x] 06-03-PLAN.md — Card flow wiring (pool build, filter, fallback, confirm_card_pick RPC) + evolution stage logic + Player.tscn stage visual containers + airbag_active→airbag_count migration
- [x] 06-04-PLAN.md — All 6 weapon Level 2/3 stat scaling (D-11 table) + stage3_damage_mult reads + Earth element_tier scaling in Game.gd

Wave 1 *(autonomous)*

- 06-01: Player.gd vars + XpOrb.gd + Player.tscn replication + GameState.gd reset

Wave 2 *(autonomous — new files, no overlap with Wave 1)*

- 06-02: PlayerHUD.{tscn,gd} + CardOverlay.{tscn,gd}

Wave 3 *(blocked on Waves 1 and 2 — card flow needs Player vars and CardOverlay scene)*

- 06-03: Player.gd card flow + Game.gd confirm_card_pick + Player.tscn stage containers + WeaponManager.gd airbag migration

Wave 4 *(blocked on Wave 3 — needs stage3_damage_mult var wired)*

- 06-04: WeaponManager.gd + all weapon .gd files + Game.gd Earth tier scaling

**Cross-cutting constraints:**

- `CanvasLayer` must be used for ALL local UI (W4) — never `SceneTree.paused`
- All XP/card/evolution state changes are host-authoritative: owning peer sends intent RPC → host validates → host broadcasts result (P8)
- `is_multiplayer_authority()` guards on all owning-peer UI and input logic

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

**Plans:** 3/3 plans complete

Plans:
**Wave 1**

- [x] 07-01-PLAN.md — Autoload + data foundation: emit_hud RPC, GameState loop_number=1 + start_next_loop() hook, Enemy const→var, XpOrb loop-scaled XP

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 07-02-PLAN.md — New scenes: CarHUD.tscn/.gd (5 indicators + Loop label + fade tween) + EliteEnemy.tscn/.gd (2× HP, 1.5× damage, purple)

**Wave 3** *(blocked on Wave 2 completion)*

- [x] 07-03-PLAN.md — Game.gd/Player.gd integration: CarHUD instantiation, elite spawn timer + LIDAR, difficulty scaling, revive-once-per-loop gate, host-routed SUSPENSION

Wave 1 *(autonomous)*

- 07-01: GameEvents.gd + GameState.gd + Enemy.gd + XpOrb.gd foundation

Wave 2 *(blocked on Wave 1 — new scenes need emit_hud RPC, GameState.loop_number, Enemy var stats)*

- 07-02: CarHUD.{tscn,gd} + EliteEnemy.{tscn,gd} (no file overlap with Wave 3)

Wave 3 *(blocked on Waves 1 and 2 — wires the new scenes into the running game)*

- 07-03: Game.gd + Player.gd integration (CarHUD instantiate, elite timer/LIDAR, difficulty scaling, revive gate, SUSPENSION)

**Descoped/deferred (locked decisions):** HUD-08 (V2X) removed per D-11; LOOP-01 (visible countdown) removed per D-15; LOOP-02 (room transition) is Phase 8. LOOP-03 satisfied by `start_next_loop()` hook (Phase 8 calls it); LOOP-06 already handled by existing reset path (D-18).

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

**Plans:** 3/3 plans complete

Plans:
**Wave 1**

- [x] 08-01-PLAN.md — Room 2 (Bamberg Altstadt corridors) + Room 3 (Burg Altenburg arena) geometry in Game.tscn + shared Entities node refactor (spawners repointed off Room1)
- [x] 08-02-PLAN.md — Boss.tscn + Boss.gd 3-phase HP-threshold state machine (melee → +ranged volley → enrage), phase color RPC, mob-swarm trigger

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 08-03-PLAN.md — Game.gd integration: current_room tracking, _transition_to_room call_local RPC, auto room-clear, boss spawn, mob swarm + LIDAR, boss-death loop advance, Boss pre-registration

Wave 1 *(autonomous — parallel, no file overlap)*

- 08-01: scenes/Game.tscn (Room2 + Room3 geometry, shared Entities, spawner spawn_path)
- 08-02: scenes/enemies/Boss.{tscn,gd} (self-contained boss state machine)

Wave 2 *(blocked on Waves 1 — needs Room2/Room3 + shared Entities + Boss.tscn to exist)*

- 08-03: scenes/Game.gd (transition RPC, room-clear, boss/mob spawn, loop advance, pre-registration)

---

### Phase 9: Map Overhaul — TileMap Sub-Rooms

**Goal:** Replace current polygon-based single rooms with TileMap-based sub-room system — each of the 3 locations has 5 sub-rooms (last sub-room of Room 3 is boss arena), layouts derived from real OSM geometry but fully hardcoded, Kenney Roguelike Modern City + Tiny Dungeon + 1-Bit Pack assets, scrolling camera following players
**UI hint:** yes

**Requirements:**

- MAP-01: Each of the 3 rooms contains 5 sub-rooms connected by open doorways (no loading screen within a room)
- MAP-02: Sub-rooms are cleared sequentially — clearing one opens the passage to the next
- MAP-03: Sub-room 5 of Room 3 (Burg Altenburg) is the boss arena
- MAP-04: Room 1 (ERBA) feel — open grass/park with overgrown dystopian city elements
- MAP-05: Room 2 (Bamberg Altstadt) feel — urban street grid, tighter corridors between building blocks
- MAP-06: Room 3 (Burg Altenburg) feel — stone castle, multiple courtyards, fortress walls
- MAP-07: Camera scrolls to follow players within a sub-room (no fixed 800×600 viewport)
- MAP-08: All layout geometry hardcoded — no OSM API calls at runtime
- MAP-09: OSMRoomGenerator.gd replaced entirely — boundary walls and obstacles unified in one system
- MAP-10: TileMap uses Kenney assets (Roguelike Modern City for rooms 1+2, Tiny Dungeon for room 3)
- MAP-11: Kenney tiles are placeholders — asset paths swappable for ChatGPT-generated custom tiles

**Success Criteria:**

1. Full run traverses Room 1 (5 sub-rooms) → Room 2 (5 sub-rooms) → Room 3 (4 sub-rooms + boss) without API calls
2. ERBA feels open/grassy, Altstadt feels like city streets, Burg feels like stone fortress
3. Camera follows players smoothly within each sub-room

**Pitfall watch:**

- Camera + multiplayer — scrolling camera must use one viewport per client; never sync camera position over network
- NavMesh rebake — NavigationRegion2D must be rebaked for each sub-room's TileMap geometry before enemies spawn
- TileMap collision — ensure TileSet physics layers are set so enemies and players collide with wall tiles correctly
- Sub-room transition — opening the passage must be host-authoritative; clients receive RPC to unlock the door, never open it locally
- OSMRoomGenerator removal — all existing room geometry in Game.tscn must be migrated; nothing should reference the old generator

**Plans:** 3/4 plans executed

Plans:

- [x] 09-01-PLAN.md — TileMap infrastructure: Game.tscn restructure (3 TileMap nodes, old geometry removed) + RoomLayouts.gd with all 17 hardcoded sub-room dictionaries
- [x] 09-02-PLAN.md — Camera2D: Player.tscn Camera2D node + Player.gd authority enable + update_camera_limits method (parallel to Plan 01)
- [x] 09-03-PLAN.md — Core logic: RoomBuilder.gd TileMap population engine + Game.gd sub-room state machine + OSMRoomGenerator deletion
- [ ] 09-04-PLAN.md — Integration: camera limit wiring into all sub-room transitions + full human verification checkpoint

Wave 1 *(autonomous — parallel, no file overlap)*

- 09-01: scenes/Game.tscn + scenes/RoomLayouts.gd
- 09-02: scenes/Player.tscn + scenes/Player.gd

Wave 2 *(blocked on Wave 1 — RoomBuilder needs RoomLayouts data; Game.gd needs TileMap nodes in Game.tscn)*

- 09-03: scenes/RoomBuilder.gd + scenes/Game.gd + delete scenes/OSMRoomGenerator.gd

Wave 3 *(blocked on Waves 1 and 2 — camera wiring needs update_camera_limits from Plan 02 and _transition_to_sub_room from Plan 03)*

- 09-04: scenes/Game.gd + scenes/Player.gd (camera limit wiring) + human checkpoint

---

## v1.1 Milestone: Juicy Feedback

**Milestone Goal:** Every player action (combat, collection, progression, abilities, downs/revives) produces immediate, discernible, and satisfying audiovisual feedback — grounded in game-feel/"meaningful play" theory (discernability + integration) — with paired sound on every juice moment, and team-visible broadcast for shared moments (healing, revival, big hits). Purely additive presentation layer — no changes to authoritative game state/logic.

Phase numbering continues from Phase 9 (previous milestone's last phase). Consolidated to 2 phases per user direction (max 2 phases for this milestone) — the original 7-stage research-derived sequencing (foundation infra → combat feedback → collection/progression → status-fix+elemental/ability → downed/revive/broadcast → evolution transform → sound pass+soak test) is preserved as internal waves within these 2 phases rather than as separate roadmap phases. See `.planning/research/SUMMARY.md` for the full research backing this sequencing.

### Phase 10: Juicy Feedback — Visual & Gameplay Polish

**Goal:** Every player action (combat, collection, progression, abilities, downs/revives, evolution) produces immediate, discernible, satisfying audiovisual feedback across all connected peers — the full non-sound juice layer, implemented as a purely additive presentation layer on top of the already-complete core game with zero changes to authoritative state/logic. This phase covers 27 requirements and is expected to require multiple plans/waves internally (consistent with `coarse` granularity in config.json).

**Suggested internal sequencing (for the planner):**

1. Foundational juice infrastructure — `JuiceManager`/`Juice.gd` autoload, persistent `FxLayer` container, CPUParticles2D-only convention, pooled/capped damage-number spawner and trauma-based shake accumulator, cleanup backstops. No gameplay-file edits in this wave — must exist and be verifiable in isolation before any consuming effect is built.
2. Combat feedback — floating damage numbers, player hit-flash, capped screen shake, animated HP-bar flash, hit-stop on kill, death particle burst. Lowest-risk, highest-value: almost entirely Pattern-A diff-watch on already-replicated state (`current_hp`/`health`), extending the existing `_last_hp_seen`-style idiom.
3. Collection & progression feedback — XP orb magnetism (cosmetic ghost-clone flight) + travel-to-bar, level-up burst, and the shared card-overlay pop-in animation (covers both level-up and sub-room weapon-choice presentations, per PROG-02).
4. Status-effect sync fix + elemental/ability juice — fix the discovered host-only burn/slow visibility bug first, then build element-specific hit VFX and role-ability juice (dash trail, aura pulse, heal sparkle, drone deploy) plus enemy spawn-in telegraph on top of the corrected sync state.
5. Downed/revive + team-wide broadcast juice — collapse animation, team-visible revive progress ring + success burst, team-visible healing feedback, team-visible big-hit feedback. Wires the already-scaffolded but unused `GameEvents.player_downed`/`player_revived` signals.
6. Evolution transform closure moment — deliberately sequenced last since it composes hit-stop + shake + particles + sound simultaneously, and carries the highest agency-risk (must not feel like a cutscene; no camera lock or input freeze for the transforming player or teammates still fighting live).

**UI hint:** yes

**Requirements:**

- SYS-01: All new particle effects use `CPUParticles2D` (not `GPUParticles2D`, which silently fails to render under this project's renderer)
- SYS-02: Damage numbers and screen shake are pooled/capped so high enemy density and rapid multi-weapon fire don't produce unreadable visual clutter
- SYS-03: Juice effect nodes (tweens, particles, floating text) are cleaned up without leaking over a full 15-minute loop
- DMG-01: A floating damage number appears over an enemy when it's hit, showing the amount of damage dealt
- DMG-02: The player's own sprite flashes (tints red/white) briefly when taking damage
- DMG-03: The screen shakes briefly when the player takes damage; shake magnitude is capped so simultaneous multi-hits don't compound into unreadable chaos
- DMG-04: The player's health bar flashes and animates down (not snaps instantly) when taking damage
- DMG-05: A brief hit-stop (freeze-frame) occurs on enemy kill, implemented as a local cosmetic pause — never a global `Engine.time_scale` change
- DMG-06: Enemy death produces a particle burst at its position
- DMG-07: Weapon/element-specific hit VFX appear on impact (fire scorch, ice shatter, earth crack) matching the element that dealt the damage
- DMG-08: Screen shake has a global intensity setting (off/low/normal) so it can be turned down for a live projected demo audience
- PICK-01: XP orbs drift toward a player when the player is within pickup range (magnetism)
- PICK-02: A collected XP orb visually travels to the player's XP bar; the XP bar value only increases once the orb visually arrives
- PROG-01: Leveling up triggers a burst effect around the player
- PROG-02: The card selection overlay animates in with a pop/scale-in rather than appearing instantly — applies to both level-up card picks and the sub-room weapon-choice overlay (same shared component)
- PROG-03: Reaching an evolution stage threshold triggers a capped (~1–1.5s), non-blocking multi-sensory transform moment (flash, particles, brief slow-mo-style effect, sound) that does not freeze player input or lock the camera
- ABIL-01: Enemy burn (Fire) and slow (Ice) status effects are visible on all clients, not just the host (fixes existing sync gap)
- ABIL-02: Speedster's dash leaves a visible trail/afterimage effect
- ABIL-03: Engineer's heal produces a visible sparkle/particle effect on the healed player
- ABIL-04: Tank's aura ability has a visible pulse effect
- ABIL-05: Engineer's drone deployment has a visible spawn effect
- ABIL-06: Enemies show a spawn-in telegraph effect when they appear
- COOP-01: A player entering the downed state shows a visible collapse animation
- COOP-02: Reviving a downed player shows a visible progress ring, visible to all players (not just the two involved)
- COOP-03: A successful revive triggers a visible success burst, visible to all players
- COOP-04: Healing effects (Engineer heal, Earth passive) are visible to all players, not just the healed player
- COOP-05: A significant/big hit triggers feedback visible to all players, not just the player who was hit

**Success Criteria:**

1. Hitting an enemy shows a pooled/capped floating damage number on host and client alike; taking damage flashes the player's sprite, triggers capped screen shake (adjustable via an off/low/normal setting), and animates the HP bar down rather than snapping it; killing an enemy produces a local cosmetic hit-stop plus a particle burst — all built from `CPUParticles2D`.
2. Walking near an XP orb makes it visibly drift toward the player before collection, then visually fly to the XP bar (bar value only increases on arrival); leveling up triggers a burst effect around the player; both the level-up card overlay and the sub-room weapon-choice overlay animate in with a pop/scale-in.
3. Enemy burn (Fire) and slow (Ice) status effects are visible on host and client screens alike (sync gap fixed); hitting an enemy with Fire/Ice/Earth shows the matching element hit VFX; Speedster's dash leaves a trail, Tank's aura pulses, Engineer's heal sparkles and drone deployment has a spawn effect; newly spawned enemies show a brief telegraph before becoming active.
4. A player entering the downed state shows a collapse animation visible to every connected screen; reviving shows a team-visible progress ring and a team-visible success burst; Engineer/Earth healing and significant hits produce feedback visible to the whole team, not only the player directly involved.
5. Reaching an evolution stage threshold triggers a capped (~1–1.5s) non-blocking multi-sensory transform visible to every peer, without freezing input or locking any camera for the transforming player or teammates.
6. A manual test trigger confirms damage numbers and shake stay pooled/capped under simulated swarm volume, and running effects repeatedly for several minutes leaves zero orphaned Tween/particle/label nodes (checked via the remote scene tree inspector).

**Pitfall watch:**

- Never use `Engine.time_scale` or `SceneTree.paused` for hit-stop — implement it as a local, per-peer cosmetic float read only by presentation code, never by movement/AI/cooldown/RPC dispatch (this project's Bullet.gd trusts identical wall-clock deltas across peers; `time_scale` would desync client-simulated bullets from replicated truth)
- CPUParticles2D only, never GPUParticles2D — this project's gl_compatibility renderer silently fails to render GPUParticles2D with no error; applies to every new particle effect across every wave (hit sparks, death burst, level-up, pickups, ability juice, evolution stinger)
- Death burst (and any other despawn-adjacent VFX) must fire via an RPC carrying `global_position` before `queue_free()` — never assume a dying Enemy node survives to the next frame; diff-watch alone races the despawn
- Parent all transient VFX to the persistent `FxLayer` container, never to the triggering node (dying enemy, consumed orb, revived player) — capture `global_position` first
- Team-visible broadcasts (revive progress, success burst, big-hit feedback) should target Player nodes directly — they have stable, deterministic cross-peer names, unlike Enemy/Bullet's non-deterministic spawner-assigned names; for events with no existing replicated field (e.g. "this was a significant hit"), extend `GameEvents`' existing reliable-broadcast pattern rather than fragmenting into a parallel signal bus
- Damage numbers and screen shake must be pooled/capped/trauma-accumulated from the start and shared across every wave — later waves (elemental, evolution) must reuse this infra, not add a second, uncapped path
- Verify the exact mechanism for adding `is_burning`/`is_slowed` to Enemy's MultiplayerSynchronizer replicated set during planning — do not assume it's a one-line addition without checking the current sync configuration
- XP magnetism is a cosmetic ghost-clone flight only — the real collection RPC and XP value stay untouched; no new networked orb state (revisit only if playtesting shows the ghost-clone feel is unsatisfying)
- Evolution transform must never feel like a cutscene — no camera lock, no input freeze for the transforming player or teammates, even though it composes hit-stop + shake + particles + sound simultaneously
- Card pop-in (level-up and sub-room weapon-choice, shared component per PROG-02) must stay local `CanvasLayer` UI, never `SceneTree.paused` (same discipline as Phase 6's W4)
- 20 Hz replication-tick granularity means simultaneous multi-bolt hits landing within one sync tick may under-count as a single merged damage number — accepted scope for this demo, not a bug to chase here
- Every spawn path across every effect type needs a matching cleanup path plus a defensive backstop timer — orphaned Tween/particle/label nodes accumulate silently over a full 15-minute loop; build this as shared foundational infra in wave 1, don't retrofit per-wave

**Plans:** 11/12 plans executed

Plans:

**Wave 1** *(foundational infra)*

- [x] 10-01-PLAN.md — Juice + Settings autoloads, scenes/vfx/ builders, persistent FxLayer, project.godot registration (SYS-01/02/03)
- [x] 10-02-PLAN.md — Music/SFX audio buses (default_bus_layout.tres) + Sfx.gd/Music.gd bus reassignment (DMG-08)

**Wave 2** *(combat + collection/progression, parallel — no file overlap)*

- [x] 10-03-PLAN.md — Enemy combat juice: damage numbers, white flash, HP ghost-chip, death burst + kill hit-stop (DMG-01/04/05/06)
- [x] 10-04-PLAN.md — Player combat juice: hit-flash, capped self-shake, HP ghost-chip, level-up burst (DMG-02/03/04, PROG-01)
- [x] 10-05-PLAN.md — Main Menu Settings sub-panel: shake cycle + Music/SFX sliders (DMG-08)
- [x] 10-06-PLAN.md — XP orb magnetism + travel-to-bar arrival-gated increase (PICK-01/02)
- [x] 10-07-PLAN.md — CardOverlay comic restyle + pop/scale-in entrance (PROG-02)

**Wave 3** *(status-fix + elemental/ability — parallel, Enemy vs Player files)*

- [x] 10-08-PLAN.md — Enemy status-sync fix + element hit VFX + spawn telegraph (ABIL-01, DMG-07, ABIL-06)
- [x] 10-09-PLAN.md — Ability juice: dash trail, aura pulse, heal sparkle, drone deploy (ABIL-02/03/04/05, COOP-04)

**Wave 4** *(downed/revive + team broadcast — shares Player.gd with Wave 3)*

- [x] 10-10-PLAN.md — Downed collapse, team-visible revive ring + success, big-hit broadcast; wires GameEvents.player_downed/player_revived (COOP-01/02/03/05)

**Wave 5** *(evolution — shares Player.gd with Wave 4)*

- [x] 10-11-PLAN.md — Evolution transform closure moment: charge-up then element-colored reveal, non-blocking (PROG-03)

**Wave 6** *(validation gate)*

- [ ] 10-12-PLAN.md — Static discipline sweep + human-verify soak/leak + Settings audible/visual (SYS-02/03; Success Criterion 6)

---

### Phase 11: Whole-Game Sound Design Pass & Soak-Test Validation

**Goal:** A full sound design pass across the *entire* game, not just the new Phase 10 juice moments — today only two cues exist in the whole project (`shoot()`/`hit()` in `autoloads/Sfx.gd`); the other 5 weapons, role abilities, pickups, UI/menu, room/loop transitions, and boss events are currently silent. **Actual audio asset sourcing/creation depends on human input from the team** — this phase's coding work is the trigger-point plumbing (extending `Sfx.gd`/`Music.gd`, wiring each hook using the existing safe-load pattern so a missing file degrades silently rather than breaking), not authoring audio content. The full milestone is validated with a genuine ~15-minute soak test plus a real multi-peer swarm playtest. This phase is expected to require multiple plans internally (consistent with `coarse` granularity in config.json).

**Suggested internal sequencing (for the planner):**

1. Produce a complete audio-parts checklist covering the whole game (every Phase 10 juice moment PLUS every currently-silent existing action: the other 5 weapons, role abilities, pickups, UI/menu, room/loop transitions, boss phase events) — hand this list to the team so they can source/record/choose the actual sound files; do not fabricate audio content.
2. Wire the trigger-point plumbing for each cue as files become available, reusing the existing `Sfx.gd` pool-extension + safe-load pattern; onset-only discipline for continuous effects (Fire burn DoT, Earth passive heal tick); reserved/priority voices for must-hear stingers (kill fanfare, evolution, downed/revive), bumping the shared pool size if needed.
3. Run a full-length (~15-minute) continuous-loop soak test on both host and client roles independently, watching node count for leaks.
4. Run a late-loop 2–3-real-peer swarm playtest checking damage-number/shake readability and audible stingers under heavy simultaneous fire.

**UI hint:** no

**Requirements:**

- SFX-01: Every juice moment from Phase 10 has a paired sound cue
- SFX-02: Continuous/repeating effects (Fire burn DoT, Earth passive heal tick) play a sound cue only on activation onset, not on every tick
- SFX-03: Existing gameplay actions across the whole game that currently lack a sound cue (the other 5 weapons beyond screws/bolts, role abilities, pickups, UI/menu interactions, room/loop transitions, boss phase events) receive one, using the same safe-load `Sfx.gd`/`Music.gd` pattern

**Success Criteria:**

1. A complete audio-parts checklist exists covering the whole game (Phase 10 juice moments + previously-silent existing actions), handed off for the team to source actual sound files.
2. Every juice moment from Phase 10 (damage, hit-flash, kill, death burst, pickup, level-up, evolution, dash, aura, heal, drone, spawn-in, downed, revive, big hit) has an audible, distinct sound cue wired once its file is available.
3. Continuous/repeating effects (Fire burn DoT, Earth passive heal tick) play their sound cue only once on activation onset, not on every tick.
4. Previously-silent existing actions (other weapons, abilities, pickups, UI, transitions, boss events) have cues wired using the same safe-load pattern.
5. A full ~15-minute continuous loop on both host and client roles ends with no visible node-count growth (checked via remote scene tree/profiler) and no dropped must-hear stingers.
6. A 2–3-real-peer swarm playtest under heavy simultaneous fire keeps damage numbers/shake readable and stingers audible, not silently stolen by the shared voice pool.

**Pitfall watch:**

- This phase's code work is plumbing, not content — actual WAV/audio files depend on human input from the team; the safe-load pattern (`ResourceLoader.exists()` check already established in `Sfx.gd`) means a not-yet-provided file degrades to silence, not a crash, so wiring can proceed ahead of asset delivery
- Sound cue on onset only, never on every tick of continuous effects (burn DoT, Earth heal aura) — matches SFX-02 exactly and the existing Sfx.gd cue-pairing pattern
- Reserve/priority voices for must-hear stingers (kill fanfare, evolution, downed/revive) so they aren't stolen by routine hit sounds during busy fights; bump the shared pool size if needed (~18–20 from 12) — decide concretely during this phase rather than leaving it ambiguous
- Multiplayer-specific pitfalls (time_scale asymmetry, RPC despawn races, per-peer leak differences) are invisible in solo testing — this soak/swarm test must be run with real second/third peers, not solo

**Plans:** TBD

---

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Network Foundation & Lobby | 2/2 | Complete | 2026-05-09 |
| 2. Player Movement & Sync | 2/2 | Complete | 2026-05-09 |
| 3. Room 1, Enemy AI, Combat Core | 5/5 | Complete | 2026-05-09 |
| 4. Weapons & Item Pickups | 5/5 | Complete | 2026-05-31 |
| 5. Roles & Elements | 5/5 | Complete | 2026-06-15 |
| 6. XP, Level-Up Cards & Evolution | 4/4 | Complete | 2026-06-18 |
| 7. CarHUD, Loop Timer & Difficulty Scaling | 3/3 | Complete | 2026-06-19 |
| 8. Rooms 2 & 3, Boss | 3/3 | Complete | 2026-06-22 |
| 9. Map Overhaul — TileMap Sub-Rooms | 3/4 | In progress | — |
| 10. Juicy Feedback — Visual & Gameplay Polish | 0/12 | Not started | — |
| 11. Whole-Game Sound Design Pass & Soak-Test Validation | 0/TBD | Not started | — |
