## RoomBuilder.gd
## Phase 9 (D-04, MAP-08): TileMap population engine.
## Reads SUB_ROOM_DATA + ROOM_ART from RoomLayouts.gd and populates the active
## room's TileMap by calling set_cell() for floor, wall, obstacle and deco cells.
## Also repopulates Marker2D spawn point nodes from layout data.
##
## All three rooms use the same build path: every biome is a set of single-tile
## 256px TileSetAtlasSources (assets/lovableassats), so variation switches the
## SOURCE id while the atlas coord is always (0,0). Per-room art choices (floor
## variants, wall faces/caps, obstacles, deco scatter) come from ROOM_ART.
##
## Design decisions:
##   - extends RefCounted: no node lifecycle, no _ready(), pure functional
##   - Separation of concerns: does NOT call _bake_navigation — Game.gd owns that step
##   - Called from _transition_to_sub_room() (RPC call_local context on all peers)
##   - Returns Rect2 pixel bounds so Game.gd can update camera limits
class_name RoomBuilder
extends RefCounted

const ATLAS_ORIGIN := Vector2i(0, 0)  ## single-tile sources: always coord (0,0)

## Cast-shadow geometry for wall faces (in tiles). The shadow falls down-right — the same
## top-left light the comic UI's hard (3,3) offset shadows imply — and leans sideways so
## it reads as cast by a standing wall, not as a dark stripe painted under it.
const WALL_SHADOW_DROP: float = 0.55
const WALL_SHADOW_SKEW: float = 0.35
const WALL_SHADOW_ALPHA: float = 0.30
## Small down-right nudge on the prop blob shadows so they agree with the same light.
const PROP_SHADOW_LEAN: float = 0.08

