# HANDOVER — CARIAD Final Presentation "Roge-Like"

This document contains EVERYTHING needed to build our final presentation deck.
It is the single source of truth. If slide content conflicts with anything else,
this document wins.

---

## 1. CONTEXT & GRADING (why the deck looks the way it does)

- **Course:** Designing Gamified Systems — Prof. Dr. Benedikt Morschheuser, University of Bamberg
- **Project brief:** "Project 2: CARIAD — Designing an Immersive In-Car Game for Families on Road Trips"
- **Presentation:** 20 July 2026, in person. **Language: English.** ~15 min group part
  + 2 min individual reflection per person + ~10 min Q&A. Every team member presents.
- **Team (4):** Christian (PM & Sound) · Moritz (Lead Architect & Main Developer) ·
  Okan (Head of Design) · Jan (AI Design & Integration)

**Grading criteria the deck must visibly serve** (30P group + 20P individual):
1. Fit to the provided CARIAD task
2. Elaboration/maturity of concept & prototype
3. Game-/playfulness of the approach
4. Conducted evaluation (we tested at the Gamification EXPO, 26 June 2026)
5. Connection to and understanding of literature, theory and lecture
6. Structure, form, media use (images, videos, graphics)
7. Time management
8. Individual contribution to the team project

**The official brief asked for:** a game (concept) that transforms long car journeys
into engaging entertainment for families, using the car's sensors:
- Inputs (pick 1+): LiDAR/Radar (object detection), interior camera, V2X
- Outputs (pick 2+): LED matrix headlights, active suspension, climate control,
  seat massage, V2X
- Target: families on road trips; game must satisfy the psychological need for
  **social interaction**; play in 10–15-minute chunks on 1h+ trips.

---

## 2. THE GAME — FACT SHEET

**Title:** Roge-Like (working title)
**One-liner:** A top-down 3-player co-op roguelike (built in Godot 4, LAN) where each
player is a car that evolves into a battle robot — and the car's real sensor systems
(AC, engine, seat massage, suspension, LiDAR, V2X) are the game's feedback language,
shown on an always-visible CARIAD dashboard HUD.

### Core loop
LOBBY → ROOM 1 → ROOM 2 → ROOM 3 (BOSS) →
kill enemies → collect XP → team levels up → each player picks 1 of 3 cards →
collect car-part pickups → unlock weapons → loop ends (boss dead or 15 min) →
next loop starts HARDER (enemy HP/damage/density scale up; weapons & XP carry over).

### Roles (each player picks 1 role + 1 element, both exclusive)
| Role | Unique trait | Stage-2 signature ability |
|---|---|---|
| **Tank** | Higher HP, melee aura | Burst aura (larger, timed) |
| **Speedster** | Faster movement, dash | Afterimage dash (damaging trail) |
| **Engineer** | Passive team heal, deploys heal-drone | Repair pulse (burst heal to all) |

### Elements
| Element | Effect | CARIAD HUD trigger |
|---|---|---|
| 🔥 Fire | Burn DoT on hit + periodic damage ring | ENGINE OVERHEAT |
| ❄️ Ice | Slow on hit + slowing ground trail | AC COLD |
| 🌿 Earth | Passive 1 HP/s team heal + pushback | SEAT MASSAGE |

### Evolution (universal 3-stage arc, XP thresholds)
Stage 1 **Normal Car** (drives/fights like a car) → Stage 2 **Proto-Bot** (full
transform, robot movement, skeletal/unfinished look, signature ability unlocks) →
Stage 3 **Full AutoBot** (fully armored, all abilities, max power).

### Weapons (all car-themed, auto-aim/auto-fire, max 6 active, unlocked via car-part drops)
| Weapon | Behavior |
|---|---|
| Screws & Bolts (starter) | Single projectile → nearest enemy, 0.5 s |
| Exhaust Flames | 60° fire cone, 1.5 s |
| Spinning Tires | 3 orbiting hitboxes, passive |
| Antenna Beam | 500 px piercing laser, 2.0 s |
| Horn Shockwave | 360° burst, 3.0 s |
| Airbag Shield | Absorbs 1 lethal hit, passive |

