extends CanvasLayer
## Phase 6 (XP-02, XP-03, D-06/D-08/D-09): 3-card level-up selection overlay.
## Local CanvasLayer — no SceneTree.paused (W4). Driven by Player.gd.
## Phase 10 (D-12): comic paper/ink restyle. Phase 10 (PROG-02): pop/scale-in entrance.
## Shared by BOTH the level-up card pick and the sub-room weapon-choice presentation —
## one component, restyled once, both call sites inherit the look and the pop-in.

var _cards: Array = []
var _selected: int = 0

const WEAPON_NAMES := {
	"screws_and_bolts": "Screws & Bolts",
	"exhaust_flames": "Exhaust Flames",
	"spinning_tires": "Spinning Tires",
	"antenna_beam": "Antenna Beam",
	"horn_shockwave": "Horn Shockwave",
}

## Weapon/stat icons live here; missing files fall back to icon_generic.png.
const ICON_DIR := "res://assets/active/ui/icons/"
const STAT_ICONS := {
	"Speed": "icon_stat_speed.png",
	"Max HP": "icon_stat_maxhp.png",
	"Damage": "icon_stat_damage.png",
	"Cooldown": "icon_stat_cooldown.png",  # not delivered yet — falls back to icon_generic
}

func _ready() -> void:
	_apply_comic_style()

## Comic UI pass (D-12): paper/ink comic_box on each card, Bangers font + ink text on the
## title/hint/card labels. Called once at _ready; the selected-vs-unselected accent-box
## swap itself lives in _refresh_display below (runs every navigate()/show_cards()).
func _apply_comic_style() -> void:
	var f := UiStyle.button_font()
	var title_lbl: Label = get_node_or_null("OverlayBackground/OverlayContainer/TitleLabel")
	if title_lbl:
		if f:
			title_lbl.add_theme_font_override("font", f)
		title_lbl.add_theme_font_size_override("font_size", 28)  # Heading tier
		title_lbl.add_theme_color_override("font_color", UiStyle.INK)
	var hint_lbl: Label = get_node_or_null("OverlayBackground/OverlayContainer/HintLabel")
	if hint_lbl:
		if f:
			hint_lbl.add_theme_font_override("font", f)
		hint_lbl.add_theme_color_override("font_color", UiStyle.INK)
	for i in range(3):
		var card_node: PanelContainer = get_node_or_null("OverlayBackground/OverlayContainer/CardsRow/Card%d" % i)
		var border: ColorRect = get_node_or_null("OverlayBackground/OverlayContainer/CardsRow/Card%d/Card%dBorder" % [i, i])
		var type_lbl: Label = get_node_or_null("OverlayBackground/OverlayContainer/CardsRow/Card%d/Card%dBorder/Card%dInner/Card%dTypeLabel" % [i, i, i, i])
		var name_lbl: Label = get_node_or_null("OverlayBackground/OverlayContainer/CardsRow/Card%d/Card%dBorder/Card%dInner/Card%dNameLabel" % [i, i, i, i])
		var desc_lbl: Label = get_node_or_null("OverlayBackground/OverlayContainer/CardsRow/Card%d/Card%dBorder/Card%dInner/Card%dDescLabel" % [i, i, i, i])
		if card_node:
			card_node.add_theme_stylebox_override("panel", UiStyle.comic_box(UiStyle.PAPER))
		if border:
			# The comic_box stylebox on the PanelContainer above now draws the paper
			# background + ink border + shadow; the old flat-color ColorRect goes
			# transparent so it no longer paints over it. Selection swap moves to the
			# PanelContainer's "panel" stylebox override in _refresh_display.
			border.color = Color(0, 0, 0, 0)
		for lbl in [type_lbl, name_lbl, desc_lbl]:
			if lbl:
				if f:
					lbl.add_theme_font_override("font", f)
				lbl.add_theme_color_override("font_color", UiStyle.INK)
		if desc_lbl:
			desc_lbl.add_theme_font_size_override("font_size", 16)  # Body tier (was 12px)

## Optional title lets the sub-room weapon choice reuse this overlay with its own heading.
func show_cards(cards: Array, title: String = "LEVEL UP — PICK A CARD") -> void:
	_cards = cards
	_selected = 0
	var title_lbl := get_node_or_null("OverlayBackground/OverlayContainer/TitleLabel")
	if title_lbl:
		title_lbl.text = title
	_refresh_display()
	_play_pop_in()

## PROG-02/D-12: pop/scale-in entrance — local CanvasLayer Tween only, never a tree pause,
## no RPC. Both card-pick call sites (level-up + sub-room weapon choice) share this since
## they both call the single show_cards() above.
func _play_pop_in() -> void:
	var bg: ColorRect = get_node_or_null("OverlayBackground")
	var container: Control = get_node_or_null("OverlayBackground/OverlayContainer")
	if bg:
		bg.color.a = 0.0
	if container:
		container.pivot_offset = container.size * 0.5
		container.scale = Vector2(0.7, 0.7)
	visible = true
	var tween := create_tween()
	if bg:
		tween.tween_property(bg, "color:a", 0.55, 0.15)
	if container:
		tween.parallel().tween_property(container, "scale", Vector2(1.05, 1.05), 0.18) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(container, "scale", Vector2.ONE, 0.07) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func hide_overlay() -> void:
	visible = false
	_cards = []
	# Reset to resting values so the next show_cards() re-triggers a clean pop-in.
	var bg: ColorRect = get_node_or_null("OverlayBackground")
	var container: Control = get_node_or_null("OverlayBackground/OverlayContainer")
	if bg:
		bg.color.a = 0.55
	if container:
		container.scale = Vector2.ONE

