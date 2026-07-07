## RoomBuilder.gd
## Phase 9 (D-04, MAP-08): TileMap population engine.
## Reads SUB_ROOM_DATA from RoomLayouts.gd and populates the active room's TileMap
## by calling set_cell() for floor, wall, and obstacle rects.
## Also repopulates Marker2D spawn point nodes from layout data.
##
## Design decisions:
##   - extends RefCounted: no node lifecycle, no _ready(), pure functional
##   - Separation of concerns: does NOT call _bake_navigation — Game.gd owns that step
##   - Called from _transition_to_sub_room() (RPC call_local context on all peers)
##   - Returns Rect2 pixel bounds so Game.gd can update camera limits
class_name RoomBuilder
extends RefCounted

## Phase 9 (D-04, MAP-08): Build a sub-room by populating the TileMap with floor/wall/obstacle
## rects from RoomLayouts.SUB_ROOM_DATA, then repopulate spawn point Marker2D children.
##
## @param room_id      Room index (1, 2, or 3)
## @param sub_room_id  Sub-room index (1–5 for rooms 1+2, 1–5 for room 3, 6 = connector)
## @param game_node    The Game scene root Node2D (used to resolve room node paths)
## @returns            Pixel bounds of the sub-room as Rect2 (for camera limit update)
func build_sub_room(room_id: int, sub_room_id: int, game_node: Node) -> Rect2:
	## Step 1: Retrieve layout from static data
	var layout: Dictionary = RoomLayouts.SUB_ROOM_DATA[room_id][sub_room_id]

	## Step 2: Get TileMap node
	var tilemap: TileMap = game_node.get_node("Room%d/TileMap" % room_id)

	## Step 3: Clear all cells from all layers — removes stale tiles from previous sub-rooms
	tilemap.clear()

	## Step 4: Determine source_id from layout["tileset_src"]
	var source_id: int = layout["tileset_src"]  # SRC_MODERN=0 or SRC_DUNGEON=1

	## Step 4b: Register all atlas tiles this sub-room will use.
	## Godot 4 requires tiles to be registered on TileSetAtlasSource before set_cell() renders them.
	## Room 1 (ERBA) uses its own multi-source registration across the erba atlases.
	var is_erba: bool = room_id == 1
	var is_alt: bool = room_id == 2
	if is_erba or is_alt:
		if is_erba:
			_register_erba_tiles(tilemap)
		else:
			_register_altstadt_tiles(tilemap)
		## Obstacles/deco render on layer 1 ABOVE the floor — the ERBA rocks and the
		## Altstadt roof tile have transparent edges, so the floor must stay visible.
		if tilemap.get_layers_count() < 2:
			tilemap.add_layer(-1)
	else:
		var _src := tilemap.tile_set.get_source(source_id) as TileSetAtlasSource
		if _src:
			## Floor / decorative tiles — no collision.
			## Mix tiles are modern-city-only; dungeon tileset has 11 rows so registering
			## MC rows 16-17 there triggers "outside texture" errors.
			var _floor_reg: Array[Vector2i] = [layout["floor_tile"]]
			if source_id == RoomLayouts.SRC_MODERN:
				_floor_reg.append_array([
					RoomLayouts.MC_FLOOR_CRACK,
					RoomLayouts.MC_FLOOR_GRASS_ALT,
					RoomLayouts.MC_FLOOR_GRASS,
				])
			for _ac: Vector2i in _floor_reg:
				if not _src.has_tile(_ac):
					_src.create_tile(_ac)
			## Solid tiles (walls + obstacles) — full-cell collision polygon on physics layer 0
			## so the player and bullets actually collide with them.
			for _ac: Vector2i in [layout["wall_tile"], layout["obstacle_tile"]]:
				_ensure_solid_tile(_src, _ac, RoomLayouts.TILE_SIZE / 2.0)

	## Step 5: Place floor tiles with optional mix rules per room
	## Room 1 (ERBA): hash-weighted grass variants from erba_floor.png (see below)
	## Room 2 (Altstadt): every 10th tile (mix_idx % 10 == 0) → grass
	## Room 3 (Burg Altenburg): no mixing — pure stone
	var floor_tile: Vector2i = layout["floor_tile"]
	for floor_rect in layout["floor"]:
		var rect: Rect2i = floor_rect
		for x_off in range(rect.size.x):
			for y_off in range(rect.size.y):
				var coords := Vector2i(rect.position.x + x_off, rect.position.y + y_off)
				var tile: Vector2i = floor_tile
				if is_erba:
					## Macro blocks: every texture spans 2x2 cells; the cell renders the
					## quadrant matching its position, the variant is hashed PER BLOCK
					## (top-left cell) so all four quadrants always agree.
					var quad := Vector2i(posmod(coords.x, 2), posmod(coords.y, 2))
					if sub_room_id == 6:
						## Connector: pure stone road, macro-tiled
						tile = floor_tile + quad
					else:
						## Weighted grass pick per block: ~1/16 slab blocks, ~3/16
						## flowers/tufts, rest plain grass variants.
						var blk := coords - quad
						var cat: int = _cell_hash(blk, 1) % 16
						var pick: int = _cell_hash(blk, 2)
						if cat == 0:
							tile = RoomLayouts.ERBA_GRASS_SLABS[pick % RoomLayouts.ERBA_GRASS_SLABS.size()]
						elif cat <= 3:
							tile = RoomLayouts.ERBA_GRASS_DETAIL[pick % RoomLayouts.ERBA_GRASS_DETAIL.size()]
						else:
							tile = RoomLayouts.ERBA_GRASS_PLAIN[pick % RoomLayouts.ERBA_GRASS_PLAIN.size()]
						tile += quad
				elif is_alt and sub_room_id != 6:
					## janv2 art: single-tile sources, so the mix switches the SOURCE
					## (asphalt vs mossy grass patch), not the atlas coord.
					if _cell_hash(coords, 1) % 10 == 0:
						tilemap.set_cell(0, coords, RoomLayouts.SRC_ALT_GRASS, Vector2i(0, 0))
						continue
				## room_id == 3: no mixing — pure stone
				tilemap.set_cell(0, coords, source_id, tile)

	## Step 6: Place wall tiles
	## ERBA 2.5D: light comes from above — wall cells show the bright CAP (top-down
	## slabs); only south edges (no wall below) get one row of the dark brick FACE.
	## The standard 2-tile perimeter reads as cap row + shadowed front + contact shadow.
	## Altstadt keeps its face/cap split. wall_cells tracks wall coords so shadow and
	## face detection cannot mistake a wall for floor (walls are not yet on the map).
	var wall_tile: Vector2i = layout["wall_tile"]
	var use_depth: bool = is_erba or is_alt
	var wall_cells := {}
	if use_depth:
		for wall_rect in layout["walls"]:
			var r: Rect2i = wall_rect
			for x_off in range(r.size.x):
				for y_off in range(r.size.y):
					wall_cells[Vector2i(r.position.x + x_off, r.position.y + y_off)] = true
	for wall_rect in layout["walls"]:
		var rect: Rect2i = wall_rect
		for x_off in range(rect.size.x):
			for y_off in range(rect.size.y):
				var coords := Vector2i(rect.position.x + x_off, rect.position.y + y_off)
				if is_erba:
					var quad := Vector2i(posmod(coords.x, 2), posmod(coords.y, 2))
					var tile: Vector2i
					if not wall_cells.has(coords + Vector2i(0, 1)):
						## South edge: one row of dark brick face. Always the BOTTOM
						## half of the face texture (its base/moss row meets the grass);
						## hash per 2-wide column block so both halves agree.
						var blk := coords - Vector2i(quad.x, 0)
						var pick: int = _cell_hash(blk, 3)
						tile = RoomLayouts.ERBA_WALL_FACES[pick % RoomLayouts.ERBA_WALL_FACES.size()] \
							+ Vector2i(quad.x, 1)
					else:
						## Everything else is the bright top-down cap, standard 2x2 macro.
						var pick: int = _cell_hash(coords - quad, 3)
						tile = RoomLayouts.ERBA_WALL_CAPS[pick % RoomLayouts.ERBA_WALL_CAPS.size()] + quad
					tilemap.set_cell(0, coords, RoomLayouts.SRC_ERBA_WALL, tile)
				elif use_depth:
					## Altstadt: single wall PNG — face and cap are two sources sharing
					## the texture; the cap source is darkened via modulate.
					var below := coords + Vector2i(0, 1)
					var below_is_floor: bool = not wall_cells.has(below) \
						and tilemap.get_cell_source_id(0, below) != -1
					var src: int = RoomLayouts.SRC_ALT_WALL if below_is_floor else RoomLayouts.SRC_ALT_WALL_CAP
					tilemap.set_cell(0, coords, src, Vector2i(0, 0))
				else:
					tilemap.set_cell(0, coords, source_id, wall_tile)
	## Step 6b (ERBA 2.5D): cast a contact shadow under each wall — but not as one straight
	## line. Directly below the wall the shadow is strong; below that it continues SOFT on
	## a per-column hash (~2/3 of columns) for a ragged edge, and at the right-hand end of
	## a wall run one soft cell leans diagonally down-right, as if the light came from the
	## upper left. Road tiles (connector) stay untouched.
	if is_erba:
		var soft_cells := {}
		for w: Vector2i in wall_cells:
			var below: Vector2i = w + Vector2i(0, 1)
			if wall_cells.has(below):
				continue
			if tilemap.get_cell_source_id(0, below) == RoomLayouts.SRC_ERBA_GRASS:
				tilemap.set_cell(0, below, RoomLayouts.SRC_ERBA_GRASS,
					RoomLayouts.ERBA_FLOOR_SHADOW + Vector2i(posmod(below.x, 2), posmod(below.y, 2)))
				## ragged second row: most columns get a soft tail, some stop short
				if _cell_hash(below, 8) % 3 != 0:
					soft_cells[below + Vector2i(0, 1)] = true
				## diagonal lean at the right end of a wall run
				if not wall_cells.has(w + Vector2i(1, 0)):
					soft_cells[below + Vector2i(1, 0)] = true
		for s: Vector2i in soft_cells:
			if wall_cells.has(s):
				continue
			if tilemap.get_cell_source_id(0, s) != RoomLayouts.SRC_ERBA_GRASS:
				continue
			if _is_erba_shadow(tilemap.get_cell_atlas_coords(0, s)):
				continue  # never soften a strong shadow cell
			tilemap.set_cell(0, s, RoomLayouts.SRC_ERBA_GRASS,
				RoomLayouts.ERBA_FLOOR_SHADOW_SOFT + Vector2i(posmod(s.x, 2), posmod(s.y, 2)))

	## Step 7: Place obstacle tiles.
	## ERBA: the 2x2 rock pile pattern from erba_props.png goes on LAYER 1 — the props have
	## transparent edges, so the grass floor placed in step 5 stays visible underneath.
	var obstacle_tile: Vector2i = layout["obstacle_tile"]
	for obs_rect in layout["obstacles"]:
		var rect: Rect2i = obs_rect
		for x_off in range(rect.size.x):
			for y_off in range(rect.size.y):
				var coords := Vector2i(rect.position.x + x_off, rect.position.y + y_off)
				if is_erba:
					## 2x2 piles are anchored to the RECT origin and only used where the
					## full block fits — leftover edge cells (odd width/height) get a
					## complete single rock instead of a cut-off pile half.
					var block_fits: bool = (x_off - posmod(x_off, 2) + 1 < rect.size.x) \
						and (y_off - posmod(y_off, 2) + 1 < rect.size.y)
					var piece: Vector2i
					if block_fits:
						piece = RoomLayouts.ERBA_ROCK_ORIGIN + Vector2i(posmod(x_off, 2), posmod(y_off, 2))
					else:
						piece = RoomLayouts.ERBA_ROCKS_SINGLE[_cell_hash(coords, 6) % RoomLayouts.ERBA_ROCKS_SINGLE.size()]
					tilemap.set_cell(1, coords, RoomLayouts.SRC_ERBA_PROPS, piece)
				elif is_alt:
					## Roof tile has transparent rounded corners → layer 1 over the floor
					tilemap.set_cell(1, coords, RoomLayouts.SRC_ALT_ROOF, Vector2i(0, 0))
				else:
					tilemap.set_cell(0, coords, source_id, obstacle_tile)

	## Step 7b (ERBA): sparse deco on plain grass (layer 1, no collision) — pebbles,
	## flower patches, bushes, stumps, plus a rare 2-cell park bench.
	## Skips shadowed cells and cells already carrying an obstacle.
	if is_erba and sub_room_id != 6:
		for floor_rect in layout["floor"]:
			var rect: Rect2i = floor_rect
			for x_off in range(rect.size.x):
				for y_off in range(rect.size.y):
					var coords := Vector2i(rect.position.x + x_off, rect.position.y + y_off)
					if tilemap.get_cell_source_id(1, coords) != -1:
						continue  # obstacle or bench half already there
					if tilemap.get_cell_source_id(0, coords) != RoomLayouts.SRC_ERBA_GRASS:
						continue  # wall or road cell
					if _is_erba_shadow(tilemap.get_cell_atlas_coords(0, coords)):
						continue  # keep contact shadows clean
					## Rare bench: needs the right-hand neighbor free and on plain grass too
					if _cell_hash(coords, 7) % 331 == 0:
						var right := coords + Vector2i(1, 0)
						if tilemap.get_cell_source_id(1, right) == -1 \
							and tilemap.get_cell_source_id(0, right) == RoomLayouts.SRC_ERBA_GRASS \
							and not _is_erba_shadow(tilemap.get_cell_atlas_coords(0, right)):
							tilemap.set_cell(1, coords, RoomLayouts.SRC_ERBA_PROPS, RoomLayouts.ERBA_BENCH_LEFT)
							tilemap.set_cell(1, right, RoomLayouts.SRC_ERBA_PROPS, RoomLayouts.ERBA_BENCH_RIGHT)
							continue
					if _cell_hash(coords, 4) % 29 != 0:
						continue
					var pick: int = _cell_hash(coords, 5) % RoomLayouts.ERBA_PEBBLES.size()
					tilemap.set_cell(1, coords, RoomLayouts.SRC_ERBA_PROPS, RoomLayouts.ERBA_PEBBLES[pick])

	## Step 8: Update player spawn points
	## Remove all existing Marker2D children (queue_free — safe in non-physics context)
	## then add new children from layout data
	var spawn_node: Node = game_node.get_node("Room%d/SpawnPoints" % room_id)
	for c in spawn_node.get_children():
		c.queue_free()
	var spawn_idx: int = 1
	for sp_pos in layout["spawn_points"]:
		var marker := Marker2D.new()
		marker.name = "Spawn%d" % spawn_idx
		marker.position = sp_pos  ## already in pixels from RoomLayouts
		spawn_node.add_child(marker)
		spawn_idx += 1

	## Step 9: Update enemy spawn points
	var enemy_spawn_node: Node = game_node.get_node("Room%d/EnemySpawnPoints" % room_id)
	for c in enemy_spawn_node.get_children():
		c.queue_free()
	var esp_idx: int = 1
	for esp_pos in layout["enemy_spawns"]:
		var marker := Marker2D.new()
		marker.name = "ESpawn%d" % esp_idx
		marker.position = esp_pos  ## already in pixels from RoomLayouts
		enemy_spawn_node.add_child(marker)
		esp_idx += 1

	## Step 10: Store exit tile coords on game_node for _open_exit_passage() RPC
	game_node._exit_tile_coords = Array(layout["exit_tile_coords"], TYPE_VECTOR2I, "", null)

	## Step 11: Calculate and return pixel bounds for camera limit update
	return Rect2(0, 0,
		layout["width_tiles"] * RoomLayouts.TILE_SIZE,
		layout["height_tiles"] * RoomLayouts.TILE_SIZE)


