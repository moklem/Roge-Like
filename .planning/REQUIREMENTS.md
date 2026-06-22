# Requirements: Roge-Like

**Defined:** 2026-05-05
**Revised:** 2026-05-05 (added weapon system, XP/level-up cards, evolution stages; removed loop-end cards)
**Core Value:** The CARIAD HUD must always fire convincingly — every major game event triggers the corresponding vehicle sensor indicator, making gameplay feel like a real in-car system demo.

---

## v1 Requirements

### Network

- [ ] **NET-01**: Host can create a LAN session; their IP is displayed for others to enter
- [ ] **NET-02**: Client can join by entering the host's IP address
- [ ] **NET-03**: Connection status is visible during join (connecting / failed / success)
- [ ] **NET-04**: Host disconnect immediately ends the session for all clients with a "Host Left" screen
- [ ] **NET-05**: Game supports 1–3 players (solo host usable without additional machines)

### Lobby

- [ ] **LOBB-01**: Player picks one of 3 roles (Tank, Speedster, Engineer) before game starts
- [ ] **LOBB-02**: Roles are exclusive — a role chosen by one player is locked for others
- [ ] **LOBB-03**: Player independently picks one element (Fire, Ice, Earth) — separate from role
- [ ] **LOBB-04**: All players see every other player's confirmed role + element before game starts
- [ ] **LOBB-05**: Host can start the game once at least 1 player is in the lobby

### Movement

- [ ] **MOVE-01**: Each player moves with WASD in top-down view
- [ ] **MOVE-02**: Player positions are visible on all connected clients in real time
- [ ] **MOVE-03**: Players cannot walk through room walls
- [ ] **MOVE-04**: Each player's role label is visible above their character

### Combat

- [ ] **CMBT-01**: At least one basic enemy type chases and attacks the nearest player
- [ ] **CMBT-02**: Enemy pathfinds around room walls (does not walk through obstacles)
- [ ] **CMBT-03**: Enemies are spawned and controlled by the host; clients see the synced result
- [ ] **CMBT-04**: Starter weapon: screws and bolts fly outward automatically from the player
- [ ] **CMBT-05**: Bullets/projectiles despawn on enemy or wall contact
- [ ] **CMBT-06**: Bullet hits apply damage to the struck enemy (host-authoritative)
- [ ] **CMBT-07**: Enemy death removes the enemy from all clients simultaneously
- [ ] **CMBT-08**: Enemy death drops an XP orb pickup at the enemy's position
- [ ] **CMBT-09**: Player walking over XP orb collects it; orb despawns from all clients

### Weapons & Items

- [ ] **WEAP-01**: Enemies occasionally drop a car-part item pickup on death (random chance)
- [ ] **WEAP-02**: Player walking over an item pickup collects it; triggers weapon unlock or upgrade
- [ ] **WEAP-03**: Collecting a new car-part unlocks the corresponding weapon (added to WeaponManager)
- [ ] **WEAP-04**: Active weapons fire automatically on independent cooldown timers
- [ ] **WEAP-05**: Player can hold up to 6 active weapons simultaneously
- [ ] **WEAP-06**: Minimum weapon set includes at least 5 car-themed weapons (see v2 for full list)
  - **WEAP-06a**: Exhaust Flames — fire cone behind the player
  - **WEAP-06b**: Spinning Tires — orbiting projectiles that deflect enemies
  - **WEAP-06c**: Antenna Beam — long-range piercing laser
  - **WEAP-06d**: Horn Shockwave — close-range area burst
  - **WEAP-06e**: Airbag Shield — brief damage-absorbing shell
- [x] **WEAP-07**: Each weapon can be upgraded to level 3 (via card picks); each level improves damage, speed, or area
- [x] **WEAP-08**: All active weapons and their levels reset on death

### XP & Level-Up

- [ ] **XP-01**: Collecting XP orbs fills a visible XP bar on the player's HUD
- [ ] **XP-02**: On level-up, a card selection overlay appears for that player
- [ ] **XP-03**: Card selection shows 3 random cards drawn from an eligible pool
- [ ] **XP-04**: Card types include: weapon unlock, weapon upgrade (level 1→2→3), element upgrade, stat boost (speed / max HP / damage / cooldown reduction)
- [ ] **XP-05**: Card pool is filtered: weapon unlock cards removed if player already has that weapon; upgrade cards removed if weapon is at max level
- [ ] **XP-06**: A fallback card is always available (e.g., +10% damage) so the pool never runs dry
- [ ] **XP-07**: Card selection is per-player and non-blocking — other players continue playing during one player's card pick
- [ ] **XP-08**: Selected cards take effect immediately and stack for the rest of the session
- [ ] **XP-09**: Level number is visible on the player's screen

