extends CanvasLayer
## Tab-Stats-HUD — local per-peer overlay. HOLD Tab to view the owning player's live,
## card-driven stats (role, element, level/stage, HP, speed, damage, cooldown, weapons).
## Never synced, never pauses the tree (mirrors CardOverlay). CanvasLayer.layer = 5 so it
## renders above CarHUD (3) and the Juice vignette (4) but below the ESC PauseMenu (6).
## Reads the local Player node fresh each frame while shown — no signals, no RPC.
##
## Lives bottom-left, the same screen home as the small HP card (Game.gd hides that card
## while Tab is held). Content is built in code as three color-coded groups with ink
## separator lines: CHARAKTER (blue) / KAMPFWERTE (red) / WAFFEN (purple).

@onready var _panel: PanelContainer = $StatsPanel
@onready var _title: Label = $StatsPanel/Margin/StatsBox/TitleLabel
@onready var _box: VBoxContainer = $StatsPanel/Margin/StatsBox

## Weapon id → display name (mirrors CardOverlay.WEAPON_NAMES).
const WEAPON_NAMES := {
	"screws_and_bolts": "Screws & Bolts",
	"exhaust_flames": "Exhaust Flames",
	"spinning_tires": "Spinning Tires",
	"antenna_beam": "Antenna Beam",
	"horn_shockwave": "Horn Shockwave",
}

## Group header colors — dark enough to read on the comic paper panel.
const COL_CHARACTER := Color(0.10, 0.45, 0.85)   # blue
const COL_COMBAT    := Color(0.78, 0.12, 0.10)   # red
const COL_WEAPONS   := Color(0.45, 0.18, 0.70)   # purple
## Per-stat value colors inside KAMPFWERTE.
const COL_HP        := Color(0.05, 0.55, 0.20)
const COL_SPEED     := Color(0.10, 0.45, 0.85)
const COL_DAMAGE    := Color(0.78, 0.12, 0.10)
const COL_COOLDOWN  := Color(0.80, 0.45, 0.02)
## Element → [German display name, color] for the CHARAKTER group's element row.
const ELEMENT_DISPLAY := {
	"Fire":  ["Feuer 🔥", Color(0.85, 0.30, 0.05)],
	"Ice":   ["Eis ❄️", Color(0.15, 0.55, 0.85)],
	"Earth": ["Erde 🌿", Color(0.15, 0.55, 0.20)],
}

## Value labels updated live in _refresh(), keyed by stat id.
var _values: Dictionary = {}
## Weapon list labels container (rows rebuilt only when the loadout signature changes).
var _weapons_box: VBoxContainer = null
var _weapons_signature: String = ""

func _ready() -> void:
	_build_rows()
	_apply_comic_style()
	visible = false  # hidden until Tab is held

## Static row structure: group headers, name/value rows, ink separators. Values start
## empty and are filled per-frame by _refresh().
func _build_rows() -> void:
	_add_header("CHARAKTER", COL_CHARACTER)
	_add_row("role", "Rolle", UiStyle.INK)
	_add_row("element", "Element", UiStyle.INK)
	_add_row("level", "Team-Level", UiStyle.INK)
	_add_row("stage", "Stufe", UiStyle.INK)
	_add_separator()
	_add_header("KAMPFWERTE", COL_COMBAT)
	_add_row("hp", "HP", COL_HP)
	_add_row("speed", "Speed", COL_SPEED)
	_add_row("damage", "Damage", COL_DAMAGE)
	_add_row("cooldown", "Cooldown", COL_COOLDOWN)
	_add_separator()
	_add_header("WAFFEN", COL_WEAPONS)
	_weapons_box = VBoxContainer.new()
	_weapons_box.add_theme_constant_override("separation", 2)
	_box.add_child(_weapons_box)

func _add_header(text: String, color: Color) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_font_size_override("font_size", 15)
	var f := UiStyle.button_font()
	if f:
		lbl.add_theme_font_override("font", f)
	_box.add_child(lbl)

