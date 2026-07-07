## RoomLayouts.gd
## Pure data file — no logic, no _ready(), no signals.
## Contains all hardcoded sub-room layout dictionaries for Phase 9.
##
## Usage: RoomLayouts.SUB_ROOM_DATA[room_id][sub_room_id]
## room_id: 1 (ERBA), 2 (Altstadt), 3 (Burg Altenburg)
## sub_room_id: 1–5 (playable) + 6 (connector) for rooms 1 and 2; 1–5 only for room 3
##
## All tile coordinates are in tile-grid units (not pixels).
## Pixel positions (spawn_points, enemy_spawns) = tile_coord * TILE_SIZE (16 px).
## Atlas coordinates are [ASSUMED] from visual PNG inspection — verify by opening
## tilemap_packed.png and counting columns/rows (0-indexed) from top-left.
class_name RoomLayouts
extends RefCounted

## Tile size in pixels
const TILE_SIZE: int = 16

## Tileset asset paths (D-17, D-21) — swap here for custom art
const TILESET_MODERN_PATH: String = "res://assets/kenney/roguelike-modern-city/Tilemap/tilemap_packed.png"
const TILESET_DUNGEON_PATH: String = "res://assets/kenney/tiny-dungeon/Tilemap/tilemap_packed.png"
const TILESET_1BIT_PATH: String = "res://assets/kenney/1-bit-pack/Tilemap/tileset_legacy.png"

## TileSet source IDs (must match TileSetAtlasSource index in TileSet resource)
const SRC_MODERN: int = 0  ## roguelike-modern-city — room 2
const SRC_DUNGEON: int = 1  ## tiny-dungeon — room 3
const SRC_1BIT: int = 2     ## 1-bit-pack — room 3 wall fill fallback
const SRC_ERBA_GRASS: int = 3  ## erba_floor.png — room 1 floors
const SRC_ERBA_WALL: int = 4   ## erba_wall.png — room 1 walls
const SRC_ERBA_PROPS: int = 5  ## erba_props.png — room 1 obstacles + deco
const SRC_ERBA_STONE: int = 6  ## erba_road.png — room 1 connector road
## Room 2 (Altstadt) — custom janv2 art (assets/janv2/modern-city, one 32px PNG per tile,
## atlas coord is always (0,0)). Room2/TileMap uses TileSetAltstadt (tile_size 32, scale 0.5).
const SRC_ALT_ASPHALT: int = 10  ## janv2 floor-asphalt — room 2 base floor
const SRC_ALT_GRASS: int = 11    ## janv2 floor-grass — room 2 floor mix (~1/10)
const SRC_ALT_ROAD: int = 12     ## janv2 floor-connector — room 2 connector road
const SRC_ALT_WALL: int = 13     ## janv2 wall — room 2 wall faces
const SRC_ALT_ROOF: int = 14     ## janv2 obstacle-roof — room 2 obstacles (layer 1)
const SRC_ALT_WALL_CAP: int = 15 ## same wall texture, darkened via modulate (2.5D tops)

## ─────────────────────────────────────────────────────────────────────────────
## Atlas coordinates for Roguelike Modern City (37 cols × 28 rows, 16+1px spacing)
## ALL COORDINATES [ASSUMED] from visual PNG inspection — verify before shipping.
## ─────────────────────────────────────────────────────────────────────────────
const MC_FLOOR_ASPHALT   := Vector2i(0, 13)  ## dark gray asphalt road (row 13 = confirmed dark road)
const MC_FLOOR_GRASS     := Vector2i(0, 16)  ## green grass (row 16 col 0 = confirmed green)
const MC_FLOOR_GRASS_ALT := Vector2i(3, 16)  ## green grass variant (row 16 col 3 = same hue)
const MC_FLOOR_CRACK     := Vector2i(0, 17)  ## darker green ground variety (row 17 col 0)
const MC_WALL_BRICK      := Vector2i(0, 0)   ## dark brick building wall (row 0 = confirmed reddish-brown)
const MC_WALL_BRICK_ALT  := Vector2i(1, 0)   ## lighter brick variant
const MC_OBSTACLE_ROOF   := Vector2i(3, 0)   ## building rooftop obstacle
const MC_OBSTACLE_ROOF_ALT := Vector2i(4, 0) ## lighter rooftop variant
const MC_CONNECTOR_ROAD  := Vector2i(0, 15)  ## pure dark asphalt road surface
const MC_CONNECTOR_CENTER := Vector2i(5, 15) ## road center marking stripe

