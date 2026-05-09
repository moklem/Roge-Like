extends Area2D
## XP orb pickup — spawned by Game.gd when enemy dies (CMBT-08).
## Collection is host-authoritative (CMBT-09, D-16).
## Pitfall 5: _collected flag prevents double-collection race condition.

var _collected: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("players"):
		return
	# Only the peer who physically stepped on the orb sends the request
	# (body_entered fires on all peers; peer_id check prevents duplicate RPCs)
	if body.peer_id != multiplayer.get_unique_id():
		return
	if multiplayer.is_server():
		# Host calls directly — call_remote rpc_id(1) from peer 1 to itself is a no-op in Godot 4
		_request_collect(name)
	else:
		_request_collect.rpc_id(1, name)

@rpc("any_peer", "call_remote", "reliable")
func _request_collect(_orb_name: String) -> void:
	# Runs on host only — validate then despawn
	if not multiplayer.is_server():
		return
	if _collected:
		return  # Pitfall 5: already collected by another player
	_collected = true
	# CMBT-09: queue_free on host propagates to all clients via MultiplayerSpawner (PickupSpawner)
	queue_free()