### Evolution

- [ ] **EVOL-01**: Every player starts Stage 1 (Normal Car) — moves and fights like a car, basic attacks, starter stats, car-shaped visual
- [ ] **EVOL-02**: Reaching the Stage 2 XP level threshold triggers full transformation to Proto-Bot
  - Player now moves and fights like a robot — locomotion style changes completely (no longer a car)
  - Visually raw and unfinished: skeletal robot shape, basic limb geometry, no armor, exposed parts (placeholder: distinct robot-limb rectangle arrangement)
  - One new signature ability unlocks (role-specific)
  - Already a meaningful power increase over Stage 1; weaker than Stage 3 due to missing armor and abilities
- [ ] **EVOL-03**: Reaching the Stage 3 XP level threshold triggers transformation to Full AutoBot
  - Same robot movement and locomotion as Stage 2 — the movement style does NOT change here
  - Fully armored and visually complete: plated surfaces, fuller silhouette (placeholder: larger, more decorated rectangle arrangement)
  - All role and element abilities active
  - Maximum power tier with stat bonuses
- [ ] **EVOL-04**: Stage is visible on the player's own and teammates' characters
- [ ] **EVOL-05**: Stage thresholds are the same for all roles (universal arc)
- [ ] **EVOL-06**: Stage resets to 1 (Normal Car) at the start of each new run

### Health

- [ ] **HLTH-01**: Each player has a visible health bar shown to all players
- [ ] **HLTH-02**: Enemies deal damage to players on contact or projectile hit
- [ ] **HLTH-03**: Player health is synced to all clients in real time
- [ ] **HLTH-04**: Player reaching 0 HP enters a downed state (cannot act, visible downed indicator)
- [ ] **HLTH-05**: A teammate can walk near a downed player and hold a key to revive them
- [ ] **HLTH-06**: Revive has a visible hold-progress bar (not instant)
- [x] **HLTH-07**: Each player may be revived at most once per 15-minute loop; counter resets at loop end
- [ ] **HLTH-08**: If all players are simultaneously downed, the run ends (game over)

### Car HUD

- [x] **HUD-01**: A Car HUD side panel is always visible on all players' screens during gameplay
- [x] **HUD-02**: Panel contains labeled indicator boxes: AC, ENGINE, SEAT MASSAGE, SUSPENSION, LIDAR, V2X
- [x] **HUD-03**: Ice ability used → "AC ❄️ COLD" lights up on all screens
- [x] **HUD-04**: Fire ability used → "ENGINE 🔥 OVERHEAT" lights up on all screens
- [x] **HUD-05**: Earth healing active → "SEAT MASSAGE 🌿 ACTIVE" lights up on all screens
- [x] **HUD-06**: Any player takes a significant hit → "SUSPENSION ⚡ IMPACT" lights up on all screens
- [x] **HUD-07**: Enemy spawns in the current room → "LIDAR 🔴 OBJECT DETECTED" lights up on all screens
- [x] **HUD-08**: Random interval auto-trigger → "V2X 📡 SIGNAL SENT" lights up on all screens
- [x] **HUD-09**: Each indicator fades out after a few seconds (not permanently lit)
- [x] **HUD-10**: HUD event broadcasts via RPC — all clients see the same indicator fire simultaneously

### Roguelike Loop

- [x] **LOOP-01**: A visible 15-minute countdown timer is shown on all players' screens
- [x] **LOOP-02**: After the current room is cleared, all players transition to the next room simultaneously
- [x] **LOOP-03**: Run ends when the boss is defeated or the timer expires — next loop starts, harder
- [x] **LOOP-04**: Each successive loop increases enemy HP, damage, and spawn density
- [x] **LOOP-05**: Loop number is visible to all players
- [x] **LOOP-06**: Weapons, XP level, and evolution stage carry over between rooms within a session; reset only on full death (team wipe)

### Roles

- [ ] **ROLE-01**: Tank has noticeably higher max HP than other roles
- [ ] **ROLE-02**: Tank has a melee aura ability that damages nearby enemies
- [ ] **ROLE-03**: Tank's Stage 2 signature ability: sustained aura burst (larger radius, short duration)
- [ ] **ROLE-04**: Speedster moves faster than other roles
- [ ] **ROLE-05**: Speedster has a dash ability (brief burst of speed / invincibility frames)
- [ ] **ROLE-06**: Speedster's Stage 2 signature ability: afterimage dash (leaves damaging trail)
- [x] **ROLE-07**: Engineer has a passive heal that periodically restores HP to nearby teammates
- [x] **ROLE-08**: Engineer deploys a drone that targets nearby enemies
- [x] **ROLE-09**: Engineer's Stage 2 signature ability: repair pulse (burst heal to all teammates)
- [ ] **ROLE-10**: Each role feels mechanically distinct in a 3-player session

