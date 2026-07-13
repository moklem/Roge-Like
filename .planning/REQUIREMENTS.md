# Requirements: Roge-Like

**Defined:** 2026-05-05
**Revised:** 2026-05-05 (added weapon system, XP/level-up cards, evolution stages; removed loop-end cards)
**Revised:** 2026-07-13 (added v1.1 Juicy Feedback milestone requirements)

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

### Health & Revival

- [ ] **HLTH-01**: Each player has a visible health bar shown to all players
- [ ] **HLTH-02**: Enemies deal damage to players on contact or projectile hit
- [ ] **HLTH-03**: Player health is synced to all clients in real time
- [ ] **HLTH-04**: Player reaching 0 HP enters a downed state (cannot act, visible downed indicator)
- [ ] **HLTH-05**: A teammate can walk near a downed player and hold a key to revive them
- [ ] **HLTH-06**: Revive has a visible hold-progress bar (not instant)
- [ ] **HLTH-07**: Each player may be revived at most once per 15-minute loop; counter resets at loop end
- [ ] **HLTH-08**: If all players are simultaneously downed, the run ends (game over)

### Weapons & Items

- [ ] **WEAP-01**: Enemies occasionally drop a car-part item pickup on death (random chance)
- [ ] **WEAP-02**: Player walking over an item pickup collects it; triggers weapon unlock or upgrade
- [ ] **WEAP-03**: Collecting a new car-part unlocks the corresponding weapon (added to WeaponManager)
- [ ] **WEAP-04**: Active weapons fire automatically on independent cooldown timers
- [ ] **WEAP-05**: Player can hold up to 6 active weapons simultaneously
- [ ] **WEAP-06**: Minimum weapon set includes at least 5 car-themed weapons (Exhaust Flames, Spinning Tires, Antenna Beam, Horn Shockwave, Airbag Shield)
- [ ] **WEAP-07**: Each weapon can be upgraded to level 3 (via card picks); each level improves damage, speed, or area
- [ ] **WEAP-08**: All active weapons and their levels reset on death

### Roles & Elements

- [ ] **ROLE-01**: Tank has noticeably higher max HP than other roles
- [ ] **ROLE-02**: Tank has a melee aura ability that damages nearby enemies
- [ ] **ROLE-03**: Tank's Stage 2 signature ability: sustained aura burst (larger radius, short duration)
- [ ] **ROLE-04**: Speedster moves faster than other roles
- [ ] **ROLE-05**: Speedster has a dash ability (brief burst of speed / invincibility frames)
- [ ] **ROLE-06**: Speedster's Stage 2 signature ability: afterimage dash (leaves damaging trail)
- [ ] **ROLE-07**: Engineer has a passive heal that periodically restores HP to nearby teammates
- [ ] **ROLE-08**: Engineer deploys a drone that targets nearby enemies
- [ ] **ROLE-09**: Engineer's Stage 2 signature ability: repair pulse (burst heal to all teammates)
- [ ] **ROLE-10**: Each role feels mechanically distinct in a 3-player session
- [ ] **ELEM-01**: Fire element adds a burn damage-over-time effect to enemies hit by the player
- [ ] **ELEM-02**: Fire element has a periodic area ring that damages enemies in range
- [ ] **ELEM-03**: Ice element applies a slow effect to enemies hit by the player
- [ ] **ELEM-04**: Ice element periodically creates a ground trail that blocks / slows enemy movement
- [ ] **ELEM-05**: Earth element provides passive healing per second to the whole team
- [ ] **ELEM-06**: Earth element has a shockwave ability that pushes enemies back
- [ ] **ELEM-07**: Element abilities trigger the appropriate CARIAD HUD indicator when activated

### XP, Cards & Evolution

- [ ] **XP-01**: Collecting XP orbs fills a visible XP bar on the player's HUD
- [ ] **XP-02**: On level-up, a card selection overlay appears for that player
- [ ] **XP-03**: Card selection shows 3 random cards drawn from an eligible pool
- [ ] **XP-04**: Card types include: weapon unlock, weapon upgrade (level 1→2→3), element upgrade, stat boost
- [ ] **XP-05**: Card pool is filtered: weapon unlock cards removed if player already has that weapon; upgrade cards removed if weapon is at max level
- [ ] **XP-06**: A fallback card is always available so the pool never runs dry
- [ ] **XP-07**: Card selection is per-player and non-blocking — other players continue playing during one player's card pick
- [ ] **XP-08**: Selected cards take effect immediately and stack for the rest of the session
- [ ] **XP-09**: Level number is visible on the player's screen
- [ ] **EVOL-01**: Every player starts Stage 1 (Normal Car)
- [ ] **EVOL-02**: Reaching Stage 2 XP threshold triggers transformation to Proto-Bot
- [ ] **EVOL-03**: Reaching Stage 3 XP threshold transforms to Full AutoBot
- [ ] **EVOL-04**: Stage is visible on the player's own and teammates' characters
- [ ] **EVOL-05**: Stage thresholds are the same for all roles (universal arc)
- [ ] **EVOL-06**: Stage resets to 1 (Normal Car) at the start of each new run

