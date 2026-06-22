extends Node
## OSM-driven room layout: fetches only named/significant buildings as anchor points,
## then places a handful of landmark obstacles + corridor-divider walls that split
## the room into sub-areas.  Detail level: low — only structural highlights.
## Falls back silently when offline.

signal room_osm_ready(room_id: int)

## Bounding boxes (south_lat, west_lon, north_lat, east_lon) — Bamberg, Germany.
const BBOXES: Dictionary = {
	1: [49.895, 10.893, 49.901, 10.905],  ## Bamberg Dom-Insel
	2: [49.882, 10.872, 49.890, 10.888],  ## Bamberg Berggebiet
	3: [49.877, 10.865, 49.884, 10.875],  ## Burg Altenburg
}

## Per-room corridor dividers.  Each entry splits the room with a wall + gap.
## axis: "x" = vertical wall, "y" = horizontal wall.
## pos: 0-1 fraction of room width/height.
## gap_t / gap_b: top/left and bottom/right of the gap, as 0-1 fraction.
const ROOM_DIVIDERS: Dictionary = {
	1: [  ## 2 vertical dividers → 3 sub-rooms (entry | mid | far)
		{"axis": "x", "pos": 0.35, "gap_t": 0.38, "gap_b": 0.62},
		{"axis": "x", "pos": 0.66, "gap_t": 0.38, "gap_b": 0.62},
	],
	2: [  ## 1 horizontal divider → lower entry + upper climb
		{"axis": "y", "pos": 0.50, "gap_t": 0.40, "gap_b": 0.60},
	],
	3: [],  ## boss arena — no extra dividers, static room geometry handles it
}

## Max named landmark buildings to pick as anchor obstacles per room.
const MAX_ANCHORS: int = 5
## Size of each anchor obstacle in game pixels.
const ANCHOR_SIZE: float = 58.0