## Deterministic per-cell hash for tile variation. A plain linear form like
## (x*31 + y*17) % 16 degenerates to (y - x) % 16 → diagonal stripes; the xor-shift
## scramble kills any directional pattern. Same result on every peer (pure function).
## Whether a floor atlas coord belongs to one of the two shadow macro blocks
## (they occupy the right end of erba_floor.png, starting at ERBA_FLOOR_SHADOW.x).
static func _is_erba_shadow(ac: Vector2i) -> bool:
	return ac.x >= RoomLayouts.ERBA_FLOOR_SHADOW.x

static func _cell_hash(c: Vector2i, salt: int) -> int:
	var h: int = c.x * 374761393 + c.y * 668265263 + salt * 144269504
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return absi(h)

## Create the tile if missing and attach a full-cell collision polygon (physics layer 0).
## half = half the tile size in the source's own pixel space (16 for the 32px ERBA tiles).
## dark < 1.0 additionally darkens the tile via per-tile modulate (used for wall caps).
func _ensure_solid_tile(src: TileSetAtlasSource, ac: Vector2i, half: float, dark: float = 1.0) -> void:
	if not src.has_tile(ac):
		src.create_tile(ac)
	var td := src.get_tile_data(ac, 0)
	if td == null:
		return
	if dark < 1.0:
		td.modulate = Color(dark, dark, dark)
	if td.get_collision_polygons_count(0) == 0:
		td.add_collision_polygon(0)
		td.set_collision_polygon_points(0, 0, PackedVector2Array([
			Vector2(-half, -half), Vector2(half, -half),
			Vector2(half, half), Vector2(-half, half),
		]))

