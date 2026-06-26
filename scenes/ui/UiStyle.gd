class_name UiStyle
extends RefCounted
## Shared menu/lobby styling. Applies the Sharpshooter font to buttons, the Transformers
## Movie font to the title, legible styleboxes/outlines over the background image, and a
## full-screen background. Fonts/background are loaded at runtime with existence checks so
## a missing file degrades to the default look instead of breaking the scene.

const BUTTON_FONT_PATH := "res://assets/ui/fonts/Sharpshooter.ttf"
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

## Apply the button font + styleboxes to every Button under root.
static func style_buttons(root: Node) -> void:
	var f := button_font()
	var buttons: Array = []
	_collect(root, "Button", buttons)
	for b in buttons:
		if f:
			b.add_theme_font_override("font", f)
		b.add_theme_font_size_override("font_size", 24)
		b.add_theme_color_override("font_color", Color(0.93, 0.93, 0.96))
		b.add_theme_color_override("font_hover_color", Color(1, 1, 1))
		b.add_theme_stylebox_override("normal",  _box(Color(0.10, 0.10, 0.13, 0.85)))
		b.add_theme_stylebox_override("hover",   _box(Color(0.20, 0.20, 0.26, 0.92)))
		b.add_theme_stylebox_override("pressed", _box(Color(0.06, 0.06, 0.09, 0.95)))
		b.add_theme_stylebox_override("disabled", _box(Color(0.10, 0.10, 0.12, 0.55)))
		b.add_theme_stylebox_override("focus",   _box(Color(0, 0, 0, 0), true))

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
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.98))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("outline_size", 4)

static func _box(bg: Color, focus: bool = false) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(6)
	s.set_content_margin_all(8)
	if focus:
		s.border_color = Color(1.0, 0.8, 0.2)
		s.set_border_width_all(2)
	return s

static func _collect(node: Node, klass: String, out: Array) -> void:
	for c in node.get_children():
		if c.is_class(klass):
			out.append(c)
		_collect(c, klass, out)
