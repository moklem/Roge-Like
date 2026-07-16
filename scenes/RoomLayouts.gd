## RoomLayouts.gd
## Pure data file — no logic, no _ready(), no signals.
## Contains all hardcoded sub-room layout dictionaries for Phase 9.
##
## Usage: RoomLayouts.SUB_ROOM_DATA[room_id][sub_room_id]
## room_id: 1 (ERBA), 2 (Altstadt), 3 (Burg Altenburg)
## sub_room_id: 1–5 (playable) + 6 (connector) for rooms 1 and 2; 1–5 only for room 3
##
## All tile coordinates are in tile-grid units (not pixels).
## Pixel positions (spawn_points, enemy_spawns) are literal pixel values — the
## "n * 16" expressions are leftovers from the old 16px grid; the resulting pixel
## positions are unchanged on the 32px grid, so they were kept verbatim.
class_name RoomLayouts
extends RefCounted

## On-screen size of one tile-grid cell in pixels. 32px grid: half the tile counts
## of the old 16px grid, identical room pixel dimensions — tiles render 2x larger.
const TILE_SIZE: int = 32

## ─────────────────────────────────────────────────────────────────────────────
## TileSet source IDs (must match the TileSetAtlasSource indices in Game.tscn).
## All world art lives in assets/lovableassats/<biome>/ as single-tile 256px PNGs
## — the atlas coord is always (0,0); tile VARIATION switches the SOURCE.
## Each room's TileMap: tile_size 256 @ node scale 0.125 → 32px per cell.
## ─────────────────────────────────────────────────────────────────────────────
## Room 1 — ERBA (TileSetErba)
const SRC_ERBA_GRASS: int = 3          ## base grass floor (exit-passage floor)
const SRC_ERBA_WALL_FACE: int = 4      ## wall front (south-facing cells)
const SRC_ERBA_WALL_CAP_A: int = 5     ## wall top variant A
const SRC_ERBA_CONNECTOR: int = 6      ## connector corridor path floor
const SRC_ERBA_WALL_CAP_B: int = 7     ## wall top variant B
const SRC_ERBA_ROCKS: int = 8          ## boulder pile obstacle (solid, layer 1)
const SRC_ERBA_FLOWER: int = 9         ## flower deco (layer 1, no collision)
const SRC_ERBA_PEBBLES: int = 10       ## pebble deco (layer 1, no collision)
const SRC_ERBA_GRASS_SHADOW: int = 11  ## grass texture, dark-modulated at registration

## Room 2 — ALTSTADT (TileSetAltstadt)
const SRC_ALT_COBBLE_B: int = 10       ## base cobblestone floor
const SRC_ALT_COBBLE_C: int = 11       ## cobble variant (floor mix)
const SRC_ALT_CARPET: int = 12         ## connector carpet runner (middle row)
const SRC_ALT_WALL_FACE: int = 13      ## house wall front
const SRC_ALT_ROOF: int = 14           ## house/roof obstacle (solid, layer 1)
const SRC_ALT_WALL_CAP: int = 15       ## wall top
const SRC_ALT_GRASS_PATCH: int = 16    ## mossy grass patch (floor mix)
const SRC_ALT_BARREL: int = 17         ## barrel deco (layer 1, no collision)
const SRC_ALT_CRATE: int = 18          ## crate deco (layer 1, no collision)
const SRC_ALT_LANTERN: int = 19        ## lantern deco (layer 1, no collision)
const SRC_ALT_COBBLE_SHADOW: int = 20  ## cobble texture, dark-modulated

## Room 3 — BURG ALTENBURG (TileSetBurg) — castle set v2 (2026-07)
const SRC_BURG_FLOOR_B: int = 1        ## base sandstone floor
const SRC_BURG_FLOOR_A: int = 2        ## sandstone with wood-plank inlay (floor mix)
const SRC_BURG_WALL_FACE: int = 3      ## castle wall front (gray cracked stone)
const SRC_BURG_WALL_CAP: int = 4       ## castle wall top (red roof tiles)
const SRC_BURG_FLOOR_SHADOW: int = 5   ## floor texture, dark-modulated
const SRC_BURG_TORCH: int = 6          ## wall torch, cyan flame (wall deco, layer 1)
const SRC_BURG_BANNER: int = 7         ## red lion banner (wall deco, layer 1)
const SRC_BURG_KNIGHT: int = 8         ## knight armor statue (floor deco scatter, layer 1)
const SRC_BURG_SHIELD: int = 9         ## lion crest shield (wall deco, layer 1)
const SRC_BURG_BARREL: int = 10        ## barrel obstacle (solid, layer 1)
const SRC_BURG_CRATE: int = 11         ## crate obstacle (solid, layer 1)
const SRC_BURG_CHEST: int = 12         ## chest obstacle (solid, layer 1)

