# Phase 9: Map Overhaul — TileMap Sub-Rooms - Context

**Gathered:** 2026-06-24
**Status:** Ready for planning

<domain>
## Phase Boundary

Replace the current polygon-based single-room system (OSMRoomGenerator + Game.tscn StaticBody2D walls) with a TileMap-based sub-room system. Each of the 3 locations (ERBA, Bamberg Altstadt, Burg Altenburg) has 5 playable sub-rooms plus a short connector corridor to the next location. Room 3's 5th sub-room is the boss arena. All geometry is hardcoded — no OSM API calls at runtime. Kenney Roguelike Modern City + Tiny Dungeon + 1-Bit Pack tiles are used as placeholders, swappable for custom ChatGPT-generated assets.

**Not in Phase 9 scope:**
- New gameplay mechanics (weapons, roles, elements, XP)
- Enemy balancing or boss changes
- ChatGPT tile generation — Kenney tiles are the placeholder, generation happens separately
- Full open-world continuous map — locations remain separate scenes with corridor transitions between them
- Minimap or map UI overlay

</domain>

<decisions>
## Implementation Decisions

### Camera System

- **D-01:** `Camera2D` node added to `Player.tscn`. Enabled only for the locally authoritative player: `$Camera2D.enabled = is_multiplayer_authority()`. No network sync of camera position. Each machine shows its own player's view.
- **D-02:** Camera follows player smoothly within sub-rooms. Sub-rooms are larger than 800×600 — camera scrolls. Zoom level TBD by planner (start at 1.0, adjust for playability).
- **D-03:** Camera limits (`limit_left`, `limit_right`, `limit_top`, `limit_bottom`) are set per sub-room so the camera never scrolls outside the sub-room boundaries.

### Sub-Room Layout System

- **D-04:** All sub-room geometry is **code-generated** from hardcoded coordinate arrays in GDScript. No hand-painting in Godot editor. A `RoomBuilder.gd` script reads layout data (tile positions, wall rects, obstacle rects) and calls `TileMap.set_cell()` to place tiles at runtime.
- **D-05:** Layout data is derived from real OSM geometry (manually abstracted by the implementer from OpenStreetMap). High-level extraction — building footprints become rectangular obstacle blocks, street outlines become walkable corridors. Not 1:1 pixel-accurate.
- **D-06:** Each sub-room is defined as a dictionary: `{ "floor": [...rects...], "walls": [...rects...], "obstacles": [...rects...], "exit_dir": Vector2i, "spawn_points": [...positions...] }`.
- **D-07:** `OSMRoomGenerator.gd` is **deleted entirely**. `Game.tscn` boundary wall StaticBody2D nodes are **removed**. One unified system (TileMap + RoomBuilder) handles all geometry.

### Sub-Room Progression

- **D-08:** Each sub-room has one **exit passage** that is blocked by wall tiles at start. After all enemies are cleared, the host removes those wall tiles via RPC (`@rpc("call_local", "reliable")`), opening the gap. Clients receive the same RPC and see the wall disappear simultaneously.
- **D-09:** Sub-rooms are numbered 1–5 within each location. Sub-room 5 of Room 3 is the boss arena (boss spawns on enter, no normal enemies before boss).
- **D-10:** A `SubRoomManager.gd` (or extension of `Game.gd`) tracks `current_sub_room: int` (1–5) per location. Transition increments this counter.

### Location-to-Location Transition (ERBA → Altstadt → Burg)

- **D-11:** After clearing sub-room 5 of a location, players enter a **short corridor sub-room (sub-room 6 / connector)** that visually represents the journey between locations (road, bridge, path). No enemies spawn here — it is a pure walking corridor.
- **D-12:** At the end of the connector corridor, a brief **fade** triggers the scene change to the next location (Room 2 / Room 3). The existing `_transition_to_room()` RPC is reused for the actual scene switch; the connector is the approach animation.
- **D-13:** Connector sub-room geometry is simple — a long horizontal or vertical corridor with Kenney road/path tiles. No OSM basis needed for connectors.

### TileMap Asset Mapping