### Progression & co-op
- Team XP pool (thresholds scale ×1/×2/×3 with party size); on level-up ALL
  players pick simultaneously from their own 1-of-3 cards (weapon unlock /
  weapon upgrade lvl 1–3 / element upgrade / stat boost) → deck-building, builds
  discussed as a team.
- Downed & revive: HP→0 = downed; teammate holds E ~3.5 s → revive at 50 HP;
  max 1 revive per loop; all down = game over.

### The CARIAD HUD (our unique selling point)
Always-visible side panel on every screen, simulating real car sensor outputs.
Every major game event fires the matching indicator on ALL screens simultaneously
(fades after ~3 s):
- AC ❄️ COLD ← Ice ability used
- ENGINE 🔥 OVERHEAT ← Fire ability used
- SEAT MASSAGE 🌿 ACTIVE ← Earth healing
- SUSPENSION ⚡ IMPACT ← a player takes a big hit
- LIDAR 🔴 OBJECT DETECTED ← enemy spawns (LiDAR's ONLY role in the game)
- V2X 📡 SIGNAL SENT ← periodic auto-trigger

### World: OSM → route → rooms (important, tell it exactly like this)
- The route through the game IS a real Bamberg route taken from OpenStreetMap:
  **ERBA island (Regnitz river banks) → Bamberg Altstadt (medieval street grid) →
  Burg Altenburg (hilltop fortress)** — the city the team studies in.
- How OSM actually shaped the rooms: real building footprints were abstracted into
  rectangular obstacle blocks; real street outlines became the walkable corridors.
  ERBA is open/grassy like the island park, Altstadt is tight corridors between
  house blocks, the Burg is stone courtyards.
- Tech evolution: first a runtime OSM room generator; in Phase 9 replaced by **17
  hand-tuned TileMap sub-rooms** (3 locations × 5 sub-rooms + connectors, sub-room 5
  of the Burg = boss arena) — hardcoded from the OSM abstractions for determinism
  and multiplayer performance. Custom tile art per biome (AI-generated via Lovable).
- LiDAR is NOT part of world-building — it only drives enemy-spawn events/indicator.

### Tech facts (for credibility / Q&A)
- Godot 4, GDScript, ENet LAN multiplayer, 1–3 players, host-authoritative
  (all enemy AI/bullets/XP simulated on host; clients replicate).
- 20 Hz snapshot replication with client-side exponential interpolation
  (synced_position pattern) — fixed the visible 20-fps stutter of remote players.
- Renderer constraint: CPUParticles2D only (gl_compatibility renderer).
- Sound: data-driven cue table, 16-voice pool + 4 reserved priority voices for
  must-hear stingers; music per location, composed in Ableton.
- 15-min loop timer, per-loop difficulty scaling, boss with 3 HP-threshold phases
  + mob swarms.

### Development journey
11 official phases + 2 unofficial ones (present as "11 phases + what came after"):
1. Network foundation & lobby (ENet, host/join, role+element lobby)
2. Player movement & sync
3. Room 1, enemy AI, combat core (navmesh, downed/revive)
4. Weapons & item pickups (Vampire-Survivors loop)
5. Roles & elements
6. XP, level-up cards & evolution
7. CarHUD, loop timer & difficulty scaling
8. Rooms 2 & 3, boss
9. Map overhaul — TileMap sub-rooms (OSM → hardcoded layouts)
10. Juicy feedback — visual & gameplay polish
11. Whole-game sound design pass
12. *(unofficial)* Full art & asset overhaul — placeholders → final art: hand-drawn
    sprites (Okan), Lovable world tiles + particles (Jan), comic UI restyle,
    shadows/walk-bounce/HP-bars, per-player cameras
13. *(unofficial)* Feel, debugging & optimization pass — netcode interpolation fix,
    boss telegraphs, offscreen arrows, audio conversion (63 MB WAV → 5.6 MB OGG),
    playtesting & plan adjustments

### Evaluation (one line, on the Impact slide)
Tested with real participants at the **Gamification EXPO (26 June 2026**, part of the
25-years WIAI celebration): visitors played the prototype on multiple laptops; we
observed sessions and collected feedback. [TEAM: add 1–2 concrete findings here.]

### Impact points
- **Business:** in-car gaming is a growing market (9 of 10 Gen-Z play regularly;
  strong demand esp. in China — CARIAD 2024); co-op sensor-driven games are a
  differentiator for the connected-car cabin.
- **Society:** shared play instead of parallel solo screens — the game is built
  around social interaction (co-op roles, revives, team XP, team card picks).
- **End users:** families on road trips get 10–15-min co-op sessions per loop that
  match the brief's play-time chunks; roles let different skill levels play together.

---

## 2b. ASSET INVENTORY — WHO MADE WHAT (complete, with filenames)

Only a curated subset of images is uploaded to this project. This inventory lists
the COMPLETE asset base of the game so you understand the true scope of each
person's work (use these numbers and names on the individual slides S20–S25 and
the pipeline slide S16). Filenames without extension; all are .png unless noted.