const GAME_W      := 800.0
const GAME_H      := 600.0
const MARGIN      := 36.0
const WALL_W      := 22.0   ## thickness of corridor-divider walls
const BLD_COLOR   := Color(0.30, 0.27, 0.33, 1.0)
const WALL_COLOR  := Color(0.32, 0.30, 0.34, 1.0)
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
	## Only named buildings — keeps response tiny and gives us meaningful anchors.
	## Room 3 also grabs named historic features (castle walls, towers).
	var q: String
	if room_id == 3:
		q = (
			"[out:json][timeout:15];"
			+ "(way[\"name\"][\"building\"](%s);" % bbox
			+ "way[\"name\"][\"historic\"](%s);" % bbox
			+ "way[\"barrier\"=\"wall\"](%s);" % bbox
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
		_apply_layout(_pending_room, [])   ## still add dividers even without OSM data

func _on_http_done(_res: int, code: int, _hdrs: PackedStringArray, body: PackedByteArray) -> void:
	var anchors: Array = []
	if code == 200:
		var parsed = JSON.parse_string(body.get_string_from_utf8())
		if parsed is Dictionary:
			anchors = _extract_anchors(_pending_room, parsed)
	else:
		push_warning("OSMRoomGenerator: HTTP %d for room %d" % [code, _pending_room])
	_apply_layout(_pending_room, anchors)
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
		## Discard anchors too close to the boundary wall
		if gpos.x < MARGIN + ANCHOR_SIZE or gpos.x > GAME_W - MARGIN - ANCHOR_SIZE:
			continue
		if gpos.y < MARGIN + ANCHOR_SIZE or gpos.y > GAME_H - MARGIN - ANCHOR_SIZE:
			continue
		## Rough area from geom bbox for sorting
		var lats: Array = []; var lons: Array = []
		for g in geom:
			lats.append(float(g.get("lat", 0.0)))
			lons.append(float(g.get("lon", 0.0)))
		var area: float = (lats.max() - lats.min()) * (lons.max() - lons.min())
		candidates.append({"pos": gpos, "name": name, "area": area})

	candidates.sort_custom(func(a, c): return a["area"] > c["area"])
	return candidates.slice(0, MAX_ANCHORS)

## ── layout application ───────────────────────────────────────────────────────

func _apply_layout(room_id: int, anchors: Array) -> void:
	var room: Node = _game.get_node_or_null("Room%d" % room_id)
	if room == null:
		return

	## 1. Corridor-divider walls — the main structural feature
	var dividers: Array = ROOM_DIVIDERS.get(room_id, [])
	for div in dividers:
		_add_divider(room, div)

	## 2. Landmark anchor obstacles (named buildings as reference points)
	var spawn_node: Node = room.get_node_or_null("EnemySpawnPoints")
	var si: int = 0
	for i in range(anchors.size()):
		var anchor: Dictionary = anchors[i]
		_add_anchor(room, anchor["pos"], anchor["name"], i)
		## Spawn point offset from anchor toward room centre
		if spawn_node != null:
			var to_centre := (Vector2(GAME_W, GAME_H) * 0.5 - anchor["pos"]).normalized()
			var sp_pos := (anchor["pos"] + to_centre * (ANCHOR_SIZE * 0.8 + 24.0)).clamp(
				Vector2(55, 55), Vector2(GAME_W - 55, GAME_H - 55))
			var m := Marker2D.new()
			m.name = "OsmSpawn%d" % si
			m.position = sp_pos
			spawn_node.add_child(m)
			si += 1

	## 3. Rebake navmesh if anything was added
	if not anchors.is_empty() or not dividers.is_empty():
		var nav: NavigationRegion2D = room.get_node_or_null("NavigationRegion2D")
		if nav:
			nav.bake_navigation_polygon(false)

## ── wall helpers ─────────────────────────────────────────────────────────────

## Adds a wall with a corridor gap.  axis="x" → vertical wall, axis="y" → horizontal.
func _add_divider(room: Node, div: Dictionary) -> void:
	var axis: String = div["axis"]
	var pos_frac: float = div["pos"]
	var gap_t: float = div["gap_t"]   ## fraction where gap starts
	var gap_b: float = div["gap_b"]   ## fraction where gap ends

	if axis == "x":
		var wx: float = MARGIN + pos_frac * (GAME_W - MARGIN * 2.0)
		var seg_top_h: float = (gap_t * (GAME_H - MARGIN * 2.0))
		var seg_bot_h: float = ((1.0 - gap_b) * (GAME_H - MARGIN * 2.0))
		if seg_top_h > 4.0:
			_add_wall_rect(room, "DivV_Top",
				Vector2(wx, MARGIN + seg_top_h * 0.5),
				Vector2(WALL_W, seg_top_h))
		if seg_bot_h > 4.0:
			_add_wall_rect(room, "DivV_Bot",
				Vector2(wx, GAME_H - MARGIN - seg_bot_h * 0.5),
				Vector2(WALL_W, seg_bot_h))
	else:  ## axis == "y"
		var wy: float = MARGIN + pos_frac * (GAME_H - MARGIN * 2.0)
		var seg_l_w: float = (gap_t * (GAME_W - MARGIN * 2.0))
		var seg_r_w: float = ((1.0 - gap_b) * (GAME_W - MARGIN * 2.0))
		if seg_l_w > 4.0:
			_add_wall_rect(room, "DivH_L",
				Vector2(MARGIN + seg_l_w * 0.5, wy),
				Vector2(seg_l_w, WALL_W))
		if seg_r_w > 4.0:
			_add_wall_rect(room, "DivH_R",
				Vector2(GAME_W - MARGIN - seg_r_w * 0.5, wy),
				Vector2(seg_r_w, WALL_W))

func _add_wall_rect(room: Node, node_name: String, center: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.name = node_name
	body.position = center
	body.collision_mask = 0
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	cs.shape = rect
	body.add_child(cs)
	var vis := Polygon2D.new()
	vis.color = WALL_COLOR
	var hw := size.x * 0.5; var hh := size.y * 0.5
	vis.polygon = PackedVector2Array([
		Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(hw, hh), Vector2(-hw, hh)
	])
	body.add_child(vis)
	room.add_child(body)

## Landmark obstacle: square block at the OSM-derived position, labelled by name.
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
	## Small name label above the block so it's identifiable in-game
	var lbl := Label.new()
	lbl.text = label
	lbl.add_theme_font_size_override("font_size", 7)
	lbl.add_theme_color_override("font_color", Color(0.75, 0.72, 0.68))
	lbl.position = Vector2(-ANCHOR_SIZE * 0.5, -ANCHOR_SIZE * 0.5 - 10)
	body.add_child(lbl)
	room.add_child(body)