- **D-14:** **Room 1 (ERBA) and Room 2 (Altstadt):** Use `Roguelike Modern City` tileset. Floor = asphalt/grass mix (dystopian overgrown feel). Walls = brick/building tiles. Obstacles = building roof tiles (top-down view of buildings).
- **D-15:** **Room 3 (Burg Altenburg):** Use `Tiny Dungeon` tileset. Floor = stone/cobblestone. Walls = castle stone walls. Obstacles = tower/turret tiles.
- **D-16:** **Connectors:** Use road/path tiles from Roguelike Modern City for ERBA→Altstadt connector; stone path tiles from Tiny Dungeon for Altstadt→Burg connector.
- **D-17:** All Kenney tiles live under `res://assets/kenney/`. Paths used in TileSet resources: `res://assets/kenney/roguelike-modern-city/Tilemap/tilemap_packed.png` and `res://assets/kenney/tiny-dungeon/Tilemap/tilemap_packed.png`.
- **D-18:** Tile size is **16×16 px** for both packs. Sub-rooms are designed in tile-grid units (e.g., 60×40 tiles = 960×640 px per sub-room).

### Style Direction

- **D-19:** Visual feel is **dystopian overgrown city** — ERBA and Altstadt mix grass tiles into asphalt, suggesting vegetation reclaiming the city. Not clean/polished — intentionally gritty.
- **D-20:** Walls use thick solid tile blocks (same visual weight as current Polygon2D walls). No thin-line walls. Buildings are solid blocks seen from above.
- **D-21:** Kenney tiles are placeholders. Asset paths in TileSet are swappable 1:1 — ChatGPT-generated custom tiles can replace them later without code changes.

### Claude's Discretion

