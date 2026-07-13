extends Label
## DamageNumber — pooled, world-space floating combat text (DMG-01).
## Poolable: `show_number()` re-triggers the full animation on an existing instance;
## the node hides itself when done and is NEVER queue_free()'d by itself — Juice.gd
## owns the fixed pool (SYS-02) and reuses this node for the next hit.
##
## Styling per UI-SPEC: Bangers comic font (UiStyle.button_font()), 4px black ink
## outline, font size continuously scaled with damage magnitude (D-01/D-03).

const FLOAT_DISTANCE: float = 40.0
const FLOAT_DURATION: float = 0.6
const FADE_DURATION: float = 0.2
const POP_DURATION: float = 0.1
const JITTER_RANGE: float = 8.0

var _tween: Tween = null

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	z_index = 10

## (Re)starts the punch-scale-pop + float-up + fade-out presentation for `amount`
## damage in `color` (element-colored per D-02, white for non-elemental). Safe to call
## repeatedly on a pooled/reused instance — kills any in-flight tween first.
func show_number(amount: int, color: Color) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()

	var font := UiStyle.button_font()
	if font:
		add_theme_font_override("font", font)
	# D-03: continuous font-size ramp with damage magnitude (UI-SPEC formula).
	var font_size := int(clampf(18.0 + float(amount) * 0.55, 18.0, 40.0))
	add_theme_font_size_override("font_size", font_size)
	add_theme_color_override("font_color", color)
	add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	add_theme_constant_override("outline_size", 4)

	text = str(amount)
	modulate = Color(1, 1, 1, 1)
	scale = Vector2(1.0, 1.0)
	visible = true

	var start_pos := position
	var jitter := randf_range(-JITTER_RANGE, JITTER_RANGE)
	var end_pos := start_pos + Vector2(jitter, -FLOAT_DISTANCE)

	_tween = create_tween()
	_tween.set_parallel(true)
	# Punch-scale pop: 1.0 -> 1.2 -> 1.0 over the first ~0.1s (UI-SPEC).
	_tween.tween_property(self, "scale", Vector2(1.2, 1.2), POP_DURATION * 0.5) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", Vector2(1.0, 1.0), POP_DURATION * 0.5) \
		.set_delay(POP_DURATION * 0.5)
	# Float upward over the full lifetime.
	_tween.tween_property(self, "position", end_pos, FLOAT_DURATION)
	# Fade out over the final ~0.2s.
	_tween.tween_property(self, "modulate:a", 0.0, FADE_DURATION) \
		.set_delay(FLOAT_DURATION - FADE_DURATION)
	_tween.chain().tween_callback(_on_presentation_finished)

func _on_presentation_finished() -> void:
	visible = false