## Room 1 (ERBA): register every used tile across the four erba atlas sources.
## Grass variants + shadow (no collision), wall faces/caps (collision, caps darkened),
## rock pile + deco scatter + bench (rocks collide, deco doesn't), road (no collision).
func _register_erba_tiles(tilemap: TileMap) -> void:
	var half: float = tilemap.tile_set.tile_size.x / 2.0  # 64px erba tileset → 32
	## All floor/wall/road entries are macro-block bases — register all 4 quadrants each.
	var QUADS: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]
	var grass := tilemap.tile_set.get_source(RoomLayouts.SRC_ERBA_GRASS) as TileSetAtlasSource
	if grass:
		for base: Vector2i in RoomLayouts.ERBA_GRASS_PLAIN + RoomLayouts.ERBA_GRASS_DETAIL + RoomLayouts.ERBA_GRASS_SLABS:
			for q: Vector2i in QUADS:
				if not grass.has_tile(base + q):
					grass.create_tile(base + q)
		## Contact shadow blocks: strong directly under the wall, soft for the ragged tail
		for pair: Array in [[RoomLayouts.ERBA_FLOOR_SHADOW, 0.66], [RoomLayouts.ERBA_FLOOR_SHADOW_SOFT, 0.84]]:
			for q: Vector2i in QUADS:
				var ac: Vector2i = pair[0] + q
				if not grass.has_tile(ac):
					grass.create_tile(ac)
				var std := grass.get_tile_data(ac, 0)
				if std:
					std.modulate = Color(pair[1], pair[1], pair[1])
	var wall := tilemap.tile_set.get_source(RoomLayouts.SRC_ERBA_WALL) as TileSetAtlasSource
	if wall:
		for base: Vector2i in RoomLayouts.ERBA_WALL_FACES + RoomLayouts.ERBA_WALL_CAPS:
			for q: Vector2i in QUADS:
				_ensure_solid_tile(wall, base + q, half)
	var props := tilemap.tile_set.get_source(RoomLayouts.SRC_ERBA_PROPS) as TileSetAtlasSource
	if props:
		for off in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
			_ensure_solid_tile(props, RoomLayouts.ERBA_ROCK_ORIGIN + off, half)
		for ac: Vector2i in RoomLayouts.ERBA_ROCKS_SINGLE:
			_ensure_solid_tile(props, ac, half)
		for ac: Vector2i in RoomLayouts.ERBA_PEBBLES:
			if not props.has_tile(ac):
				props.create_tile(ac)
		for ac: Vector2i in [RoomLayouts.ERBA_BENCH_LEFT, RoomLayouts.ERBA_BENCH_RIGHT]:
			if not props.has_tile(ac):
				props.create_tile(ac)
	var stone := tilemap.tile_set.get_source(RoomLayouts.SRC_ERBA_STONE) as TileSetAtlasSource
	if stone:
		for q: Vector2i in QUADS:
			if not stone.has_tile(RoomLayouts.ERBA_CONNECTOR_ROAD + q):
				stone.create_tile(RoomLayouts.ERBA_CONNECTOR_ROAD + q)