func navigate(direction: int) -> void:
	if _cards.is_empty():
		return
	_selected = wrapi(_selected + direction, 0, _cards.size())
	_refresh_display()
	Sfx.play("ui_navigate")

func get_selected_index() -> int:
	return _selected

func get_selected_card() -> Dictionary:
	if _selected >= 0 and _selected < _cards.size():
		return _cards[_selected]
	return {}

func _refresh_display() -> void:
	for i in range(3):
		var card_node := get_node_or_null("OverlayBackground/OverlayContainer/CardsRow/Card%d" % i)
		var type_lbl := get_node_or_null("OverlayBackground/OverlayContainer/CardsRow/Card%d/Card%dBorder/Card%dInner/Card%dTypeLabel" % [i, i, i, i])
		var name_lbl := get_node_or_null("OverlayBackground/OverlayContainer/CardsRow/Card%d/Card%dBorder/Card%dInner/Card%dNameLabel" % [i, i, i, i])
		var icon_rect := get_node_or_null("OverlayBackground/OverlayContainer/CardsRow/Card%d/Card%dBorder/Card%dInner/Card%dIcon" % [i, i, i, i])
		var desc_lbl := get_node_or_null("OverlayBackground/OverlayContainer/CardsRow/Card%d/Card%dBorder/Card%dInner/Card%dDescLabel" % [i, i, i, i])
		if card_node == null:
			continue
		if i < _cards.size():
			card_node.visible = true
			if type_lbl: type_lbl.text = _card_type_text(_cards[i])
			if name_lbl: name_lbl.text = _card_name_text(_cards[i])
			if icon_rect: icon_rect.texture = _card_icon(_cards[i])
			if desc_lbl: desc_lbl.text = _card_desc_text(_cards[i])
		else:
			card_node.visible = false
		# D-12: accent comic_box marks the selected card; unselected cards stay plain paper.
		card_node.add_theme_stylebox_override("panel",
			UiStyle.comic_box(Color(1.0, 0.84, 0.25)) if i == _selected else UiStyle.comic_box(UiStyle.PAPER))

func _card_icon(card: Dictionary) -> Texture2D:
	var file := "icon_generic.png"
	match card.get("type", ""):
		"weapon_unlock", "weapon_upgrade":
			file = "icon_%s.png" % card.get("weapon_id", "")
		"element_upgrade":
			file = "icon_element.png"
		"stat_boost":
			file = STAT_ICONS.get(card.get("stat", ""), "icon_generic.png")
	var path := ICON_DIR + file
	if not ResourceLoader.exists(path):
		path = ICON_DIR + "icon_generic.png"
	return load(path)

func _card_type_text(card: Dictionary) -> String:
	match card.get("type", ""):
		"weapon_unlock":   return "New Weapon"
		"weapon_upgrade":  return "Upgrade"
		"element_upgrade": return "Element Boost"
		"stat_boost":      return "Stat Boost"
		_:                 return "Damage Boost"

func _card_name_text(card: Dictionary) -> String:
	match card.get("type", ""):
		"weapon_unlock":   return WEAPON_NAMES.get(card.get("weapon_id", ""), card.get("weapon_id", ""))
		"weapon_upgrade":  return "%s Lv%d" % [WEAPON_NAMES.get(card.get("weapon_id", ""), card.get("weapon_id", "")), card.get("new_level", 2)]
		"element_upgrade": return "Tier %d" % card.get("new_tier", 2)
		"stat_boost":
			# Cooldown is a reduction — "+10% Cooldown" would read as a downgrade
			if card.get("stat", "") == "Cooldown":
				return "-%d%% Cooldown" % card.get("amount", 10)
			return "+%d%% %s" % [card.get("amount", 10), card.get("stat", "")]
		_:                 return "+10%% Damage"

func _card_desc_text(card: Dictionary) -> String:
	match card.get("type", ""):
		"weapon_unlock":   return "Unlocks %s" % WEAPON_NAMES.get(card.get("weapon_id", ""), card.get("weapon_id", ""))
		"weapon_upgrade":  return _weapon_upgrade_desc(card.get("weapon_id", ""), card.get("new_level", 2))
		"element_upgrade": return "Proc rate: %d%%" % (25 * card.get("new_tier", 2))
		"stat_boost":
			if card.get("stat", "") == "Cooldown":
				return "Weapons & ability fire %d%% faster" % card.get("amount", 10)
			return "Increases %s by %d%%" % [card.get("stat", ""), card.get("amount", 10)]
		_:                 return "+10% all damage"

func _weapon_upgrade_desc(wid: String, lvl: int) -> String:
	match [wid, lvl]:
		["screws_and_bolts", 2]: return "2 bolts, +-15 deg spread"
		["screws_and_bolts", 3]: return "3 bolts, faster cooldown"
		["exhaust_flames", 2]:   return "Wider cone, longer range"
		["exhaust_flames", 3]:   return "120 deg cone, slows enemies"
		["spinning_tires", 2]:   return "4th orbit, +25% spin speed"
		["spinning_tires", 3]:   return "5 orbits, +6 dmg per tick"
		["antenna_beam", 2]:     return "Fires twice per activation"
		["antenna_beam", 3]:     return "+10 damage, wider hitbox"
		["horn_shockwave", 2]:   return "Wider radius, faster cooldown"
		["horn_shockwave", 3]:   return "Double knockback, brief stun"
		_:                       return "Upgrade weapon"
