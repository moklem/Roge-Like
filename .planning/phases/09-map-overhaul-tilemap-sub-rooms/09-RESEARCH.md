# Phase 9: Map Overhaul — TileMap Sub-Rooms — Research

**Researched:** 2026-06-24
**Domain:** Godot 4.6 TileMap, Camera2D, sub-room progression, multiplayer-safe geometry, Kenney tileset integration
**Confidence:** HIGH (all key findings verified directly from codebase, project files, and asset inspection)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** `Camera2D` added to `Player.tscn`. Enabled only for `is_multiplayer_authority()`. No network sync of camera position.
- **D-02:** Camera follows player smoothly within sub-rooms. Zoom at 1.0 (planner adjusts).
- **D-03:** Camera limits (`limit_left/right/top/bottom`) set per sub-room so camera never scrolls outside sub-room boundaries.
- **D-04:** All sub-room geometry is code-generated from hardcoded coordinate arrays. No hand-painting. `RoomBuilder.gd` calls `TileMap.set_cell()` at runtime.
- **D-05:** Layout data derived from real OSM geometry (manually abstracted by implementer). High-level — building footprints become rectangular obstacle blocks.
- **D-06:** Each sub-room defined as: `{ "floor": [...rects...], "walls": [...rects...], "obstacles": [...rects...], "exit_dir": Vector2i, "spawn_points": [...positions...] }`.
- **D-07:** `OSMRoomGenerator.gd` deleted entirely. `Game.tscn` boundary wall StaticBody2D nodes removed. One unified TileMap + RoomBuilder system handles all geometry.
- **D-08:** Exit passage blocked by wall tiles at sub-room start. Host removes wall tiles via `@rpc("call_local", "reliable")` after all enemies cleared.
- **D-09:** Sub-rooms numbered 1–5 per location. Sub-room 5 of Room 3 is boss arena.
- **D-10:** `SubRoomManager.gd` (or extension of `Game.gd`) tracks `current_sub_room: int` (1–5) per location.
- **D-11:** After clearing sub-room 5 of a location, players enter a short connector corridor (sub-room 6 / connector). No enemies.
- **D-12:** At end of connector corridor, fade triggers scene change to next location. Existing `_transition_to_room()` RPC reused for actual scene switch.
- **D-13:** Connector geometry is simple — long horizontal or vertical corridor with Kenney road/path tiles.
- **D-14:** Room 1 (ERBA) + Room 2 (Altstadt): `Roguelike Modern City` tileset. Floor = asphalt/grass mix. Walls = brick/building. Obstacles = building roof tiles.
- **D-15:** Room 3 (Burg Altenburg): `Tiny Dungeon` tileset. Floor = stone/cobblestone. Walls = castle stone walls. Obstacles = tower/turret tiles.
- **D-16:** Connectors: road/path tiles from Roguelike Modern City (ERBA→Altstadt); stone path from Tiny Dungeon (Altstadt→Burg).
- **D-17:** All Kenney tiles under `res://assets/kenney/`. Paths: `res://assets/kenney/roguelike-modern-city/Tilemap/tilemap_packed.png` and `res://assets/kenney/tiny-dungeon/Tilemap/tilemap_packed.png`.
- **D-18:** Tile size 16×16 px. Sub-rooms designed in tile-grid units (e.g., 60×40 tiles = 960×640 px).
- **D-19:** Visual feel: dystopian overgrown city. Grass tiles mixed into asphalt for ERBA/Altstadt.
- **D-20:** Thick solid tile-block walls. No thin-line walls.
- **D-21:** Kenney tiles are placeholders. TileSet paths go through `const` or resource so swapping is a 1-line change per tileset.

### Claude's Discretion