## ─────────────────────────────────────────────────────────────────────────────
## ROOM_ART — per-room art config consumed by RoomBuilder's unified build path.
##   floor_src      : base floor source id
##   floor_mix      : [[src, one_in_n], ...] hash-mixed floor variants
##   shadow_src     : (legacy, unused since 2026-07-16 — wall shadows are now slanted
##                    Polygon2Ds built by RoomBuilder._add_wall_shadows)
##                    under south-facing wall faces
##   wall_faces     : source pool for south-facing wall cells (hash pick)
##   wall_caps      : source pool for wall top cells (hash pick)
##   obstacle_srcs  : solid obstacle source pool (hash pick per cell, layer 1)
##   house_src      : solid landmark source for the layout's "houses" cells
##                    (drawn oversized, collision = 1 cell); -1 = none
##   deco           : [[src, one_in_n], ...] scatter deco (layer 1, no collision)
##   wall_deco      : [[src, one_in_n], ...] overlay deco on south-facing wall
##                    FACE cells (torches/banners; layer 1, no extra collision)
##   carpet_src     : floor source for the layout's optional "carpet" rects
##                    (layer 0 override, e.g. boss-arena runner); -1 = none
##   connector_src  : connector corridor floor source (-1 = room has no connector)
##   connector_full : true → whole corridor floor uses connector_src;
##                    false → only the middle row (carpet runner), rest floor_src
## ─────────────────────────────────────────────────────────────────────────────
const ROOM_ART: Dictionary = {
	1: {
		"floor_src": SRC_ERBA_GRASS,
		"floor_mix": [],
		"shadow_src": SRC_ERBA_GRASS_SHADOW,
		"wall_faces": [SRC_ERBA_WALL_FACE],
		"wall_caps": [SRC_ERBA_WALL_CAP_A, SRC_ERBA_WALL_CAP_B],
		"obstacle_srcs": [SRC_ERBA_ROCKS],
		"house_src": -1,
		"deco": [[SRC_ERBA_FLOWER, 26], [SRC_ERBA_PEBBLES, 31]],
		"wall_deco": [],
		"carpet_src": -1,
		"connector_src": SRC_ERBA_CONNECTOR,
		"connector_full": true,
	},
	2: {
		## Center obstacle rects are a barrel/crate depot (solid); houses are
		## hand-placed via each sub-room's "houses" cells and drawn at 64px.
		"floor_src": SRC_ALT_COBBLE_B,
		"floor_mix": [[SRC_ALT_COBBLE_C, 5], [SRC_ALT_GRASS_PATCH, 11]],
		"shadow_src": SRC_ALT_COBBLE_SHADOW,
		"wall_faces": [SRC_ALT_WALL_FACE],
		"wall_caps": [SRC_ALT_WALL_CAP],
		"obstacle_srcs": [SRC_ALT_BARREL, SRC_ALT_CRATE],
		"house_src": SRC_ALT_ROOF,
		"deco": [[SRC_ALT_LANTERN, 43]],
		"wall_deco": [],
		"carpet_src": -1,
		"connector_src": SRC_ALT_CARPET,
		"connector_full": false,
	},
	3: {
		## Castle set v2: bright sandstone floor with a rare wood-inlay accent
		## against red roof-tile caps / gray stone faces. Obstacle rects are supply
		## depots (barrels/crates, occasional chest). Walls are dressed via
		## wall_deco (torches, banners, shields); knight statues stand as rare
		## free deco in the open room.
		"floor_src": SRC_BURG_FLOOR_B,
		"floor_mix": [[SRC_BURG_FLOOR_A, 13]],
		"shadow_src": SRC_BURG_FLOOR_SHADOW,
		"wall_faces": [SRC_BURG_WALL_FACE],
		"wall_caps": [SRC_BURG_WALL_CAP],
		"obstacle_srcs": [SRC_BURG_BARREL, SRC_BURG_CRATE, SRC_BURG_BARREL, SRC_BURG_CRATE, SRC_BURG_CHEST],
		"house_src": -1,
		"deco": [[SRC_BURG_KNIGHT, 131]],
		"wall_deco": [[SRC_BURG_TORCH, 5], [SRC_BURG_BANNER, 7], [SRC_BURG_SHIELD, 9]],
		"carpet_src": -1,
		"connector_src": -1,
		"connector_full": false,
	},
}