### Elements

- [ ] **ELEM-01**: Fire element adds a burn damage-over-time effect to enemies hit by the player
- [ ] **ELEM-02**: Fire element has a periodic area ring that damages enemies in range
- [ ] **ELEM-03**: Ice element applies a slow effect to enemies hit by the player
- [ ] **ELEM-04**: Ice element periodically creates a ground trail that blocks / slows enemy movement
- [ ] **ELEM-05**: Earth element provides passive healing per second to the whole team
- [ ] **ELEM-06**: Earth element has a shockwave ability that pushes enemies back
- [ ] **ELEM-07**: Element abilities trigger the appropriate CARIAD HUD indicator when activated

### Rooms

- [ ] **ROOM-01**: Room 1 (ERBA) — open, wide space; tutorial-level enemy density; teaches movement + combat
- [x] **ROOM-02**: Room 2 (Bamberg Altstadt) — narrow corridors; higher enemy density; punishes clustering
- [x] **ROOM-03**: Room 3 (Burg Altenburg) — large arena; boss fight
- [x] **ROOM-04**: Boss has at least 2 distinct attack phases with different behavior per phase
- [x] **ROOM-05**: Random mob swarms spawn between boss attack phases (harder each loop)
- [ ] **ROOM-06**: Enemy or mob spawns during boss fight trigger LIDAR HUD indicator
- [ ] **ROOM-07**: All room transitions are simultaneous across all clients

---

## v2 Requirements

### Weapon Expansion

- **WEAP-V2-01**: Gear Shield — rotating gear that blocks projectiles
- **WEAP-V2-02**: Turbo Boost — propulsion burst that deals contact damage while dashing
- **WEAP-V2-03**: Oil Slick — puddle that slows enemies walking through it
- **WEAP-V2-04**: Headlight Beam — long-range sweeping beam
- **WEAP-V2-05**: Seatbelt Lasso — grabs and pulls an enemy toward the player

### Visual Polish

- **VIS-01**: Placeholder shapes replaced with sprite artwork for players, enemies, weapons
- **VIS-02**: Named room visual identity (each room has thematic tile aesthetic)
- **VIS-03**: Evolution transformation animations (car → proto-bot → autobot)
- **VIS-04**: Particle effects for elemental abilities and stage transitions

### Gameplay Extensions

- **GAME-01**: Per-role unique Stage 2 and Stage 3 visual forms
- **GAME-02**: Elemental combo interactions (e.g., Fire + Ice = Steam cloud)
- **GAME-03**: More than 3 enemy types with distinct behaviors (ranged, fast, armored)
- **GAME-04**: Passive Driver NPC with visible "car" model integrating into the scene

### Quality of Life

- **QOL-01**: LAN auto-discovery (avoid manual IP entry)
- **QOL-02**: In-game pause menu for host
- **QOL-03**: Spectator timer display mode for projector

---

## Out of Scope

| Feature | Reason |
|---------|--------|
| Meta-progression across runs | All upgrades reset on death — no persistent unlocks in this build |
| Loop-end card picks | Replaced entirely by XP level-up card system |
| Host migration | Complex in ENet; game over on host disconnect is sufficient for demo |
| 4th human player (Driver) | Driver is NPC auto-system; 3 laptops available at demo |
| Online / internet multiplayer | LAN only; no relay or STUN/TURN |
| Mobile or controller input | Keyboard only |
| Custom art / sprites / animations | Placeholder shapes throughout |
| Inventory or equip screens | No item management UI — pickup to auto-equip |
| Chat system | Not needed at the same table |
| Save / load | Session-only; no persistence between app launches |

