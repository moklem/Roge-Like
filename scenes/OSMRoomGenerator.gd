extends Node
## OSM-driven room decoration: fetches named buildings and places them as
## landmark obstacles inside the active room.  Room structure (boundary walls,
## corridor blocks, Keep, towers) is defined in Game.tscn — this script only
## adds OSM-sourced buildings on top, with a clearly distinct colour.
## Falls back silently when offline.

signal room_osm_ready(room_id: int)

## Bounding boxes (south_lat, west_lon, north_lat, east_lon) — Bamberg, Germany.
const BBOXES: Dictionary = {
	1: [49.9020, 10.8860, 49.9070, 10.9000],  ## ERBA (Erba-Insel, ehem. Baumwollspinnerei)
	2: [49.8930, 10.8870, 49.9020, 10.9050],  ## Bamberg Altstadt (UNESCO-Kernzone)
	3: [49.8760, 10.8590, 49.8820, 10.8690],  ## Burg Altenburg
}

## Max named landmark buildings to place per room.
const MAX_ANCHORS: int = 5
## Size of each OSM building obstacle in game pixels.
const ANCHOR_SIZE: float  = 48.0
## Minimum distance between an OSM anchor centre and any existing StaticBody2D centre.
const MIN_CLEAR: float    = 72.0

const GAME_W      := 800.0
const GAME_H      := 600.0
const MARGIN      := 60.0   ## keep anchors away from boundary walls
## Distinct purplish tint — clearly different from room walls (grey 0.3) and blocks.
const BLD_COLOR   := Color(0.30, 0.27, 0.33, 1.0)
const OSM_TIMEOUT := 12.0

var _http: HTTPRequest
var _pending_room: int = 0
var _game: Node = null

func _ready() -> void:
	_game = get_parent()
	_http = HTTPRequest.new()
	_http.timeout = OSM_TIMEOUT
	add_child(_http)
	_http.request_completed.connect(_on_http_done)

func fetch_for_room(room_id: int) -> void:
	if not BBOXES.has(room_id):
		return
	_pending_room = room_id
	var b: Array = BBOXES[room_id]
	var bbox: String = "%.6f,%.6f,%.6f,%.6f" % [b[0], b[1], b[2], b[3]]
	## Room 3: also grab named historic features (castle keep, towers).
	var q: String
	if room_id == 3:
		q = (
			"[out:json][timeout:15];"
			+ "(way[\"name\"][\"building\"](%s);" % bbox
			+ "way[\"name\"][\"historic\"](%s);" % bbox
			+ ");out geom;"
		)
	else:
		q = "[out:json][timeout:15];way[\"name\"][\"building\"](%s);out geom;" % bbox
	var err: int = _http.request(
		"https://overpass-api.de/api/interpreter",
		PackedStringArray(["Content-Type: application/x-www-form-urlencoded"]),
		HTTPClient.METHOD_POST,
		"data=" + q
	)
	if err != OK:
		push_warning("OSMRoomGenerator: HTTP request error %d" % err)
		emit_signal("room_osm_ready", _pending_room)

func _on_http_done(_res: int, code: int, _hdrs: PackedStringArray, body: PackedByteArray) -> void:
	var anchors: Array = []
	if code == 200:
		var parsed = JSON.parse_string(body.get_string_from_utf8())
		if parsed is Dictionary:
			anchors = _extract_anchors(_pending_room, parsed)
	else:
		push_warning("OSMRoomGenerator: HTTP %d for room %d" % [code, _pending_room])
	if not anchors.is_empty():
		_apply_anchors(_pending_room, anchors)
	emit_signal("room_osm_ready", _pending_room)

## ── coordinate conversion ────────────────────────────────────────────────────

func _to_game_pos(lat: float, lon: float, south: float, west: float,
		lat_cos: float, scale: float) -> Vector2:
	var north: float = BBOXES[_pending_room][2]
	return Vector2(
		MARGIN + (lon - west) * lat_cos * scale,
		MARGIN + (north - lat) * scale
	)

func _bbox_scale(room_id: int) -> float:
	var b: Array = BBOXES[room_id]
	var lat_cos := cos(deg_to_rad((float(b[0]) + float(b[2])) * 0.5))
	var sx := (GAME_W - MARGIN * 2.0) / ((float(b[3]) - float(b[1])) * lat_cos)
	var sy := (GAME_H - MARGIN * 2.0) / (float(b[2]) - float(b[0]))
	return minf(sx, sy)

## ── anchor extraction ─────────────────────────────────────────────────────────

