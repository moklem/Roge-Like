# CARIAD Final Presentation — Complete Outline (v5)

**Course:** Designing Gamified Systems (Prof. Morschheuser, Uni Bamberg)
**Project 2:** CARIAD — Immersive In-Car Game for Families on Road Trips
**Team (4):** Okan · Jan · Moritz · Christian · **Language: English**
**Format:** ~15 min group deck + individual reflections (2 min/person) + Q&A

**Theory approach:** No standalone theory slide. Anchor the 3 lenses once on the
Concept slide, then *sprinkle* small callouts where they fit:
SDT (Autonomy/Competence/Relatedness) · Flow (challenge-skill balance) ·
Meaningful Play (Salen & Zimmerman: feedback must be *discernable + integrated*).
Meta-frame = Morschheuser et al. (2018) gamification engineering method.

*Speaker assignment for the group slides is still open — decide with the team.
In the Individual part each slide is owned by the named person.*

---

## PART 0 — Opening
1. **Title & Team** — CARIAD challenge in one line, the 4 names.
2. **The Challenge & Analysis** — families on road trips, CARIAD sensor tech, target
   user/persona, core need = *social interaction*. Sprinkle: SDT Relatedness.

## PART 1 — Concept, Journey & Team
3. **Our Concept / The Pitch** — co-op car→robot roguelike; the car's sensors *become*
   the game's feedback language; 3 pitched ideas → chosen one. Footer strip: "Designed
   through 3 lenses: SDT · Flow · Meaningful Play".
4. **Development Journey** — 11 official phases (Network → Combat → Roles/Elements →
   XP/Evolution → HUD/Loop → Rooms/Boss → Map overhaul → Juicy Feedback → Sound) **+
   Phase 12–13** bundling everything after: full art & asset overhaul (placeholders →
   final) and feel/polish/optimization pass.
5. **Team & How We Worked** — 4 roles on one slide + **team-decisions block**: "Game
   concept, theme, mechanics, elements & roles — every core decision made together."

## PART 2 — Game Mechanics (player experience)
6. **Core Loop** — loop diagram (Kill → XP → Level → Card → harder), element/role
   touchpoints on the loop. Sprinkle: Flow.
7. **Input ↔ Output Mapping** — two real-world data inputs drive the game:
   **LiDAR** (object detection) → enemy spawns only, and **OSM map data** → shapes the
   whole game world/route. Outputs = the CARIAD HUD: AC→Ice, ENGINE→Fire, SEAT
   MASSAGE→Earth, SUSPENSION→hit, V2X→interval, LIDAR indicator→spawn.
8. **Roles: Tank / Speedster / Engineer** — one slide, 3 columns: role + its effect/
   signature ability. Sprites already shown in Okan's part. Sprinkle: SDT Autonomy.
9. **Elements: Fire / Ice / Earth** — effect + HUD trigger per element.
10. **Evolution: Car → Proto-Bot → Full AutoBot** — the 3 stages with sprites.
11. **Weapons** — 6 car-part weapons + pickup unlock, weapon file/icons.

## PART 3 — Game Design Elements (systems we engineered)
12. **XP, Level-Up Cards & Deck-Building** — card overlay in detail, build variety.
    Sprinkle: SDT Autonomy.
13. **CARIAD HUD in Detail** — always-visible panel; which indicators are grouped vs. fire
    individually; broadcast to all screens. Sprinkle: Meaningful Play (integrated feedback).
14. **World Building: OSM → Route → Rooms** — the route *emerges from OSM*: a real
    Bamberg path (ERBA island on the Regnitz → Altstadt medieval street grid → Burg
    Altenburg fortress). How OSM actually shaped the rooms: building footprints →
    obstacle blocks, street outlines → walkable corridors; first a runtime OSM room
    generator, then hardcoded into 17 TileMap sub-rooms for determinism/performance.
    (LiDAR is *not* part of world-building — it only drives enemy spawns.)

## PART 4 — Game Feel
15. **Juicy Feedback I — Combat & Progression** — hit-flash, hit-stop, death burst, screen
    shake, XP magnetism, level-up burst, evolution transform. Sprinkle: Competence + Meaningful Play.
16. **Juicy Feedback II — Asset Pipeline** — Lovable + Claude Code flow: prompt → generate →
    import → replace placeholders → polish UI.

## PART 5 — Individual Contributions (graded: 2 min / person, incl. 1 reflection line each)

**Christian — Project Management & Sound (2)**
17. **Project Management** — coordination, timeline, CARIAD-brief alignment, **steered the
    asset plan** (what sprites were needed / what to AI-generate), **plus debugging,
    playtesting and adjusting the plan as work progressed**.
18. **Development & Sound Design** — coding contributions + **sound made in Ableton**
    (music tracks, SFX, audio pass).

**Moritz — Lead Architect & Main Developer (1)**
19. **Architecture & Main Coding** — set up the whole project architecture (GSD workflow &
    tooling), host-authoritative net model, and was the main coder across core systems.

**Okan — Head of Design (3, curated — not all 230 assets)**
20. **Art Direction & Roles** — one idle sprite per stage (Tank/Speedster/Engineer × 3
    stages = 9 idles); the handwriting.
21. **Enemies & Weapons** — enemy/elite/boss idles + one strong weapon file + XP-orb animation.
22. **Juicy Feedback — what we watched for** — discernable+integrated feedback ·
    pooled/capped for readability · team-visible broadcasts · local hit-stop (never
    time_scale) · CPUParticles only · cleanup/no leaks. *(feel/design = Okan; particle
    assets = Jan)*

**Jan — AI Design & Integration (3)**
23. **AI R&D & Pipeline** — which AI tool does what, Lovable workflow, close coordination with Okan.
24. **World-Building (Lovable)** — 29 tiles/props across ERBA (8) / Altstadt (10) / Burg (11).
25. **Particles + UI** — 21 VFX particles + UI system (card overlay, CarHUD) + element/stat
    icons (weapon icons excluded — Okan's domain). **UI & icons built with Claude Code.**

## PART 6 — Impact, Close & Demo
26. **Impact** — business (in-car gaming market, Gen Z), society (family bonding),
    end-users. One line: tested with real participants at the Gamification EXPO.
27. **Closing & Roadmap** — what's next (online via Tailscale, more content), thanks.
28. **Live Prototype Demo — Finale** — play the running game live; Q&A happens at the
    machine.

---

### Timing reality
28 slides. Individual section (17–25) ≈ the graded 2-min-per-person part. Group part
(1–16, 26–28 = 19 slides) for ~15 min. Ending on the live demo as the finale.

### Open before drafting slide content
- Group-slide speaker assignment (Parts 0–4, 6) — decide with team.
- Jan particles: kept on slide 25 with icons+UI (consolidated).
- Evaluation: folded as one line on slide 26 (not a standalone slide).
