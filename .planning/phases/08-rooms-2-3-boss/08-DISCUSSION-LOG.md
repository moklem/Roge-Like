# Phase 8: Rooms 2 & 3, Boss - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-06-22
**Phase:** 08-rooms-2-3-boss
**Areas discussed:** Room transition mechanism, Room 2 & 3 geometry, Boss design, Mob swarm composition

---

## Room Transition Mechanism

| Option | Description | Selected |
|--------|-------------|----------|
| Hide/show nodes in Game.tscn | All 3 rooms as children; active room visible, others hidden. No scene reload. | ✓ |
| Separate scenes per room | Each room is its own .tscn; transition = remove + instantiate. | |
| You decide | Claude picks architecture. | |

**User's choice:** Hide/show nodes in Game.tscn

---

| Option | Description | Selected |
|--------|-------------|----------|
| All enemies dead (auto-trigger) | Host detects 0 enemies, fires transition automatically. | ✓ |
| All enemies dead + E to continue | Prompt appears after clear; gives players time to collect XP. | |
| You decide | Claude picks based on GameState/Game.gd. | |

**User's choice:** All enemies dead (auto-trigger)

---

| Option | Description | Selected |
|--------|-------------|----------|
| Teleport players + despawn pickups | Move players to new room spawn points via RPC; queue_free pickups/orbs. | ✓ |
| Fade to black, then new room | Brief screen fade using CanvasLayer AnimationPlayer. | |
| You decide | Claude handles cleanup. | |

**User's choice:** Teleport players to new room spawn points, despawn pickups

---

## Room 2 & 3 Geometry

| Option | Description | Selected |
|--------|-------------|----------|
| H-shaped or T-shaped corridors | Central hub + corridor arms as wall segments. | |
| Two rooms connected by bottleneck | Two open areas + narrow connecting passage. | |
| One room with internal wall lanes | Same outer boundary as Room 1, internal walls create lanes. | |
| You decide | Claude picks the geometry. | |

**User's choice (freeform):** "I want to give you this open-source map data so that you construct it based on those — check it." User wants OSM data to be fetched and used as the source for room geometry.
**Notes:** Both Room 2 (Bamberg Altstadt) and Room 3 (Burg Altenburg) will be derived from OSM/real-world map data. Researcher fetches the data; planner decides exact abstraction after inspecting it.

---

| Option | Description | Selected |
|--------|-------------|----------|
| Streets become corridors, buildings become walls | Read map data, translate main streets to floor polygons, buildings to StaticBody2D walls. | |
| Simplified abstraction inspired by the map | Hand-craft 5–10 wall segments capturing the feel without 1:1 accuracy. | |
| OSM-derived (Burg Altenburg castle layout) | Use actual castle map data for the arena shape. | ✓ |

**User's choice (Room 3):** OSM-derived from Burg Altenburg castle layout
**User's choice (Room 2):** OSM-derived — "fetch the data first and then let's see what works" (researcher decides approach after inspecting OSM data)

---

## Boss Design

| Option | Description | Selected |
|--------|-------------|----------|
| 500 HP | Beatable in ~2–3 min. Good for demo pacing. | |
| 300 HP | Fast fight; good for demo with spectators. | |
| 1000 HP | Long fight; phases feel distinct. | ✓ |
| You decide | Claude picks for 15-minute loop target. | |

**User's choice:** 1000 HP

---

| Option | Description | Selected |
|--------|-------------|----------|
| 2 phases: charge+melee → ranged+faster (at 50% HP) | Clear behavioral shift at one threshold. | |
| 3 phases: slow+melee → fast+ranged → enrage+all | Phase 1 (100–66%), Phase 2 (66–33%), Phase 3 (33–0%) enrage. | ✓ |
| 2 phases with elemental attacks | Boss alternates fire-burst and ice-slow cone. | |

**User's choice:** 3 phases — slow+melee → fast+ranged → enrage+all

---

| Option | Description | Selected |
|--------|-------------|----------|
| Large dark-colored rectangle with visible health bar | 2–3× enemy size, dark color, health bar above. | |
| You decide | Claude picks a placeholder visual. | ✓ |

**User's choice:** You decide

---

## Mob Swarm Composition

| Option | Description | Selected |
|--------|-------------|----------|
| Between phase transitions (at 66% and 33% HP) | Swarm spawns at the moment boss enters Phase 2 and Phase 3. | ✓ |
| On a timer during boss fight | Continuous periodic waves throughout the fight. | |
| Both: phase transitions + periodic timer | Swarm at transitions + extra waves during Phase 3. | |

**User's choice:** Between phase transitions (at 66% and 33% HP)

---

| Option | Description | Selected |
|--------|-------------|----------|
| Normal enemies only, scaled per loop | 5 + (loop_number × 3) normal enemies. No new types needed. | |
| Mix of normal + elite enemies | Mostly normal + 1 elite per swarm (2 in Phase 3 swarm). | ✓ |
| You decide | Claude picks composition. | |

**User's choice:** Mix of normal + elite enemies

---

## Claude's Discretion

- Boss placeholder visual (size, color, shape — must distinguish from normal enemies and elite enemy)
- Boss melee charge distance and speed (Phase 1 tuning)
- Boss ranged projectile spread angle and speed (Phase 2 tuning)
- Whether boss briefly pauses attacks (~2s) when mob swarm spawns at phase transitions
- Exact Room 2 and Room 3 geometry derived from OSM data

## Deferred Ideas

- Visible boss phase transition cutscene/animation (screen flash on phase change) — post-demo polish
- Per-phase music or audio cues (Phase 3 enrage audio) — out of scope for placeholder build
- Room 2 mid-corridor ambush trigger (scripted spawns at checkpoint) — own feature, future phase
- Boss projectile element types (fire/ice projectiles triggering HUD indicators) — CARIAD tie-in, future phase
