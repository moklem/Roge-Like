extends Area2D
## CarPartPickup — car-part weapon unlock pickup. Replicates XpOrb._collected guard.
## D-04: Separate scene from XpOrb; pre-registered in PickupSpawner.
## D-05: Collection is host-authoritative; _collected flag prevents double-collect (W1).
## W1: Client sends RPC to host; host validates _collected then despawns and sends weapon_unlocked.

@export var weapon_id: String = ""

var _collected: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	if has_node("Label"):
		$Label.text = weapon_id.left(6)

func _process(_delta: float) -> void:
	for p in get_tree().get_nodes_in_group("players"):
		if p.peer_id != multiplayer.get_unique_id():
			continue
		var wm := p.get_node_or_null("WeaponManager")
		if wm == null:
			return
		visible = wm.unlocked_weapons.size() < wm.MAX_WEAPONS and not wm.unlocked_weapons.has(weapon_id)
		return

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("players"):
		return
	if body.peer_id != multiplayer.get_unique_id():
		return
	var wm := body.get_node_or_null("WeaponManager")
	if wm != null:
		if wm.unlocked_weapons.size() >= wm.MAX_WEAPONS or wm.unlocked_weapons.has(weapon_id):
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
	var game := get_node_or_null("/root/Game")
	if game and game.has_method("weapon_unlocked"):
		game.weapon_unlocked.rpc(weapon_id, collector_peer_id)
	# CMBT-09 pattern: queue_free on host propagates to all clients via PickupSpawner
	queue_free()
