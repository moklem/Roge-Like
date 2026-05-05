extends Control
## Game over screen — shown when host disconnects or team wipes.
## D-04: Auto-returns to main menu after short delay.

@onready var return_button: Button = $VBoxContainer/ReturnButton

func _ready() -> void:
	return_button.pressed.connect(_on_return_pressed)
	# D-04: auto-return after ~2 seconds
	await get_tree().create_timer(2.0).timeout
	_on_return_pressed()

func _on_return_pressed() -> void:
	Lobby.remove_multiplayer_peer()
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
