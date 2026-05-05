# Roge-Like

## What This Is

A top-down co-op roguelike built in Godot 4 for a CARIAD university project demo. Up to 3 players connect over LAN from separate laptops; one hosts, others join by IP. The game features 3 player roles (Tank, Speedster, Engineer), 3 elemental ability modifiers (Fire, Ice, Earth), and a persistent side-panel Car HUD that simulates CARIAD vehicle sensor outputs in real time — lighting up as players fight through 3 hand-crafted rooms toward a looping boss encounter.

## Core Value

The CARIAD HUD must always fire convincingly — every major game event (ice attack, fire damage, enemy spawn, big hit) should trigger the corresponding vehicle sensor indicator, making the gameplay feel like a real in-car system demo.

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] LAN multiplayer: host/join screen, ENet, 1–3 players (solo testable)
- [ ] Host-authoritative: enemy AI and bullet physics run only on host, synced to clients
- [ ] Host disconnect = game over for everyone (no migration)
- [ ] 3 exclusive roles: Tank (melee aura, high HP), Speedster (dash, fast), Engineer (drones, heals)
- [ ] Role selection screen — roles are locked once chosen, no duplicates
- [ ] Elements (Fire/Ice/Earth) are a separate pick per player, independent of role
- [ ] Top-down WASD movement for all players
- [ ] Basic enemy that chases nearest player
- [ ] Auto-attack / bullet system with damage
- [ ] Health bars visible for all players
- [ ] One rectangular room with walls (core combat prototype)
- [ ] Car HUD side panel always visible — indicator boxes light up on game events
- [ ] HUD: Ice attack → "AC ❄️ COLD", Fire attack → "ENGINE 🔥 OVERHEAT", Earth healing → "SEAT MASSAGE 🌿 ACTIVE", Big hit → "SUSPENSION ⚡ IMPACT", Enemy spawn → "LIDAR 🔴 OBJECT DETECTED", Random interval → "V2X 📡 SIGNAL SENT"
- [ ] Driver is an NPC auto-system — no human player, reacts to events
- [ ] Revive system: downed state, any teammate holds key to revive (proximity), once per 15-min loop, resets after loop
- [ ] 3 hand-crafted rooms: ERBA (open island, tutorial), Bamberg Altstadt (tight corridors), Burg Altenburg (boss arena)
- [ ] Boss room: single boss with 2–3 attack phases + random mob swarm waves between phases
- [ ] Mob swarms and boss encounters trigger additional V2X / LIDAR HUD indicators
- [ ] 15-minute loop timer; after loop ends → card-pick upgrade screen (1 of 3 cards)
- [ ] Upgrades stack within a session; full reset on death (classic roguelike)
- [ ] Each subsequent loop is harder (enemy HP, damage, and density scale up)
- [ ] Elemental modifiers: Fire (burn aura, area ring), Ice (slow/freeze, trail blocks mobs), Earth (team HPS, shockwave)
- [ ] Placeholder art throughout (colored shapes, no sprites required)

### Out of Scope

- Meta-progression across sessions — upgrades reset on death, no persistent unlocks
- Host migration — host disconnect ends the run for all players
- 4th human player slot for Driver — Driver is NPC/auto only
- Custom art, sprites, or animations — placeholder shapes only for this build
- Online / internet multiplayer — LAN only
- Mobile or controller input — keyboard only

## Context

- **Platform:** Godot 4, Windows laptops, LAN (ENet)
- **Event:** CARIAD university project demo — presented both live (3 laptops on a table, people play) and projected to an audience; no hard deadline yet
- **CARIAD angle:** The Car HUD simulates vehicle sensor outputs (climate control, active suspension, seat massage, LiDAR, V2X) as a "what gameplay could feel like inside a connected car" concept. The HUD is always visible as a side panel.
- **Team:** Building together; solo testability (1 player = host only) is required so developers can test without 3 machines available
- **Art:** Placeholder shapes throughout — this is a prototype/demo, visual polish is not a goal

## Constraints

- **Engine:** Godot 4 only — ENet for multiplayer, no third-party networking libraries
- **Art:** Placeholder shapes — no time budget for sprites or animations
- **Network:** LAN only, manual IP entry, no relay/matchmaking server
- **Authority:** Host-authoritative — all game logic (enemies, bullets) authoritative on host machine
- **Roles:** Maximum 3 concurrent players; roles are exclusive (one of each per session)

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Host-authoritative network model | Simplest correct approach for LAN co-op; avoids desyncing enemies/bullets across clients | — Pending |
| Driver is NPC auto-system | Only 3 laptops available; Driver HUD still fires from game events without a human player | — Pending |
| Elements are a separate pick from role | Allows replayability — same role can play differently each run | — Pending |
| Host disconnect = game over | Host migration in Godot ENet is complex; game over is correct call for a demo prototype | — Pending |
| Placeholder art only | Demo focuses on CARIAD HUD concept and multiplayer gameplay; visual polish is not the goal | — Pending |
| Upgrades stack within session, reset on death | Standard roguelike feel; no meta-progression complexity needed for demo | — Pending |

---

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-05-05 after initialization*