## Build a sub-room by populating the TileMap with floor/wall/obstacle/deco cells
## from RoomLayouts data, then repopulate spawn point Marker2D children.
##
## @param room_id      Room index (1, 2, or 3)
## @param sub_room_id  Sub-room index (1–5 playable, 6 = connector for rooms 1+2)
## @param game_node    The Game scene root Node2D (used to resolve room node paths)
## @returns            Pixel bounds of the sub-room as Rect2 (for camera limit update)
func build_sub_room(room_id: int, sub_room_id: int, game_node: Node) -> Rect2:
	var layout: Dictionary = RoomLayouts.SUB_ROOM_DATA[room_id][sub_room_id]
	var art: Dictionary = RoomLayouts.ROOM_ART[room_id]

	var tilemap: TileMap = game_node.get_node("Room%d/TileMap" % room_id)

	## Clear all cells from all layers — removes stale tiles from previous sub-rooms
	tilemap.clear()

	## Blob-shadow container for map props (obstacles/houses), recreated per build. As a
	## sibling ADDED AFTER the TileMap it draws above the tile art, so the shadows are
	## placed at each prop's south edge where they land on the floor, not on the prop.
	var prop_shadows: Node2D = _reset_prop_shadows(room_id, game_node)

	## Register every tile this room can use (Godot 4 requires tiles to exist on
	## the TileSetAtlasSource before set_cell() renders them).
	_register_room_tiles(tilemap, art)

	## Obstacles + deco render on layer 1 ABOVE the floor — they have transparent
	## edges, so the floor must stay visible underneath.
	if tilemap.get_layers_count() < 2:
		tilemap.add_layer(-1)

	var is_connector: bool = sub_room_id == 6
	var floor_src: int = art["floor_src"]
	var floor_mix: Array = art["floor_mix"]
	## Connector carpet runner: middle interior row of the corridor
	var mid_row: int = int(layout["height_tiles"] / 2.0)

	## Step 1: Floor cells — base floor with hash-mixed variants; connectors use
	## the connector source (full corridor, or middle-row runner for room 2).
	for floor_rect in layout["floor"]:
		var rect: Rect2i = floor_rect
		for x_off in range(rect.size.x):
			for y_off in range(rect.size.y):
				var coords := Vector2i(rect.position.x + x_off, rect.position.y + y_off)
				var src: int = floor_src
				if is_connector:
					if art["connector_full"] or coords.y == mid_row:
						src = art["connector_src"]
				else:
					for mix_idx in range(floor_mix.size()):
						var mix: Array = floor_mix[mix_idx]
						if _cell_hash(coords, 1 + mix_idx) % int(mix[1]) == 0:
							src = mix[0]
							break
				tilemap.set_cell(0, coords, src, ATLAS_ORIGIN)

	## Step 1b: Carpet runner — optional layer-0 floor override rects (e.g. the
	## ceremonial carpet across the boss arena). Placed after the floor mix so it
	## always wins; excluded from deco via the floor_srcs check below.
	var carpet_src: int = art["carpet_src"]
	if carpet_src != -1:
		for carpet_rect in layout.get("carpet", []):
			var rect: Rect2i = carpet_rect
			for x_off in range(rect.size.x):
				for y_off in range(rect.size.y):
					var coords := Vector2i(rect.position.x + x_off, rect.position.y + y_off)
					tilemap.set_cell(0, coords, carpet_src, ATLAS_ORIGIN)

	## Step 2: Wall cells — 2.5D look (Enter-the-Gungeon style) in ALL rooms:
	## wall cells with floor directly below show the wall FACE (front view),
	## all other wall cells show the CAP (top view). Floor was placed in step 1,
	## walls are not yet on the map — wall_cells tracks them so face detection
	## cannot mistake a wall for floor.
	var wall_cells := {}
	for wall_rect in layout["walls"]:
		var r: Rect2i = wall_rect
		for x_off in range(r.size.x):
			for y_off in range(r.size.y):
				wall_cells[Vector2i(r.position.x + x_off, r.position.y + y_off)] = true
	var faces: Array = art["wall_faces"]
	var caps: Array = art["wall_caps"]
	var face_cells: Array[Vector2i] = []
	for coords: Vector2i in wall_cells:
		var below := coords + Vector2i(0, 1)
		var below_is_floor: bool = not wall_cells.has(below) \
			and tilemap.get_cell_source_id(0, below) != -1
		var pick: int = _cell_hash(coords, 3)
		var src: int
		if below_is_floor:
			src = faces[pick % faces.size()]
			face_cells.append(coords)
		else:
			src = caps[pick % caps.size()]
		tilemap.set_cell(0, coords, src, ATLAS_ORIGIN)

	## Step 2a: Wall deco — torches/banners overlaid on some south-facing wall
	## faces (layer 1, purely visual; the wall's collision already blocks).
	var wall_deco: Array = art["wall_deco"]
	if not wall_deco.is_empty():
		for coords: Vector2i in face_cells:
			for wd_idx in range(wall_deco.size()):
				var wd: Array = wall_deco[wd_idx]
				if _cell_hash(coords, 20 + wd_idx) % int(wd[1]) == 0:
					tilemap.set_cell(1, coords, wd[0], ATLAS_ORIGIN)
					break

	## Step 2b: Cast shadow — slanted semi-transparent parallelograms falling down-right
	## from every south-facing wall face (replaces the old darkened-floor-tile row, which
	## read as paint on the ground rather than as a shadow the wall throws). One polygon
	## per horizontal RUN of face cells, never per cell — adjacent per-cell quads would
	## overlap at the skewed edges and double-darken the seams. Drawn into PropShadows
	## BEFORE the prop blobs, so it renders beneath them.
	var floor_srcs: Array = [floor_src]
	for mix in floor_mix:
		floor_srcs.append(mix[0])
	_add_wall_shadows(prop_shadows, tilemap, face_cells)

	## Step 3: Obstacles — solid tile per cell on layer 1 (transparent edges keep
	## the floor visible underneath). Source is hash-picked from the room's pool
	## (e.g. Altstadt: barrel/crate depot mix).
	var obstacle_srcs: Array = art["obstacle_srcs"]
	for obs_rect in layout["obstacles"]:
		var rect: Rect2i = obs_rect
		for x_off in range(rect.size.x):
			for y_off in range(rect.size.y):
				var coords := Vector2i(rect.position.x + x_off, rect.position.y + y_off)
				var src: int = obstacle_srcs[_cell_hash(coords, 7) % obstacle_srcs.size()]
				tilemap.set_cell(1, coords, src, ATLAS_ORIGIN)
				## Ground the prop with the characters' blob shadow — only on the rect's
				## south row, so stacked obstacle rows don't stripe shadows across each other.
				if y_off == rect.size.y - 1:
					_add_prop_shadow(prop_shadows, tilemap, coords, 0.95)

	## Step 3a: Houses — hand-placed solid landmark cells (Altstadt). The house
	## texture is drawn oversized (64px on the 32px grid) so it reads as a real
	## building; collision stays one cell so paths around it remain generous.
	var house_src: int = art["house_src"]
	if house_src != -1:
		for house_cell: Vector2i in layout.get("houses", []):
			tilemap.set_cell(1, house_cell, house_src, ATLAS_ORIGIN)
			## Houses draw oversized (64px art on the 32px grid) → wider shadow to match.
			_add_prop_shadow(prop_shadows, tilemap, house_cell, 1.7)

	## Step 3b: Deco scatter (flowers/pebbles/lanterns/…) on plain floor cells —
	## layer 1, no collision. Skips connector corridors, shadowed cells and cells
	## already carrying an obstacle.
	if not is_connector and not art["deco"].is_empty():
		for floor_rect in layout["floor"]:
			var rect: Rect2i = floor_rect
			for x_off in range(rect.size.x):
				for y_off in range(rect.size.y):
					var coords := Vector2i(rect.position.x + x_off, rect.position.y + y_off)
					if tilemap.get_cell_source_id(1, coords) != -1:
						continue  # obstacle already there
					if tilemap.get_cell_source_id(0, coords) not in floor_srcs:
						continue  # wall or carpet cell
					for deco_idx in range(art["deco"].size()):
						var deco: Array = art["deco"][deco_idx]
						if _cell_hash(coords, 10 + deco_idx) % int(deco[1]) == 0:
							tilemap.set_cell(1, coords, deco[0], ATLAS_ORIGIN)
							break

	## Step 4: Update player spawn points
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

	## Step 5: Update enemy spawn points
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

	## Step 6: Store exit tile coords on game_node for _open_exit_passage() RPC
	game_node._exit_tile_coords = Array(layout["exit_tile_coords"], TYPE_VECTOR2I, "", null)

	## Step 7: Calculate and return pixel bounds for camera limit update
	return Rect2(0, 0,
		layout["width_tiles"] * RoomLayouts.TILE_SIZE,
		layout["height_tiles"] * RoomLayouts.TILE_SIZE)