## ─────────────────────────────────────────────────────────────────────────────
## Atlas coordinates for Tiny Dungeon (12 cols × 11 rows, 16+1px spacing)
## Geometry tiles are in top 3 rows only. ALL [ASSUMED] from visual inspection.
## ─────────────────────────────────────────────────────────────────────────────
const TD_FLOOR_STONE      := Vector2i(0, 1)  ## gray cobblestone floor [ASSUMED]
const TD_FLOOR_STONE_DARK := Vector2i(1, 1)  ## darker stone variant [ASSUMED]
const TD_WALL_CASTLE      := Vector2i(0, 0)  ## castle stone wall block [ASSUMED]
const TD_WALL_CASTLE_ALT  := Vector2i(1, 0)  ## darker wall block [ASSUMED]
const TD_OBSTACLE_TOWER   := Vector2i(2, 0)  ## tower/turret top [ASSUMED]

## ─────────────────────────────────────────────────────────────────────────────
## 1-Bit Pack fallback (49 cols × 22 rows) for Room 3 wall variety
## ─────────────────────────────────────────────────────────────────────────────
const BIT_WALL_FILL  := Vector2i(2, 0)  ## solid dark fill [ASSUMED]
const BIT_FLOOR_FILL := Vector2i(0, 4)  ## floor tile variety [ASSUMED]

