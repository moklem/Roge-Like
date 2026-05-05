extends Control
## Main menu — host/join screen.
## NET-03: Connection status visible (connecting / failed / success).
## Transitions to LobbyScreen on successful connection.

@onready var host_button: Button = $VBoxContainer/HostButton
@onready var join_button: Button = $VBoxContainer/JoinButton
@onready var ip_line: LineEdit = $VBoxContainer/IPLineEdit
@onready var status_label: Label = $VBoxContainer/StatusLabel

func _ready() -> void:
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	Lobby.connection_failed.connect(_on_connection_failed)
	multiplayer.connected_to_server.connect(_on_connected_to_server)

func _on_host_pressed() -> void:
	Lobby.create_game()
	status_label.text = "Hosting on %s" % Lobby.get_local_ip()
	# D-03: Host goes to lobby immediately (solo start available)
	get_tree().change_scene_to_file("res://scenes/ui/LobbyScreen.tscn")

func _on_join_pressed() -> void:
	var ip: String = ip_line.text.strip_edges()
	if ip.is_empty():
		status_label.text = "Please enter host IP"
		return
	# NET-03: show connecting status
	status_label.text = "Connecting to %s..." % ip
	host_button.disabled = true
	join_button.disabled = true
	Lobby.join_game(ip)

func _on_connected_to_server() -> void:
	# NET-03: connection successful
	status_label.text = "Connected!"
	get_tree().change_scene_to_file("res://scenes/ui/LobbyScreen.tscn")

func _on_connection_failed() -> void:
	# NET-03: connection failed — show error + re-enable buttons
	status_label.text = "Connection failed. Check IP and try again."
	host_button.disabled = false
	join_button.disabled = false