- Exact sub-room dimensions in tiles (planner tunes per-location)
- Which specific tile indices from Kenney tilesheets map to floor/wall/obstacle categories
- Whether to use `TileMapLayer` (Godot 4.3+) or classic `TileMap` node depending on project Godot version
- NavigationRegion2D bake strategy for TileMap-based collision (may use TileMap's built-in navigation layer instead of a separate NavigationPolygon)
- Exact OSM coordinate abstraction per sub-room — planner extracts from OSM and simplifies

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Prior Phase Architecture

- `.planning/phases/08-rooms-2-3-boss/08-CONTEXT.md` — D-01–D-04: current room visibility/collision system; D-03: `_transition_to_room()` RPC pattern (reused in Phase 9); D-06: NavMesh bake pattern
- `.planning/phases/07-carhud-loop-timer-difficulty-scaling/07-CONTEXT.md` — D-17: `GameState.start_next_loop()` hook; difficulty scaling
- `.planning/phases/01-network-foundation-and-lobby/01-CONTEXT.md` — RPC discipline (`@rpc("call_local", "reliable")` for simultaneous state changes)

### Live Code (read before modifying)

- `scenes/Game.gd` — `_transition_to_room()` (line ~129), `current_room`, `_spawn_enemies()`, `_bake_navmesh()` — all must be extended for sub-room system
- `scenes/Game.tscn` — Existing Room1/Room2/Room3 node structure + TileMap + NavigationRegion2D (all being replaced/refactored)
- `scenes/OSMRoomGenerator.gd` — **Being deleted** — read to understand what to remove from Game.gd `_ready()` (lines 89–95)
- `scenes/Player.tscn` + `scenes/Player.gd` — Camera2D being added here; check existing node structure

### Kenney Assets

- `assets/kenney/roguelike-modern-city/Tilemap/tilemap_packed.png` — Rooms 1+2 tileset source
- `assets/kenney/tiny-dungeon/Tilemap/tilemap_packed.png` — Room 3 tileset source
- `assets/kenney/roguelike-modern-city/Tilesheet.txt` — Tile index reference for Modern City
- `assets/kenney/tiny-dungeon/Tilesheet.txt` — Tile index reference for Tiny Dungeon

### Project Requirements

- `.planning/ROADMAP.md` §Phase 9 — MAP-01–MAP-11 (11 requirements); pitfall watch: camera+multiplayer, NavMesh rebake, TileMap collision layers, sub-room transition authority
- `.planning/REQUIREMENTS.md` §Rooms — ROOM-01–07 (must still be satisfied after overhaul)

### Visual Reference

- `WhatsApp Image 2026-06-14 at 17.46.53 (1).jpeg` — AutoBonk.io title screen: dystopian cartoon city style, target visual direction
- `WhatsApp Image 2026-06-20 at 19.30.42.jpeg`, `19.30.43.jpeg`, `19.30.43 (1).jpeg` — Robot character style references

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- **`_transition_to_room(next_room: int)` in `Game.gd`** — Host-authoritative RPC that hides/shows rooms and teleports players. Phase 9 extends this to also handle sub-room transitions (a lighter version of the same pattern).
- **`$Room1/SpawnPoints` marker pattern** — Sub-rooms will follow the same `SpawnPoints` child structure for player teleport on sub-room entry.
- **`_bake_navmesh()` in `Game.gd`** — Currently bakes `Room{N}/NavigationRegion2D`. Needs to target the active sub-room's navmesh after TileMap geometry is placed.
- **`GameState.start_next_loop()`** — Still called on boss defeat; Phase 9 doesn't change this.
- **Existing `TileMap` node in `Room1`** — There is already a `TileMap` child node in Room1 with a `TileSet` (currently empty/placeholder). This can be the starting point for the new system.

### Established Patterns

- **Host-authoritative gate opening:** Exit passage removal uses `@rpc("call_local", "reliable")` — never let clients open gates locally.
- **Collision layer disable on hidden rooms:** Phase 8 established the pattern of disabling StaticBody2D collision on hidden rooms. TileMap collision layers must follow the same disable/enable pattern.
- **NavMesh bake after geometry placement:** Always bake AFTER all tiles are placed — baking before placement produces no-navmesh result.
- **`call_deferred()` for physics-safe spawns:** Any spawning triggered from within physics callbacks uses `call_deferred()`.

### Integration Points

- **`Game.gd`:** Add `current_sub_room: int = 1`. Add `_transition_to_sub_room(next: int)` method. Add `_open_exit_passage()` RPC. Wire enemy-cleared check to call `_open_exit_passage()` instead of `_transition_to_room()` for sub-room progression.
- **`Player.tscn`:** Add `Camera2D` node with `enabled = false` by default; `Player.gd._ready()` sets `enabled = is_multiplayer_authority()`.
- **`RoomBuilder.gd` (new):** Reads layout dictionaries and calls `TileMap.set_cell()`. Called by `Game.gd` on sub-room entry.
- **`OSMRoomGenerator.gd`:** Delete. Remove its instantiation from `Game.gd._ready()` (lines 89–95).

</code_context>

<specifics>
## Specific Ideas

- **Dystopian overgrown style:** Mix Kenney grass tiles INTO asphalt areas — like plants growing through cracked pavement. Not a clean green park, not a clean city — in between.
- **OSM authenticity:** ERBA should feel like an island (surrounded by implied water or boundary walls shaped like the Regnitz river banks). Altstadt should have the feel of a medieval street grid (narrow corridors between building blocks). Burg Altenburg should feel like a stone fortress with multiple courtyards.
- **5 sub-rooms per location:** ~1 minute of combat each = 5 min per location. Sub-rooms escalate in enemy density within a location (sub-room 1 = lightest, sub-room 5 = heaviest before boss).
- **Kenney → ChatGPT swap:** All TileSet paths go through one `const` or resource file so that swapping the entire visual theme later is a 1-line change per tileset.
- **Reference:** AutoBonk.io (WhatsApp image) shows the exact cartoon dystopian city top-down aesthetic we're targeting.

</specifics>

<deferred>
## Deferred Ideas

- **ChatGPT-generated custom tiles** — Replacing Kenney placeholders with AI-generated art in the exact dystopian cartoon style. Separate task after Phase 9 is playable.
- **Minimap** — Showing sub-room layout would help players navigate. Out of scope for Phase 9.
- **Animated tiles** — Flickering lights, flowing water, moving grass. Kenney tiles are static; animation pass is post-demo polish.
- **Per-location ambient sound** — ERBA = urban park sounds, Altstadt = city noise, Burg = wind/stone echo. Audio pass is post-demo.
- **Full open-world continuous map** — Walking seamlessly from ERBA to Altstadt to Burg without any scene boundary. The connector corridor approach is a middle ground; a true open world is a separate project.

</deferred>

---

*Phase: 9-map-overhaul-tilemap-sub-rooms*
*Context gathered: 2026-06-24*