### Okan — hand-drawn game art (≈230 files)
**Player characters — 41 sprites** (3 roles × 3 evolution stages, idle + walk cycles):
- Tank: tank_1_idle, tank_1_walk_1–2 · tank_2_idle, tank_2_walk_1–3 · tank_3_idle, tank_3_walk_1–4
- Speedster: speedster_1_idle, speedster_1_walk_1–2 · speedster_2_idle, speedster_2_walk_1–4 · speedster_3_idle, speedster_3_walk_1–8
- Engineer: engineer_1_idle, engineer_1_walk_1–3 · engineer_2_idle, engineer_2_walk_1–3 · engineer_3_idle, engineer_3_walk_1–3
- Plus: heal_drone_1, heal_drone_2 (Engineer's drone)

**Enemies — 18 sprites:**
- enemy_1_idle + enemy_1_walk_1–3 · enemy_2_idle + enemy_2_walk_1–3
- elite_idle + elite_walk_1–5 · boss_idle + boss_walk_1–3

**Weapons — 141 animation frames** (grouped by weapon):
- beam_01–15 (Antenna Beam) · exhaust_01–12 (Exhaust Flames) · screw_01–06
  (Screws & Bolts) · tire_01–03 (Spinning Tires) · shockwave_01–04 (Horn
  Shockwave) · shield3_01–36 + shield6_01–65 (Airbag Shield animation sets)

**XP orb — 27 files:** xp_orb + xp_orb_anim_01–26 (26-frame animation)

**Weapon UI icons — 5:** icon_screws_and_bolts, icon_exhaust_flames,
icon_spinning_tires, icon_antenna_beam, icon_horn_shockwave

### Jan — AI-generated & curated (Lovable + Claude Code)
**World tiles/props via Lovable — 29 files, 3 biomes:**
- ERBA (8): floor-connector, floor-grass-b, flower, obstacle-rocks, prop-pebbles,
  wall-cap-a, wall-cap-b, wall-face-b
- Altstadt (10): floor-cobble-b, floor-cobble-c, floor-grass-patch,
  floor-transition-carpet, obstacle-roof, prop-barrel, prop-crate, prop-lantern,
  wall-cap-a, wall-face-a
- Burg Altenburg (11): floor-a, floor-b, prop-banner, prop-barrel, prop-chest,
  prop-crate, prop-knight, prop-shield, prop-torch, wall-cap-a, wall-face-a

**VFX particle textures — 21:** badge_eco, badge_sport, brake_puff, brakeline,
ember, heal_plus, levelup, overdrive_spark, pebble, poof, repair_plus, revive,
rim_cold, rim_hot, rim_massage, scan_ring, shard, spark, speed_streak,
speedline, star

**UI (built with Claude Code):** card overlay, CarHUD panel styling, comic UI
restyle + element/stat icons (5): icon_element, icon_stat_cooldown,
icon_stat_damage, icon_stat_maxhp, icon_stat_speed

**Element ground art:** skid_fire, skid_ice, skid_earth, ice_trail_1–2

### Christian — sound, made in Ableton
**Music — 5 location/menu tracks:** lobby.mp3 (menu/lobby), Erba.ogg (Room 1),
altstadt1.mp3 + altstadt2.ogg (Room 2), Altenburg.ogg (Room 3 / boss approach)
**SFX — 22 cues (.wav):** antenna_beam, boss_phase, dash, downed, enemy_die,
evolution, exhaust_flames, game_over, horn_shockwave, kill_fanfare, level_up,
revive, run_start, shield_up, shield_up_s2, shoot, transition, ui_click,
ui_confirm, ui_navigate, xp_arrive, xp_arrive_2

### Moritz — no art assets; his output is the codebase itself
Architecture, GSD tooling/workflow, netcode, core systems (~all .gd gameplay code).

---

## 3. THEORY — sprinkle, don't lecture

No standalone theory slide. One anchor + small corner callouts:

- **Anchor (Concept slide footer):** "Designed through 3 lenses: Self-Determination
  Theory · Flow · Meaningful Play."
- **Meaningful Play (Salen & Zimmerman)** — feedback must be *discernable* and
  *integrated*. THE core thesis: our CARIAD HUD makes every game action discernable
  (indicator fires) and integrated (into the car context). Use on the CARIAD-HUD
  slide and Juicy-Feedback slide.
- **Self-Determination Theory (Deci & Ryan; Rigby & Ryan)** — Autonomy: role/element/
  card build choices (Roles + Cards slides). Competence: juicy feedback, level-ups.
  Relatedness: co-op, revives, team XP — literally the brief's "social interaction"
  requirement (Challenge slide).
- **Flow (Csikszentmihalyi)** — per-loop difficulty scaling keeps challenge matched
  to skill; 10–15-min chunks (Core-Loop slide).
- **Meta-frame (mention once, e.g., Journey slide):** our process followed
  Morschheuser et al. (2018), "How to design gamification" — analysis → ideation →
  design → prototype → evaluation. It is the professor's own method.

---

## 4. THE DECK — 28 slides

Global style: 16:9. English. Clean and minimal, Apple-Keynote-like — simple
layouts, lots of whitespace, colors derived from our game art. No decorative
icons or emojis; visuals are exclusively our game assets plus clean native
mockups/diagrams (no screenshots exist — the running game is shown live in the
final demo). Big images, minimal text (max ~5 short bullets/slide), consistent
title style. Every slide gets speaker notes. Asset filenames referenced below
exist in the uploaded project files.

### PART 0 — Opening
**S1 · Title & Team** — Game logo/name + subtitle "A co-op in-car roguelike for
CARIAD". 4 names. Background: Hintergrund.png.
**S2 · The Challenge & Analysis** — the brief in 3 bullets (families on road trips,
use car sensors as I/O, social interaction as core need); target users (parents +
kids, driver excluded — no automated driving); 10–15-min chunks. Callout: SDT
Relatedness = the brief's requirement.

### PART 1 — Concept, Journey & Team
**S3 · Our Concept / The Pitch** — one big statement: "The car doesn't just host the
game — the car IS the game's feedback system." Co-op car→robot roguelike; 3 players,
3 roles, 3 elements; every action echoes on the CARIAD dashboard. Footer strip:
3 lenses. (We pitched 3 ideas in interim 1; this won because it maximizes
playfulness + sensor use.)
**S4 · Development Journey** — horizontal timeline of the 11 phases + "12–13: art
overhaul & polish" (use the phase list from section 2). Mark interim presentations
and EXPO on the timeline. One line: process = Morschheuser et al. (2018).
**S5 · Team & How We Worked** — 2×2 grid: Christian (PM & Sound) · Moritz (Lead
Architect & Main Dev) · Okan (Head of Design) · Jan (AI Design & Integration).
Below, a full-width team block: "Game concept, theme, mechanics, elements, roles —
every core decision was made together."

### PART 2 — Game Mechanics
**S6 · Core Loop** — circular loop diagram: Fight → XP → Level-up → Card pick →
stronger → harder loop. Element/role touchpoints as small icons on the ring
(icon_element.png, stat icons). Callout: Flow (difficulty scales per loop).
**S7 · Input ↔ Output Mapping** — two-column diagram. LEFT (real-world data in):
LiDAR → enemy spawns ONLY; OSM map data → shapes the whole world/route. RIGHT
(car outputs = HUD): AC→Ice, ENGINE→Fire, SEAT MASSAGE→Earth, SUSPENSION→big hit,
V2X→interval, LIDAR indicator→spawn. This slide proves brief-fit (inputs 1+,
outputs 2+ ✓).
**S8 · Roles** — 3 columns (Tank/Speedster/Engineer): role + trait + signature
ability (use table in section 2). Small idle sprites as column headers
(tank_1_idle.png, speedster_1_idle.png, engineer_1_idle.png). Callout: SDT Autonomy.
**S9 · Elements** — 3 columns Fire/Ice/Earth: gameplay effect + HUD trigger. Use
skid_fire.png / skid_ice.png / skid_earth.png as visuals.
**S10 · Evolution** — big horizontal 3-step: Car → Proto-Bot → Full AutoBot with
one sprite per stage (e.g., tank_1_idle → tank_2_idle → tank_3_idle) and arrows;
one line what changes per stage.
**S11 · Weapons** — grid of the 6 weapons with icons (icon_screws_and_bolts.png,
icon_exhaust_flames.png, icon_spinning_tires.png, icon_antenna_beam.png,
icon_horn_shockwave.png + one for airbag if provided) + one line each; footer:
"unlocked via car-part drops, max 6 active, all auto-fire."

### PART 3 — Game Design Elements
**S12 · XP, Cards & Deck-Building** — clean native mockup of the 1-of-3 card pick
(3 card shapes side by side); how it works, card types, stacking builds; team
picks simultaneously → build discussion. Callout: SDT Autonomy + Competence.
**S13 · CARIAD HUD in Detail** — rebuild the HUD side panel as a clean native
mockup (6 labeled indicator boxes) with annotation callouts: what triggers each,
grouped vs. individual firing, broadcast to ALL screens simultaneously, fade
after ~3 s. Callout: Meaningful Play — discernable + integrated feedback. THE
theory payoff slide.
**S14 · World Building: OSM → Route → Rooms** — 3-step visual: (1) stylized map
sketch of Bamberg with the route ERBA → Altstadt → Burg Altenburg marked (native
shapes, no real map image needed), (2) abstraction (building footprints → blocks,
streets → corridors), (3) the tile art per biome (erba_*, altstadt_*, burg_*
tile samples as 3 boards). Mention: 17 sub-rooms, boss arena = Burg sub-room 5;
runtime generator → hardcoded for determinism. Explicitly: LiDAR is NOT
world-building.

### PART 4 — Game Feel
**S15 · Juicy Feedback I — Combat & Progression** — what "juice" means (immediate,
discernable, satisfying feedback); grid of examples: hit-flash, tiered impact
(spark/squash/ring), hit-stop on kill, capped screen shake, death burst, XP-orb
magnetism + travel-to-bar, level-up burst, evolution transform moment. Use VFX
textures (spark.png, star.png, ember.png, levelup.png, poof.png). Callout: SDT
Competence + Meaningful Play.
**S16 · Juicy Feedback II — Asset Pipeline** — flow diagram: concept/art direction
(Okan) → AI generation (Lovable: world tiles, particles; Claude Code: UI & icons)
→ curation ("hard ausgesiebt" — most generations rejected) → import → integration
in Godot. Show 1 before/after (a plain colored placeholder shape drawn natively
vs. a final sprite, e.g., tank_3_idle.png).

### PART 5 — Individual Contributions (graded; 1 reflection line each, first person)
**S17 · Christian I — Project Management** — coordination & timeline, CARIAD-brief
alignment, steered the asset plan (defined WHAT sprites were needed and what to
AI-generate — curated Okan's and Jan's pipelines), debugging & playtesting,
adjusted the plan as reality hit. Reflection line placeholder.
**S18 · Christian II — Development & Sound** — coding contributions; complete sound
identity made in **Ableton**: location music (ERBA/Altstadt/Burg tracks), SFX, and
the audio pass (cue table, priority voices). Reflection line placeholder.
**S19 · Moritz — Architecture & Main Coding** — set up the entire project
architecture: Godot project structure, GSD workflow/tooling, git discipline;
host-authoritative multiplayer model; main coder across core systems (netcode,
combat, rooms, boss, HUD plumbing). Reflection line placeholder.
**S20 · Okan I — Art Direction & Roles** — the game's visual handwriting; hand-drawn
character art: 3 roles × 3 evolution stages (show the 9 idle sprites as a 3×3
grid). Implemented his art in the project himself. Reflection line placeholder.
**S21 · Okan II — Enemies, Weapons & XP Orb** — enemy_1_idle, enemy_2_idle,
elite_idle, boss_idle (+ walk cycles exist); weapon art (show one strong weapon
sheet, e.g., the beam frames) and the 26-frame XP-orb animation (show as strip).
Reflection line placeholder.
**S22 · Okan III — Juicy Feedback: what we watched for** — the design rules behind
the juice: feedback must be discernable + integrated; pooled/capped effects so
swarm fights stay readable; team-visible broadcasts for shared moments; local
hit-stop (never global time_scale); CPUParticles-only constraint; cleanup — no
leaks over a 15-min loop. (Feel design = Okan; particle textures = Jan.)
Reflection line placeholder.
**S23 · Jan I — AI R&D & Pipeline** — evaluated which AI tool fits which asset
class (Lovable vs. Claude Code vs. others); built the generation workflow; tight
iteration loop with Okan (style matching). Reflection line placeholder.
**S24 · Jan II — World-Building (Lovable)** — 29 tiles/props across 3 biomes:
ERBA (8) / Altstadt (10) / Burg (11) — floors, walls, props (barrel, lantern,
knight, torch, chest…). Show a 3-column tile board per biome. Implemented in the
TileMaps himself. Reflection line placeholder.
**S25 · Jan III — Particles + UI** — 21 VFX particle textures (spark, ember, star,
shard, heal_plus, levelup, revive, poof, rim effects, speedlines, badges…);
UI system: card overlay + CarHUD styling + element/stat icons — **UI & icons
built with Claude Code**. Reflection line placeholder.

### PART 6 — Impact, Close & Demo
**S26 · Impact** — 3 columns business/society/end-users (use section 2 impact
points). Bottom line: "Tested with real participants at the Gamification EXPO
(26 June 2026)." [+ 1–2 findings from the team]
**S27 · Closing & Roadmap** — what's next: online play (Tailscale/dedicated),
more content (roles, elements, bosses), mobile-friendly input. Thank you + repo
line. Q&A transition.
**S28 · Live Demo — Finale** — near-empty slide: game title + "Let's play."
(Live demo on laptops.)

---

## 5. OPEN ITEMS THE TEAM MUST FILL
- [ ] 8 reflection lines (2 per person is safer: 1 learning + 1 challenge) — S17–S25
- [ ] 1–2 concrete EXPO findings — S26
- [ ] The 3 pitched ideas from interim 1 (names/one-liners) — S3
- [ ] Speaker assignment for group slides (S1–S16, S26–S28)
