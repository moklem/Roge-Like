extends CanvasLayer
## Phase 6 (XP-02, XP-03, D-06/D-08/D-09): 3-card level-up selection overlay.
## Local CanvasLayer — no SceneTree.paused (W4). Driven by Player.gd.

var _cards: Array = []
var _selected: int = 0

const WEAPON_NAMES := {
	"screws_and_bolts": "Screws & Bolts",
	"exhaust_flames": "Exhaust Flames",
	"spinning_tires": "Spinning Tires",
	"antenna_beam": "Antenna Beam",
	"horn_shockwave": "Horn Shockwave",
	"airbag_shield": "Airbag Shield",
}

func show_cards(cards: Array) -> void:
	_cards = cards
	_selected = 0
	_refresh_display()
	visible = true

func hide_overlay() -> void:
	visible = false
	_cards = []

func navigate(direction: int) -> void:
	if _cards.is_empty():
		return
	_selected = wrapi(_selected + direction, 0, _cards.size())
	_refresh_display()

func get_selected_index() -> int:
	return _selected

func get_selected_card() -> Dictionary:
	if _selected >= 0 and _selected < _cards.size():
		return _cards[_selected]
	return {}

func _refresh_display() -> void:
	for i in range(3):
		var card_node := get_node_or_null("OverlayBackground/OverlayContainer/CardsRow/Card%d" % i)
		var border := get_node_or_null("OverlayBackground/OverlayContainer/CardsRow/Card%d/Card%dBorder" % [i, i])
		var type_lbl := get_node_or_null("OverlayBackground/OverlayContainer/CardsRow/Card%d/Card%dBorder/Card%dInner/Card%dTypeLabel" % [i, i, i, i])
		var name_lbl := get_node_or_null("OverlayBackground/OverlayContainer/CardsRow/Card%d/Card%dBorder/Card%dInner/Card%dNameLabel" % [i, i, i, i])
		var desc_lbl := get_node_or_null("OverlayBackground/OverlayContainer/CardsRow/Card%d/Card%dBorder/Card%dInner/Card%dDescLabel" % [i, i, i, i])
		if card_node == null:
			continue
		if i < _cards.size():
			card_node.visible = true
			if type_lbl: type_lbl.text = _card_type_text(_cards[i])
			if name_lbl: name_lbl.text = _card_name_text(_cards[i])
			if desc_lbl: desc_lbl.text = _card_desc_text(_cards[i])
		else:
			card_node.visible = false
		if border:
			border.color = Color(0.4, 1.0, 0.4, 1) if i == _selected else Color(0.35, 0.35, 0.4, 1)

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
		"stat_boost":      return "+%d%% %s" % [card.get("amount", 10), card.get("stat", "")]
		_:                 return "+10%% Damage"

func _card_desc_text(card: Dictionary) -> String:
	match card.get("type", ""):
		"weapon_unlock":   return "Unlocks %s" % WEAPON_NAMES.get(card.get("weapon_id", ""), card.get("weapon_id", ""))
		"weapon_upgrade":  return _weapon_upgrade_desc(card.get("weapon_id", ""), card.get("new_level", 2))
		"element_upgrade": return "Proc rate: %d%%" % (25 * card.get("new_tier", 2))
		"stat_boost":      return "Increases %s by %d%%" % [card.get("stat", ""), card.get("amount", 10)]
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
		["airbag_shield", 2]:    return "Absorb hit + heal to 25% HP"
		["airbag_shield", 3]:    return "2 charges"
		_:                       return "Upgrade weapon"
