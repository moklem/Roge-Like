extends Area2D
## CarPartPickup — car-part weapon unlock pickup. Replicates XpOrb._collected guard.
## D-04: Separate scene from XpOrb; pre-registered in PickupSpawner.
## D-05: Collection is host-authoritative; _collected flag prevents double-collect (W1).
## W1: Client sends RPC to host; host validates _collected then despawns and sends weapon_unlocked.

@export var weapon_id: String = ""

var _collected: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	# Update label with weapon_id for debug visibility
	if has_node("Label"):
		$Label.text = weapon_id.left(6)

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("players"):
		return
	# W1: Only the peer who stepped on it sends the RPC — prevents duplicate RPCs from all peers
	if body.peer_id != multiplayer.get_unique_id():
		return
	if multiplayer.is_server():
		_request_collect(name, body.peer_id)
	else:
		_request_collect.rpc_id(1, name, body.peer_id)

@rpc("any_peer", "call_remote", "reliable")
func _request_collect(_pickup_name: String, collector_peer_id: int) -> void:
	# Runs on host only
	if not multiplayer.is_server():
		return
	if _collected:
		return  # W1: double-collect guard — second RPC sees true and exits immediately
	_collected = true
	# Notify collecting player's peer to add weapon
	# CR-01 fix: call_remote skips local execution — host must call locally when it is the collector
	var game := get_node_or_null("/root/Game")
	if game and game.has_method("weapon_unlocked"):
		if collector_peer_id == multiplayer.get_unique_id():
			game.weapon_unlocked(weapon_id)  # host collecting: direct local call
		else:
			game.weapon_unlocked.rpc_id(collector_peer_id, weapon_id)  # client collecting: RPC
	# CMBT-09 pattern: queue_free on host propagates to all clients via PickupSpawner
	queue_free()
