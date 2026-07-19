extends CanvasLayer
## PauseMenu — in-run settings overlay, toggled with ESC.
##
## It does NOT pause anything. `SceneTree.paused` (and `Engine.time_scale`) would stop this
## peer's physics, RPC dispatch and client-side bullet simulation while every other peer kept
## running, which desyncs the session — the same hard constraint that governs Juice's hit-stop.
## So the world, the enemies and the other players carry on while this is open, and the panel
## says so out loud.
##
## What it does instead is freeze the LOCAL player's own input (Player.menu_open), because
## WASD is bound to ui_left/ui_right/ui_up/ui_down — the very actions that drive the sliders.
## Without that gate, holding A to turn the music down would also walk the character left.
##
## Everything in here is per-client and never synced (D-10), exactly like the main-menu panel.

@onready var panel: PanelContainer = $Panel
@onready var shake_cycle_button: Button = $Panel/Margin/VBox/ShakeGroup/ShakeCycleButton
@onready var music_slider: HSlider = $Panel/Margin/VBox/MusicGroup/MusicSlider
@onready var sfx_slider: HSlider = $Panel/Margin/VBox/SfxGroup/SfxSlider
@onready var resume_button: Button = $Panel/Margin/VBox/ResumeButton
@onready var quit_button: Button = $Panel/Margin/VBox/QuitButton

var _open: bool = false

func _ready() -> void:
	panel.add_theme_stylebox_override("panel", UiStyle.comic_box(UiStyle.PAPER))
	UiStyle.style_buttons(self)
	UiStyle.style_labels(self)

	shake_cycle_button.text = Settings.shake_label()
	music_slider.value = Settings.music_volume
	sfx_slider.value = Settings.sfx_volume

	shake_cycle_button.pressed.connect(_on_shake_cycle_pressed)
	music_slider.value_changed.connect(Settings.set_music_volume)
	sfx_slider.value_changed.connect(Settings.set_sfx_volume)
	resume_button.pressed.connect(close)
	quit_button.pressed.connect(_on_quit_pressed)

	_apply_open(false)

## ESC toggles. `ui_cancel` is Godot's built-in Escape binding — the project's InputMap
## overrides ui_left/right/up/down (WASD) but leaves ui_cancel at its default.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_apply_open(not _open)
		get_viewport().set_input_as_handled()

func close() -> void:
	_apply_open(false)

func _apply_open(open: bool) -> void:
	_open = open
	visible = open
	var player := _local_player()
	if player != null:
		player.menu_open = open
	if open:
		# Focus the first control so the panel is keyboard-drivable, and so a stray Space
		# (role_ability, also ui_accept) lands on a button rather than nowhere.
		resume_button.grab_focus()

## The player node this peer actually controls — the only one whose input we may freeze.
func _local_player() -> Node:
	for p in get_tree().get_nodes_in_group("players"):
		if p.is_multiplayer_authority():
			return p
	return null

func _on_shake_cycle_pressed() -> void:
	Settings.cycle_shake()
	shake_cycle_button.text = Settings.shake_label()

## Leaves the run. Drops the peer first (mirrors GameOver._on_return_pressed) so the host
## isn't left holding a half-dead connection.
func _on_quit_pressed() -> void:
	_apply_open(false)
	# Quitting mid-run skips the game-over path, so reset team XP/level/loop state
	# here too — otherwise the next run starts with the abandoned run's progression.
	GameState.reset_for_new_run()
	Lobby.remove_multiplayer_peer()
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
