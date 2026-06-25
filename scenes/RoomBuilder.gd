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
	var _src := tilemap.tile_set.get_source(source_id) as TileSetAtlasSource
	if _src:
		## Floor / decorative tiles — no collision.
		for _ac: Vector2i in [
			layout["floor_tile"],
			RoomLayouts.MC_FLOOR_CRACK, RoomLayouts.MC_FLOOR_GRASS_ALT, RoomLayouts.MC_FLOOR_GRASS,
		]:
			if not _src.has_tile(_ac):
				_src.create_tile(_ac)
		## Solid tiles (walls + obstacles) — full-cell collision polygon on physics layer 0
		## so the player and bullets actually collide with them.
		for _ac: Vector2i in [layout["wall_tile"], layout["obstacle_tile"]]:
			if not _src.has_tile(_ac):
				_src.create_tile(_ac)
			var _td := _src.get_tile_data(_ac, 0)
			if _td.get_collision_polygons_count(0) == 0:
				var _half := RoomLayouts.TILE_SIZE / 2.0
				_td.add_collision_polygon(0)
				_td.set_collision_polygon_points(0, 0, PackedVector2Array([
					Vector2(-_half, -_half), Vector2(_half, -_half),
					Vector2(_half, _half), Vector2(-_half, _half),
				]))

	## Step 5: Place floor tiles with optional mix rules per room
	## Room 1 (ERBA): every 3rd tile (mix_idx % 3 == 0) → crack, % 3 == 1 → grass alt
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
				if room_id == 1:
					if mix_idx % 3 == 0:
						tile = RoomLayouts.MC_FLOOR_CRACK      ## cracked asphalt transition
					elif mix_idx % 3 == 1:
						tile = RoomLayouts.MC_FLOOR_GRASS_ALT  ## lighter grass variant
				elif room_id == 2:
					if mix_idx % 10 == 0:
						tile = RoomLayouts.MC_FLOOR_GRASS      ## occasional grass patch
				## room_id == 3: no mixing — pure stone
				tilemap.set_cell(0, coords, source_id, tile)

	## Step 6: Place wall tiles
	var wall_tile: Vector2i = layout["wall_tile"]
	for wall_rect in layout["walls"]:
		var rect: Rect2i = wall_rect
		for x_off in range(rect.size.x):
			for y_off in range(rect.size.y):
				var coords := Vector2i(rect.position.x + x_off, rect.position.y + y_off)
				tilemap.set_cell(0, coords, source_id, wall_tile)

	## Step 7: Place obstacle tiles
	var obstacle_tile: Vector2i = layout["obstacle_tile"]
	for obs_rect in layout["obstacles"]:
		var rect: Rect2i = obs_rect
		for x_off in range(rect.size.x):
			for y_off in range(rect.size.y):
				var coords := Vector2i(rect.position.x + x_off, rect.position.y + y_off)
				tilemap.set_cell(0, coords, source_id, obstacle_tile)

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


## Phase 9 (D-11, D-13): Build the connector corridor sub-room.
## Connector is sub_room_id == 6 in the layout data (rooms 1 and 2 only).
## No enemies in connector — pure walking corridor.
##
## @param room_id   Room index (1 or 2)
## @param game_node The Game scene root Node2D
## @returns         Pixel bounds of the connector corridor as Rect2
func build_connector(room_id: int, game_node: Node) -> Rect2:
	return build_sub_room(room_id, 6, game_node)


## Phase 9 (Pitfall 4): Toggle TileMap collision layer for hidden rooms.
## Hidden rooms (Room 2, Room 3) start with collision_layer=0.
## When a room becomes active, enable its TileMap collision.
## When a room becomes hidden, disable its TileMap collision.
##
## @param room_id   Room index (1, 2, or 3)
## @param enabled   true = enable collision, false = disable
## @param game_node The Game scene root Node2D
func set_tilemap_collision(room_id: int, enabled: bool, game_node: Node) -> void:
	var tilemap: Node = game_node.get_node_or_null("Room%d/TileMap" % room_id)
	if tilemap == null:
		return
	# In Godot 4.3+, TileMap is deprecated and wraps TileMapLayer children internally.
	# collision_enabled lives on TileMapLayer, not on the TileMap wrapper.
	for child in tilemap.get_children():
		if child is TileMapLayer:
			child.collision_enabled = enabled
