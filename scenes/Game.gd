extends Node2D
## Game scene controller — spawns players, manages room lifecycle.
## P7: spawn_function used instead of add_spawnable_scene so peer_id data
##     is passed to ALL peers at spawn time (clients get correct authority).
## P3: Only host calls spawner.spawn(); clients receive via replication.

const PLAYER_SCENE := preload("res://scenes/Player.tscn")

func _ready() -> void:
	# P7: custom spawn_function — replaces add_spawnable_scene so the spawn
	# data Dictionary (id, role, pos) is forwarded to every peer automatically.
	$MultiplayerSpawner.spawn_function = _do_spawn

	if multiplayer.is_server():
		_spawn_all_players()

func _spawn_all_players() -> void:
	var spawn_points := $Room1/SpawnPoints.get_children()
	var idx := 0
	for id in Lobby.players:
		var spawn_pos := Vector2(400, 300)
		if idx < spawn_points.size():
			spawn_pos = spawn_points[idx].global_position
		# spawner.spawn(data) calls _do_spawn(data) on HOST AND all CLIENTS
		$MultiplayerSpawner.spawn({
			"id": id,
			"role": Lobby.players.get(id, {}).get("role", "Player"),
			"pos": spawn_pos,
		})
		idx += 1

## Called on every peer by the MultiplayerSpawner with identical data.
## Returns the node to add — peer_id is set correctly everywhere.
func _do_spawn(data: Dictionary) -> Node:
	var player := PLAYER_SCENE.instantiate()
	player.peer_id    = data["id"]
	player.role_label = data["role"]
	player.position   = data["pos"]
	player.name       = "Player_%d" % data["id"]
	return player
