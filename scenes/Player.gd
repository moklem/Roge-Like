extends CharacterBody2D
## Player movement controller — handles WASD input, wall collision, health, downed state, revive.
## P3: All input handling guarded by is_multiplayer_authority().
## P4: MultiplayerSynchronizer replicates position, health, is_downed at 20 Hz (interval = 0.05).
## D-17: health and is_downed synced via MultiplayerSynchronizer from owning peer.
## Pitfall 3: receive_damage is @rpc("any_peer") so host (any_peer) calls rpc_id(peer_id) —
##   owning peer decrements health, MultiplayerSynchronizer replicates outward.

const SPEED: float = 200.0
const MAX_HP: int = 100
const REVIVE_DURATION: float = 3.5   # D-13: 3-4 seconds
const FIRE_INTERVAL: float = 0.5     # seconds between auto-shots (Plan 04 will use this)
const REVIVE_PROXIMITY: float = 60.0 # pixels — must be within this range to revive

@export var peer_id: int = 0
@export var role_label: String = ""

## D-17: replicated via MultiplayerSynchronizer SceneReplicationConfig
var health: int = MAX_HP
var is_downed: bool = false

var _fire_cooldown: float = 0.0

func _ready() -> void:
	# Set authority based on peer_id — only the owning peer controls this player
	set_multiplayer_authority(peer_id)
	# Required for enemy group discovery and game-over check
	add_to_group("players")
	# Update role label display (MOVE-04)
	if has_node("RoleLabel"):
		$RoleLabel.text = role_label

func _process(_delta: float) -> void:
	# D-12: downed visual tint runs on ALL peers from synced is_downed value
	if is_downed:
		$Sprite.modulate = Color(0.4, 0.4, 0.4)   # grayscale tint
	else:
		$Sprite.modulate = Color.WHITE
	# HLTH-01: Update health bar from synced health value (all peers)
	if has_node("HealthBar"):
		$HealthBar.value = float(health) / float(MAX_HP) * 100.0

func _physics_process(delta: float) -> void:
	# P3: Only the authority peer reads input and moves
	if not is_multiplayer_authority():
		return
	# HLTH-04: Downed players cannot act
	if is_downed:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	var dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = dir * SPEED
	move_and_slide()
	# Auto-fire cooldown tick (Plan 04 adds _try_fire — stub safe to leave for now)
	_fire_cooldown -= delta
	if _fire_cooldown <= 0.0:
		_fire_cooldown = FIRE_INTERVAL
		_try_fire()
	# HLTH-05: Check revive input (E key) each frame
	_check_revive(delta)

## HLTH-05: Check if holding E near a downed teammate; send request to host each frame
func _check_revive(_delta: float) -> void:
	if not Input.is_action_pressed("revive"):
		# Hide revive bar if not pressing revive
		if has_node("ReviveBar"):
			$ReviveBar.visible = false
		return
	var nearby := _find_nearby_downed()
	if nearby == null:
		if has_node("ReviveBar"):
			$ReviveBar.visible = false
		return
	# Send attempt_revive to host (Game.gd accumulates progress per-frame)
	var game := get_node_or_null("/root/Game")
	if game and game.has_method("attempt_revive"):
		game.attempt_revive.rpc_id(1, peer_id, nearby.peer_id)

## Find downed player within REVIVE_PROXIMITY range
func _find_nearby_downed() -> Node:
	for p in get_tree().get_nodes_in_group("players"):
		if p == self:
			continue
		if not p.is_downed:
			continue
		if global_position.distance_to(p.global_position) <= REVIVE_PROXIMITY:
			return p
	return null

## HLTH-02 / Pitfall 3: Called via rpc_id(peer_id) from host (Enemy.gd or Bullet.gd).
## Uses @rpc("any_peer") because the host (peer 1) is NOT the node's multiplayer authority
## (authority = owning peer via set_multiplayer_authority). "any_peer" allows host to send
## this RPC to the owning peer. Owning peer applies damage to own health —
## MultiplayerSynchronizer then replicates health outward to all clients.
@rpc("any_peer", "call_remote", "reliable")
func receive_damage(amount: int) -> void:
	health -= amount
	if health <= 0:
		health = 0
		_enter_downed()

## HLTH-04: Enter downed state — disable actions, trigger visual, notify GameState
func _enter_downed() -> void:
	is_downed = true
	# GameState.track_downed checks if all players are down → game over (added in Plan 05)
	if GameState.has_method("track_downed"):
		GameState.track_downed(peer_id)

## Called by Game.gd when host confirms revive complete (via receive_revive RPC — see Plan 05)
func revive() -> void:
	health = MAX_HP / 2  # revive with 50% HP
	is_downed = false

## HLTH-06: Update ReviveBar on this player node (called by Game.gd revive accumulator via RPC)
## progress: 0.0 to 1.0
## @rpc("any_peer") so host can push update to the owning peer's client (HLTH-06 replication fix)
@rpc("any_peer", "call_remote", "reliable")
func set_revive_progress(progress: float) -> void:
	if has_node("ReviveBar"):
		$ReviveBar.visible = progress > 0.0
		$ReviveBar.value = progress * 100.0

## CMBT-04: Auto-fire toward nearest enemy — D-06: aimed at nearest enemy
func _try_fire() -> void:
	var nearest := _find_nearest_enemy()
	if nearest == null:
		return
	var dir := (nearest.global_position - global_position).normalized()
	# BulletSpawner lives in Game.gd — Plan 05 adds it to Game.tscn
	# Only the authority peer fires (already inside is_multiplayer_authority guard in _physics_process)
	# Per RESEARCH.md architecture: Player calls spawner directly — spawner is host-side
	# The owning player peer calls spawn() only if they are also the server.
	# In single-host architecture, player 1 (host) fires own bullets directly.
	# For client players: they are authority of their own player node but NOT the server.
	# Therefore only the host player auto-fires; client-owned players need to route through host.
	# Simplest correct approach: owning peer sends fire_request to host, host spawns bullet.
	# Implementation: send @rpc to host with pos + dir; host calls BulletSpawner.spawn().
	var game := get_node_or_null("/root/Game")
	if game == null:
		return
	if multiplayer.is_server():
		# Host player fires directly
		if game.has_node("BulletSpawner"):
			game.get_node("BulletSpawner").spawn({
				"pos": global_position,
				"dir": dir,
				"owner_id": peer_id
			})
	else:
		# Client player sends fire request to host
		if game.has_method("request_fire"):
			game.request_fire.rpc_id(1, global_position, dir, peer_id)

func _find_nearest_enemy() -> Node:
	var nearest: Node = null
	var nearest_dist: float = INF
	for e in get_tree().get_nodes_in_group("enemies"):
		var d: float = global_position.distance_to(e.global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = e
	return nearest
