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
const SRC_MODERN: int = 0  ## roguelike-modern-city — rooms 1+2
const SRC_DUNGEON: int = 1  ## tiny-dungeon — room 3
const SRC_1BIT: int = 2     ## 1-bit-pack — room 3 wall fill fallback

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
## SUB_ROOM_DATA — keyed by room_id (1, 2, 3) then sub_room_id (1–6 or 1–5)
##
## Each sub-room dictionary shape (D-06 extended):
##   "floor"            : Array[Rect2i]   — floor tile fill rectangles
##   "walls"            : Array[Rect2i]   — wall tile fill rectangles (2-tile perimeter)
##   "obstacles"        : Array[Rect2i]   — solid obstacle rectangles
##   "exit_dir"         : Vector2i        — exit direction (Vector2i(1,0) = right; Vector2i(0,0) = no exit)
##   "exit_tile_coords" : Array[Vector2i] — the 3 wall tile coords forming the blocked exit passage
##   "spawn_points"     : Array[Vector2]  — player teleport positions in pixels (tile * TILE_SIZE)
##   "enemy_spawns"     : Array[Vector2]  — enemy spawn positions in pixels
##   "width_tiles"      : int             — sub-room width in tiles
##   "height_tiles"     : int             — sub-room height in tiles
##   "tileset_src"      : int             — which TileSet source ID to use
##   "floor_tile"       : Vector2i        — primary floor atlas coord
##   "wall_tile"        : Vector2i        — wall atlas coord
##   "obstacle_tile"    : Vector2i        — obstacle atlas coord
## ─────────────────────────────────────────────────────────────────────────────
static var SUB_ROOM_DATA: Dictionary = {

	## ═══════════════════════════════════════════════════════════════════════
	## ROOM 1: ERBA (Roguelike Modern City tileset, grass-dominant, open feel)
	## ═══════════════════════════════════════════════════════════════════════
	1: {
		## ── ERBA SR-1: Open island intro — lightest density ────────────────
		## 50×35 tiles. Perimeter wall 2 tiles. Inner floor 46×31.
		## 2 small obstacle blocks. Exit right wall at row 17.
		1: {
			"width_tiles":  50,
			"height_tiles": 35,
			"tileset_src":  0,  # SRC_MODERN
			"floor_tile":   Vector2i(0, 16),  # MC_FLOOR_GRASS
			"wall_tile":    Vector2i(0, 0),   # MC_WALL_BRICK
			"obstacle_tile": Vector2i(3, 0),  # MC_OBSTACLE_ROOF
			"exit_dir": Vector2i(1, 0),
			# exit_tile_coords: right wall (x=48,49) at rows 16,17,18 — 3-tile gap
			"exit_tile_coords": [
				Vector2i(48, 16), Vector2i(48, 17), Vector2i(48, 18),
				Vector2i(49, 16), Vector2i(49, 17), Vector2i(49, 18),
			],
			# Perimeter walls (2-tile thick): top, bottom, left, right
			"walls": [
				Rect2i(0, 0, 50, 2),       # top wall
				Rect2i(0, 33, 50, 2),      # bottom wall
				Rect2i(0, 0, 2, 35),       # left wall
				Rect2i(48, 0, 2, 35),      # right wall
			],
			# Floor: inner area 46×31 tiles
			"floor": [
				Rect2i(2, 2, 46, 31),      # main floor
			],
			# Obstacles: 2 small blocks (3×3 and 4×4)
			"obstacles": [
				Rect2i(8, 8,  4, 4),   # NW building block
				Rect2i(34, 22, 3, 3),  # SE small block
			],
			# Player spawn points (pixels): left quarter, 3 vertical positions
			"spawn_points": [
				Vector2(5 * 16, 9 * 16),
				Vector2(5 * 16, 17 * 16),
				Vector2(5 * 16, 25 * 16),
			],
			# Enemy spawn points (pixels): corners and right side
			"enemy_spawns": [
				Vector2(38 * 16, 5 * 16),
				Vector2(38 * 16, 29 * 16),
				Vector2(20 * 16, 5 * 16),
				Vector2(20 * 16, 29 * 16),
				Vector2(44 * 16, 12 * 16),
				Vector2(44 * 16, 22 * 16),
			],
		},

		## ── ERBA SR-2: Open park + first building blocks ────────────────────
		## 55×38 tiles. 2–3 obstacle blocks. Exit right wall at row 19.
		2: {
			"width_tiles":  55,
			"height_tiles": 38,
			"tileset_src":  0,
			"floor_tile":   Vector2i(0, 16),  # MC_FLOOR_GRASS
			"wall_tile":    Vector2i(0, 0),
			"obstacle_tile": Vector2i(3, 0),
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
			],
			"floor": [
				Rect2i(2, 2, 51, 34),
			],
			"obstacles": [
				Rect2i(8, 8, 5, 5),    # NW block
				Rect2i(30, 20, 4, 4),  # center block
				Rect2i(40, 8, 4, 4),   # NE block
			],
			"spawn_points": [
				Vector2(5 * 16, 10 * 16),
				Vector2(5 * 16, 19 * 16),
				Vector2(5 * 16, 28 * 16),
			],
			"enemy_spawns": [
				Vector2(42 * 16, 5 * 16),
				Vector2(42 * 16, 32 * 16),
				Vector2(20 * 16, 5 * 16),
				Vector2(20 * 16, 32 * 16),
				Vector2(48 * 16, 12 * 16),
				Vector2(48 * 16, 26 * 16),
			],
		},

		## ── ERBA SR-3: Mixed asphalt/grass, 3–4 obstacles ──────────────────
		## 60×40 tiles. Exit right wall at row 20.
		3: {
			"width_tiles":  60,
			"height_tiles": 40,
			"tileset_src":  0,
			"floor_tile":   Vector2i(0, 16),  # MC_FLOOR_GRASS
			"wall_tile":    Vector2i(0, 0),
			"obstacle_tile": Vector2i(3, 0),
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
			],
			"floor": [
				Rect2i(2, 2, 56, 36),
			],
			"obstacles": [
				Rect2i(8, 8, 5, 5),    # NW
				Rect2i(8, 26, 5, 5),   # SW
				Rect2i(30, 14, 6, 6),  # center
				Rect2i(42, 27, 4, 5),  # SE quadrant
			],
			"spawn_points": [
				Vector2(5 * 16, 10 * 16),
				Vector2(5 * 16, 20 * 16),
				Vector2(5 * 16, 30 * 16),
			],
			"enemy_spawns": [
				Vector2(46 * 16, 5 * 16),
				Vector2(46 * 16, 34 * 16),
				Vector2(22 * 16, 5 * 16),
				Vector2(22 * 16, 34 * 16),
				Vector2(52 * 16, 14 * 16),
				Vector2(52 * 16, 26 * 16),
				Vector2(34 * 16, 5 * 16),
			],
		},

		## ── ERBA SR-4: Denser buildings, narrowing paths ───────────────────
		## 60×42 tiles. 4–5 obstacle blocks. Exit right wall at row 21.
		4: {
			"width_tiles":  60,
			"height_tiles": 42,
			"tileset_src":  0,
			"floor_tile":   Vector2i(0, 16),  # MC_FLOOR_GRASS
			"wall_tile":    Vector2i(0, 0),
			"obstacle_tile": Vector2i(3, 0),
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
			],
			"floor": [
				Rect2i(2, 2, 56, 38),
			],
			"obstacles": [
				Rect2i(8, 8, 6, 6),    # NW
				Rect2i(8, 27, 6, 6),   # SW
				Rect2i(28, 10, 6, 7),  # upper center
				Rect2i(28, 25, 6, 7),  # lower center
				Rect2i(44, 16, 5, 5),  # mid-right
			],
			"spawn_points": [
				Vector2(5 * 16, 10 * 16),
				Vector2(5 * 16, 21 * 16),
				Vector2(5 * 16, 32 * 16),
			],
			"enemy_spawns": [
				Vector2(46 * 16, 5 * 16),
				Vector2(46 * 16, 36 * 16),
				Vector2(22 * 16, 5 * 16),
				Vector2(22 * 16, 36 * 16),
				Vector2(52 * 16, 14 * 16),
				Vector2(52 * 16, 28 * 16),
				Vector2(36 * 16, 5 * 16),
				Vector2(36 * 16, 36 * 16),
			],
		},

		## ── ERBA SR-5: Pre-corridor — most obstacles, heaviest density ─────
		## 65×44 tiles. 5–6 obstacle blocks. Exit right wall at row 22.
		5: {
			"width_tiles":  65,
			"height_tiles": 44,
			"tileset_src":  0,
			"floor_tile":   Vector2i(0, 16),  # MC_FLOOR_GRASS
			"wall_tile":    Vector2i(0, 0),
			"obstacle_tile": Vector2i(3, 0),
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
			],
			"floor": [
				Rect2i(2, 2, 61, 40),
			],
			"obstacles": [
				Rect2i(8, 7, 7, 7),    # NW
				Rect2i(8, 29, 7, 7),   # SW
				Rect2i(25, 10, 7, 8),  # upper left-center
				Rect2i(25, 25, 7, 8),  # lower left-center
				Rect2i(44, 10, 6, 7),  # upper right-center
				Rect2i(44, 26, 6, 6),  # lower right-center
			],
			"spawn_points": [
				Vector2(5 * 16, 11 * 16),
				Vector2(5 * 16, 22 * 16),
				Vector2(5 * 16, 33 * 16),
			],
			"enemy_spawns": [
				Vector2(50 * 16, 5 * 16),
				Vector2(50 * 16, 38 * 16),
				Vector2(22 * 16, 5 * 16),
				Vector2(22 * 16, 38 * 16),
				Vector2(57 * 16, 14 * 16),
				Vector2(57 * 16, 30 * 16),
				Vector2(36 * 16, 5 * 16),
				Vector2(36 * 16, 38 * 16),
			],
		},

		## ── ERBA SR-6 (Connector): Straight horizontal road corridor ───────
		## 80×10 tiles. Minimal walls (1-tile top/bottom). Road floor. No obstacles.
		## Full-width exit — connector ends at right edge.
		6: {
			"width_tiles":  80,
			"height_tiles": 10,
			"tileset_src":  0,
			"floor_tile":   Vector2i(0, 15),   # MC_CONNECTOR_ROAD
			"wall_tile":    Vector2i(0, 0),    # MC_WALL_BRICK
			"obstacle_tile": Vector2i(3, 0),   # unused in connector
			"exit_dir": Vector2i(1, 0),
			# Connector exit: full right edge (no blocked-wall exit passage needed)
			"exit_tile_coords": [],
			"walls": [
				Rect2i(0, 0, 80, 1),   # top wall (1 tile)
				Rect2i(0, 9, 80, 1),   # bottom wall (1 tile)
			],
			"floor": [
				Rect2i(0, 1, 80, 8),   # full corridor floor
			],
			"obstacles": [],
			"spawn_points": [
				Vector2(4 * 16, 3 * 16),
				Vector2(4 * 16, 5 * 16),
				Vector2(4 * 16, 7 * 16),
			],
			"enemy_spawns": [],
		},
	},

	## ═══════════════════════════════════════════════════════════════════════
	## ROOM 2: BAMBERG ALTSTADT (Roguelike Modern City, asphalt-dominant, tighter)
	## ═══════════════════════════════════════════════════════════════════════
	2: {
		## ── ALTSTADT SR-1: Entry square — slightly open ─────────────────────
		## 55×38 tiles. More obstacles than ERBA SR-1. Exit right wall at row 19.
		1: {
			"width_tiles":  55,
			"height_tiles": 38,
			"tileset_src":  0,
			"floor_tile":   Vector2i(0, 13),   # MC_FLOOR_ASPHALT
			"wall_tile":    Vector2i(0, 0),    # MC_WALL_BRICK
			"obstacle_tile": Vector2i(3, 0),   # MC_OBSTACLE_ROOF
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
			],
			"floor": [
				Rect2i(2, 2, 51, 34),
			],
			"obstacles": [
				Rect2i(8, 6, 6, 7),    # NW building
				Rect2i(8, 24, 6, 7),   # SW building
				Rect2i(24, 12, 5, 5),  # center-left block
				Rect2i(38, 6, 5, 5),   # NE block
				Rect2i(38, 26, 5, 5),  # SE block
			],
			"spawn_points": [
				Vector2(5 * 16, 9 * 16),
				Vector2(5 * 16, 19 * 16),
				Vector2(5 * 16, 29 * 16),
			],
			"enemy_spawns": [
				Vector2(44 * 16, 5 * 16),
				Vector2(44 * 16, 32 * 16),
				Vector2(20 * 16, 5 * 16),
				Vector2(20 * 16, 32 * 16),
				Vector2(50 * 16, 14 * 16),
				Vector2(50 * 16, 24 * 16),
			],
		},

		## ── ALTSTADT SR-2: First narrow street corridors ────────────────────
		## 55×40 tiles. Obstacle rows creating 2 main corridors, each 5–6 tiles wide.
		2: {
			"width_tiles":  55,
			"height_tiles": 40,
			"tileset_src":  0,
			"floor_tile":   Vector2i(0, 13),  # MC_FLOOR_ASPHALT
			"wall_tile":    Vector2i(0, 0),
			"obstacle_tile": Vector2i(3, 0),
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
			],
			"floor": [
				Rect2i(2, 2, 51, 36),
			],
			# Two building rows creating corridors (each block leaves 5-tile gaps)
			"obstacles": [
				Rect2i(8, 5, 8, 12),   # north row, left block
				Rect2i(22, 5, 8, 12),  # north row, right block
				Rect2i(36, 5, 8, 12),  # north row, far right
				Rect2i(8, 22, 8, 12),  # south row, left block
				Rect2i(22, 22, 8, 12), # south row, center
				Rect2i(36, 22, 8, 12), # south row, far right
			],
			"spawn_points": [
				Vector2(5 * 16, 8 * 16),
				Vector2(5 * 16, 20 * 16),
				Vector2(5 * 16, 32 * 16),
			],
			"enemy_spawns": [
				Vector2(44 * 16, 5 * 16),
				Vector2(44 * 16, 33 * 16),
				Vector2(18 * 16, 3 * 16),
				Vector2(18 * 16, 35 * 16),
				Vector2(50 * 16, 18 * 16),
				Vector2(50 * 16, 30 * 16),
			],
		},

		## ── ALTSTADT SR-3: Dense block grid, multiple choke points ──────────
		## 60×42 tiles. 3 corridor paths, 2 of them 4 tiles wide. Exit right row 21.
		3: {
			"width_tiles":  60,
			"height_tiles": 42,
			"tileset_src":  0,
			"floor_tile":   Vector2i(0, 13),  # MC_FLOOR_ASPHALT
			"wall_tile":    Vector2i(0, 0),
			"obstacle_tile": Vector2i(3, 0),
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
			],
			"floor": [
				Rect2i(2, 2, 56, 38),
			],
			# Dense grid: building blocks with 4-tile corridors between them
			"obstacles": [
				Rect2i(8, 5, 9, 14),   # NW large block
				Rect2i(23, 5, 9, 14),  # N center block
				Rect2i(38, 5, 9, 14),  # NE block
				Rect2i(8, 23, 9, 14),  # SW large block
				Rect2i(23, 23, 9, 14), # S center block
				Rect2i(38, 23, 9, 14), # SE block
			],
			"spawn_points": [
				Vector2(5 * 16, 10 * 16),
				Vector2(5 * 16, 21 * 16),
				Vector2(5 * 16, 32 * 16),
			],
			"enemy_spawns": [
				Vector2(48 * 16, 4 * 16),
				Vector2(48 * 16, 36 * 16),
				Vector2(20 * 16, 3 * 16),
				Vector2(20 * 16, 37 * 16),
				Vector2(54 * 16, 16 * 16),
				Vector2(54 * 16, 30 * 16),
				Vector2(34 * 16, 3 * 16),
			],
		},

		## ── ALTSTADT SR-4: Tightest layout, punishes clustering ─────────────
		## 60×44 tiles. Most building mass. 4-tile corridors. Exit right row 22.
		4: {
			"width_tiles":  60,
			"height_tiles": 44,
			"tileset_src":  0,
			"floor_tile":   Vector2i(0, 13),  # MC_FLOOR_ASPHALT
			"wall_tile":    Vector2i(0, 0),
			"obstacle_tile": Vector2i(3, 0),
			"exit_dir": Vector2i(1, 0),
			"exit_tile_coords": [
				Vector2i(58, 21), Vector2i(58, 22), Vector2i(58, 23),
				Vector2i(59, 21), Vector2i(59, 22), Vector2i(59, 23),
			],
			"walls": [
				Rect2i(0, 0, 60, 2),
				Rect2i(0, 42, 60, 2),
				Rect2i(0, 0, 2, 44),
				Rect2i(58, 0, 2, 44),
			],
			"floor": [
				Rect2i(2, 2, 56, 40),
			],
			# Tightest layout: L-shaped building arrangement, 4-tile gaps
			"obstacles": [
				Rect2i(8, 5, 10, 16),  # NW mega block
				Rect2i(8, 23, 10, 16), # SW mega block
				Rect2i(24, 9, 10, 9),  # center-top block
				Rect2i(24, 26, 10, 9), # center-bottom block
				Rect2i(40, 5, 8, 10),  # NE upper
				Rect2i(40, 19, 8, 6),  # NE lower
				Rect2i(40, 29, 8, 10), # SE block
			],
			"spawn_points": [
				Vector2(5 * 16, 10 * 16),
				Vector2(5 * 16, 22 * 16),
				Vector2(5 * 16, 34 * 16),
			],
			"enemy_spawns": [
				Vector2(50 * 16, 4 * 16),
				Vector2(50 * 16, 38 * 16),
				Vector2(20 * 16, 3 * 16),
				Vector2(20 * 16, 39 * 16),
				Vector2(56 * 16, 16 * 16),
				Vector2(56 * 16, 30 * 16),
				Vector2(36 * 16, 3 * 16),
				Vector2(36 * 16, 39 * 16),
			],
		},

		## ── ALTSTADT SR-5: Large central courtyard + building mass ──────────
		## 65×45 tiles. Large building block in center. Exit right row 22.
		5: {
			"width_tiles":  65,
			"height_tiles": 45,
			"tileset_src":  0,
			"floor_tile":   Vector2i(0, 13),  # MC_FLOOR_ASPHALT
			"wall_tile":    Vector2i(0, 0),
			"obstacle_tile": Vector2i(3, 0),
			"exit_dir": Vector2i(1, 0),
			"exit_tile_coords": [
				Vector2i(63, 21), Vector2i(63, 22), Vector2i(63, 23),
				Vector2i(64, 21), Vector2i(64, 22), Vector2i(64, 23),
			],
			"walls": [
				Rect2i(0, 0, 65, 2),
				Rect2i(0, 43, 65, 2),
				Rect2i(0, 0, 2, 45),
				Rect2i(63, 0, 2, 45),
			],
			"floor": [
				Rect2i(2, 2, 61, 41),
			],
			"obstacles": [
				Rect2i(8, 6, 10, 10),   # NW block
				Rect2i(8, 28, 10, 10),  # SW block
				Rect2i(26, 8, 18, 12),  # large center-north block
				Rect2i(26, 24, 18, 12), # large center-south block
				Rect2i(50, 6, 8, 10),   # NE block
				Rect2i(50, 28, 8, 10),  # SE block
			],
			"spawn_points": [
				Vector2(5 * 16, 11 * 16),
				Vector2(5 * 16, 22 * 16),
				Vector2(5 * 16, 33 * 16),
			],
			"enemy_spawns": [
				Vector2(52 * 16, 4 * 16),
				Vector2(52 * 16, 40 * 16),
				Vector2(22 * 16, 4 * 16),
				Vector2(22 * 16, 40 * 16),
				Vector2(58 * 16, 16 * 16),
				Vector2(58 * 16, 32 * 16),
				Vector2(36 * 16, 4 * 16),
				Vector2(36 * 16, 40 * 16),
			],
		},

		## ── ALTSTADT SR-6 (Connector): Road corridor → Burg transition ─────────
		## 80×10 tiles. Road floor (Modern City). Must use SRC_MODERN (0) since
		## Room2/TileMap only has TileSetModern — source_id=1 would silently fail.
		6: {
			"width_tiles":  80,
			"height_tiles": 10,
			"tileset_src":  0,  # SRC_MODERN — Room2/TileMap only has source 0
			"floor_tile":   Vector2i(0, 15),   # MC_CONNECTOR_ROAD (dark asphalt)
			"wall_tile":    Vector2i(0, 0),    # MC_WALL_BRICK
			"obstacle_tile": Vector2i(3, 0),   # unused
			"exit_dir": Vector2i(1, 0),
			"exit_tile_coords": [],
			"walls": [
				Rect2i(0, 0, 80, 1),
				Rect2i(0, 9, 80, 1),
			],
			"floor": [
				Rect2i(0, 1, 80, 8),
			],
			"obstacles": [],
			"spawn_points": [
				Vector2(4 * 16, 3 * 16),
				Vector2(4 * 16, 5 * 16),
				Vector2(4 * 16, 7 * 16),
			],
			"enemy_spawns": [],
		},
	},

	## ═══════════════════════════════════════════════════════════════════════
	## ROOM 3: BURG ALTENBURG (Tiny Dungeon tileset, stone fortress feel)
	## No connector — SR-5 is boss arena, boss death ends loop.
	## ═══════════════════════════════════════════════════════════════════════
	3: {
		## ── BURG SR-1: Outer fortress courtyard ─────────────────────────────
		## 55×40 tiles. 2–3 tower obstacle blocks. Exit right wall at row 20.
		1: {
			"width_tiles":  55,
			"height_tiles": 40,
			"tileset_src":  1,  # SRC_DUNGEON
			"floor_tile":   Vector2i(0, 1),    # TD_FLOOR_STONE
			"wall_tile":    Vector2i(0, 0),    # TD_WALL_CASTLE
			"obstacle_tile": Vector2i(2, 0),   # TD_OBSTACLE_TOWER
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
			],
			"floor": [
				Rect2i(2, 2, 51, 36),
			],
			"obstacles": [
				Rect2i(10, 8, 5, 5),   # NW tower
				Rect2i(10, 26, 5, 5),  # SW tower
				Rect2i(34, 16, 5, 5),  # center tower
			],
			"spawn_points": [
				Vector2(5 * 16, 10 * 16),
				Vector2(5 * 16, 20 * 16),
				Vector2(5 * 16, 30 * 16),
			],
			"enemy_spawns": [
				Vector2(44 * 16, 5 * 16),
				Vector2(44 * 16, 34 * 16),
				Vector2(22 * 16, 5 * 16),
				Vector2(22 * 16, 34 * 16),
				Vector2(50 * 16, 14 * 16),
				Vector2(50 * 16, 26 * 16),
			],
		},

		## ── BURG SR-2: Inner gatehouse passage ──────────────────────────────
		## 55×40 tiles. Narrower walkway pattern. Exit right row 20.
		2: {
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
			],
			"floor": [
				Rect2i(2, 2, 51, 36),
			],
			# Gatehouse: two large blocks with narrow center passage
			"obstacles": [
				Rect2i(8, 5, 8, 12),   # north wall-block
				Rect2i(8, 23, 8, 12),  # south wall-block
				Rect2i(22, 8, 8, 10),  # center-north block
				Rect2i(22, 22, 8, 10), # center-south block
				Rect2i(38, 10, 5, 5),  # NE tower
				Rect2i(38, 24, 5, 5),  # SE tower
			],
			"spawn_points": [
				Vector2(5 * 16, 10 * 16),
				Vector2(5 * 16, 20 * 16),
				Vector2(5 * 16, 30 * 16),
			],
			"enemy_spawns": [
				Vector2(44 * 16, 4 * 16),
				Vector2(44 * 16, 34 * 16),
				Vector2(18 * 16, 3 * 16),
				Vector2(18 * 16, 35 * 16),
				Vector2(50 * 16, 16 * 16),
				Vector2(50 * 16, 28 * 16),
			],
		},

		## ── BURG SR-3: Second courtyard with tower obstacles ────────────────
		## 60×42 tiles. 3–4 tower blocks. Exit right row 21.
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
			],
			"floor": [
				Rect2i(2, 2, 56, 38),
			],
			"obstacles": [
				Rect2i(8, 7, 5, 5),    # NW tower
				Rect2i(8, 29, 5, 5),   # SW tower
				Rect2i(24, 12, 5, 5),  # center-west tower
				Rect2i(24, 24, 5, 5),  # center-west lower tower
				Rect2i(40, 7, 5, 5),   # NE tower
				Rect2i(40, 29, 5, 5),  # SE tower
			],
			"spawn_points": [
				Vector2(5 * 16, 10 * 16),
				Vector2(5 * 16, 21 * 16),
				Vector2(5 * 16, 32 * 16),
			],
			"enemy_spawns": [
				Vector2(48 * 16, 4 * 16),
				Vector2(48 * 16, 36 * 16),
				Vector2(20 * 16, 4 * 16),
				Vector2(20 * 16, 36 * 16),
				Vector2(54 * 16, 14 * 16),
				Vector2(54 * 16, 28 * 16),
				Vector2(34 * 16, 4 * 16),
			],
		},

		## ── BURG SR-4: Approach to keep — dense tower arrangement ───────────
		## 65×44 tiles. Densest tower arrangement before boss. Exit right row 22.
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
			],
			"floor": [
				Rect2i(2, 2, 61, 40),
			],
			"obstacles": [
				Rect2i(8, 7, 5, 5),    # NW tower
				Rect2i(8, 17, 5, 5),   # W-upper tower
				Rect2i(8, 31, 5, 5),   # SW tower
				Rect2i(20, 10, 5, 5),  # inner NW
				Rect2i(20, 28, 5, 5),  # inner SW
				Rect2i(34, 7, 5, 5),   # N-center tower
				Rect2i(34, 31, 5, 5),  # S-center tower
				Rect2i(48, 10, 5, 5),  # NE tower
				Rect2i(48, 28, 5, 5),  # SE tower
			],
			"spawn_points": [
				Vector2(5 * 16, 11 * 16),
				Vector2(5 * 16, 22 * 16),
				Vector2(5 * 16, 33 * 16),
			],
			"enemy_spawns": [
				Vector2(54 * 16, 4 * 16),
				Vector2(54 * 16, 38 * 16),
				Vector2(22 * 16, 4 * 16),
				Vector2(22 * 16, 38 * 16),
				Vector2(60 * 16, 14 * 16),
				Vector2(60 * 16, 30 * 16),
				Vector2(40 * 16, 4 * 16),
				Vector2(40 * 16, 38 * 16),
			],
		},

		## ── BURG SR-5 (Boss Arena): Open arena — boss fight ─────────────────
		## 70×50 tiles. Open 40×30 center zone clear of obstacles.
		## 3-tile perimeter wall. No exit (boss death → loop end).
		## exit_dir = Vector2i(0, 0) signals no exit passage.
		5: {
			"width_tiles":  70,
			"height_tiles": 50,
			"tileset_src":  1,
			"floor_tile":   Vector2i(0, 1),
			"wall_tile":    Vector2i(0, 0),
			"obstacle_tile": Vector2i(2, 0),
			"exit_dir": Vector2i(0, 0),  # no exit — boss death ends loop
			"exit_tile_coords": [],       # no blocked exit passage
			# 3-tile thick perimeter walls
			"walls": [
				Rect2i(0, 0, 70, 3),    # top wall 3 tiles thick
				Rect2i(0, 47, 70, 3),   # bottom wall 3 tiles thick
				Rect2i(0, 0, 3, 50),    # left wall 3 tiles thick
				Rect2i(67, 0, 3, 50),   # right wall 3 tiles thick
			],
			# Floor with no center obstacles — clear 40×30 zone at center
			# Center zone: tiles (15,10) to (55,40)
			"floor": [
				Rect2i(3, 3, 64, 44),   # full inner area
			],
			# Perimeter-only obstacles (corner towers — not in center clear zone)
			"obstacles": [
				Rect2i(4, 4, 4, 4),     # NW corner tower
				Rect2i(62, 4, 4, 4),    # NE corner tower
				Rect2i(4, 42, 4, 4),    # SW corner tower
				Rect2i(62, 42, 4, 4),   # SE corner tower
			],
			# Spawn points: bottom center (players enter from south)
			"spawn_points": [
				Vector2(32 * 16, 40 * 16),
				Vector2(35 * 16, 42 * 16),
				Vector2(38 * 16, 40 * 16),
			],
			"enemy_spawns": [
				# Boss spawns in center of the arena
				Vector2(35 * 16, 25 * 16),
			],
		},
	},
}
