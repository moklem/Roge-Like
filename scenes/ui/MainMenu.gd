extends Control
## Main menu — host/join screen.
## D-03: Host sees lobby immediately, can start solo.
## D-04: Host disconnect auto-returns to this scene.

@onready var host_button: Button = $VBoxContainer/HostButton
@onready var join_button: Button = $VBoxContainer/JoinButton
@onready var ip_line: LineEdit = $VBoxContainer/IPLineEdit
@onready var status_label: Label = $VBoxContainer/StatusLabel

func _ready() -> void:
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	Lobby.connection_failed.connect(_on_connection_failed)
	Lobby.game_starting.connect(_on_game_starting)

func _on_host_pressed() -> void:
	Lobby.create_game()
	status_label.text = "Hosting on port %d" % Lobby.PORT
	# Transition to lobby screen (Phase 2 will add LobbyScreen.tscn)
	# For now, just stay on this screen with status update

func _on_join_pressed() -> void:
	var ip: String = ip_line.text.strip_edges()
	if ip.is_empty():
		status_label.text = "Please enter host IP"
		return
	status_label.text = "Connecting to %s..." % ip
	Lobby.join_game(ip)

func _on_connection_failed() -> void:
	status_label.text = "Connection failed"

func _on_game_starting() -> void:
	get_tree().change_scene_to_file("res://scenes/Game.tscn")
