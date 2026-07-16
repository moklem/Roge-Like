extends CanvasLayer
## OffscreenIndicators — small comic-style edge arrows pointing at what this peer cannot
## see right now: teammates outside the view (downed ones pulse red — they need you) and
## the opened exit passage.
##
## Purely local presentation, exactly like the camera itself: every peer derives its own
## arrows each frame from already-replicated positions. Nothing here is networked, nothing
## here allocates per frame — one full-rect Control redraws its handful of triangles.

## The CarHUD panel is opaque and covers the right strip — that part of the screen is not
## play area, so arrows for targets "behind" it park at the play area's edge instead.
const HUD_PANEL_WIDTH := 200.0
## How far the arrows sit inside the play-area edge.
const EDGE_MARGIN := 26.0
## Half-length of the arrow — the whole thing is ~22 px: a hint, not a billboard.
const ARROW_SIZE := 11.0

const TEAMMATE_COLOR := Color(0.99, 0.95, 0.83)   # UiStyle.PAPER — same paper as the panels
const DOWNED_COLOR   := Color(0.95, 0.20, 0.15)
const EXIT_COLOR     := Color(1.00, 0.84, 0.25)   # the comic buttons' hover yellow
const INK            := Color(0.08, 0.07, 0.10)   # UiStyle.INK

var _canvas: Control = null

func _ready() -> void:
	layer = 2   # above the world, below CarHUD (3), vignette (4) and the ESC overlay (6)
	_canvas = Control.new()
	_canvas.name = "ArrowCanvas"
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_arrows)
	add_child(_canvas)

func _process(_delta: float) -> void:
	_canvas.queue_redraw()

func _draw_arrows() -> void:
	var world_to_screen: Transform2D = _canvas.get_viewport().get_canvas_transform()
	var view: Vector2 = _canvas.get_viewport_rect().size
	var play_rect := Rect2(0.0, 0.0, view.x - HUD_PANEL_WIDTH, view.y)
	# Teammates: every player this peer does not control. Downed ones read urgent.
	for p in get_tree().get_nodes_in_group("players"):
		if not is_instance_valid(p) or p.is_multiplayer_authority():
			continue
		var color: Color = DOWNED_COLOR if p.is_downed else TEAMMATE_COLOR
		_draw_edge_arrow(world_to_screen * p.global_position, play_rect, color, p.is_downed)
	# The opened exit — the "hier lang" the exit_open cue announces audibly.
	var game := get_node_or_null("/root/Game")
	if game == null or game.get("_exit_open") != true:
		return
	var coords: Array = game.get("_exit_tile_coords")
	if coords is Array and not coords.is_empty():
		var tm: TileMap = game.get_node_or_null("Room%d/TileMap" % game.current_room)
		if tm != null:
			var sum := Vector2.ZERO
			for c in coords:
				sum += tm.to_global(tm.map_to_local(c))
			_draw_edge_arrow(world_to_screen * (sum / coords.size()), play_rect, EXIT_COLOR, false)

## One chunky outlined triangle at the play-area edge, pointing at an offscreen target.
## On-screen targets draw nothing — the arrow only exists while it has something to say.
func _draw_edge_arrow(target: Vector2, play_rect: Rect2, color: Color, pulse: bool) -> void:
	if play_rect.has_point(target):
		return
	var inner := play_rect.grow(-EDGE_MARGIN)
	var pos := target.clamp(inner.position, inner.end)
	var dir := (target - pos).normalized()
	if dir == Vector2.ZERO:
		return
	var s := ARROW_SIZE
	if pulse:
		# Downed teammate: breathe between 100% and ~130% so the red arrow won't be missed
		s *= 1.15 + 0.15 * sin(float(Time.get_ticks_msec()) / 1000.0 * 6.0)
	var ang := dir.angle()
	# Notched-back triangle — the same chunky ink-outlined shape language as the comic panels
	var pts := PackedVector2Array([
		pos + Vector2(s, 0).rotated(ang),
		pos + Vector2(-s * 0.7, s * 0.7).rotated(ang),
		pos + Vector2(-s * 0.35, 0).rotated(ang),
		pos + Vector2(-s * 0.7, -s * 0.7).rotated(ang),
	])
	_canvas.draw_colored_polygon(pts, color)
	var outline := pts.duplicate()
	outline.append(pts[0])
	_canvas.draw_polyline(outline, INK, 2.5, true)
