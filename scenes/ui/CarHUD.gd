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

## WaveLabel node reference and last-seen wave for change detection (polls GameState.display_wave).
var _wave_label: Label = null
var _last_wave: int = 0

## Driver Mode indicator — a single dynamic panel whose text/color changes per host roll.
## Distinct from the 5 reactive indicators: it displays the active team-wide sub-room effect.
var _driver_panel: PanelContainer = null
var _driver_label: Label = null
var _driver_style: StyleBoxFlat = null
var _driver_tween: Tween = null
## mode → [display text, lit background color]. Hold time arrives with the signal (host-rolled 3-5s).
const DRIVER_MODE_DISPLAY: Dictionary = {
	"eco":       ["Driver Mode: ECO",       Color(0.12, 0.4, 0.7, 1)],
	"sport":     ["Driver Mode: SPORT",     Color(0.55, 0.48, 0.05, 1)],
	"repair":    ["Driver Mode: REPAIR",    Color(0.1, 0.55, 0.2, 1)],
	"overdrive": ["Driver Mode: OVERDRIVE", Color(0.45, 0.18, 0.7, 1)],
}

## Comic restyle (matches MainMenu/LobbyScreen/PlayerHUD). Only the LOOK changes here — every
## indicator still lights on its own hud_event and fades on its own tween, exactly as before.
## An unlit indicator is a dim page; a lit one keeps its saturated signal color, which is what
## carries the meaning, so the lit palette is deliberately left alone.
const IDLE_BG: Color = Color(0.86, 0.83, 0.74, 1.0)   # muted paper, so a lit panel pops off it
const IDLE_TEXT: Color = Color(0.08, 0.07, 0.10, 0.5)  # ink at half strength
const LIT_TEXT: Color = Color(1.0, 1.0, 1.0, 1.0)

func _ready() -> void:
	# Mirror Game.gd line 106: connect to hud_event signal so CarHUD reacts on all peers.
	GameEvents.hud_event.connect(_on_hud_event)

	_apply_comic_style()

	# Build indicator dictionary — get node references and create per-indicator StyleBoxFlats.
	_build_indicators()

	# Driver Mode: one dynamic panel driven by the host's per-sub-room roll (GameEvents.driver_mode).
	_build_driver_indicator()
	GameEvents.driver_mode.connect(_on_driver_mode)

	# Cache LoopLabel and set initial text.
	_loop_label = get_node_or_null("CarHUDPanel/CarHUDContainer/LoopLabel")
	_last_loop_number = GameState.loop_number
	if _loop_label:
		_loop_label.text = "Loop: %d" % _last_loop_number

	# Cache WaveLabel and set initial text.
	_wave_label = get_node_or_null("CarHUDPanel/CarHUDContainer/WaveLabel")
	_last_wave = GameState.display_wave
	if _wave_label:
		_wave_label.text = "WELLE %d/%d" % [_last_wave, GameState.WAVES_PER_ROOM]

## Comic panel + comic font on every label. The indicator labels carry emoji (❄️🔥🌿⚡🔴) which
## Bangers has no glyphs for — they survive because FontFile.allow_system_fallback is on, so the
## system emoji face fills them in. Verified: the emoji resolve to real glyph widths, not tofu.
func _apply_comic_style() -> void:
	var panel: Panel = get_node_or_null("CarHUDPanel")
	if panel != null:
		panel.add_theme_stylebox_override("panel", UiStyle.comic_box(
			Color(UiStyle.PAPER.r, UiStyle.PAPER.g, UiStyle.PAPER.b, 0.93)))
	var f := UiStyle.button_font()
	for lbl in _all_labels():
		if f:
			lbl.add_theme_font_override("font", f)
		lbl.add_theme_font_size_override("font_size", 17)
		lbl.add_theme_color_override("font_color", IDLE_TEXT)
	var loop: Label = get_node_or_null("CarHUDPanel/CarHUDContainer/LoopLabel")
	if loop != null:
		loop.add_theme_font_size_override("font_size", 22)
		loop.add_theme_color_override("font_color", UiStyle.INK)
	# WaveLabel: the most-glanced line — biggest, ink-dark, so "WELLE x/3" reads at a glance.
	var wave: Label = get_node_or_null("CarHUDPanel/CarHUDContainer/WaveLabel")
	if wave != null:
		wave.add_theme_font_size_override("font_size", 26)
		wave.add_theme_color_override("font_color", UiStyle.INK)

func _all_labels() -> Array:
	var out: Array = []
	var container := get_node_or_null("CarHUDPanel/CarHUDContainer")
	if container == null:
		return out
	for child in container.get_children():
		if child is Label:
			out.append(child)
		for sub in child.get_children():
			if sub is Label:
				out.append(sub)
	return out

