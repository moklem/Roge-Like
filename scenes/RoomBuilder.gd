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
	## Room 1 (ERBA) uses its own multi-source registration across the Cainos sheets.
	var is_erba: bool = room_id == 1
	if is_erba:
		_register_erba_tiles(tilemap)
		## Props (rock obstacles, pebble deco) render on layer 1 ABOVE the grass floor —
		## they have transparency, so the floor must stay visible underneath.
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
	## Room 1 (ERBA): hash-weighted grass variants from the Cainos sheet (see below)
	## Room 2 (Altstadt): every 10th tile (mix_idx % 10 == 0) → grass
	## Room 3 (Burg Altenburg): no mixing — pure stone
	var floor_tile: Vector2i = layout["floor_tile"]
	for floor_rect in layout["floor"]:
		var rect: Rect2i = floor_rect
		for x_off in range(rect.size.x):
			for y_off in range(rect.size.y):
				var coords := Vector2i(rect.position.x + x_off, rect.position.y + y_off)
				var mix_idx: int = (x_off + y_off)
				var tile: Vector2i = floor_tile
				if is_erba and sub_room_id != 6:
					## Connector (SR 6) stays pure stone road; playable sub-rooms pick a
					## weighted grass variant per cell via _cell_hash: ~1/16 slab tiles,
					## ~3/16 flowers/tufts, rest plain — each category rotates through
					## several sheet variants.
					var cat: int = _cell_hash(coords, 1) % 16
					var pick: int = _cell_hash(coords, 2)
					if cat == 0:
						tile = RoomLayouts.ERBA_GRASS_SLABS[pick % RoomLayouts.ERBA_GRASS_SLABS.size()]
					elif cat <= 3:
						tile = RoomLayouts.ERBA_GRASS_DETAIL[pick % RoomLayouts.ERBA_GRASS_DETAIL.size()]
					else:
						tile = RoomLayouts.ERBA_GRASS_PLAIN[pick % RoomLayouts.ERBA_GRASS_PLAIN.size()]
				elif room_id == 2:
					if mix_idx % 10 == 0:
						tile = RoomLayouts.MC_FLOOR_GRASS      ## occasional grass patch
				## room_id == 3: no mixing — pure stone
				tilemap.set_cell(0, coords, source_id, tile)

	## Step 6: Place wall tiles
	## ERBA 2.5D (Enter-the-Gungeon look): wall cells with floor directly below them show
	## the brick FACE (you look at the wall's front), all other wall cells show the dark
	## CAP (you look at the wall's top). Floor was placed in step 5, walls are not yet on
	## the map — wall_cells tracks them so face detection cannot mistake a wall for floor.
	var wall_tile: Vector2i = layout["wall_tile"]
	var wall_cells := {}
	if is_erba:
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
					var below := coords + Vector2i(0, 1)
					var below_is_floor: bool = not wall_cells.has(below) \
						and tilemap.get_cell_source_id(0, below) != -1
					var pick: int = _cell_hash(coords, 3)
					var tile: Vector2i
					if below_is_floor:
						tile = RoomLayouts.ERBA_WALL_FACES[pick % RoomLayouts.ERBA_WALL_FACES.size()]
					else:
						tile = RoomLayouts.ERBA_WALL_CAPS[pick % RoomLayouts.ERBA_WALL_CAPS.size()]
					tilemap.set_cell(0, coords, RoomLayouts.SRC_ERBA_WALL, tile)
				else:
					tilemap.set_cell(0, coords, source_id, wall_tile)
	## Step 6b (ERBA 2.5D): darken the grass row directly under each wall face — cheap
	## contact shadow that sells the wall height. Road tiles (connector) stay untouched.
	if is_erba:
		for w: Vector2i in wall_cells:
			var below: Vector2i = w + Vector2i(0, 1)
			if wall_cells.has(below):
				continue
			if tilemap.get_cell_source_id(0, below) == RoomLayouts.SRC_ERBA_GRASS:
				tilemap.set_cell(0, below, RoomLayouts.SRC_ERBA_GRASS, RoomLayouts.ERBA_FLOOR_SHADOW)

	## Step 7: Place obstacle tiles.
	## ERBA: the 2x2 rock pile pattern from TX Props goes on LAYER 1 — the props have
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
				else:
					tilemap.set_cell(0, coords, source_id, obstacle_tile)

	## Step 7b (ERBA): sparse pebble deco on plain grass (layer 1, no collision).
	## Skips shadowed cells and cells already carrying an obstacle.
	if is_erba and sub_room_id != 6:
		for floor_rect in layout["floor"]:
			var rect: Rect2i = floor_rect
			for x_off in range(rect.size.x):
				for y_off in range(rect.size.y):
					var coords := Vector2i(rect.position.x + x_off, rect.position.y + y_off)
					if _cell_hash(coords, 4) % 29 != 0:
						continue
					if tilemap.get_cell_source_id(1, coords) != -1:
						continue  # obstacle already there
					if tilemap.get_cell_source_id(0, coords) != RoomLayouts.SRC_ERBA_GRASS:
						continue  # wall or road cell
					if tilemap.get_cell_atlas_coords(0, coords) == RoomLayouts.ERBA_FLOOR_SHADOW:
						continue  # keep contact shadows clean
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

