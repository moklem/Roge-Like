class_name UiStyle
extends RefCounted
## Shared menu/lobby styling. Applies the Bangers comic font to buttons/labels, the
## Transformers Movie font to the title, comic-panel styleboxes (paper background, thick
## ink border, hard offset shadow), and a full-screen background. Fonts/background are
## loaded at runtime with existence checks so a missing file degrades to the default look
## instead of breaking the scene.

const BUTTON_FONT_PATH := "res://assets/ui/fonts/Bangers.ttf"  # comic font (SIL OFL)
const TITLE_FONT_PATH   := "res://assets/ui/fonts/TransformersMovie.ttf"
const BACKGROUND_PATH   := "res://assets/Hintergrund.png"

static var _button_font: Font = null
static var _title_font: Font = null

static func button_font() -> Font:
	if _button_font == null and ResourceLoader.exists(BUTTON_FONT_PATH):
		_button_font = load(BUTTON_FONT_PATH)
	return _button_font

static func title_font() -> Font:
	if _title_font == null and ResourceLoader.exists(TITLE_FONT_PATH):
		_title_font = load(TITLE_FONT_PATH)
	return _title_font

## Add a full-screen background image behind all existing UI (once per screen).
static func add_background(root: Control, path: String = BACKGROUND_PATH) -> void:
	if root.has_node("StyleBackground") or not ResourceLoader.exists(path):
		return
	var tr := TextureRect.new()
	tr.name = "StyleBackground"
	tr.texture = load(path)
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE  # never eat clicks
	root.add_child(tr)
	root.move_child(tr, 0)  # render behind the rest of the UI

## Style the big title as a bold logo: Transformers font, large size, heavy outline + shadow.
static func style_title(label: Label) -> void:
	if label == null:
		return
	var f := title_font()
	if f:
		label.add_theme_font_override("font", f)
	label.add_theme_font_size_override("font_size", 240)
	label.add_theme_color_override("font_color", Color(1, 1, 1))
	# Heavy black outline = the "fett"/logo weight.
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override("outline_size", 18)
	# Drop shadow for extra logo punch.
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	label.add_theme_constant_override("shadow_offset_x", 6)
	label.add_theme_constant_override("shadow_offset_y", 6)
	label.add_theme_constant_override("shadow_outline_size", 6)
	# Don't let the narrow VBox clip the oversized logo text.
	label.clip_text = false
	label.autowrap_mode = TextServer.AUTOWRAP_OFF

## Comic ink color used for text on the paper-colored panels.
const INK := Color(0.08, 0.07, 0.10)
## Comic paper background for buttons/panels.
const PAPER := Color(0.99, 0.95, 0.83)

## Apply the comic font + comic-panel styleboxes to every Button under root.
## Paper background, dark ink text, thick black border, hard offset shadow;
## hover pops yellow, pressed sinks into the page.
static func style_buttons(root: Node) -> void:
	var f := button_font()
	var buttons: Array = []
	_collect(root, "Button", buttons)
	for b in buttons:
		# Breathing room between the chunky comic panels: bump the separation of any
		# Box container that holds a button (default 4px crams the hard shadows together).
		var parent: Node = b.get_parent()
		if parent is BoxContainer:
			parent.add_theme_constant_override("separation", 16)
		if f:
			b.add_theme_font_override("font", f)
		b.add_theme_font_size_override("font_size", 26)
		b.add_theme_color_override("font_color", INK)
		b.add_theme_color_override("font_hover_color", INK)
		b.add_theme_color_override("font_pressed_color", INK)
		b.add_theme_color_override("font_disabled_color", Color(INK.r, INK.g, INK.b, 0.45))
		b.add_theme_stylebox_override("normal",  comic_box(PAPER))
		b.add_theme_stylebox_override("hover",   comic_box(Color(1.0, 0.84, 0.25)))
		b.add_theme_stylebox_override("pressed", comic_box(Color(0.96, 0.62, 0.16), true))
		b.add_theme_stylebox_override("disabled", comic_box(Color(0.85, 0.82, 0.74, 0.7)))
		b.add_theme_stylebox_override("focus",   _focus_box())

## Apply the button font + a dark outline to every Label under root (legible on the bg).
static func style_labels(root: Node) -> void:
	var labels: Array = []
	_collect(root, "Label", labels)
	for l in labels:
		style_label(l)

## Style a single label (used for dynamically created player-list rows too).
static func style_label(label: Label) -> void:
	var f := button_font()
	if f:
		label.add_theme_font_override("font", f)
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(0.98, 0.97, 0.94))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override("outline_size", 5)

## Comic nameplate above a player: comic font + heavy ink outline on the RoleLabel
## (doubles as the player name — role IS the identity, see Lobby D-05) and the
## LevelUpLabel, plus ink-outlined world-space Health/Revive bars.
static func style_player_nameplate(player: Node) -> void:
	var f := button_font()
	var name_lbl: Label = player.get_node_or_null("RoleLabel")
	if name_lbl:
		if f:
			name_lbl.add_theme_font_override("font", f)
		name_lbl.add_theme_font_size_override("font_size", 16)
		name_lbl.add_theme_color_override("font_color", Color(1, 1, 1))
		name_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		name_lbl.add_theme_constant_override("outline_size", 6)
	var levelup_lbl: Label = player.get_node_or_null("LevelUpLabel")
	if levelup_lbl:
		if f:
			levelup_lbl.add_theme_font_override("font", f)
		levelup_lbl.add_theme_font_size_override("font_size", 12)
		levelup_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
		levelup_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		levelup_lbl.add_theme_constant_override("outline_size", 4)
	style_world_bar(player.get_node_or_null("HealthBar"), Color(0.30, 0.85, 0.25))
	style_world_bar(player.get_node_or_null("ReviveBar"), Color(0.30, 0.65, 1.0))

## Comic-style world-space progress bar: dark backing with ink frame, and a fill that
## carries its own ink outline so partial values still read as a chunky outlined block.
static func style_world_bar(bar: ProgressBar, fill_color: Color) -> void:
	if bar == null:
		return
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.12, 0.10, 0.13, 0.95)
	bg.border_color = Color(0, 0, 0, 1)
	bg.set_border_width_all(2)
	bg.set_corner_radius_all(4)
	var fg := StyleBoxFlat.new()
	fg.bg_color = fill_color
	fg.border_color = Color(0, 0, 0, 1)
	fg.set_border_width_all(2)
	fg.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fg)

## Comic-panel stylebox: solid bg, thick black border, hard offset shadow.
## pressed=true pulls the shadow in so the button looks pushed into the page.
static func comic_box(bg: Color, pressed: bool = false) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = Color(0, 0, 0, 1)
	s.set_border_width_all(3)
	s.set_corner_radius_all(10)
	s.set_content_margin_all(10)
	s.shadow_color = Color(0, 0, 0, 0.85)
	s.shadow_size = 1 if pressed else 4
	s.shadow_offset = Vector2(1, 1) if pressed else Vector2(3, 3)
	return s

static func _focus_box() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0, 0, 0, 0)
	s.border_color = Color(1.0, 0.8, 0.2)
	s.set_border_width_all(3)
	s.set_corner_radius_all(10)
	s.set_content_margin_all(10)
	return s

static func _collect(node: Node, klass: String, out: Array) -> void:
	for c in node.get_children():
		if c.is_class(klass):
			out.append(c)
		_collect(c, klass, out)