## Room 2 (Altstadt): register the janv2 single-tile sources. Every source holds exactly
## one tile at (0,0). Wall, wall-cap, and roof are solid; the cap source shares the wall
## texture and is darkened via modulate for the 2.5D top look.
func _register_altstadt_tiles(tilemap: TileMap) -> void:
	var half: float = tilemap.tile_set.tile_size.x / 2.0  # 32px tileset → 16
	for sid: int in [RoomLayouts.SRC_ALT_ASPHALT, RoomLayouts.SRC_ALT_GRASS, RoomLayouts.SRC_ALT_ROAD]:
		var src := tilemap.tile_set.get_source(sid) as TileSetAtlasSource
		if src and not src.has_tile(Vector2i.ZERO):
			src.create_tile(Vector2i.ZERO)
	var wall := tilemap.tile_set.get_source(RoomLayouts.SRC_ALT_WALL) as TileSetAtlasSource
	if wall:
		_ensure_solid_tile(wall, Vector2i.ZERO, half)
	var cap := tilemap.tile_set.get_source(RoomLayouts.SRC_ALT_WALL_CAP) as TileSetAtlasSource
	if cap:
		_ensure_solid_tile(cap, Vector2i.ZERO, half, 0.55)
	var roof := tilemap.tile_set.get_source(RoomLayouts.SRC_ALT_ROOF) as TileSetAtlasSource
	if roof:
		_ensure_solid_tile(roof, Vector2i.ZERO, half)

