# Phase 3 Discussion Log

**Date:** 2026-05-09
**Participants:** User, Claude
**Phase:** 3 — Room 1, Enemy AI, Combat Core

---

## Discussion Summary

Discussed 4 core gray areas for Phase 3: Enemy AI & Pathfinding, Projectile System, Damage & Hit Detection, Health & Downed State. User selected all areas for deep discussion.

---

## Area 1: Enemy AI & Pathfinding

### Question 1: Pathfinding Update Frequency
**Options Presented:**
- Every frame (~60 Hz)
- Every 0.5–1 second
- Adaptive (plan when player visible)
- Other approach

**User Selection:** Every frame (~60 Hz)
**Rationale:** Responsive pursuit, snappy feel
**Decision Locked:** D-01 — Enemy pathfinding updates every frame

---

### Question 2: Enemy Targeting Strategy
**Options Presented:**
- Always nearest player
- Field of view (detection radius)
- Aggro on player sight + persistence

**User Selection:** Field of view (detection radius)
**Rationale:** More game-like, adds tactical layer, players can sneak/group
**Decision Locked:** D-02 — Enemies use detection radius; outside range they idle

---

### Question 3: Room Geometry Implementation
**Options Presented:**
- TileMap only
- StaticBody2D colliders only
- TileMap + static bodies for detail

**User Input:** "Later you will be given the googlemaps oms data from erba insel etc. make a design choice that lays the groundwork for that"
**Key Context:** Map data coming for ERBA island; geometry needs to be importable later
**Decision Locked:** D-03 — Use placeholder rectangles now; dedicated Map Data Import phase later

---

### Question 4: How to Prepare for Map Data Import
**Options Presented:**
- StaticBody2D colliders (manual mapping)
- Build import script now
- Placeholder now, dedicated import phase later

**User Selection:** Placeholder now, dedicated import phase later
**Rationale:** Keeps Phase 3 focused on combat, defers map import complexity
**Decisions Locked:** D-03 (confirmed), navmesh spike noted (D-04)

---

## Area 2: Projectile System

### Question 1: Projectile Spawning Strategy
**Options Presented:**
- MultiplayerSpawner (replicated)
- Host simulation + sync
- Hybrid (spawn via spawner, sync via Synchronizer)

**User Selection:** MultiplayerSpawner (replicated)
**Rationale:** All peers see bullets from creation, deterministic physics
**Decision Locked:** D-05 — Bullets spawned via MultiplayerSpawner

---

### Question 2: Bullet Hit Detection Authority
**Options Presented:**
- Host only
- Clients detect locally
- Client detects + reports to host

**User Selection:** Host only
**Rationale:** Single source of truth, prevents desync
**Decision Locked:** D-07 — Host detects bullet hits, broadcasts despawn RPC

---

### Question 3: Screw/Bolt Firing Pattern
**Options Presented:**
- 360° outward burst
- Aimed at nearest enemy
- Both (toggle or upgrade)

**User Selection:** Aimed at nearest enemy
**Rationale:** Tactical, efficient, focuses fire
**Decision Locked:** D-06 — Projectiles aimed at nearest detected enemy

---

## Area 3: Damage & Hit Detection

### Question 1: Enemy Contact Damage Authority
**Options Presented:**
- Host only
- Host + clients detect, host arbitrates
- Client applies immediately

**User Selection:** Host only
**Rationale:** Consistent with bullet authority pattern, single source of truth
**Decision Locked:** D-09 — Host detects enemy contact, applies damage

---

### Question 2: Enemy Contact Damage Frequency
**Options Presented:**
- Once per contact
- Damage over time (every 1s)
- Both (initial hit + periodic DoT)

**User Selection:** Once per contact
**Rationale:** Encourages dodging, prevents instant kill by swarms
**Decision Locked:** D-10 — Damage once per contact; player must move to avoid next hit

---

### Question 3: Bullet Hit Immunity
**Options Presented:**
- Owner is immune
- Owner takes damage
- Owner immune for first 0.2s

**User Selection:** Owner is immune
**Rationale:** Standard, prevents accidental self-damage
**Decision Locked:** D-08 — Players immune to own bullets

---

## Area 4: Health & Downed State

### Question 1: Health Bar Display
**Options Presented:**
- World-space above character
- HUD panel (side or corner)
- World-space + optional HUD summary

**User Selection:** World-space + optional HUD summary
**Rationale:** Full information, familiar roguelike feel
**Decision Locked:** D-11 — Health bars above all characters + optional HUD summary

---

### Question 2: Downed State Appearance
**Options Presented:**
- Color shift (grayed out / red tint)
- Rotation/tilt (knocked over)
- Size reduction + blink
- Floating / hovering effect

**User Selection:** Color shift (grayed out / red tint)
**Rationale:** Simple, placeholder-friendly, instantly recognizable
**Decision Locked:** D-12 — Downed state = color shift (grayscale or red)

---

### Question 3: Revive Hold Duration
**Options Presented:**
- 2 seconds
- 3–4 seconds
- 5+ seconds
- Configurable per difficulty loop

**User Selection:** 3–4 seconds
**Rationale:** Meaningful penalty without being brutal, creates vulnerability
**Decision Locked:** D-13 — Revive hold is 3–4 seconds

---

### Question 4: Game Over Trigger When All Downed
**Options Presented:**
- Immediate
- Grace period (5 seconds)
- Last player has 10s to self-revive

**User Selection:** Immediate
**Rationale:** Clean, unambiguous, no edge cases
**Decision Locked:** D-14 — All downed = immediate game over

---

## Summary of Locked Decisions

**Enemy AI:**
- D-01: Frame-by-frame pathfinding (~60 Hz)
- D-02: Detection radius targeting
- D-03: Placeholder geometry, map import phase deferred
- D-04: 30-min navmesh spike before commit

**Projectiles:**
- D-05: MultiplayerSpawner replication
- D-06: Aimed at nearest enemy
- D-07: Host-only hit detection with RPC despawn
- D-08: Owner immune to own bullets

**Damage:**
- D-09: Host-only contact damage
- D-10: Once per contact (no DoT)

**Health & UI:**
- D-11: World-space bars + HUD summary
- D-12: Color shift for downed state
- D-13: 3–4 second revive hold
- D-14: Immediate game over when all downed

**Network & Authority:**
- D-15: Enemy spawning via spawn_function pattern
- D-16: XP orb collection host-authoritative
- D-17: Health synced via MultiplayerSynchronizer at 20 Hz
- D-18: Single basic enemy type (melee, chase)
- D-19: Fixed spawn points, 3–5 enemies for testing

---

## Deferred Ideas

- **Map Data Import Phase:** When Google Maps data for ERBA island is available
- **Multiple Enemy Types:** Phase 8+ (ranged, fast, armored)
- **Wave Spawning:** Phase 6 (loop timer and scaling)
- **Visual Feedback (VFX):** Phase 7+ (particles, screen shake, knockback)
- **HUD Event Wiring:** Phase 6+ (LIDAR, SUSPENSION indicators)

---

*Discussion Log — Phase 3*
*2026-05-09*