func _process(_delta: float) -> void:
	# Polling pattern: update loop label only when loop_number changes (RESEARCH.md OQ4).
	if GameState.loop_number != _last_loop_number:
		_last_loop_number = GameState.loop_number
		if _loop_label:
			_loop_label.text = "Loop: %d" % _last_loop_number
	# Same polling pattern for the wave line (host-synced via GameState.display_wave).
	if GameState.display_wave != _last_wave:
		_last_wave = GameState.display_wave
		if _wave_label:
			_wave_label.text = "WELLE %d/%d" % [_last_wave, GameState.WAVES_PER_ROOM]

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
		# Per-indicator comic panel, starting idle (D-04 / UI-SPEC). comic_box() hands back a
		# StyleBoxFlat, so the lit/idle transitions below still just swap bg_color and the
		# ink border and drop shadow ride along untouched.
		var style := UiStyle.comic_box(IDLE_BG)
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

## event → pre-colored rim overlay texture flashed around the screen edge alongside the panel
## blink. Only the climate/comfort trio gets a rim; suspension/lidar stay panel-only.
const RIM_FOR := {"ac": "rim_cold", "engine": "rim_hot", "seat_massage": "rim_massage"}
## A sustained effect re-emits its HUD event every ~1s (Earth heal → seat_massage, Fire bursts),
## which would re-trigger the rim every frame-worth and pin it on-screen. Same onset gate as the
## Sfx HUD echo: the rim only re-flashes after the event stream has actually gone quiet this long.
const RIM_ONSET_GAP: float = 1.5
var _rim_last_seen: Dictionary = {}

func _activate_indicator(event_name: String) -> void:
	if RIM_FOR.has(event_name):
		var now: float = float(Time.get_ticks_msec()) / 1000.0
		var last: float = _rim_last_seen.get(event_name, -1000.0)
		_rim_last_seen[event_name] = now
		if now - last >= RIM_ONSET_GAP:
			Juice.rim_flash(Juice.vfx(RIM_FOR[event_name]))
	var entry: Dictionary = _indicators[event_name]
	var panel: PanelContainer = entry["panel"]
	var lbl: Label              = entry["label"]
	var style: StyleBoxFlat     = entry["style"]
	var lit_color: Color        = entry["lit_color"]

	# If a tween is already running, restart cleanly (D-05: per-indicator independent tween).
	var existing_tween = entry["tween"]
	if existing_tween != null and existing_tween.is_valid():
		existing_tween.kill()

	# Apply lit state: bright background, white text with a heavy ink outline (comic pass —
	# the outline has to carry the text over the saturated signal colors).
	style.bg_color = lit_color
	lbl.add_theme_color_override("font_color", LIT_TEXT)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	lbl.add_theme_constant_override("outline_size", 5)
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
	# Back to the dim page (D-04 idle state, comic palette).
	style.bg_color = IDLE_BG
	lbl.add_theme_color_override("font_color", IDLE_TEXT)
	lbl.add_theme_constant_override("outline_size", 0)

# ------------------------------------------------------------------------------
# Driver Mode indicator — single dynamic panel, text/color per host roll.
# ------------------------------------------------------------------------------

func _build_driver_indicator() -> void:
	var base := "CarHUDPanel/CarHUDContainer/DriverModeIndicator"
	_driver_panel = get_node_or_null(base)
	_driver_label = get_node_or_null(base + "/DriverModeLabel")
	if _driver_panel == null or _driver_label == null:
		push_warning("CarHUD: missing Driver Mode nodes")
		return
	_driver_style = UiStyle.comic_box(IDLE_BG)
	_driver_panel.add_theme_stylebox_override("panel", _driver_style)

## GameEvents.driver_mode fires on all peers. Show the active mode brightly for the host-rolled
## duration (matches the gameplay effect duration exactly), then fade back to the dim idle state.
func _on_driver_mode(mode: String, duration: float) -> void:
	if _driver_panel == null or not DRIVER_MODE_DISPLAY.has(mode):
		return
	if _driver_tween != null and _driver_tween.is_valid():
		_driver_tween.kill()
	var info: Array = DRIVER_MODE_DISPLAY[mode]
	_driver_label.text = info[0]
	_driver_style.bg_color = info[1]
	_driver_label.add_theme_color_override("font_color", LIT_TEXT)
	_driver_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	_driver_label.add_theme_constant_override("outline_size", 5)
	_driver_panel.modulate.a = 1.0
	# Hold for the effect duration, fade out, then reset to idle.
	_driver_tween = _driver_panel.create_tween()
	_driver_tween.tween_interval(duration)
	_driver_tween.tween_property(_driver_panel, "modulate:a", 0.0, 0.5)
	_driver_tween.tween_callback(_restore_driver_idle)

func _restore_driver_idle() -> void:
	if _driver_panel == null:
		return
	_driver_panel.modulate.a = 1.0
	_driver_style.bg_color = IDLE_BG
	_driver_label.text = "Driver Mode:"
	_driver_label.add_theme_color_override("font_color", IDLE_TEXT)
	_driver_label.add_theme_constant_override("outline_size", 0)
