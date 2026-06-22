extends Node
## Builds interior room obstacles from real OSM building/historic polygon data.
## Room boundary walls stay in Game.tscn; all interior structure comes from here.
## Offline fallback: places simple rectangles that recreate the original layout.

signal room_osm_ready(room_id: int)

const BBOXES: Dictionary = {
	1: [49.9020, 10.8860, 49.9070, 10.9000],  ## ERBA (Erba-Insel)
	2: [49.8930, 10.8870, 49.9020, 10.9050],  ## Bamberg Altstadt
	3: [49.8760, 10.8590, 49.8820, 10.8690],  ## Burg Altenburg
}

## Offline fallback geometry per room — used when API is unreachable.
## Matches the original Game.tscn block layout so rooms stay playable offline.
const FALLBACK: Dictionary = {
	2: [
		{"pos": Vector2(242, 200), "w": 115, "h": 200},
		{"pos": Vector2(235, 140), "w": 130, "h": 180},
		{"pos": Vector2(565, 200), "w": 130, "h": 200},
		{"pos": Vector2(242, 475), "w": 115, "h": 150},
		{"pos": Vector2(235, 460), "w": 130, "h": 180},
		{"pos": Vector2(565, 475), "w": 130, "h": 150},
	],
	3: [
		{"pos": Vector2(400, 220), "w": 80,  "h": 80},
		{"pos": Vector2(120, 120), "w": 60,  "h": 60},
		{"pos": Vector2(660, 120), "w": 60,  "h": 60},
	],
}

const MAX_BUILDINGS  := 18    ## cap to keep navmesh bake fast
const TARGET_BLDG_PX := 62.0  ## normalise each building's largest extent to this
const MIN_BLDG_PX    := 36.0  ## floor on building size
const MARGIN         := 50.0  ## keep buildings away from boundary walls
const GAME_W         := 800.0
const GAME_H         := 600.0
const BLD_COLOR      := Color(0.30, 0.27, 0.33, 1.0)  ## purplish — distinct from grey walls
const OSM_TIMEOUT    := 12.0

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
		push_warning("OSMRoomGenerator: request error %d (room %d) — using fallback" % [err, room_id])
		_place_fallback(room_id)
		emit_signal("room_osm_ready", room_id)

func _on_http_done(_res: int, code: int, _hdrs: PackedStringArray, body: PackedByteArray) -> void:
	var buildings: Array = []
	if code == 200:
		var parsed = JSON.parse_string(body.get_string_from_utf8())
		if parsed is Dictionary:
			buildings = _extract_buildings(_pending_room, parsed)
	else:
		push_warning("OSMRoomGenerator: HTTP %d (room %d) — using fallback" % [code, _pending_room])
	if buildings.is_empty():
		_place_fallback(_pending_room)
	else:
		_place_buildings(_pending_room, buildings)
	emit_signal("room_osm_ready", _pending_room)

# ── coordinate helpers ────────────────────────────────────────────────────────

func _bbox_scale(room_id: int) -> float:
	var b: Array = BBOXES[room_id]
	var lat_cos := cos(deg_to_rad((float(b[0]) + float(b[2])) * 0.5))
	var sx := (GAME_W - MARGIN * 2.0) / ((float(b[3]) - float(b[1])) * lat_cos)
	var sy := (GAME_H - MARGIN * 2.0) / (float(b[2]) - float(b[0]))
	return minf(sx, sy)

func _to_game_pos(lat: float, lon: float, south: float, west: float,
		lat_cos: float, scale: float) -> Vector2:
	var north: float = BBOXES[_pending_room][2]
	return Vector2(
		MARGIN + (lon - west) * lat_cos * scale,
		MARGIN + (north - lat) * scale
	)

# ── building extraction ───────────────────────────────────────────────────────

func _extract_buildings(room_id: int, data: Dictionary) -> Array:
	var b: Array = BBOXES[room_id]
	var south := float(b[0]); var west := float(b[1]); var north := float(b[2])
	var lat_cos := cos(deg_to_rad((south + north) * 0.5))
	var scale := _bbox_scale(room_id)

	var results: Array = []
	for elem in data.get("elements", []):
		if elem.get("type") != "way":
			continue
		var tags: Dictionary = elem.get("tags", {})
		if not (tags.has("building") or tags.has("historic")):
			continue
		var name: String = tags.get("name", "")
		var geom: Array = elem.get("geometry", [])
		if geom.size() < 3:
			continue

		## Project vertices to game space
		var raw: Array = []
		for g in geom:
			raw.append(_to_game_pos(float(g.get("lat", 0.0)), float(g.get("lon", 0.0)),
				south, west, lat_cos, scale))

		## Centroid
		var centroid := Vector2.ZERO
		for pt in raw:
			centroid += pt as Vector2
		centroid /= raw.size()

		## Skip if centroid outside playable margin
		if centroid.x < MARGIN or centroid.x > GAME_W - MARGIN:
			continue
		if centroid.y < MARGIN or centroid.y > GAME_H - MARGIN:
			continue

		## Shape relative to centroid, compute max extent
		var local: Array = []
		var max_ext := 0.0
		for pt in raw:
			var lp: Vector2 = (pt as Vector2) - centroid
			local.append(lp)
			max_ext = maxf(max_ext, lp.length())

		## Normalise to TARGET_BLDG_PX (floor at MIN_BLDG_PX)
		var half := maxf(TARGET_BLDG_PX, MIN_BLDG_PX) * 0.5
		var sf: float = half / maxf(max_ext, 1.0)
		var poly := PackedVector2Array()
		for lp in local:
			poly.append((lp as Vector2) * sf + centroid)

		results.append({"polygon": poly, "centroid": centroid, "name": name, "area": max_ext * max_ext})

	results.sort_custom(func(a, c): return a["area"] > c["area"])
	return results.slice(0, MAX_BUILDINGS)

