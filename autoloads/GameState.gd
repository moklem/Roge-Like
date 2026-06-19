extends Node
## GameState autoload — host-authoritative run state.
## Clients read via MultiplayerSynchronizer (Phase 6).
## D-13: Only host writes; all writes guarded by multiplayer.is_server().

var loop_timer: float = 0.0  # seconds remaining; host only writes
var loop_number: int = 1  # D-16: starts at 1; Phase 8 increments via start_next_loop()
var revives_used: Dictionary = {}  # peer_id → int (count used this loop)

func _ready() -> void:
	# D-16 / Pitfall 6: ensure correct base even before peers connect
	loop_number = 1

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

## LOOP-03 / D-17: Called by Phase 8 after boss defeat. Hook point for next-loop setup.
## Increments loop_number, clears revives_used (HLTH-07 / D-22). Host-guarded.
func start_next_loop() -> void:
	if not multiplayer.has_multiplayer_peer():
		return
	if multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return
	if not multiplayer.is_server():
		return
	loop_number += 1
	revives_used = {}
	print("Loop %d started" % loop_number)

## CR-02 fix: Reset loop-scoped state so next run starts fresh.
## Called on host before _broadcast_game_over; also resets revives_used so
## a player who hit the revive cap last game is not blocked in the new run.
func reset_for_new_run() -> void:
	loop_number = 1
	loop_timer  = 0.0
	revives_used = {}

## D-14: Broadcast game over to all peers including host (call_local)
@rpc("authority", "call_local", "reliable")
func _broadcast_game_over() -> void:
	## D-16 / WEAP-08: Reset all weapon managers before scene change.
	## Runs on ALL peers (call_local) — each peer resets its own local player's WeaponManager.
	## Using get_nodes_in_group so it works on any peer without needing host authority.
	for p in get_tree().get_nodes_in_group("players"):
		if p.has_node("WeaponManager"):
			p.get_node("WeaponManager").reset()
		# Phase 6 (D-14, EVOL-06): reset progression for the next run
		p.xp = 0
		p.level = 1
		p.element_tier = 1
		p.stage3_damage_mult = 1.0
		p.is_picking_card = false
		p.evolution_stage = 1  # direct reset — skip deferred visual swap before scene change
	# CR-02: reset loop-scoped state before scene change so next run starts at loop 1
	reset_for_new_run()
	get_tree().change_scene_to_file("res://scenes/ui/GameOver.tscn")
