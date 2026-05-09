extends Node2D
## Game scene controller — spawns players, manages room lifecycle.
## P7: All spawnable scene types registered in MultiplayerSpawner.

const PLAYER_SCENE := preload("res://scenes/Player.tscn")

func _ready() -> void:
	# P7: Register Player scene in MultiplayerSpawner before any spawns
	var spawner := $MultiplayerSpawner
	spawner.add_spawnable_scene("res://scenes/Player.tscn")

	if multiplayer.is_server():
		# Host spawns all players — MultiplayerSpawner replicates to clients
		_spawn_all_players()
	# Clients: MultiplayerSpawner auto-creates player nodes from host spawns

func _spawn_all_players() -> void:
	var spawn_points := $Room1/SpawnPoints.get_children()
	var idx := 0

	for id in Lobby.players:
		var spawn_pos := Vector2(400, 300)  # default fallback
		if idx < spawn_points.size():
			spawn_pos = spawn_points[idx].global_position

		_spawn_player_at(id, spawn_pos)
		idx += 1

func _spawn_player_at(id: int, pos: Vector2) -> void:
	var player := PLAYER_SCENE.instantiate()
	player.position = pos
	player.peer_id = id
	player.role_label = Lobby.players.get(id, {}).get("role", "Player")
	player.name = "Player_%s" % id  # unique name for RPC path matching (P1)

	# Add to Entities — MultiplayerSpawner auto-replicates this to clients
	$Room1/Entities.add_child(player, true)  # force_readable_name = true