## Clear (or lazily create) the room's prop-shadow container. Sibling of the TileMap,
## appended after it so the soft blobs draw above the tile art but below the Entities
## and FxLayer nodes that come later at the Game root. Content is rebuilt per sub-room,
## mirroring tilemap.clear() at the top of build_sub_room.
func _reset_prop_shadows(room_id: int, game_node: Node) -> Node2D:
	var room: Node = game_node.get_node("Room%d" % room_id)
	var layer: Node2D = room.get_node_or_null("PropShadows")
	if layer == null:
		layer = Node2D.new()
		layer.name = "PropShadows"
		room.add_child(layer)
	for c in layer.get_children():
		c.queue_free()
	return layer

## One blob shadow at a prop cell's south edge — mostly on the floor below the prop, so
## the sprite (which draws above the tile art) doesn't sit on the prop's own pixels.
## `width_tiles` is the shadow width as a fraction of the 32px grid cell. Nudged slightly
## right so props agree with the walls' top-left light direction.
func _add_prop_shadow(container: Node2D, tilemap: TileMap, coords: Vector2i, width_tiles: float) -> void:
	var t: float = float(RoomLayouts.TILE_SIZE)
	var world: Vector2 = tilemap.to_global(tilemap.map_to_local(coords))
	var pos: Vector2 = container.to_local(world + Vector2(t * PROP_SHADOW_LEAN, t * 0.42))
	Juice.add_prop_shadow(container, pos, t * width_tiles)

## Slanted cast shadows for the south-facing wall faces. Face cells are grouped into
## horizontal runs (same row, consecutive x) and each run becomes ONE Polygon2D
## parallelogram: top edge flush with the wall base, bottom edge dropped and skewed
## down-right. Merging per run keeps the skewed side edges from double-darkening where
## per-cell quads would overlap.
func _add_wall_shadows(container: Node2D, tilemap: TileMap, face_cells: Array[Vector2i]) -> void:
	if face_cells.is_empty():
		return
	var cells: Array[Vector2i] = face_cells.duplicate()
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y if a.y != b.y else a.x < b.x)
	var run_start: Vector2i = cells[0]
	var run_end: Vector2i = cells[0]
	for i in range(1, cells.size()):
		var c: Vector2i = cells[i]
		if c.y == run_end.y and c.x == run_end.x + 1:
			run_end = c
			continue
		_add_wall_shadow_poly(container, tilemap, run_start, run_end)
		run_start = c
		run_end = c
	_add_wall_shadow_poly(container, tilemap, run_start, run_end)

