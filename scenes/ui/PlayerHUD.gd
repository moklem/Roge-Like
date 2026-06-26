extends CanvasLayer
## Phase 6 (XP-01, XP-09, D-18): Per-player XP / Level / Stage HUD strip.
## Local CanvasLayer — shown only on the owning peer's screen.

func _ready() -> void:
	# D-18: only show on the owning peer's screen.
	# Authority is assigned in Player._ready() via set_multiplayer_authority(peer_id), which runs
	# AFTER this child's _ready(). Reading it here would still see the default authority (the host),
	# hiding a client's own bar and showing every bar on the host. Defer so we read the final value.
	call_deferred("_apply_visibility")

func _apply_visibility() -> void:
	var player: Node = get_parent()
	if player and player.has_method("is_multiplayer_authority"):
		visible = player.is_multiplayer_authority()

## Called by Player.gd whenever xp/level/stage changes.
func update_hud(xp_value: int, level_value: int, xp_threshold: int, stage_value: int) -> void:
	var lvl := get_node_or_null("HUDPanel/HUDRow/LevelLabel")
	var bar := get_node_or_null("HUDPanel/HUDRow/XPBar")
	var stg := get_node_or_null("HUDPanel/HUDRow/StageLabel")
	if lvl:
		lvl.text = "LVL %d" % level_value           # D-18 copywriting
	if bar:
		bar.max_value = float(maxi(xp_threshold, 1))
		bar.value = float(xp_value)
	if stg:
		stg.text = "STG %d" % stage_value           # UI-SPEC copywriting
		# StageLabel color override per stage (UI-SPEC §StageLabel Color Override)
		match stage_value:
			2: stg.add_theme_color_override("font_color", Color(0.45, 0.45, 0.45, 1))
			3: stg.add_theme_color_override("font_color", Color(0.25, 0.75, 1.0, 1))
			_: stg.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 1))