## ─────────────────────────────────────────────────────────────────────────────
## Atlas coordinates for the ERBA atlases (room 1, sources 3-6, 64px tiles).
## Built by new_assets/build_erba_atlases.py from the AI-generated textures.
##
## MACRO BLOCKS: every floor/wall/road texture spans a 2x2 block of tiles.
## The values below are the block's TOP-LEFT tile; RoomBuilder adds the quadrant
## offset (posmod(x,2), posmod(y,2)) so each texture covers 2x2 cells seamlessly
## and the art reads at 32 world px — matching the character scale — while the
## 16px collision/layout grid stays untouched.
##   erba_floor.png — 10 blocks: grass-a/b/c, tufts, flowers, slabs, circuit,
##                    grate, shadow strong/soft
##   erba_wall.png  — 4 blocks: face-a, face-b (dark brick front, baked ~0.55),
##                    cap-a, cap-b (bright top-down slabs)
##   erba_props.png — 7x2 single tiles: rock pile 2x2, rock single, pebbles, stump /
##                    flowers, bush + bench 2x1
##   erba_road.png  — 1 block: connector road
## Room1/TileMap uses TileSetErba (tile_size 64) at node scale 0.25, so tile-grid
## coordinates and all pixel positions stay identical to the 16px rooms.
## ─────────────────────────────────────────────────────────────────────────────
## Floor variant blocks (erba_floor.png) — weighted per-block pick in RoomBuilder
const ERBA_GRASS_PLAIN: Array[Vector2i]  = [
	Vector2i(0, 0), Vector2i(2, 0), Vector2i(4, 0),
]
const ERBA_GRASS_DETAIL: Array[Vector2i] = [
	Vector2i(6, 0), Vector2i(8, 0),
]
## Rare accent blocks (~1/48 of floor cells each): stone slab patch, cyan
## circuit line, drain grate — the loud cartoon tiles stay special.
const ERBA_GRASS_SLABS: Array[Vector2i]  = [
	Vector2i(10, 0), Vector2i(12, 0), Vector2i(14, 0),
]
## Wall contact shadow blocks, two strengths (plain-grass dups, dark-modulated
## at registration). Strong sits directly under the wall, soft extends it with
## a ragged/diagonal edge. Any atlas coord with x >= ERBA_FLOOR_SHADOW.x is shadow.
const ERBA_FLOOR_SHADOW      := Vector2i(16, 0)
const ERBA_FLOOR_SHADOW_SOFT := Vector2i(18, 0)
## Wall blocks (erba_wall.png): FACES are the shadowed brick front (baked darker in
## the atlas), shown as a single row on south edges (floor/void below). CAPS are the
## bright top-down stone slabs covering every other wall cell — light from above:
## horizontal surfaces bright, vertical surfaces dark (reference dungeon look).
const ERBA_WALL_FACES: Array[Vector2i] = [
	Vector2i(0, 0), Vector2i(2, 0),
]
const ERBA_WALL_CAPS: Array[Vector2i] = [
	Vector2i(4, 0), Vector2i(6, 0),
]
## Obstacles + deco (erba_props.png): full 2x2 rock piles where they fit inside the
## obstacle rect, complete single rocks on leftover edge cells (nothing renders cut off).
const ERBA_ROCK_ORIGIN     := Vector2i(0, 0)  ## top-left of the 2x2 rock pile
const ERBA_ROCKS_SINGLE: Array[Vector2i] = [
	Vector2i(2, 0),
]
## Small deco scatter on plain grass — duplicates weight the pick (pebbles/flowers common)
const ERBA_PEBBLES: Array[Vector2i] = [
	Vector2i(3, 0), Vector2i(3, 0), Vector2i(2, 1), Vector2i(2, 1), Vector2i(3, 1), Vector2i(4, 0),
]
## Park bench deco — two adjacent cells (left + right half), placed rarely by RoomBuilder
const ERBA_BENCH_LEFT      := Vector2i(5, 0)
const ERBA_BENCH_RIGHT     := Vector2i(6, 0)
## Connector road (erba_road.png)
const ERBA_CONNECTOR_ROAD  := Vector2i(0, 0)


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
##   "exit_tile_coords" : Array[Vector2i] — the 6 wall tile coords forming the blocked exit passage
##   "walls"            : Array[Rect2i]   — wall tile fill rectangles (2-tile perimeter)
##   "floor"            : Array[Rect2i]   — floor tile fill rectangles
##   "obstacles"        : Array[Rect2i]   — solid obstacle rectangles
##   "spawn_points"     : Array[Vector2]  — player teleport positions in pixels (tile * TILE_SIZE)
##   "enemy_spawns"     : Array[Vector2]  — enemy spawn positions in pixels
## ─────────────────────────────────────────────────────────────────────────────
static var SUB_ROOM_DATA: Dictionary = {

	## =======================================================================
	## ROOM 1: ERBA-INSEL BAMBERG (Modern City, grass, organic tapered island)
	## =======================================================================
	1: {
		1: {
			"width_tiles":  52,
			"height_tiles": 36,
			"tileset_src":  3,
			"floor_tile":   Vector2i(0, 0),
			"wall_tile":    Vector2i(0, 0),
			"obstacle_tile": Vector2i(0, 0),
			"exit_dir": Vector2i(1, 0),
			"exit_tile_coords": [
				Vector2i(50, 17), Vector2i(50, 18), Vector2i(50, 19),
				Vector2i(51, 17), Vector2i(51, 18), Vector2i(51, 19),
			],
			"walls": [
				Rect2i(0, 0, 52, 2),
				Rect2i(0, 34, 52, 2),
				Rect2i(0, 0, 2, 36),
				Rect2i(50, 0, 2, 36),
				Rect2i(2, 2, 11, 6),
				Rect2i(39, 2, 11, 6),
				Rect2i(2, 28, 11, 6),
				Rect2i(39, 28, 11, 6),
			],
			"floor": [
				Rect2i(2, 2, 48, 32),
			],
			"obstacles": [
				Rect2i(22, 15, 9, 7),
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
			"width_tiles":  56,
			"height_tiles": 38,
			"tileset_src":  3,
			"floor_tile":   Vector2i(0, 0),
			"wall_tile":    Vector2i(0, 0),
			"obstacle_tile": Vector2i(0, 0),
			"exit_dir": Vector2i(1, 0),
			"exit_tile_coords": [
				Vector2i(54, 18), Vector2i(54, 19), Vector2i(54, 20),
				Vector2i(55, 18), Vector2i(55, 19), Vector2i(55, 20),
			],
			"walls": [
				Rect2i(0, 0, 56, 2),
				Rect2i(0, 36, 56, 2),
				Rect2i(0, 0, 2, 38),
				Rect2i(54, 0, 2, 38),
				Rect2i(2, 2, 12, 7),
				Rect2i(42, 2, 12, 7),
				Rect2i(2, 29, 12, 7),
				Rect2i(42, 29, 12, 7),
				Rect2i(24, 2, 8, 5),
			],
			"floor": [
				Rect2i(2, 2, 52, 34),
			],
			"obstacles": [
				Rect2i(20, 16, 8, 7),
				Rect2i(34, 18, 8, 7),
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
			"width_tiles":  60,
			"height_tiles": 40,
			"tileset_src":  3,
			"floor_tile":   Vector2i(0, 0),
			"wall_tile":    Vector2i(0, 0),
			"obstacle_tile": Vector2i(0, 0),
			"exit_dir": Vector2i(1, 0),
			"exit_tile_coords": [
				Vector2i(58, 19), Vector2i(58, 20), Vector2i(58, 21),
				Vector2i(59, 19), Vector2i(59, 20), Vector2i(59, 21),
			],
			"walls": [
				Rect2i(0, 0, 60, 2),
				Rect2i(0, 38, 60, 2),
				Rect2i(0, 0, 2, 40),
				Rect2i(58, 0, 2, 40),
				Rect2i(2, 2, 13, 7),
				Rect2i(45, 2, 13, 7),
				Rect2i(2, 30, 13, 8),
				Rect2i(45, 30, 13, 8),
				Rect2i(26, 2, 9, 5),
				Rect2i(26, 33, 9, 5),
			],
			"floor": [
				Rect2i(2, 2, 56, 36),
			],
			"obstacles": [
				Rect2i(20, 16, 7, 8),
				Rect2i(33, 16, 7, 8),
				Rect2i(46, 17, 5, 6),
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
			"width_tiles":  62,
			"height_tiles": 42,
			"tileset_src":  3,
			"floor_tile":   Vector2i(0, 0),
			"wall_tile":    Vector2i(0, 0),
			"obstacle_tile": Vector2i(0, 0),
			"exit_dir": Vector2i(1, 0),
			"exit_tile_coords": [
				Vector2i(60, 20), Vector2i(60, 21), Vector2i(60, 22),
				Vector2i(61, 20), Vector2i(61, 21), Vector2i(61, 22),
			],
			"walls": [
				Rect2i(0, 0, 62, 2),
				Rect2i(0, 40, 62, 2),
				Rect2i(0, 0, 2, 42),
				Rect2i(60, 0, 2, 42),
				Rect2i(2, 2, 14, 8),
				Rect2i(46, 2, 14, 8),
				Rect2i(2, 31, 14, 9),
				Rect2i(46, 31, 14, 9),
				Rect2i(28, 2, 10, 6),
				Rect2i(20, 34, 10, 6),
			],
			"floor": [
				Rect2i(2, 2, 58, 38),
			],
			"obstacles": [
				Rect2i(20, 17, 7, 8),
				Rect2i(34, 17, 7, 8),
				Rect2i(46, 18, 6, 7),
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
			"width_tiles":  65,
			"height_tiles": 44,
			"tileset_src":  3,
			"floor_tile":   Vector2i(0, 0),
			"wall_tile":    Vector2i(0, 0),
			"obstacle_tile": Vector2i(0, 0),
			"exit_dir": Vector2i(1, 0),
			"exit_tile_coords": [
				Vector2i(63, 21), Vector2i(63, 22), Vector2i(63, 23),
				Vector2i(64, 21), Vector2i(64, 22), Vector2i(64, 23),
			],
			"walls": [
				Rect2i(0, 0, 65, 2),
				Rect2i(0, 42, 65, 2),
				Rect2i(0, 0, 2, 44),
				Rect2i(63, 0, 2, 44),
				Rect2i(2, 2, 15, 9),
				Rect2i(48, 2, 15, 9),
				Rect2i(2, 32, 15, 10),
				Rect2i(48, 32, 15, 10),
				Rect2i(30, 2, 11, 6),
				Rect2i(24, 36, 11, 6),
				Rect2i(46, 35, 8, 7),
			],
			"floor": [
				Rect2i(2, 2, 61, 40),
			],
			"obstacles": [
				Rect2i(21, 18, 7, 8),
				Rect2i(35, 18, 7, 8),
				Rect2i(49, 19, 6, 7),
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
			"width_tiles":  80,
			"height_tiles": 9,
			"tileset_src":  6,
			"floor_tile":   Vector2i(0, 0),
			"wall_tile":    Vector2i(0, 0),
			"obstacle_tile": Vector2i(0, 0),
			"exit_dir": Vector2i(1, 0),
			"exit_tile_coords": [],
			"walls": [
				Rect2i(0, 0, 80, 1),
				Rect2i(0, 8, 80, 1),
			],
			"floor": [
				Rect2i(0, 1, 80, 7),
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
			"width_tiles":  55,
			"height_tiles": 38,
			"tileset_src":  10,
			"floor_tile":   Vector2i(0, 0),
			"wall_tile":    Vector2i(0, 0),
			"obstacle_tile": Vector2i(0, 0),
			"exit_dir": Vector2i(1, 0),
			"exit_tile_coords": [
				Vector2i(53, 18), Vector2i(53, 19), Vector2i(53, 20),
				Vector2i(54, 18), Vector2i(54, 19), Vector2i(54, 20),
			],
			"walls": [
				Rect2i(0, 0, 55, 2),
				Rect2i(0, 36, 55, 2),
				Rect2i(0, 0, 2, 38),
				Rect2i(53, 0, 2, 38),
				Rect2i(2, 2, 12, 9),
				Rect2i(41, 2, 12, 9),
				Rect2i(2, 27, 12, 9),
				Rect2i(41, 27, 12, 9),
			],
			"floor": [
				Rect2i(2, 2, 51, 34),
			],
			"obstacles": [
				Rect2i(24, 16, 7, 6),
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
			"width_tiles":  56,
			"height_tiles": 40,
			"tileset_src":  10,
			"floor_tile":   Vector2i(0, 0),
			"wall_tile":    Vector2i(0, 0),
			"obstacle_tile": Vector2i(0, 0),
			"exit_dir": Vector2i(1, 0),
			"exit_tile_coords": [
				Vector2i(54, 19), Vector2i(54, 20), Vector2i(54, 21),
				Vector2i(55, 19), Vector2i(55, 20), Vector2i(55, 21),
			],
			"walls": [
				Rect2i(0, 0, 56, 2),
				Rect2i(0, 38, 56, 2),
				Rect2i(0, 0, 2, 40),
				Rect2i(54, 0, 2, 40),
				Rect2i(2, 2, 10, 8),
				Rect2i(44, 2, 10, 8),
				Rect2i(2, 30, 10, 8),
				Rect2i(44, 30, 10, 8),
				Rect2i(20, 2, 16, 7),
				Rect2i(20, 31, 16, 7),
			],
			"floor": [
				Rect2i(2, 2, 52, 36),
			],
			"obstacles": [
				Rect2i(24, 17, 8, 6),
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
			"width_tiles":  60,
			"height_tiles": 42,
			"tileset_src":  10,
			"floor_tile":   Vector2i(0, 0),
			"wall_tile":    Vector2i(0, 0),
			"obstacle_tile": Vector2i(0, 0),
			"exit_dir": Vector2i(1, 0),
			"exit_tile_coords": [
				Vector2i(58, 20), Vector2i(58, 21), Vector2i(58, 22),
				Vector2i(59, 20), Vector2i(59, 21), Vector2i(59, 22),
			],
			"walls": [
				Rect2i(0, 0, 60, 2),
				Rect2i(0, 40, 60, 2),
				Rect2i(0, 0, 2, 42),
				Rect2i(58, 0, 2, 42),
				Rect2i(2, 2, 11, 9),
				Rect2i(47, 2, 11, 9),
				Rect2i(2, 31, 11, 9),
				Rect2i(47, 31, 11, 9),
				Rect2i(24, 2, 12, 8),
				Rect2i(24, 32, 12, 8),
			],
			"floor": [
				Rect2i(2, 2, 56, 38),
			],
			"obstacles": [
				Rect2i(26, 17, 8, 8),
				Rect2i(42, 18, 6, 7),
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
			"width_tiles":  62,
			"height_tiles": 44,
			"tileset_src":  10,
			"floor_tile":   Vector2i(0, 0),
			"wall_tile":    Vector2i(0, 0),
			"obstacle_tile": Vector2i(0, 0),
			"exit_dir": Vector2i(1, 0),
			"exit_tile_coords": [
				Vector2i(60, 21), Vector2i(60, 22), Vector2i(60, 23),
				Vector2i(61, 21), Vector2i(61, 22), Vector2i(61, 23),
			],
			"walls": [
				Rect2i(0, 0, 62, 2),
				Rect2i(0, 42, 62, 2),
				Rect2i(0, 0, 2, 44),
				Rect2i(60, 0, 2, 44),
				Rect2i(2, 2, 13, 10),
				Rect2i(47, 2, 13, 10),
				Rect2i(2, 32, 13, 10),
				Rect2i(47, 32, 13, 10),
				Rect2i(20, 2, 12, 9),
				Rect2i(34, 33, 12, 9),
			],
			"floor": [
				Rect2i(2, 2, 58, 40),
			],
			"obstacles": [
				Rect2i(24, 18, 7, 8),
				Rect2i(40, 19, 7, 8),
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
			"width_tiles":  65,
			"height_tiles": 46,
			"tileset_src":  10,
			"floor_tile":   Vector2i(0, 0),
			"wall_tile":    Vector2i(0, 0),
			"obstacle_tile": Vector2i(0, 0),
			"exit_dir": Vector2i(1, 0),
			"exit_tile_coords": [
				Vector2i(63, 22), Vector2i(63, 23), Vector2i(63, 24),
				Vector2i(64, 22), Vector2i(64, 23), Vector2i(64, 24),
			],
			"walls": [
				Rect2i(0, 0, 65, 2),
				Rect2i(0, 44, 65, 2),
				Rect2i(0, 0, 2, 46),
				Rect2i(63, 0, 2, 46),
				Rect2i(2, 2, 16, 12),
				Rect2i(47, 2, 16, 12),
				Rect2i(2, 32, 16, 12),
				Rect2i(47, 32, 16, 12),
				Rect2i(28, 2, 12, 7),
				Rect2i(28, 37, 12, 7),
			],
			"floor": [
				Rect2i(2, 2, 61, 42),
			],
			"obstacles": [
				Rect2i(30, 19, 8, 8),
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
			"width_tiles":  80,
			"height_tiles": 7,
			"tileset_src":  12,
			"floor_tile":   Vector2i(0, 0),
			"wall_tile":    Vector2i(0, 0),
			"obstacle_tile": Vector2i(0, 0),
			"exit_dir": Vector2i(1, 0),
			"exit_tile_coords": [],
			"walls": [
				Rect2i(0, 0, 80, 1),
				Rect2i(0, 6, 80, 1),
			],
			"floor": [
				Rect2i(0, 1, 80, 5),
			],
			"obstacles": [],
			"spawn_points": [
				Vector2(4 * 16, 2 * 16),
				Vector2(4 * 16, 3 * 16),
				Vector2(4 * 16, 4 * 16),
			],
			"enemy_spawns": [],
		},
	},

	## =======================================================================
	## ROOM 3: BURG ALTENBURG BAMBERG (Tiny Dungeon, stone, angular bailey)
	## =======================================================================
	3: {
		1: {
			"width_tiles":  55,
			"height_tiles": 40,
			"tileset_src":  1,
			"floor_tile":   Vector2i(0, 1),
			"wall_tile":    Vector2i(0, 0),
			"obstacle_tile": Vector2i(2, 0),
			"exit_dir": Vector2i(1, 0),
			"exit_tile_coords": [
				Vector2i(53, 19), Vector2i(53, 20), Vector2i(53, 21),
				Vector2i(54, 19), Vector2i(54, 20), Vector2i(54, 21),
			],
			"walls": [
				Rect2i(0, 0, 55, 2),
				Rect2i(0, 38, 55, 2),
				Rect2i(0, 0, 2, 40),
				Rect2i(53, 0, 2, 40),
				Rect2i(2, 2, 10, 8),
				Rect2i(43, 2, 10, 8),
				Rect2i(2, 30, 10, 8),
				Rect2i(43, 30, 10, 8),
			],
			"floor": [
				Rect2i(2, 2, 51, 36),
			],
			"obstacles": [
				Rect2i(25, 17, 6, 6),
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
			"width_tiles":  56,
			"height_tiles": 40,
			"tileset_src":  1,
			"floor_tile":   Vector2i(0, 1),
			"wall_tile":    Vector2i(0, 0),
			"obstacle_tile": Vector2i(2, 0),
			"exit_dir": Vector2i(1, 0),
			"exit_tile_coords": [
				Vector2i(54, 19), Vector2i(54, 20), Vector2i(54, 21),
				Vector2i(55, 19), Vector2i(55, 20), Vector2i(55, 21),
			],
			"walls": [
				Rect2i(0, 0, 56, 2),
				Rect2i(0, 38, 56, 2),
				Rect2i(0, 0, 2, 40),
				Rect2i(54, 0, 2, 40),
				Rect2i(2, 2, 9, 8),
				Rect2i(45, 2, 9, 8),
				Rect2i(2, 30, 9, 8),
				Rect2i(45, 30, 9, 8),
				Rect2i(20, 2, 16, 11),
				Rect2i(20, 27, 16, 11),
			],
			"floor": [
				Rect2i(2, 2, 52, 36),
			],
			"obstacles": [
				Rect2i(40, 18, 5, 5),
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
			"width_tiles":  60,
			"height_tiles": 42,
			"tileset_src":  1,
			"floor_tile":   Vector2i(0, 1),
			"wall_tile":    Vector2i(0, 0),
			"obstacle_tile": Vector2i(2, 0),
			"exit_dir": Vector2i(1, 0),
			"exit_tile_coords": [
				Vector2i(58, 20), Vector2i(58, 21), Vector2i(58, 22),
				Vector2i(59, 20), Vector2i(59, 21), Vector2i(59, 22),
			],
			"walls": [
				Rect2i(0, 0, 60, 2),
				Rect2i(0, 40, 60, 2),
				Rect2i(0, 0, 2, 42),
				Rect2i(58, 0, 2, 42),
				Rect2i(2, 2, 11, 9),
				Rect2i(47, 2, 11, 9),
				Rect2i(2, 31, 11, 9),
				Rect2i(47, 31, 11, 9),
			],
			"floor": [
				Rect2i(2, 2, 56, 38),
			],
			"obstacles": [
				Rect2i(28, 9, 5, 5),
				Rect2i(28, 28, 5, 5),
				Rect2i(16, 18, 5, 5),
				Rect2i(40, 18, 5, 5),
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
			"width_tiles":  65,
			"height_tiles": 44,
			"tileset_src":  1,
			"floor_tile":   Vector2i(0, 1),
			"wall_tile":    Vector2i(0, 0),
			"obstacle_tile": Vector2i(2, 0),
			"exit_dir": Vector2i(1, 0),
			"exit_tile_coords": [
				Vector2i(63, 21), Vector2i(63, 22), Vector2i(63, 23),
				Vector2i(64, 21), Vector2i(64, 22), Vector2i(64, 23),
			],
			"walls": [
				Rect2i(0, 0, 65, 2),
				Rect2i(0, 42, 65, 2),
				Rect2i(0, 0, 2, 44),
				Rect2i(63, 0, 2, 44),
				Rect2i(2, 2, 12, 9),
				Rect2i(51, 2, 12, 9),
				Rect2i(2, 33, 12, 9),
				Rect2i(51, 33, 12, 9),
				Rect2i(28, 2, 10, 7),
				Rect2i(28, 35, 10, 7),
			],
			"floor": [
				Rect2i(2, 2, 61, 40),
			],
			"obstacles": [
				Rect2i(18, 18, 5, 5),
				Rect2i(30, 16, 5, 5),
				Rect2i(30, 26, 5, 5),
				Rect2i(42, 18, 5, 5),
				Rect2i(42, 28, 5, 5),
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
			"width_tiles":  70,
			"height_tiles": 50,
			"tileset_src":  1,
			"floor_tile":   Vector2i(0, 1),
			"wall_tile":    Vector2i(0, 0),
			"obstacle_tile": Vector2i(2, 0),
			"exit_dir": Vector2i(0, 0),
			"exit_tile_coords": [],
			"walls": [
				Rect2i(0, 0, 70, 2),
				Rect2i(0, 48, 70, 2),
				Rect2i(0, 0, 2, 50),
				Rect2i(68, 0, 2, 50),
				Rect2i(2, 2, 3, 46),
				Rect2i(67, 2, 3, 46),
				Rect2i(2, 2, 66, 3),
				Rect2i(2, 47, 66, 3),
				Rect2i(5, 5, 8, 8),
				Rect2i(59, 5, 8, 8),
				Rect2i(5, 39, 8, 8),
				Rect2i(59, 39, 8, 8),
			],
			"floor": [
				Rect2i(2, 2, 66, 46),
			],
			"obstacles": [
				Rect2i(22, 20, 4, 4),
				Rect2i(46, 20, 4, 4),
				Rect2i(22, 30, 4, 4),
				Rect2i(46, 30, 4, 4),
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
