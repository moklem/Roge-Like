extends Control
## Main menu — host/join screen.
## NET-03: Connection status visible (connecting / failed / success).
## Transitions to LobbyScreen on successful connection.

@onready var host_button: Button = $VBoxContainer/HostButton
@onready var join_button: Button = $VBoxContainer/JoinButton
@onready var ip_line: LineEdit = $VBoxContainer/IPLineEdit
@onready var status_label: Label = $VBoxContainer/StatusLabel

var _connect_timer: float = 0.0
var _connecting: bool = false
const CONNECT_TIMEOUT: float = 5.0

func _ready() -> void:
	# Artstyle: background image + Transformers title font + Sharpshooter button font.
	UiStyle.add_background(self)
	UiStyle.style_title($VBoxContainer/TitleLabel)
	UiStyle.style_buttons(self)
	UiStyle.style_labels(self)

	# Quiet background music before the game starts (continues into the lobby).
	Music.play_lobby()

	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	Lobby.connection_failed.connect(_on_connection_failed)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	# Also listen for peer_connected on client side (more reliable than connected_to_server)
	multiplayer.peer_connected.connect(_on_peer_connected)

func _process(delta: float) -> void:
	if _connecting:
		_connect_timer += delta
		if _connect_timer >= CONNECT_TIMEOUT:
			_on_connection_failed()

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
	_connect_timer = 0.0
	_connecting = true
	Lobby.join_game(ip)

func _on_connected_to_server() -> void:
	_connecting = false
	# NET-03: connection successful
	status_label.text = "Connected!"
	get_tree().change_scene_to_file("res://scenes/ui/LobbyScreen.tscn")

func _on_peer_connected(_id: int) -> void:
	# Fallback: if connected_to_server didn't fire but peer_connected did
	if _connecting:
		_on_connected_to_server()

func _on_connection_failed() -> void:
	_connecting = false
	# NET-03: connection failed — show error + re-enable buttons
	status_label.text = "Connection failed. Check IP and try again."
	host_button.disabled = false
	join_button.disabled = false