## Name left in ink, value right-aligned in the stat's accent color.
func _add_row(id: String, label_text: String, value_color: Color) -> void:
	var row := HBoxContainer.new()
	var f := UiStyle.button_font()
	var name_lbl := Label.new()
	name_lbl.text = label_text
	name_lbl.add_theme_color_override("font_color", Color(UiStyle.INK.r, UiStyle.INK.g, UiStyle.INK.b, 0.75))
	name_lbl.add_theme_font_size_override("font_size", 16)
	if f:
		name_lbl.add_theme_font_override("font", f)
	var value_lbl := Label.new()
	value_lbl.text = "—"
	value_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_lbl.add_theme_color_override("font_color", value_color)
	value_lbl.add_theme_font_size_override("font_size", 16)
	if f:
		value_lbl.add_theme_font_override("font", f)
	row.add_child(name_lbl)
	row.add_child(value_lbl)
	_box.add_child(row)
	_values[id] = value_lbl

## Thin ink line between groups (comic style, matches the panel border).
func _add_separator() -> void:
	var line := ColorRect.new()
	line.color = Color(UiStyle.INK.r, UiStyle.INK.g, UiStyle.INK.b, 0.85)
	line.custom_minimum_size = Vector2(0, 2)
	_box.add_child(line)

## Comic paper panel + comic font (matches CarHUD / PlayerHUD). Slightly translucent so the
## fight behind it still reads during the quick hold-to-view glance.
func _apply_comic_style() -> void:
	if _panel:
		_panel.add_theme_stylebox_override("panel", UiStyle.comic_box(
			Color(UiStyle.PAPER.r, UiStyle.PAPER.g, UiStyle.PAPER.b, 0.93)))
	if _title:
		var f := UiStyle.button_font()
		if f:
			_title.add_theme_font_override("font", f)
		_title.add_theme_font_size_override("font_size", 22)
		_title.add_theme_color_override("font_color", UiStyle.INK)

func _process(_delta: float) -> void:
	# Hold-to-view: visible exactly while Tab is down; refresh live only while shown.
	var held: bool = Input.is_action_pressed("stats")
	if held != visible:
		visible = held
	if visible:
		_refresh()

func _refresh() -> void:
	var p: Node = _local_player()
	if p == null:
		return
	_values["role"].text = str(p.role_label)
	var elem_info: Array = ELEMENT_DISPLAY.get(str(p.element), ["—", UiStyle.INK])
	_values["element"].text = "%s  T%d/3" % [elem_info[0], int(p.element_tier)]
	_values["element"].add_theme_color_override("font_color", elem_info[1])
	_values["level"].text = "%d" % GameState.team_level
	_values["stage"].text = "%d / 3" % int(p.evolution_stage)
	_values["hp"].text = "%d / %d" % [int(p.health), int(p.MAX_HP)]
	_values["speed"].text = "%d" % int(p.SPEED)
	_values["damage"].text = "×%.2f" % float(p.stage3_damage_mult)
	var cd_reduction: int = int(round((1.0 - float(p.cooldown_mult)) * 100.0))
	_values["cooldown"].text = "-%d%%" % cd_reduction
	_refresh_weapons(p)

## Weapon rows rebuild only when the loadout (ids + levels) actually changes.
func _refresh_weapons(p: Node) -> void:
	var wm: Node = p.get_node_or_null("WeaponManager")
	var entries: Array = []
	if wm != null:
		for wid in wm.unlocked_weapons:
			entries.append([str(wid), int(wm.weapon_level.get(wid, 1))])
	var signature: String = str(entries)
	if signature == _weapons_signature:
		return
	_weapons_signature = signature
	for child in _weapons_box.get_children():
		child.queue_free()
	var f := UiStyle.button_font()
	if entries.is_empty():
		var lbl := Label.new()
		lbl.text = "—"
		lbl.add_theme_color_override("font_color", Color(UiStyle.INK.r, UiStyle.INK.g, UiStyle.INK.b, 0.6))
		lbl.add_theme_font_size_override("font_size", 15)
		if f:
			lbl.add_theme_font_override("font", f)
		_weapons_box.add_child(lbl)
		return
	for entry in entries:
		var lbl := Label.new()
		lbl.text = "• %s  Lv.%d" % [WEAPON_NAMES.get(entry[0], entry[0]), entry[1]]
		lbl.add_theme_color_override("font_color", COL_WEAPONS)
		lbl.add_theme_font_size_override("font_size", 15)
		if f:
			lbl.add_theme_font_override("font", f)
		_weapons_box.add_child(lbl)

## The owning-peer's Player node (the one this screen belongs to).
func _local_player() -> Node:
	var local_id: int = multiplayer.get_unique_id()
	for pl in get_tree().get_nodes_in_group("players"):
		if pl.peer_id == local_id:
			return pl
	return null