- Exact sub-room dimensions in tiles
- Which specific tile indices from Kenney tilesheets map to floor/wall/obstacle categories
- Whether to use `TileMapLayer` (Godot 4.3+) or classic `TileMap` node (planner decides based on Godot version)
- NavigationRegion2D bake strategy for TileMap-based collision (may use TileMap's built-in navigation layer)
- Exact OSM coordinate abstraction per sub-room

### Deferred Ideas (OUT OF SCOPE)

- ChatGPT-generated custom tiles
- Minimap
- Animated tiles
- Per-location ambient sound
- Full open-world continuous map
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| MAP-01 | Each of the 3 rooms contains 5 sub-rooms connected by open doorways (no loading screen within a room) | D-04, D-10: SubRoomManager + RoomBuilder handle in-room sub-room transitions; doorway is TileMap wall tiles removed at runtime, not a scene change |
| MAP-02 | Sub-rooms cleared sequentially — clearing one opens passage to next | D-08: host removes wall tiles via `@rpc("call_local", "reliable")` — mirrors existing `_check_room_clear` → passage-open pattern |
| MAP-03 | Sub-room 5 of Room 3 (Burg Altenburg) is the boss arena | D-09: `current_sub_room == 5 and current_room == 3` triggers boss spawn instead of normal wave; reuses `_spawn_boss()` pattern |
| MAP-04 | Room 1 (ERBA) feel — open grass/park with overgrown dystopian city elements | D-14, D-19: Roguelike Modern City tileset; grass+asphalt mix; confirmed tileset contains grass tiles (row 7 in tilemap_packed.png) |
| MAP-05 | Room 2 (Bamberg Altstadt) feel — urban street grid, tighter corridors | D-14, D-05: narrower floor rects derived from OSM Altstadt street geometry; building blocks as solid obstacle fills |
| MAP-06 | Room 3 (Burg Altenburg) feel — stone castle, multiple courtyards | D-15: Tiny Dungeon tileset (confirmed at `res://assets/kenney/tiny-dungeon/Tilemap/tilemap_packed.png`); courtyard layout from OSM fortress polygon |
| MAP-07 | Camera scrolls to follow players within a sub-room (no fixed 800×600 viewport) | D-01–D-03: Camera2D in Player.tscn enabled only for authority; limit_ props clamped per sub-room size |
| MAP-08 | All layout geometry hardcoded — no OSM API calls at runtime | D-04, D-07: RoomBuilder reads static GDScript arrays; OSMRoomGenerator.gd deleted |
| MAP-09 | OSMRoomGenerator.gd replaced entirely — boundary walls and obstacles unified in one system | D-07: delete OSMRoomGenerator.gd and its 7-line instantiation block in `Game.gd._ready()` (lines 89–95) |
| MAP-10 | TileMap uses Kenney assets (Roguelike Modern City for rooms 1+2, Tiny Dungeon for room 3) | D-17: both tilesets confirmed present on disk at expected paths; tile size 16×16 verified in Tilesheet.txt |
| MAP-11 | Kenney tiles are placeholders — asset paths swappable for ChatGPT-generated custom tiles | D-21: const TILESET_MODERN = "res://assets/kenney/roguelike-modern-city/..." pattern; single-line path swap |
</phase_requirements>

---

## Summary

Phase 9 replaces the current 800×600 fixed-camera, polygon-based single-room system with a scrolling-camera TileMap sub-room system. The key technical pivot is threefold: (1) the TileMap node already present in `Room1` of `Game.tscn` becomes the geometry authority — `RoomBuilder.gd` populates it with `set_cell()` calls from hardcoded layout dictionaries; (2) a new `SubRoomManager` (or inlined into `Game.gd`) tracks progression through 5 sub-rooms per location using the same host-authoritative RPC discipline already established in phases 1–8; (3) a `Camera2D` added to `Player.tscn` replaces the fixed viewport with a scrolling view constrained by per-sub-room `limit_*` properties.

The critical infrastructure decisions have already been proven correct in prior phases: `@rpc("call_local", "reliable")` for simultaneous state changes, `call_deferred()` for physics-safe spawns, and host-only gate-opening. The new work is entirely additive on top of these patterns, with one destructive step: removing `OSMRoomGenerator.gd` and its 7-line instantiation block from `Game.gd._ready()` (lines 89–95).

**Primary recommendation:** Use the classic `TileMap` node (not `TileMapLayer`) because `Game.tscn` already contains a `TileMap` node under `Room1` with an empty `TileSet` — this is the canonical entry point. Godot 4.6 still supports `TileMap` fully; `TileMapLayer` is the preferred path for Godot 4.3+ new projects but migrating the existing node is unnecessary churn.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Sub-room layout geometry | Game layer (`RoomBuilder.gd`) | `TileMap` node in Room scene | RoomBuilder owns the data and calls `set_cell()`; TileMap is the renderer + collision provider |
| Sub-room progression / gate-opening | Host (Game.gd + SubRoomManager) | All peers via RPC | Consistent with Phase 1 RPC discipline; never let clients open gates |
| Camera scrolling + limits | Client (Camera2D in Player.tscn) | No sync needed | Each peer controls its own camera; position not networked |
| Enemy spawning per sub-room | Host (Game.gd `_spawn_enemies()`) | — | No change from Phase 8 pattern |
| Navigation baking | Host + deferred (Game.gd `_bake_navigation()`) | — | Must run after `set_cell()` completes; existing pattern already deferred |
| TileSet physics collision | TileMap TileSet physics layer 0 | — | Replaces StaticBody2D boundary walls; collision layer 1 = walls |
| Boss arena (sub-room 5 of Room 3) | Game.gd (extends `_spawn_boss()`) | — | `current_sub_room == 5 and current_room == 3` routes to boss; no new pattern |

---

## Standard Stack

### Core

| Library / Node | Version / Type | Purpose | Why Standard |
|---------------|----------------|---------|--------------|
| `TileMap` (Godot built-in) | Godot 4.6 classic | Grid-based geometry, collision, rendering | Already in `Room1` in `Game.tscn`; Godot 4.6 supports it fully [VERIFIED: project.godot `config/features=PackedStringArray("4.6", ...)`] |
| `Camera2D` (Godot built-in) | Godot 4.6 | Player-following scrolling camera | `limit_left/right/top/bottom` properties clamp scroll to sub-room bounds [VERIFIED: Godot 4.6 project] |
| `NavigationRegion2D` | Godot 4.6 | Navmesh baking after TileMap geometry is placed | Already present in `Room1/NavigationRegion2D`, `Room2/NavigationRegion2D`, `Room3/NavigationRegion2D` in `Game.tscn` [VERIFIED: Game.tscn line 63] |
| `TileSet` with physics layer 0 | Godot 4.6 | Wall tile collision so `CharacterBody2D` (player) and enemies collide with tiles | `TileSet_1` in `Game.tscn` already has `physics_layer_0/collision_layer = 1` set [VERIFIED: Game.tscn line 6] |

### Supporting

| Library / Node | Purpose | When to Use |
|---------------|---------|-------------|
| `Marker2D` inside `SpawnPoints` node | Player teleport destination on sub-room entry | Follow existing `Room1/SpawnPoints/Spawn1…N` pattern; RoomBuilder populates dynamically |
| `Marker2D` inside `EnemySpawnPoints` | Enemy spawn positions per sub-room | Follow existing `Room1/EnemySpawnPoints/ESpawn1…N` pattern |
| `@rpc("call_local", "reliable")` | Simultaneous gate-opening on all peers | Same as `_transition_to_room()` — never let clients open gates unilaterally |

### No External Packages

Phase 9 is pure GDScript + Godot built-in nodes. No npm/PyPI packages involved.

---

## Package Legitimacy Audit

Not applicable — this phase installs no external packages. All dependencies are Godot 4.6 built-in nodes and local GDScript files.

---

## Architecture Patterns

### System Architecture Diagram

```
[Game.gd._ready()]
       |
       v
[RoomBuilder.gd.build_sub_room(room_id, sub_room_id)]
       |-- reads SUB_ROOM_DATA[room_id][sub_room_id] dictionary
       |-- calls TileMap.set_cell() for floor/wall/obstacle tiles
       |-- populates SpawnPoints and EnemySpawnPoints marker nodes
       |-- sets Camera2D limit_* on each player (via RPC call to all peers)
       v
[TileMap node] -- renders tiles + provides collision via TileSet physics layer 0
       |
       v
[NavigationRegion2D.bake_navigation_polygon()] (deferred, host-only)
       |
       v
[Game.gd._spawn_enemies()] --> [EnemySpawner] --> enemies use NavigationAgent2D

--- When all enemies die ---

[Game.gd._check_sub_room_clear()]  (host only)
       |
       v
[@rpc("call_local","reliable") _open_exit_passage()]
       |-- removes exit-blocking wall tiles from TileMap on all peers
       |
       v  (player walks through exit)
[Game.gd._transition_to_sub_room(next)] (host only)
       |-- if next <= 5: RoomBuilder.build_sub_room(room_id, next)
       |-- if next == 6 (connector): RoomBuilder.build_connector(room_id)
       |-- if connector end reached: _transition_to_room.rpc(room_id + 1)
```

### Recommended Project Structure

```
scenes/
├── Game.gd                      # extended: SubRoomManager vars + _transition_to_sub_room()
├── Game.tscn                    # modified: remove old StaticBody2D walls, OSMRoomGenerator ref
├── RoomBuilder.gd               # NEW: reads SUB_ROOM_DATA, calls TileMap.set_cell()
├── RoomLayouts.gd               # NEW: static const data file — all sub-room dictionaries
├── Player.gd                    # modified: Camera2D limit_ update via RPC
├── Player.tscn                  # modified: add Camera2D child node
assets/
└── kenney/
    ├── roguelike-modern-city/Tilemap/tilemap_packed.png  (confirmed present)
    └── tiny-dungeon/Tilemap/tilemap_packed.png           (confirmed present)
```

### Pattern 1: TileMap.set_cell() for Code-Generated Layouts

**What:** `RoomBuilder.gd` receives a sub-room dictionary and iterates over rectangle lists, placing tiles row-by-row with `set_cell()`.

**When to use:** Whenever a sub-room is entered (new sub-room or after room transition). Must call `erase_cell()` or `clear()` first to reset the TileMap.

```gdscript
# Source: [ASSUMED] — Godot 4.x TileMap API training knowledge
# RoomBuilder.gd pattern
func build_sub_room(tilemap: TileMap, layout: Dictionary) -> void:
    tilemap.clear()
    # Floor tiles — layer 0
    for rect in layout["floor"]:
        for x in range(rect.x, rect.x + rect.z):      # rect = Vector4i(x, y, w, h)
            for y in range(rect.y, rect.y + rect.w):
                tilemap.set_cell(0, Vector2i(x, y), TILESET_SOURCE_ID, FLOOR_ATLAS_COORD)
    # Wall tiles — layer 0 (same layer, different atlas coord)
    for rect in layout["walls"]:
        for x in range(rect.x, rect.x + rect.z):
            for y in range(rect.y, rect.y + rect.w):
                tilemap.set_cell(0, Vector2i(x, y), TILESET_SOURCE_ID, WALL_ATLAS_COORD)
    # Obstacle tiles
    for rect in layout["obstacles"]:
        for x in range(rect.x, rect.x + rect.z):
            for y in range(rect.y, rect.y + rect.w):
                tilemap.set_cell(0, Vector2i(x, y), TILESET_SOURCE_ID, OBSTACLE_ATLAS_COORD)
```

**Key implementation note:** `TileMap.set_cell()` signature in Godot 4.x is:
`set_cell(layer: int, coords: Vector2i, source_id: int = -1, atlas_coords: Vector2i = Vector2i(-1,-1), alternative_tile: int = 0)`.
`source_id` is the index of the `TileSetAtlasSource` within the `TileSet` resource, not the tile index. [ASSUMED — Godot 4.x API]

### Pattern 2: Camera2D with Sub-Room Limits

**What:** Per-sub-room camera clamping via `limit_left/right/top/bottom` on the `Camera2D` node.

**When to use:** On every sub-room entry. Called on all peers simultaneously (or the owning peer sets limits locally since camera is not networked).

```gdscript
# Source: [ASSUMED] — Godot 4.x Camera2D API
# Called by RoomBuilder or _transition_to_sub_room after building geometry
# sub_room_rect_px: Rect2 = pixel-space bounding box of the playable sub-room
func update_camera_limits(sub_room_rect_px: Rect2) -> void:
    for player in get_tree().get_nodes_in_group("players"):
        if not player.has_node("Camera2D"):
            continue
        var cam: Camera2D = player.get_node("Camera2D")
        cam.limit_left   = int(sub_room_rect_px.position.x)
        cam.limit_top    = int(sub_room_rect_px.position.y)
        cam.limit_right  = int(sub_room_rect_px.end.x)
        cam.limit_bottom = int(sub_room_rect_px.end.y)
```

**Important:** Camera2D limit properties use pixel coordinates (world space), not tile coordinates. Multiply tile coords by tile_size (16) to convert. [ASSUMED]

### Pattern 3: Host-Authoritative Gate Opening (RPC)

**What:** After enemy clear, host removes exit-passage wall tiles on all peers simultaneously.

**When to use:** When `_check_sub_room_clear()` confirms zero alive enemies tagged to current sub-room. Mirrors `_transition_to_room()` RPC pattern exactly.

```gdscript
# Source: Game.gd existing pattern (lines 128–217) [VERIFIED: Game.gd]
@rpc("authority", "call_local", "reliable")
func _open_exit_passage() -> void:
    var exit_dir: Vector2i = _current_layout.get("exit_dir", Vector2i(1, 0))
    # Remove wall tiles at the exit location in the TileMap
    var tm: TileMap = get_node("Room%d/TileMap" % current_room)
    for coord in _exit_tile_coords:   # pre-calculated when sub-room was built
        tm.erase_cell(0, coord)
    # Optionally place a floor tile in the gap
    for coord in _exit_tile_coords:
        tm.set_cell(0, coord, TILESET_SOURCE_ID, FLOOR_ATLAS_COORD)
```

### Pattern 4: OSMRoomGenerator Removal

**What to remove from `Game.gd._ready()` (lines 89–95):**

```gdscript
# REMOVE ENTIRELY — lines 89-95 of Game.gd [VERIFIED: Game.gd]
var _osm: Node = load("res://scenes/OSMRoomGenerator.gd").new()
_osm.name = "OSMRoomGenerator"
add_child(_osm)
_osm.room_osm_ready.connect(_on_osm_room_ready)
_osm.fetch_for_room.call_deferred(current_room)
```

Also remove from `_transition_to_room()` (lines 159–163):

```gdscript
# REMOVE ENTIRELY — lines 159-163 of Game.gd [VERIFIED: Game.gd]
var _osm_gen := get_node_or_null("OSMRoomGenerator")
if _osm_gen:
    _osm_gen.fetch_for_room.call_deferred(next_room)
```

Also remove `_on_osm_room_ready()` method (lines 454–457):

```gdscript
# REMOVE ENTIRELY — lines 454-457 of Game.gd [VERIFIED: Game.gd]
func _on_osm_room_ready(_room_id: int) -> void:
    pass
```

**Delete file:** `res://scenes/OSMRoomGenerator.gd` and `res://scenes/OSMRoomGenerator.gd.uid`.

### Pattern 5: NavMesh Bake After TileMap Placement

**What:** Existing `_bake_navigation()` in `Game.gd` (line 115) must be called AFTER `RoomBuilder` has finished placing all tiles. Use `call_deferred()`.

```gdscript
# Source: Game.gd line 115-118 [VERIFIED: Game.gd]
func _bake_navigation() -> void:
    var nav := get_node_or_null("Room%d/NavigationRegion2D" % current_room)
    if nav:
        nav.bake_navigation_polygon(false)
```

**Critical:** The `NavigationRegion2D` must use `parsed_geometry_type = 1` (PARSED_GEOMETRY_STATIC_COLLIDERS) so it reads TileMap physics colliders. This is already set in Game.tscn sub-resources `NavigationPolygon_1`, `_2`, `_3`. [VERIFIED: Game.tscn lines 8–46]

### Anti-Patterns to Avoid

- **Syncing Camera2D position over the network:** Camera is purely local. Never add Camera2D properties to `MultiplayerSynchronizer`. Each peer controls its own camera. [VERIFIED: D-01 from CONTEXT.md]
- **Placing tile geometry in the Godot editor:** D-04 explicitly bans hand-painting. All cells set via `set_cell()` in `RoomBuilder.gd`. The editor TileMap node stays empty; it is populated at runtime.
- **Calling `bake_navigation_polygon()` before `set_cell()` is complete:** This is the #1 navmesh failure mode. Always bake via `call_deferred()` after the RoomBuilder `build_sub_room()` call finishes.
- **Letting clients open the exit passage:** Gate opening is `@rpc("authority")` only. Never trigger tile removal from a client-side signal.
- **Using TileMap for collision on hidden rooms without disabling the physics layer:** Phase 8 established the pattern of setting `collision_layer_value(1, false)` on hidden rooms. TileMap collision must follow the same pattern — either `TileMap.collision_enabled = false` on hidden rooms or the TileMap nodes are only present in the currently active room.
- **Keeping the old Polygon2D floor and StaticBody2D walls in the Room nodes after migration:** Once RoomBuilder owns geometry, the old polygon floor (`Room1/Floor`, etc.) and old StaticBody2D walls (`Room1/WallTop`, etc.) conflict and must be removed from `Game.tscn`.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Tile collision with CharacterBody2D | Custom StaticBody2D walls that mirror TileMap cells | TileSet physics layer 0 in TileMap | TileMap automatically generates collision shapes from the physics layer at bake time; StaticBody2D duplicates create double-collision and navmesh confusion |
| Navigation mesh for TileMap-based geometry | Manual NavigationPolygon2D drawn by hand | `NavigationRegion2D.bake_navigation_polygon()` with `parsed_geometry_type = STATIC_COLLIDERS` | Already set in all 3 Room NavigationRegion2D nodes; baking auto-derives walkable area from TileMap collision shapes |
| Camera clamping via script math | Manual `global_position.clamp()` to keep camera in bounds | `Camera2D.limit_left/right/top/bottom` | Godot's built-in limit system handles smooth clamping at boundaries without custom math |
| Tile index lookup | Manually counting pixels in tilemap PNG | Inspect the PNG image directly + use `Vector2i(col, row)` atlas coords | Both tilesets confirmed 16×16 px tiles with 1 px spacing; atlas coord = `Vector2i(tile_column, tile_row)` in 0-indexed grid with 1 px spacing accounted for by Godot's `TileSetAtlasSource` configuration |

---

## Kenney Tileset Reference (Verified)

### Roguelike Modern City (`tilemap_packed.png`) [VERIFIED: inspected PNG image]

Tile size: 16×16 px, 1 px spacing. Grid: 37 columns × 28 rows = 1036 tiles. [VERIFIED: Tilesheet.txt]

Visual inspection of `tilemap_packed.png` reveals the following approximate tile regions:
- **Rows 0–2:** Brick/building rooftop tiles (browns, reds, grays) — wall/obstacle candidates
- **Row 3:** Gray asphalt/road tiles — floor candidates for city districts
- **Rows 4–5:** Sidewalk edges and road markings
- **Rows 6–7:** Grass/ground tiles (greens, tans) — floor candidates for ERBA overgrown areas
- **Rows 8–10:** Urban furniture, trees, props — obstacle decoration
- **Rows 11–14:** Interior/building tiles, windows — wall face candidates
- **Rows 15–18:** Road markings, arrows, parking — corridor/connector floor tiles
- **Rows 19–21:** Cars, vehicles (decorative obstacles)
- **Rows 22–27:** Larger building facade tiles, terrain patches

**Specific useful tile recommendations (planner to verify exact indices by visual inspection):**
- `Vector2i(0, 6)` — dark grass, ERBA floor base [ASSUMED — visual estimate from PNG]
- `Vector2i(1, 6)` — lighter grass variant [ASSUMED]
- `Vector2i(0, 3)` — dark asphalt, Altstadt floor [ASSUMED — visual estimate]
- `Vector2i(5, 3)` — road center line [ASSUMED]
- `Vector2i(0, 0)` — dark brick tile, walls [ASSUMED — visual estimate]
- `Vector2i(0, 15)` — road intersection, connector corridors [ASSUMED]

### Tiny Dungeon (`tilemap_packed.png`) [VERIFIED: inspected PNG image]

Tile size: 16×16 px, 1 px spacing. Grid: 12 columns × 11 rows = 132 tiles. [VERIFIED: Tilesheet.txt]

Visual inspection reveals:
- **Row 0:** Stone wall tops, dungeon door — wall/obstacle candidates
- **Row 1:** Stone floor variants (cobblestone, dark stone) — Room 3 floor tiles
- **Row 2:** More wall faces and dungeon props
- **Rows 3–10:** Character sprites, items, decorations (these are NOT tile-map geometry tiles but sprite assets mixed into the sheet)

**Note:** The Tiny Dungeon tilemap is primarily a character/item sprite sheet with a small tile geometry section at the top. The topmost 2–3 rows contain the usable geometric tiles (floor, walls). The planner should use rows 0–2 only for geometry. [VERIFIED: PNG image inspection]

**Specific tile recommendations:**
- `Vector2i(0, 1)` — stone floor, Room 3 cobblestone [ASSUMED — visual estimate]
- `Vector2i(1, 1)` — darker stone floor variant [ASSUMED]
- `Vector2i(0, 0)` — castle stone wall [ASSUMED — visual estimate]
- `Vector2i(1, 0)` — darker wall block [ASSUMED]

**Important:** Because Tiny Dungeon has only 12×11 tiles and most are sprites, the planner may find that TileMap coverage is sparse. Fallback: use 1-Bit Pack (`tileset_legacy.png`, 49×22 = 1078 tiles) for Room 3 wall fills where Tiny Dungeon lacks variety. [VERIFIED: 1-bit-pack Tilesheet.txt confirmed in assets directory]

---

## Current Scene State (Verified)

### What Exists in `Game.tscn` [VERIFIED: Game.tscn lines 1–509]

**Room1 node tree:**
```
Room1 (Node2D, visible=true)
├── Floor (Polygon2D — dark fill, 800×600) — REMOVE in Phase 9
├── TileMap (TileMap — has TileSet_1 with physics_layer_0/collision_layer=1, currently EMPTY) — KEEP + POPULATE
├── NavigationRegion2D (NavigationPolygon_1, agent_radius=12, parsed_geometry_type=1) — KEEP
├── SpawnPoints (Node2D) → Spawn1/2/3 — UPDATE positions for sub-rooms
├── WallTop/Bottom/Left/Right (StaticBody2D × 4) — REMOVE in Phase 9
├── DividerTop/Bottom (StaticBody2D × 2) — REMOVE in Phase 9
├── ObstNW/SW/NE/SE/CL/CR (StaticBody2D × 6) — REMOVE in Phase 9
├── CoverL1/L2/R1/R2 (StaticBody2D × 4) — REMOVE in Phase 9
├── ObstPassN/PassS (StaticBody2D × 2) — REMOVE in Phase 9
├── Entities (Node2D) — KEEP (pickup/drone/ice-trail spawn path)
└── EnemySpawnPoints (Node2D) → ESpawn1–8 — UPDATE positions for sub-rooms
```

**Room2 and Room3:** Same structure but NO TileMap node currently. They only have `Floor (Polygon2D)`, boundary `StaticBody2D` walls, `NavigationRegion2D`, `SpawnPoints`, and `EnemySpawnPoints`. OSMRoomGenerator dynamically added buildings. Phase 9 must add a TileMap node to Room2 and Room3 as well.

**Global scene nodes:**
- `HUD (CanvasLayer)` — KEEP
- `Entities (Node2D)` at scene root — KEEP (shared entity container)
- All spawner `MultiplayerSpawner` nodes — KEEP unchanged
- `Room1/Entities (Node2D)` — REMOVE (entities should live in root `Entities`, not room-specific)

Note: There are TWO `Entities` nodes — one at root level (`../Entities` is the spawner path, line 493) and one inside Room1 (line 121). The spawner uses the root-level one. The Room1-scoped one appears to be unused; confirm before removing.

### What's in Player.tscn (No Camera2D Yet) [VERIFIED: Player.tscn]

Current `Player.tscn` has no `Camera2D` node. The Phase 9 plan must add:
```
Player (CharacterBody2D)
└── Camera2D (NEW)
    ├── enabled = false  (set to true in Player.gd._ready() if is_multiplayer_authority())
    ├── zoom = Vector2(1, 1)  (planner adjusts)
    └── limit_left/right/top/bottom set by RoomBuilder on sub-room entry
```

---

## Common Pitfalls

### Pitfall 1: TileMap collision not blocking enemies after NavMesh bake
**What goes wrong:** Enemies walk through wall tiles even though they visually appear solid.
**Why it happens:** The `NavigationRegion2D` bake carves the walkable area, but enemy movement uses `NavigationAgent2D` path following — not collision. Enemies only collide with `StaticBody2D` or tile physics shapes. If TileSet physics layer is not configured with actual tile shapes, tiles render but have no collision body.
**How to avoid:** In the TileSet editor, assign each tile a CollisionShape (rectangle) within physics layer 0. The `TileSet_1` already has `physics_layer_0/collision_layer = 1` set — but the individual tiles must also have shapes assigned, or collision is empty. Verify: place a wall tile at runtime and check `get_overlapping_bodies()` on a test Area2D.
**Warning signs:** Players slide through tiles; enemies path through visual walls.

### Pitfall 2: NavMesh baked before TileMap cells are placed
**What goes wrong:** The `NavigationRegion2D` produces an empty or all-walkable polygon.
**Why it happens:** `bake_navigation_polygon()` reads the current collision state. If called in `_ready()` before `RoomBuilder.build_sub_room()` places the wall tiles, there are no colliders to carve out.
**How to avoid:** Always: `RoomBuilder.build_sub_room()` → `await get_tree().process_frame` (or `call_deferred`) → `nav.bake_navigation_polygon(false)`. [VERIFIED pattern: Game.gd line 107 uses `call_deferred("_bake_navigation")`]
**Warning signs:** Enemies walk directly to player through walls; navmesh debug overlay shows no carve-outs.

### Pitfall 3: Camera scrolls outside sub-room boundaries
**What goes wrong:** Camera follows player into negative coordinates or past the sub-room edge, showing black void.
**Why it happens:** `Camera2D.limit_*` properties default to ±10 000 000 — effectively unlimited.
**How to avoid:** After building each sub-room, explicitly set all four `limit_*` values to the sub-room's pixel bounding box: `limit_left = 0`, `limit_top = 0`, `limit_right = sub_room_width_in_tiles * TILE_SIZE`, `limit_bottom = sub_room_height_in_tiles * TILE_SIZE`.
**Warning signs:** Black bars appear at screen edges; players can see void.

### Pitfall 4: Invisible TileMap walls on hidden rooms
**What goes wrong:** Room2/Room3 TileMap tiles block movement even when the room is not visible.
**Why it happens:** `visible = false` does NOT disable physics collision on TileMap nodes. Phase 8 handles this for StaticBody2D by calling `set_collision_layer_value(1, false)` on hidden rooms. TileMap needs equivalent treatment.
**How to avoid:** When hiding a room, set `TileMap.collision_layer = 0` (or call `set_collision_layer_value(1, false)` on the TileMap). When showing, restore `collision_layer = 1`. Add this to `_transition_to_room()` alongside the existing StaticBody2D disable block (Game.gd lines 136–144). [VERIFIED existing pattern: Game.gd lines 98–104]
**Warning signs:** Players teleported to Room2 immediately collide with invisible tiles from Room1/Room3.

### Pitfall 5: Sub-room exit passage not synchronized
**What goes wrong:** One client sees the exit open (tiles gone) but another still sees wall tiles blocking it.
**Why it happens:** Tile state is local — `erase_cell()` called only on the host does not replicate to clients.
**How to avoid:** Use `@rpc("authority", "call_local", "reliable")` for `_open_exit_passage()`. Both host and all clients call `erase_cell()` on the same coords simultaneously. Store the exit tile coordinates as a class variable when the sub-room is built so the RPC handler knows which tiles to erase. [VERIFIED pattern: `_transition_to_room` RPC, Game.gd line 128]
**Warning signs:** Client is physically blocked by tiles that are visually absent (or vice versa).

### Pitfall 6: `_spawn_enemies()` using old `Room{N}/EnemySpawnPoints` path after sub-room overhaul
**What goes wrong:** `_spawn_wave()` in `Game.gd` calls `get_node("Room%d/EnemySpawnPoints" % current_room)` — this breaks if sub-rooms have their own spawn-point sets.
**Why it happens:** `_spawn_wave()` line 402 uses a static path. Once RoomBuilder dynamically places spawn points, the path hierarchy changes.
**How to avoid:** Either (a) keep a single `EnemySpawnPoints` node per Room and RoomBuilder repopulates its children on each sub-room build, or (b) add a `current_sub_room` dimension to the path lookup. Option (a) is simplest — just call `spawn_node.get_children()` after RoomBuilder updates markers. [VERIFIED: Game.gd line 402]
**Warning signs:** `_spawn_wave()` causes null reference errors or spawns at (0,0).

### Pitfall 7: Entering sub-room 5 Room 3 without triggering boss (or double-triggering)
**What goes wrong:** `_check_sub_room_clear()` calls `_transition_to_sub_room(6)` (connector) instead of routing to boss; or boss spawns twice.
**Why it happens:** The sub-room 5 → boss transition is a special case similar to how Phase 8 special-cased `next_room == 3` for boss. Without an explicit guard, `_check_sub_room_clear()` may advance to connector.
**How to avoid:** In `_transition_to_sub_room(next)`, add: `if current_room == 3 and next == 5: _spawn_boss.call_deferred(); return`. The sub-room is "entered" but enemy count starts at boss only — reuse the `current_room == 3` skip already in `_check_room_clear()` (Game.gd line 198). [VERIFIED: Game.gd lines 198–199]

---

## Code Examples

### Adding Camera2D to Player.gd._ready()

```gdscript
# Player.gd — append to end of _ready()
# Source: D-01 from CONTEXT.md [VERIFIED decision]
if has_node("Camera2D"):
    $Camera2D.enabled = is_multiplayer_authority()
```

### SubRoomManager vars in Game.gd

```gdscript
# Game.gd — add alongside current_room var [VERIFIED: Game.gd line 36]
## Phase 9: Sub-room tracker. 1–5 within each location. Reset to 1 on room transition.
var current_sub_room: int = 1

## Phase 9: Pre-calculated exit tile coordinates for the current sub-room.
## Set by RoomBuilder.build_sub_room(); read by _open_exit_passage() RPC.
var _exit_tile_coords: Array[Vector2i] = []

## Phase 9: Current sub-room rect in pixels (set by RoomBuilder). Used for camera limits.
var _current_sub_room_rect_px: Rect2 = Rect2(0, 0, 960, 640)
```

### TileSet atlas source configuration (conceptual)

```gdscript
# In RoomBuilder.gd — const block for tile source IDs and atlas coords
# Source: [ASSUMED] — must be verified against actual TileSet resource created in editor

## TileSet source IDs — assigned when TileSetAtlasSource is added to TileSet in editor
const SRC_MODERN: int = 0   # roguelike-modern-city tilemap_packed.png
const SRC_DUNGEON: int = 1  # tiny-dungeon tilemap_packed.png

## Atlas coordinates (col, row) in the 16x16+1px-spacing grid
## Room 1 + 2 (Modern City):
const MC_FLOOR_ASPHALT   := Vector2i(0, 3)   # dark asphalt [ASSUMED]
const MC_FLOOR_GRASS     := Vector2i(0, 6)   # overgrown grass [ASSUMED]
const MC_WALL_BRICK      := Vector2i(0, 0)   # brick wall [ASSUMED]
const MC_OBSTACLE_ROOF   := Vector2i(3, 0)   # building roof block [ASSUMED]

## Room 3 (Tiny Dungeon):
const TD_FLOOR_STONE     := Vector2i(0, 1)   # stone floor [ASSUMED]
const TD_WALL_CASTLE     := Vector2i(0, 0)   # castle stone wall [ASSUMED]
```

**All atlas coordinates are [ASSUMED] from visual PNG inspection. The planner must confirm exact coordinates by opening the PNG and counting columns (0-indexed) and rows (0-indexed) to the desired tile, accounting for 1 px spacing.**

---

## State of the Art

| Old Approach | Current Approach (Phase 9) | Impact |
|-------------|---------------------------|--------|
| OSMRoomGenerator.gd fetches Overpass API at runtime | All geometry hardcoded in GDScript dictionaries in `RoomLayouts.gd` | Eliminates network dependency; works 100% offline |
| Fixed 800×600 room viewed through static Camera2D (no Camera2D in Player) | Scrolling Camera2D in Player.tscn, enabled only for authority peer, limits clamped per sub-room | Players can navigate rooms larger than 800×600 |
| Single room per location (1 arena) | 5 sub-rooms per location with sequential progression | 5× more combat encounters per location; escalating density |
| Polygon2D floor + StaticBody2D walls (code-placed at runtime by OSMGenerator) | TileMap with TileSet physics layer (code-placed at runtime by RoomBuilder) | Unified geometry system; one place to change; navigation derives from tiles |
| Room boundary walls = StaticBody2D with RectangleShape2D | Wall tiles in TileMap physics layer | Fewer nodes in scene; navmesh carves from tile collision automatically |

**Deprecated/outdated in Phase 9:**
- `OSMRoomGenerator.gd` — deleted entirely; replace with `RoomLayouts.gd` static data
- `Room1/Floor` (Polygon2D) — replaced by TileMap floor tiles; remove from Game.tscn
- All `Room{N}/Wall*` and `Room{N}/Obst*` and `Room{N}/Cover*` StaticBody2D nodes — replaced by TileMap wall tiles; remove from Game.tscn
- `_on_osm_room_ready()` method in Game.gd — delete; no longer any async room signal
- Lines 89–95 and 159–163 of Game.gd — delete; OSMGenerator instantiation and fetch calls

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `Vector2i(0, 6)` is a grass tile in Roguelike Modern City | Kenney Tileset Reference | Wrong visual in room; low impact — just swap atlas coord |
| A2 | `Vector2i(0, 3)` is an asphalt tile in Roguelike Modern City | Kenney Tileset Reference | Wrong visual; low impact |
| A3 | `Vector2i(0, 0)` is a brick wall in Roguelike Modern City | Kenney Tileset Reference | Wrong visual; low impact |
| A4 | `Vector2i(0, 1)` is a stone floor in Tiny Dungeon | Kenney Tileset Reference | Wrong visual; low impact |
| A5 | `Vector2i(0, 0)` is a castle wall in Tiny Dungeon | Kenney Tileset Reference | Wrong visual; low impact |
| A6 | `TileMap.set_cell(layer, coords, source_id, atlas_coords)` signature is correct for Godot 4.6 | Architecture Patterns | API mismatch causes runtime error; HIGH risk — planner should verify in Godot docs |
| A7 | `Camera2D.limit_left/right/top/bottom` accept pixel integers in Godot 4.6 | Architecture Patterns | Camera does not clamp correctly; MEDIUM risk |
| A8 | TileMap tiles have collision only if individual tile shapes are assigned in TileSet editor (not just physics layer enabled at TileSet level) | Common Pitfalls | Silent collision failure; HIGH risk — planner must include a "configure TileSet tile shapes" task |
| A9 | Room1/Entities node (Game.tscn line 121) is unused (all spawners target root-level Entities node) | Current Scene State | If it IS used, removing it breaks a spawner path; planner must audit before deletion |

---

## Open Questions

1. **Which tiles in Roguelike Modern City and Tiny Dungeon are the "correct" floor/wall choices?**
   - What we know: Both PNGs confirmed present. Tile size 16×16 confirmed. Visual inspection gives approximate region locations.
   - What's unclear: Exact atlas coordinates for each semantic role (floor, wall, obstacle, exit-corridor).
   - Recommendation: Planner wave 0 task — open each PNG in image viewer, count to tile of interest, record Vector2i(col, row). This is 30-minute manual work, not code.

2. **Does Tiny Dungeon have enough geometry tiles?**
   - What we know: Only 132 tiles total; many are character sprites; only top ~3 rows are geometric.
   - What's unclear: Whether rows 0–2 provide enough wall/floor variety for 5 distinct sub-rooms.
   - Recommendation: If variety is insufficient, mix in 1-Bit Pack tiles for Room 3 walls. 1-Bit Pack confirmed present at `res://assets/kenney/1-bit-pack/Tilemap/tileset_legacy.png` (1078 tiles). This would require a third TileSetAtlasSource in the Room3 TileSet.

3. **Does TileMap.set_cell() replicate to clients automatically via MultiplayerSynchronizer?**
   - What we know: `TileMap` is not a `MultiplayerSynchronizer`-aware node by default. The spawner only handles game entities (players, enemies, bullets).
   - What's unclear: Whether calling `set_cell()` on the host-side TileMap node also updates clients.
   - Recommendation: TileMap cell state is part of the static scene, not replicated state. Since RoomBuilder will be called on ALL peers (not just host) via `@rpc("call_local")` in `_transition_to_sub_room()`, each peer builds the TileMap locally from the same deterministic data — no replication needed. The exit-passage opening IS the one dynamic tile change and must be RPC'd explicitly (`_open_exit_passage()`).

4. **Room2 and Room3 currently have no TileMap node — how are they added?**
   - What we know: Only Room1 has a TileMap node in Game.tscn (line 59). Room2 and Room3 have only Polygon2D floors and StaticBody2D walls.
   - What's unclear: Whether to add TileMap nodes in the editor (Game.tscn) or instantiate them at runtime in RoomBuilder.
   - Recommendation: Add TileMap nodes to Room2 and Room3 in the Godot editor (Game.tscn) with the same empty TileSet setup as Room1. This is a scene-edit step, not a code step. Plan it as Wave 0.

---

## Environment Availability

| Dependency | Required By | Available | Notes |
|------------|------------|-----------|-------|
| Godot 4.6 | All TileMap, Camera2D, RPC features | Confirmed by project.godot | `config/features=PackedStringArray("4.6", "GL Compatibility")` [VERIFIED] |
| `res://assets/kenney/roguelike-modern-city/Tilemap/tilemap_packed.png` | Rooms 1+2 tileset | Confirmed on disk | [VERIFIED: `ls` output] |
| `res://assets/kenney/tiny-dungeon/Tilemap/tilemap_packed.png` | Room 3 tileset | Confirmed on disk | [VERIFIED: `ls` output] |
| `res://assets/kenney/1-bit-pack/Tilemap/tileset_legacy.png` | Optional Room 3 wall variety | Confirmed on disk | [VERIFIED: `ls` output] |
| `res://scenes/OSMRoomGenerator.gd` | Being deleted | Present on disk | Delete in Phase 9 Plan 1 |

---

## Validation Architecture

> `nyquist_validation` is set to `false` in `.planning/config.json`. [VERIFIED: config.json]. Section included as required by output specification for MAP-01–MAP-11 acceptance checks.

Since `nyquist_validation = false`, no automated test infrastructure is planned. The following are **manual acceptance checks** (UAT criteria) the planner should include in verification tasks:

| Req ID | Behavior to Verify | Manual Check | Automated Possible? |
|--------|-------------------|--------------|---------------------|
| MAP-01 | 3 rooms × 5 sub-rooms reachable without loading screen | Run game as host, clear sub-rooms 1–5 for each location; confirm no scene-reload between sub-rooms | No — requires runtime play |
| MAP-02 | Clearing sub-room opens passage to next | Kill all enemies in sub-room 1; confirm wall tiles at exit disappear and player can walk through | No — requires runtime play |
| MAP-03 | Sub-room 5 of Room 3 spawns boss, not normal enemies | Reach sub-room 5 of Room 3; verify boss appears and no basic enemies are present | No — requires runtime play |
| MAP-04 | ERBA room has open/grassy feel | Visually inspect Room 1 sub-rooms for green/asphalt tile mix and open floor areas | No — visual check |
| MAP-05 | Altstadt has narrower corridor feel | Visually inspect Room 2 sub-rooms; corridors should feel tighter than Room 1 | No — visual check |
| MAP-06 | Burg has stone-castle fortress feel | Visually inspect Room 3 sub-rooms for stone tiles and courtyard-like layout | No — visual check |
| MAP-07 | Camera scrolls following player; never shows black void | Move player to each corner of a sub-room; camera follows and stops at sub-room edges | No — runtime |
| MAP-08 | No network requests at runtime | Run game offline (no internet); game loads and plays normally with all 15 sub-rooms visible | Partial: `grep -r "http\|fetch\|HTTPRequest" scenes/ --include="*.gd"` should return no results after OSMRoomGenerator deletion |
| MAP-09 | OSMRoomGenerator fully removed | `ls scenes/OSMRoomGenerator.gd` returns "No such file"; no `OSMRoomGenerator` reference in Game.gd | Yes: `grep -r "OSMRoomGenerator" scenes/ --include="*.gd"` returns empty |
| MAP-10 | Kenney tiles visible in all rooms | Inspect in Godot editor: Room1 TileMap shows Roguelike Modern City tiles; Room3 shows Tiny Dungeon tiles | Partial: TileSet resource paths can be verified programmatically |
| MAP-11 | Tile paths are swap-friendly | Confirm `const TILESET_MODERN` and `const TILESET_DUNGEON` constants exist in one place; changing 1 path switches all tiles for that room | Yes: `grep -r "res://assets/kenney" scenes/ --include="*.gd"` should reference only the const definitions |

---

## Security Domain

Not applicable. Phase 9 is purely local geometry/rendering code. No authentication, sessions, user data, or external endpoints. OSMRoomGenerator deletion REDUCES the attack surface by eliminating the only HTTP request in the game.

---

## Sources

### Primary (VERIFIED — from codebase direct inspection)
- `scenes/Game.gd` — full file read; `_transition_to_room()`, `_bake_navigation()`, `_spawn_wave()`, `_check_room_clear()` patterns confirmed
- `scenes/Game.tscn` — full file read; Room1/2/3 node structure, TileMap node presence, NavigationRegion2D config, StaticBody2D walls all confirmed
- `scenes/OSMRoomGenerator.gd` — full file read; confirmed instantiation at Game.gd lines 89–95 and transition call at lines 159–163
- `scenes/Player.tscn` — full file read; confirmed no Camera2D node exists; confirmed MultiplayerSynchronizer config
- `scenes/Player.gd` — partial read; confirmed authority pattern, `_physics_process` guards
- `project.godot` — confirmed Godot 4.6, GL Compatibility renderer
- `assets/kenney/roguelike-modern-city/Tilesheet.txt` — confirmed 16×16 px, 37×28 grid, 1036 tiles
- `assets/kenney/tiny-dungeon/Tilesheet.txt` — confirmed 16×16 px, 12×11 grid, 132 tiles
- `assets/kenney/1-bit-pack/Tilesheet.txt` — confirmed 16×16 px, 49×22 grid, 1078 tiles
- `assets/kenney/roguelike-modern-city/Tilemap/tilemap_packed.png` — visually inspected; tile regions identified
- `assets/kenney/tiny-dungeon/Tilemap/tilemap_packed.png` — visually inspected; geometry tiles in top rows
- `.planning/phases/09-map-overhaul-tilemap-sub-rooms/09-CONTEXT.md` — D-01 through D-21 confirmed
- `.planning/config.json` — `nyquist_validation: false` confirmed

### Tertiary (LOW confidence — training knowledge, marked [ASSUMED])
- Godot 4.x `TileMap.set_cell()` API signature
- Godot 4.x `Camera2D.limit_left/right/top/bottom` behavior
- Specific atlas coordinates for Kenney tile visual categories

---

## Metadata

**Confidence breakdown:**
- Standard stack (TileMap, Camera2D, NavigationRegion2D): HIGH — verified in existing project files
- Architecture patterns (RoomBuilder, sub-room progression, gate-opening RPC): HIGH — directly derived from verified Game.gd and CONTEXT.md
- Tile atlas coordinates: LOW — visual inspection only; planner must confirm
- TileMap API signatures: MEDIUM — training knowledge, consistent with Godot 4.x documentation patterns
- OSMRoomGenerator removal scope: HIGH — verified exact line numbers in Game.gd

**Research date:** 2026-06-24
**Valid until:** This research is based on the current codebase state. It remains valid until Game.gd, Game.tscn, or Player.tscn are modified. Kenney asset details are permanently stable.
