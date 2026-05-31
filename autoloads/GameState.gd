extends Node
## GameState autoload — host-authoritative run state.
## Clients read via MultiplayerSynchronizer (Phase 6).
## D-13: Only host writes; all writes guarded by multiplayer.is_server().

var loop_timer: float = 0.0  # seconds remaining; host only writes
var loop_number: int = 0
var revives_used: Dictionary = {}  # peer_id → int (count used this loop)

func _ready() -> void:
	pass  # Minimal until Phase 6 wires loop timer and difficulty scaling

func _process(delta: float) -> void:
	# Guard: peer must exist and be fully connected before querying is_server().
	# Without this, get_unique_id() throws "not active" during the connecting phase.
	if not multiplayer.has_multiplayer_peer():
		return
	if multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return
	if not multiplayer.is_server():
		return  # D-13: only host ticks timer
	if loop_timer > 0.0:
		loop_timer -= delta

## HLTH-08: Called from Player._enter_downed() — checks if ALL players are downed.
## D-14: Immediate game over with no grace period when all are downed.
func track_downed(_peer_id: int) -> void:
	# Use same guard pattern as _process() — connection must be active and this must be server
	if not multiplayer.has_multiplayer_peer():
		return
	if multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return
	if not multiplayer.is_server():
		return
	var players := get_tree().get_nodes_in_group("players")
	if players.is_empty():
		return
	var all_downed: bool = true
	for p in players:
		if not p.is_downed:
			all_downed = false
			break
	if all_downed:
		# D-14: Immediate game over — no grace period
		_broadcast_game_over.rpc()

## D-14: Broadcast game over to all peers including host (call_local)
@rpc("authority", "call_local", "reliable")
func _broadcast_game_over() -> void:
	## D-16 / WEAP-08: Reset all weapon managers before scene change.
	## Runs on ALL peers (call_local) — each peer resets its own local player's WeaponManager.
	## Using get_nodes_in_group so it works on any peer without needing host authority.
	for p in get_tree().get_nodes_in_group("players"):
		if p.has_node("WeaponManager"):
			p.get_node("WeaponManager").reset()
	get_tree().change_scene_to_file("res://scenes/ui/GameOver.tscn")
