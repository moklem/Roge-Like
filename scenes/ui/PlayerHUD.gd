extends CanvasLayer
## Phase 6 (XP-01, XP-09, D-18): Per-player XP / Level / Stage HUD strip.
## Local CanvasLayer — shown only on the owning peer's screen.

func _ready() -> void:
	# D-18: only show on the owning peer's screen.
	# Authority is assigned in Player._ready() via set_multiplayer_authority(peer_id), which runs
	# AFTER this child's _ready(). Reading it here would still see the default authority (the host),
	# hiding a client's own bar and showing every bar on the host. Defer so we read the final value.
	call_deferred("_apply_visibility")
	_apply_comic_style()

## Comic UI pass: paper panel with ink border, comic font on the labels, outlined XP bar.
func _apply_comic_style() -> void:
	var panel: Panel = get_node_or_null("HUDPanel")
	if panel:
		panel.add_theme_stylebox_override("panel", UiStyle.comic_box(
			Color(UiStyle.PAPER.r, UiStyle.PAPER.g, UiStyle.PAPER.b, 0.95)))
	var f := UiStyle.button_font()
	for n in ["HUDPanel/HUDRow/LevelLabel", "HUDPanel/HUDRow/StageLabel"]:
		var lbl: Label = get_node_or_null(n)
		if lbl:
			if f:
				lbl.add_theme_font_override("font", f)
			lbl.add_theme_font_size_override("font_size", 18)
			lbl.add_theme_color_override("font_color", UiStyle.INK)
	# XP fill in comic yellow-orange — pops against the paper panel.
	UiStyle.style_world_bar(get_node_or_null("HUDPanel/HUDRow/XPBar"), Color(1.0, 0.75, 0.15))

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
		lvl.text = "TEAM LVL %d" % level_value      # TEAM XP: shared level for the whole party
	if bar:
		bar.max_value = float(maxi(xp_threshold, 1))
		bar.value = float(xp_value)
	if stg:
		stg.text = "STG %d" % stage_value           # UI-SPEC copywriting
		# StageLabel color override per stage (UI-SPEC §StageLabel Color Override),
		# darkened to stay readable on the comic paper panel
		match stage_value:
			2: stg.add_theme_color_override("font_color", Color(0.42, 0.40, 0.45, 1))
			3: stg.add_theme_color_override("font_color", Color(0.10, 0.45, 0.85, 1))
			_: stg.add_theme_color_override("font_color", UiStyle.INK)
