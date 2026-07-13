extends Area2D
## XP orb pickup — spawned by Game.gd when enemy dies (CMBT-08).

const PLAYER_SCRIPT = preload("res://scenes/Player.gd")
## Collection is host-authoritative (CMBT-09, D-16).
## Pitfall 5: _collected flag prevents double-collection race condition.

## PICK-01 (10-RESEARCH.md Code Example): purely cosmetic drift toward the nearest
## already-replicated player position. Runs identically on every peer — no sync,
## no RPC. The real collection flow (_on_body_entered / _request_collect / _collected /
## the body.peer_id authority guard below) is completely untouched by this.
const MAGNET_RADIUS: float = 90.0
const MAGNET_SPEED: float = 260.0
var _magnetized: bool = false

var _collected: bool = false

func _ready() -> void:
	# Grouped so Game.gd can purge uncollected orbs on sub-room / room transitions.
	add_to_group("xp_orbs")
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	if _collected:
		return
	var nearest: Node = _find_nearest_player()
	if nearest == null:
		_magnetized = false
		return
	var dist: float = global_position.distance_to(nearest.global_position)
	if dist <= MAGNET_RADIUS:
		_magnetized = true
		global_position = global_position.move_toward(nearest.global_position, MAGNET_SPEED * delta)
	else:
		_magnetized = false

## Nearest node in group "players" by already-replicated global_position — no new
## sync, every peer computes the same drift target independently (T-10-13 mitigation).
func _find_nearest_player() -> Node:
	var nearest: Node = null
	var nearest_dist: float = INF
	for player in get_tree().get_nodes_in_group("players"):
		if not (player is Node2D):
			continue
		var d: float = global_position.distance_to(player.global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = player
	return nearest

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
	# TEAM XP: every orb feeds the shared team pool, no matter who collected it.
	# D-19: scale XP from Phase 6 base (Player.XP_PER_ORB = 15) by loop_number.
	# Loop 1 = 15 XP (unchanged), loop 2 ≈ 19 XP, loop 3 ≈ 23 XP (planner discretion per RESEARCH.md Open Q3).
	var xp_amount: int = roundi(float(PLAYER_SCRIPT.XP_PER_ORB) * (1.0 + (GameState.loop_number - 1) * 0.25))
	GameState.add_team_xp(xp_amount)
	# CMBT-09: queue_free on host propagates to all clients via PickupSpawner
	queue_free()
