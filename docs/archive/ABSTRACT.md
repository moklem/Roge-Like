# AutoBonk — A Co-op In-Car Roguelike Where the Car Is the Feedback System

*Christian · Moritz · Okan · Jan — Designing Gamified Systems, University of Bamberg*

---

AutoBonk is a three-player cooperative top-down roguelike, built in Godot 4 for the CARIAD design brief: entertain families on long car journeys in ten-to-fifteen-minute sessions, using the vehicle's own sensors and actuators. Rather than treating the car as a screen that merely hosts a game, we made **the car the game's feedback system.**

**[FIGURE 1 — Combat, later in a run]**

Each player permanently commits to one of three exclusive roles — Tank, Speedster, Engineer — and to one of three elements: Fire burns on hit, Ice slows, Earth heals the team passively. Because roles are exclusive, cooperation is structural rather than optional. A player at zero HP goes down rather than dying, and a teammate revives them by holding R nearby, once per arena. If all three go down at once, the run ends.

**[FIGURE 2 — Lobby: role & element selection]**

Play runs through three biomes abstracted from a real OpenStreetMap route through Bamberg: the ERBA island, the Altstadt, and Burg Altenburg. Each is subdivided into five arenas of three enemy waves, ending in a boss fight; defeating the boss begins the next loop, scaled harder.

**[FIGURE 3 — An ERBA arena]**

Two reinforcement loops drive engagement. Second to second, kills drop XP orbs that magnetise into one shared team pool, with thresholds scaling by party size, accompanied by roughly thirty-five juice effects. Minute to minute, the team levels up together and every player simultaneously picks one of three cards: a weapon unlock, a weapon upgrade, an element upgrade, or a stat boost. All five weapons auto-aim, are earned exclusively through these cards, and only three can be active at once, so builds get negotiated out loud. Cars evolve across three stages — Car → Proto-Bot → Full AutoBot — each unlocking the role's signature ability.

**[FIGURE 4 — Level-up card overlay]**
**[FIGURE 5 — Evolution stages, three screenshots]**

The vehicle integration is the selling point. A permanently visible CARIAD panel maps game events onto real car outputs: Ice fires *AC COLD*, Fire *AC HOT*, Earth healing *SEAT MASSAGE*, heavy damage *SUSPENSION IMPACT*, enemy spawns *LIDAR OBJECT DETECTED*. Every event broadcasts to all screens, so one player's action lights up everybody's dashboard. Driver Mode runs the other way, letting the car act on the game: once per arena the vehicle's state shifts for a few seconds and hits all three players at once — ECO speeds them up, SPORT halves their speed, REPAIR heals, OVERDRIVE boosts damage. Nobody picks it, so the team adapts together.

**[FIGURE 6 — CARIAD HUD panel]**

The game is host-authoritative over LAN, with a stateless event bus keeping the HUD synchronised across peers and snapshot interpolation smoothing remote players at 20 Hz. It was playtested at the Gamification EXPO in June 2026.

*(~405 words)*

---

# Screenshot Brief

Six plain in-game screenshots, taken during a normal run. Nothing staged or composited — just play and capture when the moment comes up. Full window, as the game ships.

### FIGURE 1 — Combat, later in a run
**What:** A busy fight with all three players on screen, ideally once everyone has evolved and has a few weapons running.
**Why:** Opens the abstract — should show co-op, action and the CARIAD panel at once.
**When:** Late in a loop, mid-wave. Take several over a run and keep the best one.

### FIGURE 2 — Lobby: role & element selection
**What:** All three players connected, each on a different role and a different element.
**Why:** Shows role exclusivity and the two-axis choice immediately.
**When:** Just before everyone readies up.

### FIGURE 3 — An ERBA arena
**What:** A Room 1 arena with enough of the tileset visible to show the biome art, players spread out, wave counter visible.
**Why:** Establishes the world-building and the OSM→biome pipeline.
**When:** Early in a wave, before the screen fills up — this one is about the space, not the action.

### FIGURE 4 — Level-up card overlay
**What:** The 1-of-3 pick overlay while it's open.
**Why:** Makes the deck-building point concrete and shows weapons come from cards.
**When:** Any team level-up. If the three cards happen to be different types, better — but take whatever comes up.

### FIGURE 5 — Evolution stages
**What:** Three screenshots of the same role at Stage 1, Stage 2 and Stage 3 — placed in the document as three images side by side, not merged into one.
**Why:** The Car → Proto-Bot → AutoBot arc is the strongest visual hook.
**When:** Right after each transform, over the course of one run.

### FIGURE 6 — CARIAD HUD panel
**What:** The panel with several indicators lit, plus the loop and wave labels.
**Why:** The brief-fit evidence — one input, multiple outputs.
**When:** During a heavy fight, when hits and abilities are firing in quick succession — that's when several indicators overlap on their own. Indicators fade after ~3 s, so expect a few attempts.

### Optional, if space allows
- **Boss fight in Burg Altenburg.**
- **OSM route → biome comparison** — the real Bamberg route beside the three tilesets.