func _add_wall_shadow_poly(container: Node2D, tilemap: TileMap, start: Vector2i, end: Vector2i) -> void:
	var t: float = float(RoomLayouts.TILE_SIZE)
	## Wall base line in world px: bottom edge of the face cells (map_to_local = cell center)
	var left: Vector2 = tilemap.to_global(tilemap.map_to_local(start)) + Vector2(-t * 0.5, t * 0.5)
	var right: Vector2 = tilemap.to_global(tilemap.map_to_local(end)) + Vector2(t * 0.5, t * 0.5)
	var slant := Vector2(t * WALL_SHADOW_SKEW, t * WALL_SHADOW_DROP)
	var poly := Polygon2D.new()
	poly.color = Color(0.0, 0.0, 0.0, WALL_SHADOW_ALPHA)
	poly.polygon = PackedVector2Array([
		container.to_local(left),
		container.to_local(right),
		container.to_local(right + slant),
		container.to_local(left + slant),
	])
	container.add_child(poly)

## Deterministic per-cell hash for tile variation. A plain linear form like
## (x*31 + y*17) % 16 degenerates to (y - x) % 16 → diagonal stripes; the xor-shift
## scramble kills any directional pattern. Same result on every peer (pure function).
static func _cell_hash(c: Vector2i, salt: int) -> int:
	var h: int = c.x * 374761393 + c.y * 668265263 + salt * 144269504
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return absi(h)

## Register all sources a room uses on its TileSet. Floors/deco get plain tiles,
## the shadow source gets a dark modulate, walls/obstacles get full-cell collision.
func _register_room_tiles(tilemap: TileMap, art: Dictionary) -> void:
	## half = half tile size in the SOURCE's own pixel space (256px tiles → 128),
	## independent of the on-screen grid size — the node scale handles that.
	var half: float = tilemap.tile_set.tile_size.x / 2.0
	var plain: Array = [art["floor_src"]]
	for mix in art["floor_mix"]:
		plain.append(mix[0])
	if int(art["connector_src"]) != -1:
		plain.append(art["connector_src"])
	if int(art["carpet_src"]) != -1:
		plain.append(art["carpet_src"])
	for deco in art["deco"]:
		plain.append(deco[0])
	for wd in art["wall_deco"]:
		plain.append(wd[0])
	for sid: int in plain:
		var src := tilemap.tile_set.get_source(sid) as TileSetAtlasSource
		if src and not src.has_tile(ATLAS_ORIGIN):
			src.create_tile(ATLAS_ORIGIN)
	## (The old darkened-floor contact-shadow tile (art["shadow_src"]) is no longer placed —
	## wall shadows are slanted Polygon2Ds in the PropShadows container since 2026-07-16.)
	## Solid tiles: wall faces, wall caps, obstacles, houses — full-cell collision
	## polygon on physics layer 0 so players and bullets collide with them.
	var solid: Array = []
	solid.append_array(art["wall_faces"])
	solid.append_array(art["wall_caps"])
	solid.append_array(art["obstacle_srcs"])
	if int(art["house_src"]) != -1:
		solid.append(art["house_src"])
	for sid: int in solid:
		var src := tilemap.tile_set.get_source(sid) as TileSetAtlasSource
		if src:
			_ensure_solid_tile(src, ATLAS_ORIGIN, half)

## Create the tile if missing and attach a full-cell collision polygon (physics layer 0).
## half = half the tile size in the source's own pixel space (128 for 256px tiles).
func _ensure_solid_tile(src: TileSetAtlasSource, ac: Vector2i, half: float) -> void:
	if not src.has_tile(ac):
		src.create_tile(ac)
	var td := src.get_tile_data(ac, 0)
	if td == null:
		return
	if td.get_collision_polygons_count(0) == 0:
		td.add_collision_polygon(0)
		td.set_collision_polygon_points(0, 0, PackedVector2Array([
			Vector2(-half, -half), Vector2(half, -half),
			Vector2(half, half), Vector2(-half, half),
		]))

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
		# Prop shadows mirror the tile content — all rooms share world origin (0,0), so
		# a departed room's shadows would otherwise draw into the newly active room.
		_reset_prop_shadows(room_id, game_node)
		return
	# Enabling: belt-and-suspenders — also restore TileMapLayer collision in case
	# Godot 4.3+ wraps layers as children with a separate collision_enabled flag.
	for child in tilemap.get_children():
		if child is TileMapLayer:
			child.collision_enabled = true