## Phase 9 (D-11, D-13): Build the connector corridor sub-room.
## Connector is sub_room_id == 6 in the layout data (rooms 1 and 2 only).
## No enemies in connector — pure walking corridor.
##
## @param room_id   Room index (1 or 2)
## @param game_node The Game scene root Node2D
## @returns         Pixel bounds of the connector corridor as Rect2
func build_connector(room_id: int, game_node: Node) -> Rect2:
	return build_sub_room(room_id, 6, game_node)


## Phase 9 (Pitfall 4): Toggle TileMap collision for hidden rooms.
## When disabling: CLEAR the TileMap entirely — this removes all physics bodies so the
## departed room's wall tiles cannot block movement in the newly active room (both rooms
## share world origin (0,0), so un-cleared physics bodies are invisible walls).
## When enabling: no action needed; build_sub_room() immediately follows and populates fresh.
##
## @param room_id   Room index (1, 2, or 3)
## @param enabled   true = enable collision, false = disable
## @param game_node The Game scene root Node2D
func set_tilemap_collision(room_id: int, enabled: bool, game_node: Node) -> void:
	var tilemap: Node = game_node.get_node_or_null("Room%d/TileMap" % room_id)
	if tilemap == null:
		return
	if not enabled:
		# Clear removes all cells and their generated physics bodies.
		# build_sub_room() will repopulate when this room becomes active again.
		(tilemap as TileMap).clear()
		return
	# Enabling: belt-and-suspenders — also restore TileMapLayer collision in case
	# Godot 4.3+ wraps layers as children with a separate collision_enabled flag.
	for child in tilemap.get_children():
		if child is TileMapLayer:
			child.collision_enabled = true