### CarHUD & Loop

- [ ] **HUD-01**: A Car HUD side panel is always visible on all players' screens during gameplay
- [ ] **HUD-02**: Panel contains labeled indicator boxes: AC, ENGINE, SEAT MASSAGE, SUSPENSION, LIDAR, V2X
- [ ] **HUD-03**: Ice ability used → "AC ❄️ COLD" lights up on all screens
- [ ] **HUD-04**: Fire ability used → "ENGINE 🔥 OVERHEAT" lights up on all screens
- [ ] **HUD-05**: Earth healing active → "SEAT MASSAGE 🌿 ACTIVE" lights up on all screens
- [ ] **HUD-06**: Any player takes a significant hit → "SUSPENSION ⚡ IMPACT" lights up on all screens
- [ ] **HUD-07**: Enemy spawns in the current room → "LIDAR 🔴 OBJECT DETECTED" lights up on all screens
- [ ] **HUD-08**: Random interval auto-trigger → "V2X 📡 SIGNAL SENT" lights up on all screens
- [ ] **HUD-09**: Each indicator fades out after a few seconds (not permanently lit)
- [ ] **HUD-10**: HUD event broadcasts via RPC — all clients see the same indicator fire simultaneously
- [ ] **LOOP-01**: A visible 15-minute countdown timer is shown on all players' screens
- [ ] **LOOP-02**: After the current room is cleared, all players transition to the next room simultaneously
- [ ] **LOOP-03**: Run ends when the boss is defeated or the timer expires — next loop starts, harder
- [ ] **LOOP-04**: Each successive loop increases enemy HP, damage, and spawn density
- [ ] **LOOP-05**: Loop number is visible to all players
- [ ] **LOOP-06**: Weapons, XP level, and evolution stage carry over between rooms within a session; reset only on full death

### Rooms & Boss

- [ ] **ROOM-01**: Room 1 (ERBA) — open, wide space; tutorial-level enemy density
- [ ] **ROOM-02**: Room 2 (Bamberg Altstadt) — narrow corridors; higher enemy density
- [ ] **ROOM-03**: Room 3 (Burg Altenburg) — large arena; boss fight
- [ ] **ROOM-04**: Boss has at least 2 distinct attack phases with different behavior per phase
- [ ] **ROOM-05**: Random mob swarms spawn between boss attack phases (harder each loop)
- [ ] **ROOM-06**: Enemy or mob spawns during boss fight trigger LIDAR HUD indicator
- [ ] **ROOM-07**: All room transitions are simultaneous across all clients

## v1.1 Requirements — Juicy Feedback

Game-feel/"juice" polish layer: immediate, discernible, satisfying audiovisual feedback on every player action, grounded in game-feel/"meaningful play" theory (discernability + integration). Purely additive presentation layer — no changes to authoritative game state/logic. See `.planning/research/SUMMARY.md` for full research backing these requirements.

### Combat Feedback

- [ ] **DMG-01**: A floating damage number appears over an enemy when it's hit, showing the amount of damage dealt
- [ ] **DMG-02**: The player's own sprite flashes (tints red/white) briefly when taking damage
- [ ] **DMG-03**: The screen shakes briefly when the player takes damage; shake magnitude is capped so simultaneous multi-hits don't compound into unreadable chaos
- [ ] **DMG-04**: The player's health bar flashes and animates down (not snaps instantly) when taking damage
- [ ] **DMG-05**: A brief hit-stop (freeze-frame) occurs on enemy kill, implemented as a local cosmetic pause — never a global `Engine.time_scale` change
- [ ] **DMG-06**: Enemy death produces a particle burst at its position
- [ ] **DMG-07**: Weapon/element-specific hit VFX appear on impact (fire scorch, ice shatter, earth crack) matching the element that dealt the damage
- [ ] **DMG-08**: Screen shake has a global intensity setting (off/low/normal) so it can be turned down for a live projected demo audience

### Collection & Progression Feedback

- [ ] **PICK-01**: XP orbs drift toward a player when the player is within pickup range (magnetism)
- [ ] **PICK-02**: A collected XP orb visually travels to the player's XP bar; the XP bar value only increases once the orb visually arrives
- [ ] **PICK-03**: Collecting a car-part/weapon pickup shows a pop/bounce animation and floating text (e.g. weapon name)
- [ ] **PROG-01**: Leveling up triggers a burst effect around the player
- [ ] **PROG-02**: The card selection overlay animates in with a pop/scale-in rather than appearing instantly
- [ ] **PROG-03**: Reaching an evolution stage threshold triggers a capped (~1–1.5s), non-blocking multi-sensory transform moment (flash, particles, brief slow-mo-style effect, sound) that does not freeze player input or lock the camera

