extends Control
## LobbyScreen — role + element pick, ready-up, player list panel.
## D-07: Single screen, role top, element bottom.
## D-08: Taken roles grayed out with "Taken" label.
## D-09: Live player list panel on right.

@onready var ip_label: Label = $HBoxContainer/LeftPanel/IPLabel
@onready var tank_btn: Button = $HBoxContainer/LeftPanel/RoleButtons/TankButton
@onready var speedster_btn: Button = $HBoxContainer/LeftPanel/RoleButtons/SpeedsterButton
@onready var engineer_btn: Button = $HBoxContainer/LeftPanel/RoleButtons/EngineerButton
@onready var fire_btn: Button = $HBoxContainer/LeftPanel/ElementButtons/FireButton
@onready var ice_btn: Button = $HBoxContainer/LeftPanel/ElementButtons/IceButton
@onready var earth_btn: Button = $HBoxContainer/LeftPanel/ElementButtons/EarthButton
@onready var ready_btn: Button = $HBoxContainer/LeftPanel/ReadyButton
@onready var start_btn: Button = $HBoxContainer/LeftPanel/StartButton
@onready var status_label: Label = $HBoxContainer/LeftPanel/StatusLabel
@onready var player_list: VBoxContainer = $HBoxContainer/PlayerListPanel/PlayerList

var _is_ready: bool = false
var _is_host: bool = false

func _ready() -> void:
	_is_host = multiplayer.is_server()

	# NET-01: display host IP prominently
	if _is_host:
		ip_label.text = "Your IP: %s" % Lobby.get_local_ip()
		start_btn.visible = true
	else:
		ip_label.text = "Connected to host"

	# Wire role buttons
	tank_btn.pressed.connect(_on_role_pressed.bind("Tank"))
	speedster_btn.pressed.connect(_on_role_pressed.bind("Speedster"))
	engineer_btn.pressed.connect(_on_role_pressed.bind("Engineer"))

	# Wire element buttons
	fire_btn.pressed.connect(_on_element_pressed.bind("Fire"))
	ice_btn.pressed.connect(_on_element_pressed.bind("Ice"))
	earth_btn.pressed.connect(_on_element_pressed.bind("Earth"))

	ready_btn.pressed.connect(_on_ready_pressed)
	start_btn.pressed.connect(_on_start_pressed)

	# Listen to lobby changes
	Lobby.player_list_changed.connect(_refresh_ui)
	_refresh_ui()

func _on_role_pressed(role: String) -> void:
	if _is_ready:
		return  # D-02: locked when ready
	# Check if role is taken by someone else
	var my_id: int = multiplayer.get_unique_id()
	for id in Lobby.players:
		if id != my_id and Lobby.players[id].get("role", "") == role:
			return  # D-08: taken, do nothing
	Lobby.set_player_role.rpc(role)

func _on_element_pressed(element: String) -> void:
	if _is_ready:
		return  # D-02: locked when ready
	Lobby.set_player_element.rpc(element)

func _on_ready_pressed() -> void:
	_is_ready = !_is_ready
	Lobby.set_player_ready.rpc(_is_ready)
	ready_btn.text = "Un-Ready" if _is_ready else "Ready"
	_set_picks_disabled(_is_ready)

func _on_start_pressed() -> void:
	if not _is_host:
		return
	if not Lobby.all_players_ready():
		status_label.text = "Waiting for all players to ready up..."
		return
	Lobby.start_game.rpc()

func _set_picks_disabled(disabled: bool) -> void:
	# D-02: lock/unlock role and element buttons
	for btn in [tank_btn, speedster_btn, engineer_btn,
				fire_btn, ice_btn, earth_btn]:
		if not btn.disabled:  # don't re-enable Taken buttons
			btn.disabled = disabled

func _refresh_ui() -> void:
	var my_id: int = multiplayer.get_unique_id()
	var my_data: Dictionary = Lobby.players.get(my_id, {})
	var my_role: String = my_data.get("role", "")

	# Update role buttons — D-08: taken by others = grayed + "Taken"
	var role_map: Dictionary = {
		"Tank": tank_btn,
		"Speedster": speedster_btn,
		"Engineer": engineer_btn
	}
	for role in role_map:
		var btn: Button = role_map[role]
		var taken_by_other: bool = false
		for id in Lobby.players:
			if id != my_id and Lobby.players[id].get("role", "") == role:
				taken_by_other = true
				break
		if taken_by_other:
			btn.text = "Taken"
			btn.disabled = true
		else:
			btn.text = role
			if not _is_ready:
				btn.disabled = false
		# Highlight current selection
		btn.modulate = Color(1, 1, 0.5) if my_role == role else Color(1, 1, 1)

	# Update element buttons — highlight selection
	var element_map: Dictionary = {
		"Fire": fire_btn, "Ice": ice_btn, "Earth": earth_btn
	}
	var my_element: String = my_data.get("element", "")
	for elem in element_map:
		var btn: Button = element_map[elem]
		btn.modulate = Color(1, 1, 0.5) if my_element == elem else Color(1, 1, 1)

	# Update Start button (host only) — D-01: only when all ready
	if _is_host:
		start_btn.disabled = not Lobby.all_players_ready()
		status_label.text = "All ready!" if Lobby.all_players_ready() else ""

	# Rebuild player list panel — D-09
	for child in player_list.get_children():
		child.queue_free()
	for id in Lobby.players:
		var data: Dictionary = Lobby.players[id]
		var role_str: String = data.get("role", "Player")  # D-06: "Player" placeholder
		var elem_str: String = data.get("element", "—")
		var ready_str: String = "✓" if data.get("ready", false) else "·"
		var row: Label = Label.new()
		row.text = "%s  %s  %s" % [role_str, elem_str, ready_str]
		player_list.add_child(row)