# ── placement ─────────────────────────────────────────────────────────────────

func _place_buildings(room_id: int, buildings: Array) -> void:
	var room: Node = _game.get_node_or_null("Room%d" % room_id)
	if room == null:
		return
	## Existing static body centres (boundary walls) — avoid placing on top of them
	var taken: Array = []
	for child in room.get_children():
		if child is StaticBody2D:
			taken.append(child.position as Vector2)

	var spawn_node: Node = room.get_node_or_null("EnemySpawnPoints")
	var placed := 0
	for bld in buildings:
		var c: Vector2 = bld["centroid"] as Vector2
		var blocked := false
		for tc in taken:
			if c.distance_to(tc as Vector2) < TARGET_BLDG_PX:
				blocked = true
				break
		if blocked:
			continue
		_add_building(room, bld["polygon"] as PackedVector2Array, bld["name"], placed, room.visible)
		taken.append(c)
		if spawn_node != null:
			var to_c: Vector2 = (Vector2(GAME_W, GAME_H) * 0.5 - c).normalized()
			var sp: Vector2 = (c + to_c * (TARGET_BLDG_PX + 20.0)).clamp(
				Vector2(55, 55), Vector2(GAME_W - 55, GAME_H - 55))
			var m := Marker2D.new()
			m.name = "OsmSpawn%d" % placed
			m.position = sp
			spawn_node.add_child(m)
		placed += 1

	if placed > 0:
		var nav: NavigationRegion2D = room.get_node_or_null("NavigationRegion2D")
		if nav:
			nav.bake_navigation_polygon(false)

func _place_fallback(room_id: int) -> void:
	if not FALLBACK.has(room_id):
		return
	var room: Node = _game.get_node_or_null("Room%d" % room_id)
	if room == null:
		return
	var defs: Array = FALLBACK[room_id]
	for i in range(defs.size()):
		var d: Dictionary = defs[i]
		var pos: Vector2 = d["pos"] as Vector2
		var hw: float = float(d["w"]) * 0.5
		var hh: float = float(d["h"]) * 0.5
		var poly := PackedVector2Array([
			Vector2(pos.x - hw, pos.y - hh), Vector2(pos.x + hw, pos.y - hh),
			Vector2(pos.x + hw, pos.y + hh), Vector2(pos.x - hw, pos.y + hh),
		])
		_add_building(room, poly, "", i, room.visible)
	var nav: NavigationRegion2D = room.get_node_or_null("NavigationRegion2D")
	if nav:
		nav.bake_navigation_polygon(false)

# ── node builder ──────────────────────────────────────────────────────────────

func _add_building(room: Node, polygon: PackedVector2Array, label: String,
		idx: int, room_active: bool) -> void:
	var body := StaticBody2D.new()
	body.name = "OSMBld%d" % idx if label.is_empty() else \
		"OSMBld%d_%s" % [idx, label.left(10).replace(" ", "_")]
	body.position = Vector2.ZERO  ## polygon coords are already in scene/room space
	body.collision_layer = 1
	body.collision_mask = 0
	## If the room is currently hidden, disable collision to prevent invisible walls.
	if not room_active:
		body.set_collision_layer_value(1, false)
	var cp := CollisionPolygon2D.new()
	cp.polygon = polygon
	body.add_child(cp)
	var vis := Polygon2D.new()
	vis.color = BLD_COLOR
	vis.polygon = polygon
	body.add_child(vis)
	if not label.is_empty():
		var cx := 0.0; var cy := 0.0
		for pt in polygon:
			cx += pt.x; cy += pt.y
		var lbl := Label.new()
		lbl.text = label
		lbl.add_theme_font_size_override("font_size", 7)
		lbl.add_theme_color_override("font_color", Color(0.75, 0.72, 0.68))
		lbl.position = Vector2(cx / polygon.size() - 20.0, cy / polygon.size() - 10.0)
		body.add_child(lbl)
	room.add_child(body)