### Ability & Elemental Feedback

- [ ] **ABIL-01**: Enemy burn (Fire) and slow (Ice) status effects are visible on all clients, not just the host (fixes existing sync gap)
- [ ] **ABIL-02**: Speedster's dash leaves a visible trail/afterimage effect
- [ ] **ABIL-03**: Engineer's heal produces a visible sparkle/particle effect on the healed player
- [ ] **ABIL-04**: Tank's aura ability has a visible pulse effect
- [ ] **ABIL-05**: Engineer's drone deployment has a visible spawn effect
- [ ] **ABIL-06**: Enemies show a spawn-in telegraph effect when they appear

### Co-op / Team-Visible Feedback

- [ ] **COOP-01**: A player entering the downed state shows a visible collapse animation
- [ ] **COOP-02**: Reviving a downed player shows a visible progress ring, visible to all players (not just the two involved)
- [ ] **COOP-03**: A successful revive triggers a visible success burst, visible to all players
- [ ] **COOP-04**: Healing effects (Engineer heal, Earth passive) are visible to all players, not just the healed player
- [ ] **COOP-05**: A significant/big hit triggers feedback visible to all players, not just the player who was hit

### Sound Design

- [ ] **SFX-01**: Every juice moment above has a paired sound cue
- [ ] **SFX-02**: Continuous/repeating effects (Fire burn DoT, Earth passive heal tick) play a sound cue only on activation onset, not on every tick

### Systemic / Foundational

- [ ] **SYS-01**: All new particle effects use `CPUParticles2D` (not `GPUParticles2D`, which silently fails to render under this project's renderer)
- [ ] **SYS-02**: Damage numbers and screen shake are pooled/capped so high enemy density and rapid multi-weapon fire don't produce unreadable visual clutter
- [ ] **SYS-03**: Juice effect nodes (tweens, particles, floating text) are cleaned up without leaking over a full 15-minute loop

## Out of Scope

| Feature | Reason |
|---------|--------|
| Meta-progression across sessions | All upgrades/weapons/stage reset on death, no persistent unlocks |
| Host migration | Host disconnect ends the run for all players |
| 4th human player slot for Driver | Driver is NPC/auto only |
| Custom art, sprites, or animations (core loop) | Placeholder shapes for the base build; some ad hoc art polish has since been added outside formal scope |
| Online / internet multiplayer | LAN only |
| Mobile or controller input | Keyboard only |
| Elemental combo cross-player interactions | Too complex for demo scope |
| Loop-end card picks | Replaced entirely by XP level-up card system |
| Fully synced (networked) XP orb magnetism | Cosmetic ghost-clone flight is sufficient; avoids new netcode surface for a purely visual effect |
| Multi-second evolution cutscene with camera lock/input freeze | Denies agency to teammates still fighting live during co-op session |
| Per-effect audio "nuisance" budget/ducking system beyond the existing voice pool | Only needed if playtesting reveals the extended Sfx.gd cue set becomes noisy; not required upfront |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| NET-01–05 | Phase 1 | Complete |
| LOBB-01–05 | Phase 1 | Complete |
| MOVE-01–04 | Phase 2 | Complete |
| CMBT-01–09 | Phase 3 | Complete |
| HLTH-01–08 | Phase 3/7 | Complete |
| WEAP-01–08 | Phase 4 | Complete |
| ROLE-01–10 | Phase 5 | Complete |
| ELEM-01–07 | Phase 5 | Complete |
| XP-01–09 | Phase 6 | Complete |
| EVOL-01–06 | Phase 6 | Complete |
| HUD-01–10 | Phase 7 | Complete |
| LOOP-01–06 | Phase 7 | Complete |
| ROOM-01–07 | Phase 8 | Complete |
| DMG-01–08 | TBD (roadmap) | Pending |
| PICK-01–03 | TBD (roadmap) | Pending |
| PROG-01–03 | TBD (roadmap) | Pending |
| ABIL-01–06 | TBD (roadmap) | Pending |
| COOP-01–05 | TBD (roadmap) | Pending |
| SFX-01–02 | TBD (roadmap) | Pending |
| SYS-01–03 | TBD (roadmap) | Pending |

**Coverage:**
- v1.1 requirements: 30 total
- Mapped to phases: 0 (pending roadmap)
- Unmapped: 30 ⚠️ (roadmap creation next)

---
*Requirements defined: 2026-05-05*
*Last updated: 2026-07-13 after v1.1 Juicy Feedback requirements definition*
