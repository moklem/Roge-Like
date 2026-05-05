extends Node
## Lobby autoload — manages ENet peer creation, player registry, and disconnect handling.
## D-10: Port 7000 hardcoded. D-13: Host is always peer 1.
## D-16/P9: peer_disconnected wired in _ready() — host disconnect triggers scene change.

const PORT: int = 7000
const MAX_CLIENTS: int = 2

# peer_id → {name: String, role: String, element: String, ready: bool}
var players: Dictionary = {}

func _ready() -> void:
	# D-16 / P9: wire peer lifecycle signals BEFORE any scene loads
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func create_game() -> void:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, MAX_CLIENTS)
	if err != OK:
		push_error("Lobby: failed to create server: %s" % error_string(err))
		connection_failed.emit()
		return
	multiplayer.multiplayer_peer = peer
	# D-13: register host in players dict (host is always peer 1)
	players[1] = {name = "Player", role = "", element = "", ready = false}
	print("Lobby: server created on port %d" % PORT)

func join_game(ip: String) -> void:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, PORT)
	if err != OK:
		push_error("Lobby: failed to join %s:%d — %s" % [ip, PORT, error_string(err)])
		connection_failed.emit()
		return
	multiplayer.multiplayer_peer = peer
	print("Lobby: connecting to %s:%d" % [ip, PORT])

func remove_multiplayer_peer() -> void:
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	players.clear()

func _on_peer_connected(id: int) -> void:
	# P2: register new peer and send current state (not in _ready)
	if not players.has(id):
		players[id] = {name = "Player", role = "", element = "", ready = false}
	_sync_player_list_to.rpc_id(id, players)
	player_list_changed.emit()
	player_list_changed.emit()

func _on_peer_disconnected(id: int) -> void:
	players.erase(id)
	# D-16 / P9: if host (id==1) disconnected, all clients return to main menu
	if id == 1:
		get_tree().change_scene_to_file("res://scenes/ui/GameOver.tscn")
	else:
		player_list_changed.emit()

func _on_server_disconnected() -> void:
	# Called on client when host disappears (fires before peer_disconnected)
	get_tree().change_scene_to_file("res://scenes/ui/GameOver.tscn")

# D-14/P1: All @rpc functions have IDENTICAL annotation + signature on both host and client.
# This autoload is always loaded at the same NodePath on every peer.

@rpc("any_peer", "call_remote", "reliable")
func _sync_player_list_to(list: Dictionary) -> void:
	# Called from host to a specific newly connected peer
	players = list
	player_list_changed.emit()

@rpc("authority", "call_local", "reliable")
func notify_player_updated(id: int, data: Dictionary) -> void:
	players[id] = data
	player_list_changed.emit()

@rpc("authority", "call_local", "reliable")
func notify_game_starting() -> void:
	game_starting.emit()

signal player_list_changed()
signal connection_failed()
signal game_starting()

func get_local_ip() -> String:
	# Returns the most likely LAN IP for display (NET-01)
	for addr in IP.get_local_addresses():
		if addr.begins_with("192.168.") or addr.begins_with("10.") or addr.begins_with("172."):
			return addr
	return "127.0.0.1"

func all_players_ready() -> bool:
	if players.is_empty():
		return false
	for id in players:
		if not players[id].get("ready", false):
			return false
	return true

# D-14/P1: All @rpc annotations IDENTICAL on both peers.
# "any_peer" + "call_local" = any peer can call it, also runs locally on caller.

@rpc("any_peer", "call_local", "reliable")
func set_player_role(role: String) -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	if sender == 0:
		sender = multiplayer.get_unique_id()
	# Validate: role must not be taken by another peer
	for id in players:
		if id != sender and players[id].get("role", "") == role:
			return  # role already taken, silently ignore
	if not players.has(sender):
		players[sender] = {name = "Player", role = "", element = "", ready = false}
	players[sender]["role"] = role
	players[sender]["name"] = role  # D-05: role IS the identity
	players[sender]["ready"] = false  # D-02: picking resets ready
	player_list_changed.emit()

@rpc("any_peer", "call_local", "reliable")
func set_player_element(element: String) -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	if sender == 0:
		sender = multiplayer.get_unique_id()
	if not players.has(sender):
		players[sender] = {name = "Player", role = "", element = "", ready = false}
	players[sender]["element"] = element
	players[sender]["ready"] = false  # D-02: picking resets ready
	player_list_changed.emit()

@rpc("any_peer", "call_local", "reliable")
func set_player_ready(is_ready: bool) -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	if sender == 0:
		sender = multiplayer.get_unique_id()
	if not players.has(sender):
		return
	# D-02: can only ready if role AND element are chosen
	if is_ready:
		var p: Dictionary = players[sender]
		if p.get("role", "").is_empty() or p.get("element", "").is_empty():
			return  # can't ready without both picks
	players[sender]["ready"] = is_ready
	player_list_changed.emit()

@rpc("authority", "call_local", "reliable")
func start_game() -> void:
	get_tree().change_scene_to_file("res://scenes/Game.tscn")