---

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| NET-01 | Phase 1 | Pending |
| NET-02 | Phase 1 | Pending |
| NET-03 | Phase 1 | Pending |
| NET-04 | Phase 1 | Pending |
| NET-05 | Phase 1 | Pending |
| LOBB-01 | Phase 1 | Pending |
| LOBB-02 | Phase 1 | Pending |
| LOBB-03 | Phase 1 | Pending |
| LOBB-04 | Phase 1 | Pending |
| LOBB-05 | Phase 1 | Pending |
| MOVE-01 | Phase 2 | Pending |
| MOVE-02 | Phase 2 | Pending |
| MOVE-03 | Phase 2 | Pending |
| MOVE-04 | Phase 2 | Pending |
| CMBT-01 | Phase 3 | Pending |
| CMBT-02 | Phase 3 | Pending |
| CMBT-03 | Phase 3 | Pending |
| CMBT-04 | Phase 3 | Pending |
| CMBT-05 | Phase 3 | Pending |
| CMBT-06 | Phase 3 | Pending |
| CMBT-07 | Phase 3 | Pending |
| CMBT-08 | Phase 3 | Pending |
| CMBT-09 | Phase 3 | Pending |
| WEAP-01 | Phase 4 | Pending |
| WEAP-02 | Phase 4 | Pending |
| WEAP-03 | Phase 4 | Pending |
| WEAP-04 | Phase 4 | Complete (04-04) |
| WEAP-05 | Phase 4 | Pending |
| WEAP-06 | Phase 4 | Pending |
| WEAP-06a | Phase 4 | Pending |
| WEAP-06b | Phase 4 | Pending |
| WEAP-06c | Phase 4 | Complete (04-04) |
| WEAP-06d | Phase 4 | Complete (04-04) |
| WEAP-06e | Phase 4 | Complete (04-05) |
| WEAP-07 | Phase 4 | Complete (04-05) |
| WEAP-08 | Phase 4 | Complete (04-05) |
| XP-01 | Phase 5 | Pending |
| XP-02 | Phase 5 | Pending |
| XP-03 | Phase 5 | Pending |
| XP-04 | Phase 5 | Pending |
| XP-05 | Phase 5 | Pending |
| XP-06 | Phase 5 | Pending |
| XP-07 | Phase 5 | Pending |
| XP-08 | Phase 5 | Pending |
| XP-09 | Phase 5 | Pending |
| EVOL-01 | Phase 5 | Pending |
| EVOL-02 | Phase 5 | Pending |
| EVOL-03 | Phase 5 | Pending |
| EVOL-04 | Phase 5 | Pending |
| EVOL-05 | Phase 5 | Pending |
| EVOL-06 | Phase 5 | Pending |
| HLTH-01 | Phase 3 | Pending |
| HLTH-02 | Phase 3 | Pending |
| HLTH-03 | Phase 3 | Pending |
| HLTH-04 | Phase 3 | Pending |
| HLTH-05 | Phase 3 | Pending |
| HLTH-06 | Phase 3 | Pending |
| HLTH-07 | Phase 6 | Complete |
| HLTH-08 | Phase 3 | Pending |
| HUD-01 | Phase 6 | Complete |
| HUD-02 | Phase 6 | Complete |
| HUD-03 | Phase 6 | Complete |
| HUD-04 | Phase 6 | Complete |
| HUD-05 | Phase 6 | Complete |
| HUD-06 | Phase 6 | Complete |
| HUD-07 | Phase 6 | Complete |
| HUD-08 | Phase 6 | Complete |
| HUD-09 | Phase 6 | Complete |
| HUD-10 | Phase 6 | Complete |
| LOOP-01 | Phase 6 | Complete |
| LOOP-02 | Phase 6 | Complete |
| LOOP-03 | Phase 6 | Complete |
| LOOP-04 | Phase 6 | Complete |
| LOOP-05 | Phase 6 | Complete |
| LOOP-06 | Phase 6 | Complete |
| ROLE-01 | Phase 7 | Pending |
| ROLE-02 | Phase 7 | Pending |
| ROLE-03 | Phase 7 | Pending |
| ROLE-04 | Phase 7 | Pending |
| ROLE-05 | Phase 7 | Pending |
| ROLE-06 | Phase 7 | Pending |
| ROLE-07 | Phase 5, Plan 03 | Complete |
| ROLE-08 | Phase 5, Plan 03 | Complete |
| ROLE-09 | Phase 5, Plan 03 | Complete |
| ROLE-10 | Phase 7 | Pending |
| ELEM-01 | Phase 7 | Pending |
| ELEM-02 | Phase 7 | Pending |
| ELEM-03 | Phase 7 | Pending |
| ELEM-04 | Phase 7 | Pending |
| ELEM-05 | Phase 7 | Pending |
| ELEM-06 | Phase 7 | Pending |
| ELEM-07 | Phase 7 | Pending |
| ROOM-01 | Phase 8 | Pending |
| ROOM-02 | Phase 8 | Complete |
| ROOM-03 | Phase 8 | Complete |
| ROOM-04 | Phase 8 | Complete |
| ROOM-05 | Phase 8 | Complete |
| ROOM-06 | Phase 8 | Pending |
| ROOM-07 | Phase 8 | Pending |

**Coverage:**

- v1 requirements: 84 total
- Mapped to phases: 84
- Unmapped: 0 ✓

---
*Requirements defined: 2026-05-05*
*Last updated: 2026-05-05 — revised: weapon system, XP/level-up, evolution stages; loop-end cards removed*
