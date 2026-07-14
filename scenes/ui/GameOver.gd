extends Control
## Game over screen — shown on a team wipe (all players downed) or when the host leaves.
## GameState.game_over_reason picks the wording; the run stats shown alongside it were
## snapshotted by _broadcast_game_over BEFORE GameState reset itself for the next run.

@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var message_label: Label = $VBoxContainer/MessageLabel
@onready var return_button: Button = $VBoxContainer/ReturnButton

func _ready() -> void:
	# Comic UI pass: same background/button/label styling as menu and lobby
	UiStyle.add_background(self)
	UiStyle.style_buttons(self)
	UiStyle.style_labels(self)
	_style_title()
	_apply_reason()
	return_button.pressed.connect(_on_return_pressed)
	return_button.grab_focus()
	_slam_in()

func _style_title() -> void:
	UiStyle.style_title(title_label)
	# style_title() is sized for the 240px main-menu logo. "GAME OVER" is a far wider string
	# and would run off both edges of the viewport at that size.
	title_label.add_theme_font_size_override("font_size", 120)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.26, 0.22))

func _apply_reason() -> void:
	if GameState.game_over_reason == GameState.REASON_HOST_LEFT:
		title_label.text = "HOST LEFT"
		message_label.text = "The host ended the session."
		return
	title_label.text = "GAME OVER"
	message_label.text = "Team wiped on loop %d — team level %d" % [
		GameState.final_loop, GameState.final_level,
	]

## Comic slam: the title punches in oversized and settles back to full size.
func _slam_in() -> void:
	# Wait a frame so the VBox has laid the label out — a pivot_offset taken from a
	# zero-size Control would scale it from the top-left corner instead of the centre.
	await get_tree().process_frame
	title_label.pivot_offset = title_label.size * 0.5
	title_label.scale = Vector2(2.2, 2.2)
	title_label.modulate.a = 0.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(title_label, "scale", Vector2.ONE, 0.35) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(title_label, "modulate:a", 1.0, 0.15)

func _on_return_pressed() -> void:
	Lobby.remove_multiplayer_peer()
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
