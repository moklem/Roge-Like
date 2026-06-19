extends CanvasLayer
## CarHUD — single global dashboard visible to all players simultaneously (D-01, D-02).
## CanvasLayer.layer = 3 to render above game world, PlayerHUD (layer=1), CardOverlay (layer=2).
## Listens to GameEvents.hud_event signal in _ready() — mirrors Game.gd line 106 pattern.
## Polls GameState.loop_number in _process() to update Loop label (RESEARCH.md Open Question 4).

## Per-indicator record: panel (PanelContainer), label (Label), style (StyleBoxFlat),
## lit_color (Color), tween (Tween or null).
var _indicators: Dictionary = {}

## LoopLabel node reference and last-seen loop number for change detection.
var _loop_label: Label = null
var _last_loop_number: int = 0

func _ready() -> void:
	# Mirror Game.gd line 106: connect to hud_event signal so CarHUD reacts on all peers.
	GameEvents.hud_event.connect(_on_hud_event)

	# Build indicator dictionary — get node references and create per-indicator StyleBoxFlats.
	_build_indicators()

	# Cache LoopLabel and set initial text.
	_loop_label = get_node_or_null("CarHUDPanel/CarHUDContainer/LoopLabel")
	_last_loop_number = GameState.loop_number
	if _loop_label:
		_loop_label.text = "Loop: %d" % _last_loop_number

func _process(_delta: float) -> void:
	# Polling pattern: update loop label only when loop_number changes (RESEARCH.md OQ4).
	if GameState.loop_number != _last_loop_number:
		_last_loop_number = GameState.loop_number
		if _loop_label:
			_loop_label.text = "Loop: %d" % _last_loop_number

# ------------------------------------------------------------------------------
# Indicator setup
# ------------------------------------------------------------------------------

func _build_indicators() -> void:
	# Indicator definitions: key → node name suffix and lit color (UI-SPEC color table).
	var definitions: Array = [
		{"key": "ac",           "panel": "AcIndicator",           "label": "AcLabel",           "lit": Color(0.1, 0.35, 0.85, 1)},
		{"key": "engine",       "panel": "EngineIndicator",       "label": "EngineLabel",       "lit": Color(0.85, 0.15, 0.1, 1)},
		{"key": "seat_massage", "panel": "SeatMassageIndicator",  "label": "SeatMassageLabel",  "lit": Color(0.1, 0.7, 0.2, 1)},
		{"key": "suspension",   "panel": "SuspensionIndicator",   "label": "SuspensionLabel",   "lit": Color(0.9, 0.8, 0.05, 1)},
		{"key": "lidar",        "panel": "LidarIndicator",        "label": "LidarLabel",        "lit": Color(0.9, 0.35, 0.05, 1)},
	]
	var container_path := "CarHUDPanel/CarHUDContainer/"
	for def in definitions:
		var panel: PanelContainer = get_node_or_null(container_path + def["panel"])
		var lbl: Label = get_node_or_null(container_path + def["panel"] + "/" + def["label"])
		if panel == null or lbl == null:
			push_warning("CarHUD: missing node for indicator '%s'" % def["key"])
			continue
		# Create a per-indicator StyleBoxFlat set to idle background (D-04 / UI-SPEC).
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.10, 0.10, 0.10, 1)  # idle bg (#1A1A1A)
		panel.add_theme_stylebox_override("panel", style)
		_indicators[def["key"]] = {
			"panel":     panel,
			"label":     lbl,
			"style":     style,
			"lit_color": def["lit"],
			"tween":     null,
		}

# ------------------------------------------------------------------------------
# HUD event handler — called on all peers when GameEvents.hud_event fires.
# ------------------------------------------------------------------------------

func _on_hud_event(event_name: String) -> void:
	if _indicators.has(event_name):
		_activate_indicator(event_name)

func _activate_indicator(event_name: String) -> void:
	var entry: Dictionary = _indicators[event_name]
	var panel: PanelContainer = entry["panel"]
	var lbl: Label              = entry["label"]
	var style: StyleBoxFlat     = entry["style"]
	var lit_color: Color        = entry["lit_color"]

	# If a tween is already running, restart cleanly (D-05: per-indicator independent tween).
	var existing_tween = entry["tween"]
	if existing_tween != null and existing_tween.is_valid():
		existing_tween.kill()

	# Apply lit state: bright background, white text with outline (UI-SPEC Component States).
	style.bg_color = lit_color
	lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1))
	lbl.add_theme_constant_override("outline_size", 1)
	panel.modulate.a = 1.0

	# Tween: hold 2.0s → fade modulate:a to 0.0 over 0.5s → restore idle in callback.
	# CRITICAL: never tween StyleBoxFlat.bg_color directly — Godot 4 cannot tween resources.
	# Instead tween the panel node's modulate:a and restore style in the callback.
	var tween := panel.create_tween()
	tween.tween_interval(2.0)
	tween.tween_property(panel, "modulate:a", 0.0, 0.5)
	tween.tween_callback(_restore_idle.bind(event_name))
	entry["tween"] = tween

func _restore_idle(event_name: String) -> void:
	if not _indicators.has(event_name):
		return
	var entry: Dictionary   = _indicators[event_name]
	var panel: PanelContainer = entry["panel"]
	var lbl: Label             = entry["label"]
	var style: StyleBoxFlat    = entry["style"]

	# Reset panel alpha first so idle style is fully visible.
	panel.modulate.a = 1.0
	# Restore idle StyleBoxFlat background (D-04 idle color).
	style.bg_color = Color(0.10, 0.10, 0.10, 1)
	# Restore dim idle label text (UI-SPEC indicator idle label text #595959).
	lbl.add_theme_color_override("font_color", Color(0.35, 0.35, 0.35, 1))
	lbl.add_theme_constant_override("outline_size", 0)