func _extract_anchors(room_id: int, data: Dictionary) -> Array:
	var b: Array = BBOXES[room_id]
	var south := float(b[0]); var west := float(b[1]); var north := float(b[2])
	var lat_cos := cos(deg_to_rad((south + north) * 0.5))
	var scale := _bbox_scale(room_id)

	var candidates: Array = []
	for elem in data.get("elements", []):
		if elem.get("type") != "way":
			continue
		var tags: Dictionary = elem.get("tags", {})
		var name: String = tags.get("name", "")
		if name.is_empty():
			continue
		var geom: Array = elem.get("geometry", [])
		if geom.size() < 2:
			continue
		## Centroid in game space
		var sum_lat := 0.0; var sum_lon := 0.0
		for g in geom:
			sum_lat += float(g.get("lat", 0.0))
			sum_lon += float(g.get("lon", 0.0))
		var clat := sum_lat / geom.size()
		var clon := sum_lon / geom.size()
		var gpos := _to_game_pos(clat, clon, south, west, lat_cos, scale)
		## Discard anchors inside the margin border
		if gpos.x < MARGIN + ANCHOR_SIZE or gpos.x > GAME_W - MARGIN - ANCHOR_SIZE:
			continue
		if gpos.y < MARGIN + ANCHOR_SIZE or gpos.y > GAME_H - MARGIN - ANCHOR_SIZE:
			continue
		## Rough area for sorting (largest / most prominent building first)
		var lats: Array = []; var lons: Array = []
		for g in geom:
			lats.append(float(g.get("lat", 0.0)))
			lons.append(float(g.get("lon", 0.0)))
		var area: float = (lats.max() - lats.min()) * (lons.max() - lons.min())
		candidates.append({"pos": gpos, "name": name, "area": area})

	candidates.sort_custom(func(a, c): return a["area"] > c["area"])
	return candidates.slice(0, MAX_ANCHORS)

## ── layout application ───────────────────────────────────────────────────────

## Places OSM anchor buildings in the room, skipping any that would overlap
## with existing StaticBody2D nodes (room walls, blocks, Keep, towers).
func _apply_anchors(room_id: int, anchors: Array) -> void:
	var room: Node = _game.get_node_or_null("Room%d" % room_id)
	if room == null:
		return

	## Collect existing obstacle centres so we can avoid them.
	var existing_centres: Array = []
	for child in room.get_children():
		if child is StaticBody2D:
			existing_centres.append(child.position)

	var spawn_node: Node = room.get_node_or_null("EnemySpawnPoints")
	var placed: int = 0
	for anchor in anchors:
		var pos: Vector2 = anchor["pos"] as Vector2
		## Skip if too close to any existing obstacle.
		var blocked := false
		for ec in existing_centres:
			if pos.distance_to(ec as Vector2) < MIN_CLEAR:
				blocked = true
				break
		if blocked:
			continue
		_add_anchor(room, pos, anchor["name"], placed)
		existing_centres.append(pos)   ## future anchors also avoid this one
		## Extra spawn point near each placed building
		if spawn_node != null:
			var to_centre: Vector2 = (Vector2(GAME_W, GAME_H) * 0.5 - pos).normalized()
			var sp_pos: Vector2 = (pos + to_centre * (ANCHOR_SIZE * 0.8 + 24.0)).clamp(
				Vector2(55, 55), Vector2(GAME_W - 55, GAME_H - 55))
			var m := Marker2D.new()
			m.name = "OsmSpawn%d" % placed
			m.position = sp_pos
			spawn_node.add_child(m)
		placed += 1

	if placed > 0:
		var nav: NavigationRegion2D = room.get_node_or_null("NavigationRegion2D")
		if nav:
			nav.bake_navigation_polygon(false)

## ── building helper ──────────────────────────────────────────────────────────

## Landmark obstacle: square block at the OSM-derived position, labelled by name.
## Colour (BLD_COLOR) is visually distinct from room walls (grey) and blocks.
func _add_anchor(room: Node, pos: Vector2, label: String, idx: int) -> void:
	var body := StaticBody2D.new()
	body.name = "Anchor%d_%s" % [idx, label.left(12).replace(" ", "_")]
	body.position = pos
	body.collision_mask = 0
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(ANCHOR_SIZE, ANCHOR_SIZE)
	cs.shape = rect
	body.add_child(cs)
	var vis := Polygon2D.new()
	vis.color = BLD_COLOR
	var h := ANCHOR_SIZE * 0.5
	vis.polygon = PackedVector2Array([
		Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)
	])
	body.add_child(vis)
	var lbl := Label.new()
	lbl.text = label
	lbl.add_theme_font_size_override("font_size", 7)
	lbl.add_theme_color_override("font_color", Color(0.75, 0.72, 0.68))
	lbl.position = Vector2(-ANCHOR_SIZE * 0.5, -ANCHOR_SIZE * 0.5 - 10)
	body.add_child(lbl)
	room.add_child(body)
