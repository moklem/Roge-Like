extends Area2D
## XP orb pickup — spawned by Game.gd when enemy dies (CMBT-08).

const PLAYER_SCRIPT = preload("res://scenes/Player.gd")
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
	# Phase 6 (XP-01, D-01): grant XP to the collecting player.
	# sender_id == 0 means the host player collected directly (not via RPC) → host peer.
	var collector_peer_id: int = multiplayer.get_remote_sender_id()
	if collector_peer_id == 0:
		collector_peer_id = multiplayer.get_unique_id()  # host collected its own orb
	# D-19: scale XP from Phase 6 base (Player.XP_PER_ORB = 15) by loop_number.
	# Loop 1 = 15 XP (unchanged), loop 2 ≈ 19 XP, loop 3 ≈ 23 XP (planner discretion per RESEARCH.md Open Q3).
	var xp_amount: int = roundi(float(PLAYER_SCRIPT.XP_PER_ORB) * (1.0 + (GameState.loop_number - 1) * 0.25))
	for p in get_tree().get_nodes_in_group("players"):
		if p.peer_id == collector_peer_id:
			if collector_peer_id == multiplayer.get_unique_id():
				p.receive_xp(xp_amount)  # host-local, no RPC
			else:
				p.receive_xp.rpc_id(collector_peer_id, xp_amount)
			break
	# CMBT-09: queue_free on host propagates to all clients via PickupSpawner
	queue_free()