## ─────────────────────────────────────────────────────────────────────────────
## SUB_ROOM_DATA — keyed by room_id (1, 2, 3) then sub_room_id (1–6 or 1–5)
##
## Each sub-room dictionary shape (D-06 extended):
##   "width_tiles"      : int             — sub-room width in tiles
##   "height_tiles"     : int             — sub-room height in tiles
##   "tileset_src"      : int             — which TileSet source ID to use
##   "floor_tile"       : Vector2i        — primary floor atlas coord
##   "wall_tile"        : Vector2i        — wall atlas coord
##   "obstacle_tile"    : Vector2i        — obstacle atlas coord
##   "exit_dir"         : Vector2i        — exit direction (Vector2i(1,0) = right; Vector2i(0,0) = no exit)
##   "exit_tile_coords" : Array[Vector2i] — the wall tile coords forming the blocked exit passage
##   "walls"            : Array[Rect2i]   — wall tile fill rectangles (1-2 tile perimeter)
##   "floor"            : Array[Rect2i]   — floor tile fill rectangles
##   "obstacles"        : Array[Rect2i]   — solid obstacle rectangles
##   "houses"           : Array[Vector2i] — optional: solid landmark cells (ROOM_ART house_src)
##   "carpet"           : Array[Rect2i]   — optional: floor-override rects (ROOM_ART carpet_src)
##   "spawn_points"     : Array[Vector2]  — player teleport positions in pixels
##   "enemy_spawns"     : Array[Vector2]  — enemy spawn positions in pixels
## ─────────────────────────────────────────────────────────────────────────────
static var SUB_ROOM_DATA: Dictionary = {

	## =======================================================================
	## ROOM 1: ERBA-INSEL BAMBERG (Modern City, grass, organic tapered island)
	## =======================================================================
	1: {
		1: {
			"width_tiles":  26,
			"height_tiles": 18,
			"tileset_src":  3,
			"floor_tile":   Vector2i(0, 0),
			"wall_tile":    Vector2i(1, 7),
			"obstacle_tile": Vector2i(0, 13),
			"exit_dir": Vector2i(1, 0),
			"exit_tile_coords": [
				Vector2i(25, 8), Vector2i(25, 9),
			],
			"walls": [
				Rect2i(0, 0, 26, 1),
				Rect2i(0, 17, 26, 1),
				Rect2i(0, 0, 1, 18),
				Rect2i(25, 0, 1, 18),
				Rect2i(1, 1, 6, 3),
				Rect2i(19, 1, 6, 3),
				Rect2i(1, 14, 6, 3),
				Rect2i(19, 14, 6, 3),
			],
			"floor": [
				Rect2i(1, 1, 24, 16),
			],
			"obstacles": [
				Rect2i(11, 7, 5, 4),
			],
			"spawn_points": [
				Vector2(6 * 16, 12 * 16),
				Vector2(6 * 16, 18 * 16),
				Vector2(6 * 16, 24 * 16),
			],
			"enemy_spawns": [
				Vector2(40 * 16, 15 * 16),
				Vector2(40 * 16, 21 * 16),
				Vector2(44 * 16, 18 * 16),
				Vector2(24 * 16, 24 * 16),
				Vector2(36 * 16, 24 * 16),
				Vector2(16 * 16, 9 * 16),
			],
		},
		2: {
			"width_tiles":  28,
			"height_tiles": 19,
			"tileset_src":  3,
			"floor_tile":   Vector2i(0, 0),
			"wall_tile":    Vector2i(1, 7),
			"obstacle_tile": Vector2i(0, 13),
			"exit_dir": Vector2i(1, 0),
			"exit_tile_coords": [
				Vector2i(27, 9), Vector2i(27, 10),
			],
			"walls": [
				Rect2i(0, 0, 28, 1),
				Rect2i(0, 18, 28, 1),
				Rect2i(0, 0, 1, 19),
				Rect2i(27, 0, 1, 19),
				Rect2i(1, 1, 6, 4),
				Rect2i(21, 1, 6, 4),
				Rect2i(1, 14, 6, 4),
				Rect2i(21, 14, 6, 4),
				Rect2i(12, 1, 4, 3),
			],
			"floor": [
				Rect2i(1, 1, 26, 17),
			],
			## Clearance: the right rock pile used to bottom out on row 12, one row above the
			## bottom-right corner wall block (which starts on row 14). That left row 13 as the
			## ONLY row where the rock's column and the wall's column are both walkable — a gate
			## exactly one tile (32px) tall, and the player capsule is 32px tall, so you wedged
			## in that corner. One row shallower opens the gate to 2 tiles.
			"obstacles": [
				Rect2i(10, 8, 4, 4),
				Rect2i(17, 9, 4, 3),
			],
			"spawn_points": [
				Vector2(6 * 16, 13 * 16),
				Vector2(6 * 16, 19 * 16),
				Vector2(6 * 16, 25 * 16),
			],
			"enemy_spawns": [
				Vector2(46 * 16, 18 * 16),
				Vector2(46 * 16, 24 * 16),
				Vector2(30 * 16, 13 * 16),
				Vector2(16 * 16, 24 * 16),
				Vector2(30 * 16, 24 * 16),
				Vector2(48 * 16, 12 * 16),
			],
		},
		3: {
			"width_tiles":  30,
			"height_tiles": 20,
			"tileset_src":  3,
			"floor_tile":   Vector2i(0, 0),
			"wall_tile":    Vector2i(1, 7),
			"obstacle_tile": Vector2i(0, 13),
			"exit_dir": Vector2i(1, 0),
			"exit_tile_coords": [
				Vector2i(29, 9), Vector2i(29, 10),
			],
			"walls": [
				Rect2i(0, 0, 30, 1),
				Rect2i(0, 19, 30, 1),
				Rect2i(0, 0, 1, 20),
				Rect2i(29, 0, 1, 20),
				Rect2i(1, 1, 7, 4),
				Rect2i(22, 1, 7, 4),
				Rect2i(1, 15, 7, 4),
				Rect2i(22, 15, 7, 4),
				Rect2i(13, 1, 5, 3),
				Rect2i(13, 16, 5, 3),
			],
			"floor": [
				Rect2i(1, 1, 28, 18),
			],
			"obstacles": [
				Rect2i(10, 8, 4, 4),
				Rect2i(16, 8, 4, 4),
				Rect2i(23, 8, 3, 4),
			],
			"spawn_points": [
				Vector2(6 * 16, 14 * 16),
				Vector2(6 * 16, 20 * 16),
				Vector2(6 * 16, 26 * 16),
			],
			"enemy_spawns": [
				Vector2(40 * 16, 12 * 16),
				Vector2(54 * 16, 20 * 16),
				Vector2(40 * 16, 27 * 16),
				Vector2(20 * 16, 27 * 16),
				Vector2(52 * 16, 26 * 16),
				Vector2(30 * 16, 12 * 16),
				Vector2(46 * 16, 27 * 16),
			],
		},
		4: {
			"width_tiles":  31,
			"height_tiles": 21,
			"tileset_src":  3,
			"floor_tile":   Vector2i(0, 0),
			"wall_tile":    Vector2i(1, 7),
			"obstacle_tile": Vector2i(0, 13),
			"exit_dir": Vector2i(1, 0),
			"exit_tile_coords": [
				Vector2i(30, 10), Vector2i(30, 11),
			],
			"walls": [
				Rect2i(0, 0, 31, 1),
				Rect2i(0, 20, 31, 1),
				Rect2i(0, 0, 1, 21),
				Rect2i(30, 0, 1, 21),
				Rect2i(1, 1, 7, 4),
				Rect2i(23, 1, 7, 4),
				Rect2i(1, 15, 7, 5),
				Rect2i(23, 15, 7, 5),
				Rect2i(14, 1, 5, 3),
				Rect2i(10, 17, 5, 3),
			],
			"floor": [
				Rect2i(1, 1, 29, 19),
			],
			"obstacles": [
				Rect2i(10, 8, 4, 5),
				Rect2i(17, 8, 4, 5),
				Rect2i(23, 9, 3, 4),
			],
			"spawn_points": [
				Vector2(6 * 16, 15 * 16),
				Vector2(6 * 16, 21 * 16),
				Vector2(6 * 16, 27 * 16),
			],
			"enemy_spawns": [
				Vector2(43 * 16, 13 * 16),
				Vector2(54 * 16, 21 * 16),
				Vector2(43 * 16, 28 * 16),
				Vector2(22 * 16, 28 * 16),
				Vector2(54 * 16, 27 * 16),
				Vector2(31 * 16, 13 * 16),
				Vector2(46 * 16, 28 * 16),
			],
		},
		5: {
			"width_tiles":  33,
			"height_tiles": 22,
			"tileset_src":  3,
			"floor_tile":   Vector2i(0, 0),
			"wall_tile":    Vector2i(1, 7),
			"obstacle_tile": Vector2i(0, 13),
			"exit_dir": Vector2i(1, 0),
			"exit_tile_coords": [
				Vector2i(31, 10), Vector2i(31, 11), Vector2i(32, 10),
				Vector2i(32, 11),
			],
			"walls": [
				Rect2i(0, 0, 33, 1),
				Rect2i(0, 21, 33, 1),
				Rect2i(0, 0, 1, 22),
				Rect2i(31, 0, 2, 22),
				Rect2i(1, 1, 8, 5),
				Rect2i(24, 1, 8, 5),
				Rect2i(1, 16, 8, 5),
				Rect2i(24, 16, 8, 5),
				Rect2i(15, 1, 6, 3),
				Rect2i(12, 18, 6, 3),
				Rect2i(23, 17, 4, 4),
			],
			"floor": [
				Rect2i(1, 1, 31, 20),
			],
			"obstacles": [
				Rect2i(10, 9, 4, 4),
				Rect2i(17, 9, 4, 4),
				Rect2i(24, 9, 4, 4),
			],
			"spawn_points": [
				Vector2(6 * 16, 16 * 16),
				Vector2(6 * 16, 22 * 16),
				Vector2(6 * 16, 28 * 16),
			],
			"enemy_spawns": [
				Vector2(45 * 16, 14 * 16),
				Vector2(57 * 16, 22 * 16),
				Vector2(45 * 16, 29 * 16),
				Vector2(20 * 16, 29 * 16),
				Vector2(57 * 16, 28 * 16),
				Vector2(33 * 16, 14 * 16),
				Vector2(46 * 16, 29 * 16),
				Vector2(30 * 16, 22 * 16),
			],
		},
		6: {
			"width_tiles":  40,
			"height_tiles": 5,
			"tileset_src":  6,
			"floor_tile":   Vector2i(0, 0),
			"wall_tile":    Vector2i(1, 7),
			"obstacle_tile": Vector2i(0, 13),
			"exit_dir": Vector2i(1, 0),
			"exit_tile_coords": [],
			"walls": [
				Rect2i(0, 0, 40, 1),
				Rect2i(0, 4, 40, 1),
			],
			"floor": [
				Rect2i(0, 0, 40, 4),
			],
			"obstacles": [],
			"spawn_points": [
				Vector2(4 * 16, 3 * 16),
				Vector2(4 * 16, 4 * 16),
				Vector2(4 * 16, 5 * 16),
			],
			"enemy_spawns": [],
		},
	},

	## =======================================================================
	## ROOM 2: BAMBERG ALTSTADT (Modern City, asphalt, angular street network)
	## =======================================================================
	2: {
		1: {
			"width_tiles":  28,
			"height_tiles": 19,
			"tileset_src":  10,
			"floor_tile":   Vector2i(0, 0),
			"wall_tile":    Vector2i(0, 0),
			"obstacle_tile": Vector2i(0, 0),
			"exit_dir": Vector2i(1, 0),
			"exit_tile_coords": [
				Vector2i(26, 9), Vector2i(26, 10), Vector2i(27, 9),
				Vector2i(27, 10),
			],
			"walls": [
				Rect2i(0, 0, 28, 1),
				Rect2i(0, 18, 28, 1),
				Rect2i(0, 0, 1, 19),
				Rect2i(26, 0, 2, 19),
				Rect2i(1, 1, 6, 5),
				Rect2i(20, 1, 7, 5),
				Rect2i(1, 13, 6, 5),
				Rect2i(20, 13, 7, 5),
			],
			"floor": [
				Rect2i(1, 1, 26, 17),
			],
			"obstacles": [
				Rect2i(12, 8, 4, 3),
			],
			## Clearance: pulled one tile in off the side walls. At x8/x18 they left a single
			## free tile (32px) against the wall, and the player capsule is 24x32 — a slot that
			## exact is where you wedge. Every house is now either >=2 tiles clear of a wall or
			## flush against one.
			"houses": [
				Vector2i(9, 3), Vector2i(17, 3),
				Vector2i(9, 14), Vector2i(17, 14),
			],
			"spawn_points": [
				Vector2(6 * 16, 14 * 16),
				Vector2(6 * 16, 19 * 16),
				Vector2(6 * 16, 24 * 16),
			],
			"enemy_spawns": [
				Vector2(46 * 16, 19 * 16),
				Vector2(38 * 16, 9 * 16),
				Vector2(38 * 16, 29 * 16),
				Vector2(24 * 16, 9 * 16),
				Vector2(24 * 16, 29 * 16),
				Vector2(50 * 16, 19 * 16),
			],
		},
		2: {
			"width_tiles":  28,
			"height_tiles": 20,
			"tileset_src":  10,
			"floor_tile":   Vector2i(0, 0),
			"wall_tile":    Vector2i(0, 0),
			"obstacle_tile": Vector2i(0, 0),
			"exit_dir": Vector2i(1, 0),
			"exit_tile_coords": [
				Vector2i(27, 9), Vector2i(27, 10),
			],
			"walls": [
				Rect2i(0, 0, 28, 1),
				Rect2i(0, 19, 28, 1),
				Rect2i(0, 0, 1, 20),
				Rect2i(27, 0, 1, 20),
				Rect2i(1, 1, 5, 4),
				Rect2i(22, 1, 5, 4),
				Rect2i(1, 15, 5, 4),
				Rect2i(22, 15, 5, 4),
				Rect2i(10, 1, 8, 4),
				Rect2i(10, 15, 8, 4),
			],
			"floor": [
				Rect2i(1, 1, 26, 18),
			],
			"obstacles": [
				Rect2i(12, 8, 4, 4),
			],
			## Clearance: these alcoves are only 4 tiles wide, so a house anywhere in the middle
			## leaves a 1-tile wedge slot on one side. Pushed flush against the side wall — the
			## remaining 3 tiles are a clean walkable gap.
			"houses": [
				Vector2i(6, 3), Vector2i(21, 3),
				Vector2i(6, 16), Vector2i(21, 16),
			],
			"spawn_points": [
				Vector2(6 * 16, 15 * 16),
				Vector2(6 * 16, 20 * 16),
				Vector2(6 * 16, 25 * 16),
			],
			"enemy_spawns": [
				Vector2(48 * 16, 20 * 16),
				Vector2(40 * 16, 13 * 16),
				Vector2(40 * 16, 28 * 16),
				Vector2(16 * 16, 20 * 16),
				Vector2(28 * 16, 28 * 16),
				Vector2(50 * 16, 13 * 16),
			],
		},
		3: {
			"width_tiles":  30,
			"height_tiles": 21,
			"tileset_src":  10,
			"floor_tile":   Vector2i(0, 0),
			"wall_tile":    Vector2i(0, 0),
			"obstacle_tile": Vector2i(0, 0),
			"exit_dir": Vector2i(1, 0),
			"exit_tile_coords": [
				Vector2i(29, 10), Vector2i(29, 11),
			],
			"walls": [
				Rect2i(0, 0, 30, 1),
				Rect2i(0, 20, 30, 1),
				Rect2i(0, 0, 1, 21),
				Rect2i(29, 0, 1, 21),
				Rect2i(1, 1, 6, 5),
				Rect2i(23, 1, 6, 5),
				Rect2i(1, 15, 6, 5),
				Rect2i(23, 15, 6, 5),
				Rect2i(12, 1, 6, 4),
				Rect2i(12, 16, 6, 4),
			],
			"floor": [
				Rect2i(1, 1, 28, 19),
			],
			"obstacles": [
				Rect2i(13, 8, 4, 5),
				Rect2i(21, 9, 3, 4),
			],
			"houses": [
				Vector2i(9, 3), Vector2i(20, 3),
				Vector2i(9, 17), Vector2i(20, 17),
			],
			"spawn_points": [
				Vector2(6 * 16, 16 * 16),
				Vector2(6 * 16, 21 * 16),
				Vector2(6 * 16, 26 * 16),
			],
			"enemy_spawns": [
				Vector2(52 * 16, 21 * 16),
				Vector2(40 * 16, 12 * 16),
				Vector2(40 * 16, 28 * 16),
				Vector2(18 * 16, 21 * 16),
				Vector2(20 * 16, 28 * 16),
				Vector2(52 * 16, 27 * 16),
				Vector2(44 * 16, 12 * 16),
			],
		},
		4: {
			"width_tiles":  31,
			"height_tiles": 22,
			"tileset_src":  10,
			"floor_tile":   Vector2i(0, 0),
			"wall_tile":    Vector2i(0, 0),
			"obstacle_tile": Vector2i(0, 0),
			"exit_dir": Vector2i(1, 0),
			"exit_tile_coords": [
				Vector2i(30, 10), Vector2i(30, 11),
			],
			"walls": [
				Rect2i(0, 0, 31, 1),
				Rect2i(0, 21, 31, 1),
				Rect2i(0, 0, 1, 22),
				Rect2i(30, 0, 1, 22),
				Rect2i(1, 1, 7, 5),
				Rect2i(23, 1, 7, 5),
				Rect2i(1, 16, 7, 5),
				Rect2i(23, 16, 7, 5),
				Rect2i(10, 1, 6, 5),
				Rect2i(17, 16, 6, 5),
			],
			"floor": [
				Rect2i(1, 1, 29, 20),
			],
			"obstacles": [
				Rect2i(12, 9, 4, 4),
				Rect2i(20, 9, 4, 5),
			],
			## Clearance: the two top houses each left a 1-tile wedge slot against their side wall.
			## Pushed flush against the walls rather than inward — moving them inward instead
			## would just relocate the 1-tile slot to between the two houses.
			"houses": [
				Vector2i(16, 3), Vector2i(22, 3),
				Vector2i(10, 17), Vector2i(14, 18),
			],
			"spawn_points": [
				Vector2(6 * 16, 14 * 16),
				Vector2(6 * 16, 21 * 16),
				Vector2(6 * 16, 28 * 16),
			],
			"enemy_spawns": [
				Vector2(54 * 16, 22 * 16),
				Vector2(40 * 16, 13 * 16),
				Vector2(36 * 16, 30 * 16),
				Vector2(18 * 16, 22 * 16),
				Vector2(20 * 16, 30 * 16),
				Vector2(54 * 16, 28 * 16),
				Vector2(50 * 16, 14 * 16),
			],
		},
		5: {
			"width_tiles":  33,
			"height_tiles": 23,
			"tileset_src":  10,
			"floor_tile":   Vector2i(0, 0),
			"wall_tile":    Vector2i(0, 0),
			"obstacle_tile": Vector2i(0, 0),
			"exit_dir": Vector2i(1, 0),
			"exit_tile_coords": [
				Vector2i(31, 11), Vector2i(31, 12), Vector2i(32, 11),
				Vector2i(32, 12),
			],
			"walls": [
				Rect2i(0, 0, 33, 1),
				Rect2i(0, 22, 33, 1),
				Rect2i(0, 0, 1, 23),
				Rect2i(31, 0, 2, 23),
				Rect2i(1, 1, 8, 6),
				Rect2i(23, 1, 9, 6),
				Rect2i(1, 16, 8, 6),
				Rect2i(23, 16, 9, 6),
				Rect2i(14, 1, 6, 4),
				Rect2i(14, 18, 6, 4),
			],
			"floor": [
				Rect2i(1, 1, 31, 21),
			],
			"obstacles": [
				Rect2i(15, 9, 4, 5),
			],
			## Clearance: left house moved one tile in (2 free tiles either side); right alcove is
			## only 3 wide, so its house goes flush against the wall instead.
			"houses": [
				Vector2i(11, 3), Vector2i(20, 3),
				Vector2i(11, 19), Vector2i(20, 19),
			],
			"spawn_points": [
				Vector2(6 * 16, 17 * 16),
				Vector2(6 * 16, 23 * 16),
				Vector2(6 * 16, 29 * 16),
			],
			"enemy_spawns": [
				Vector2(52 * 16, 23 * 16),
				Vector2(44 * 16, 15 * 16),
				Vector2(44 * 16, 30 * 16),
				Vector2(24 * 16, 23 * 16),
				Vector2(36 * 16, 15 * 16),
				Vector2(24 * 16, 30 * 16),
				Vector2(52 * 16, 29 * 16),
				Vector2(36 * 16, 30 * 16),
			],
		},
		6: {
			"width_tiles":  40,
			"height_tiles": 5,
			"tileset_src":  12,
			"floor_tile":   Vector2i(0, 0),
			"wall_tile":    Vector2i(0, 0),
			"obstacle_tile": Vector2i(0, 0),
			"exit_dir": Vector2i(1, 0),
			"exit_tile_coords": [],
			"walls": [
				Rect2i(0, 0, 40, 1),
				Rect2i(0, 4, 40, 1),
			],
			"floor": [
				Rect2i(0, 0, 40, 4),
			],
			"obstacles": [],
			"spawn_points": [
				Vector2(4 * 16, 3 * 16),
				Vector2(4 * 16, 4 * 16),
				Vector2(4 * 16, 5 * 16),
			],
			"enemy_spawns": [],
		},
	},

	## =======================================================================
	## ROOM 3: BURG ALTENBURG BAMBERG (Tiny Dungeon, stone, angular bailey)
	## =======================================================================
	3: {
		1: {
			"width_tiles":  28,
			"height_tiles": 20,
			"tileset_src":  1,
			"floor_tile":   Vector2i(0, 0),
			"wall_tile":    Vector2i(0, 0),
			"obstacle_tile": Vector2i(2, 0),
			"exit_dir": Vector2i(1, 0),
			"exit_tile_coords": [
				Vector2i(26, 9), Vector2i(26, 10), Vector2i(27, 9),
				Vector2i(27, 10),
			],
			"walls": [
				Rect2i(0, 0, 28, 1),
				Rect2i(0, 19, 28, 1),
				Rect2i(0, 0, 1, 20),
				Rect2i(26, 0, 2, 20),
				Rect2i(1, 1, 5, 4),
				Rect2i(21, 1, 6, 4),
				Rect2i(1, 15, 5, 4),
				Rect2i(21, 15, 6, 4),
			],
			"floor": [
				Rect2i(1, 1, 26, 18),
			],
			"obstacles": [
				Rect2i(12, 8, 4, 4),
			],
			"spawn_points": [
				Vector2(6 * 16, 15 * 16),
				Vector2(6 * 16, 20 * 16),
				Vector2(6 * 16, 25 * 16),
			],
			"enemy_spawns": [
				Vector2(46 * 16, 20 * 16),
				Vector2(40 * 16, 11 * 16),
				Vector2(40 * 16, 29 * 16),
				Vector2(24 * 16, 11 * 16),
				Vector2(24 * 16, 29 * 16),
				Vector2(48 * 16, 20 * 16),
			],
		},
		2: {
			"width_tiles":  28,
			"height_tiles": 20,
			"tileset_src":  1,
			"floor_tile":   Vector2i(0, 0),
			"wall_tile":    Vector2i(0, 0),
			"obstacle_tile": Vector2i(2, 0),
			"exit_dir": Vector2i(1, 0),
			"exit_tile_coords": [
				Vector2i(27, 9), Vector2i(27, 10),
			],
			"walls": [
				Rect2i(0, 0, 28, 1),
				Rect2i(0, 19, 28, 1),
				Rect2i(0, 0, 1, 20),
				Rect2i(27, 0, 1, 20),
				Rect2i(1, 1, 5, 4),
				Rect2i(22, 1, 5, 4),
				Rect2i(1, 15, 5, 4),
				Rect2i(22, 15, 5, 4),
				Rect2i(10, 1, 8, 6),
				Rect2i(10, 13, 8, 6),
			],
			"floor": [
				Rect2i(1, 1, 26, 18),
			],
			"obstacles": [
				Rect2i(20, 9, 3, 3),
			],
			"spawn_points": [
				Vector2(6 * 16, 15 * 16),
				Vector2(6 * 16, 20 * 16),
				Vector2(6 * 16, 25 * 16),
			],
			"enemy_spawns": [
				Vector2(48 * 16, 20 * 16),
				Vector2(28 * 16, 20 * 16),
				Vector2(40 * 16, 11 * 16),
				Vector2(40 * 16, 29 * 16),
				Vector2(14 * 16, 20 * 16),
				Vector2(50 * 16, 13 * 16),
			],
		},
		3: {
			"width_tiles":  30,
			"height_tiles": 21,
			"tileset_src":  1,
			"floor_tile":   Vector2i(0, 0),
			"wall_tile":    Vector2i(0, 0),
			"obstacle_tile": Vector2i(2, 0),
			"exit_dir": Vector2i(1, 0),
			"exit_tile_coords": [
				Vector2i(29, 10), Vector2i(29, 11),
			],
			"walls": [
				Rect2i(0, 0, 30, 1),
				Rect2i(0, 20, 30, 1),
				Rect2i(0, 0, 1, 21),
				Rect2i(29, 0, 1, 21),
				Rect2i(1, 1, 6, 5),
				Rect2i(23, 1, 6, 5),
				Rect2i(1, 15, 6, 5),
				Rect2i(23, 15, 6, 5),
			],
			"floor": [
				Rect2i(1, 1, 28, 19),
			],
			"obstacles": [
				Rect2i(14, 4, 3, 3),
				Rect2i(14, 14, 3, 3),
				Rect2i(8, 9, 3, 3),
				Rect2i(20, 9, 3, 3),
			],
			"spawn_points": [
				Vector2(6 * 16, 16 * 16),
				Vector2(6 * 16, 21 * 16),
				Vector2(6 * 16, 26 * 16),
			],
			"enemy_spawns": [
				Vector2(52 * 16, 21 * 16),
				Vector2(40 * 16, 13 * 16),
				Vector2(40 * 16, 30 * 16),
				Vector2(20 * 16, 13 * 16),
				Vector2(20 * 16, 30 * 16),
				Vector2(52 * 16, 27 * 16),
				Vector2(34 * 16, 21 * 16),
			],
		},
		4: {
			"width_tiles":  33,
			"height_tiles": 22,
			"tileset_src":  1,
			"floor_tile":   Vector2i(0, 0),
			"wall_tile":    Vector2i(0, 0),
			"obstacle_tile": Vector2i(2, 0),
			"exit_dir": Vector2i(1, 0),
			"exit_tile_coords": [
				Vector2i(31, 10), Vector2i(31, 11), Vector2i(32, 10),
				Vector2i(32, 11),
			],
			"walls": [
				Rect2i(0, 0, 33, 1),
				Rect2i(0, 21, 33, 1),
				Rect2i(0, 0, 1, 22),
				Rect2i(31, 0, 2, 22),
				Rect2i(1, 1, 6, 5),
				Rect2i(25, 1, 7, 5),
				Rect2i(1, 16, 6, 5),
				Rect2i(25, 16, 7, 5),
				Rect2i(14, 1, 5, 4),
				Rect2i(14, 17, 5, 4),
			],
			"floor": [
				Rect2i(1, 1, 31, 20),
			],
			## Clearance: the two lower obstacles were 3 rows deep and bottomed out exactly one
			## tile short of the south wall, leaving a 32px-high channel — the player capsule is
			## 32px tall, so that channel is a guaranteed wedge. Both are one row shallower now,
			## which opens those gaps to 2 tiles without changing the arena's read.
			"obstacles": [
				Rect2i(9, 9, 3, 3),
				Rect2i(15, 8, 3, 3),
				Rect2i(15, 13, 3, 2),
				Rect2i(21, 9, 3, 3),
				Rect2i(21, 14, 2, 2),
			],
			"spawn_points": [
				Vector2(6 * 16, 16 * 16),
				Vector2(6 * 16, 22 * 16),
				Vector2(6 * 16, 28 * 16),
			],
			"enemy_spawns": [
				Vector2(54 * 16, 22 * 16),
				Vector2(40 * 16, 12 * 16),
				Vector2(38 * 16, 30 * 16),
				Vector2(20 * 16, 30 * 16),
				Vector2(54 * 16, 30 * 16),
				Vector2(48 * 16, 12 * 16),
				Vector2(24 * 16, 12 * 16),
			],
		},
		5: {
			"width_tiles":  35,
			"height_tiles": 25,
			"tileset_src":  1,
			"floor_tile":   Vector2i(0, 0),
			"wall_tile":    Vector2i(0, 0),
			"obstacle_tile": Vector2i(2, 0),
			"exit_dir": Vector2i(0, 0),
			"exit_tile_coords": [],
			"walls": [
				Rect2i(0, 0, 35, 1),
				Rect2i(0, 24, 35, 1),
				Rect2i(0, 0, 1, 25),
				Rect2i(34, 0, 1, 25),
				Rect2i(1, 1, 2, 23),
				Rect2i(33, 1, 2, 23),
				Rect2i(1, 1, 33, 2),
				Rect2i(1, 23, 33, 2),
				Rect2i(2, 2, 5, 5),
				Rect2i(29, 2, 5, 5),
				Rect2i(2, 19, 5, 5),
				Rect2i(29, 19, 5, 5),
			],
			"floor": [
				Rect2i(1, 1, 33, 23),
			],
			"obstacles": [
				Rect2i(11, 10, 2, 2),
				Rect2i(23, 10, 2, 2),
				Rect2i(11, 15, 2, 2),
				Rect2i(23, 15, 2, 2),
			],
			"carpet": [
				Rect2i(7, 12, 22, 1),
			],
			"spawn_points": [
				Vector2(33 * 16, 42 * 16),
				Vector2(35 * 16, 42 * 16),
				Vector2(38 * 16, 42 * 16),
			],
			"enemy_spawns": [
				Vector2(35 * 16, 25 * 16),
			],
		},
	},

}