## Room 1 (ERBA): register every used tile across the four Cainos sheet sources.
## Grass variants + shadow (no collision), wall faces/caps (collision, caps darkened),
## rock pile + pebbles (rocks collide, pebbles are deco), connector road (no collision).
func _register_erba_tiles(tilemap: TileMap) -> void:
	var half: float = tilemap.tile_set.tile_size.x / 2.0  # 32px tileset → 16
	var grass := tilemap.tile_set.get_source(RoomLayouts.SRC_ERBA_GRASS) as TileSetAtlasSource
	if grass:
		for ac: Vector2i in RoomLayouts.ERBA_GRASS_PLAIN + RoomLayouts.ERBA_GRASS_DETAIL + RoomLayouts.ERBA_GRASS_SLABS:
			if not grass.has_tile(ac):
				grass.create_tile(ac)
		if not grass.has_tile(RoomLayouts.ERBA_FLOOR_SHADOW):
			grass.create_tile(RoomLayouts.ERBA_FLOOR_SHADOW)
		var std := grass.get_tile_data(RoomLayouts.ERBA_FLOOR_SHADOW, 0)
		if std:
			std.modulate = Color(0.66, 0.66, 0.66)  # contact shadow under wall faces
	var wall := tilemap.tile_set.get_source(RoomLayouts.SRC_ERBA_WALL) as TileSetAtlasSource
	if wall:
		for ac: Vector2i in RoomLayouts.ERBA_WALL_FACES:
			_ensure_solid_tile(wall, ac, half)
		for ac: Vector2i in RoomLayouts.ERBA_WALL_CAPS:
			## 0.55: clearly darker than the faces but the brick texture stays readable
			## (0.32 looked like flat black bars along the top wall rows)
			_ensure_solid_tile(wall, ac, half, 0.55)
	var props := tilemap.tile_set.get_source(RoomLayouts.SRC_ERBA_PROPS) as TileSetAtlasSource
	if props:
		for off in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
			_ensure_solid_tile(props, RoomLayouts.ERBA_ROCK_ORIGIN + off, half)
		for ac: Vector2i in RoomLayouts.ERBA_ROCKS_SINGLE:
			_ensure_solid_tile(props, ac, half)
		for ac: Vector2i in RoomLayouts.ERBA_PEBBLES:
			if not props.has_tile(ac):
				props.create_tile(ac)
	var stone := tilemap.tile_set.get_source(RoomLayouts.SRC_ERBA_STONE) as TileSetAtlasSource
	if stone:
		if not stone.has_tile(RoomLayouts.ERBA_CONNECTOR_ROAD):
			stone.create_tile(RoomLayouts.ERBA_CONNECTOR_ROAD)

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
