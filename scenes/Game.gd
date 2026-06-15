extends Node2D
## Game scene controller — spawns all entities, manages combat, revive, game-over.
## P7: spawn_function used for ALL spawners so data Dictionary is forwarded to every peer.
## P3: Only host calls spawner.spawn(); clients receive via replication.
## P6: Enemy AI runs only on host; clients render synced position.

const PLAYER_SCENE    := preload("res://scenes/Player.tscn")
const ENEMY_SCENE     := preload("res://scenes/enemies/Enemy.tscn")
const BULLET_SCENE    := preload("res://scenes/projectiles/Bullet.tscn")
const ORB_SCENE       := preload("res://scenes/pickups/XpOrb.tscn")
const CAR_PART_SCENE  := preload("res://scenes/pickups/CarPartPickup.tscn")
const CAR_PART_IDS    := ["exhaust_flames", "spinning_tires", "antenna_beam", "horn_shockwave", "airbag_shield"]
## Phase 5 Plan 03 (D-14, D-15, D-21): Engineer Heal Drone spawnable scene
const HEAL_DRONE_SCENE := preload("res://scenes/roles/HealDrone.tscn")
## Phase 5 Plan 05 (D-18, ELEM-04): Ice Trail frost zone spawnable scene
const ICE_TRAIL_SCENE := preload("res://scenes/elements/IceTrailZone.tscn")

## D-13: Revive duration 3-4 seconds (mirrors Player.REVIVE_DURATION)
const REVIVE_DURATION: float = 3.5
## D-19: Max enemies to spawn at game start
const INITIAL_ENEMY_COUNT: int = 8
## Proximity range for revive validation on host
const REVIVE_PROXIMITY: float = 80.0

## Revive accumulator — keyed by target player peer_id → seconds accumulated
var _revive_progress: Dictionary = {}

## Phase 5 Plan 03 (D-13, ROLE-07): Engineer passive heal accumulator (host-only)
var _engineer_passive_accum: float = 0.0

func _ready() -> void:
	# P7: custom spawn_functions forward data Dictionary to every peer automatically
	$MultiplayerSpawner.spawn_function = _do_spawn         # players (existing)
	$EnemySpawner.spawn_function  = _do_spawn_enemy
	$BulletSpawner.spawn_function = _do_spawn_bullet
	$PickupSpawner.spawn_function = _do_spawn_pickup
	# P7: Pre-register ALL scenes PickupSpawner may spawn before any enemy dies
	$PickupSpawner.add_spawnable_scene("res://scenes/pickups/XpOrb.tscn")
	$PickupSpawner.add_spawnable_scene("res://scenes/pickups/CarPartPickup.tscn")
	# Phase 5 Plan 03 (D-14, D-21): DroneSpawner for Engineer Heal Drone (P7 pre-register)
	$DroneSpawner.spawn_function = _do_spawn_drone
	$DroneSpawner.add_spawnable_scene("res://scenes/roles/HealDrone.tscn")
	# Phase 5 Plan 05 (D-18, ELEM-04): IceTrailSpawner for Ice Trail frost zones (P7 pre-register)
	$IceTrailSpawner.spawn_function = _do_spawn_ice_trail
	$IceTrailSpawner.add_spawnable_scene("res://scenes/elements/IceTrailZone.tscn")

	# Bake navigation polygon at runtime so new obstacles are properly carved out
	call_deferred("_bake_navigation")
	if multiplayer.is_server():
		_spawn_all_players()   # existing
		_spawn_enemies()       # CMBT-03: D-19 fixed spawn points, 3-5 enemies

func _bake_navigation() -> void:
	var nav := get_node_or_null("Room1/NavigationRegion2D")
	if nav:
		nav.bake_navigation_polygon(false)

# ==============================================================================
# PLAYER SPAWNING (existing — unchanged)
# ==============================================================================

func _spawn_all_players() -> void:
	var spawn_points := $Room1/SpawnPoints.get_children()
	var idx := 0
	for id in Lobby.players:
		var spawn_pos := Vector2(400, 300)
		if idx < spawn_points.size():
			spawn_pos = spawn_points[idx].global_position
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

# ==============================================================================
# ENEMY SPAWNING (CMBT-03, D-15, D-19)
# ==============================================================================

func _spawn_enemies() -> void:
	# D-19: Fixed spawn points at room edges (added in Plan 01)
	var points := $Room1/EnemySpawnPoints.get_children()
	for i in range(min(INITIAL_ENEMY_COUNT, points.size())):
		$EnemySpawner.spawn({"pos": points[i].global_position})

func _do_spawn_enemy(data: Dictionary) -> Node:
	var e := ENEMY_SCENE.instantiate()
	e.position = data["pos"]
	e.name = "Enemy_%d" % (randi() % 9999)
	# CMBT-08: Connect died signal to spawn XP orb at death position
	e.died.connect(_on_enemy_died)
	return e

## CMBT-08 / WEAP-01: XP orb always drops; 25% chance to also drop a car-part pickup.
func _on_enemy_died(pos: Vector2) -> void:
	if not multiplayer.is_server():
		return
	# Always drop XP orb — call_deferred prevents "Can't change state while flushing queries"
	$PickupSpawner.spawn.call_deferred({"type": "xp_orb", "pos": pos})
	# D-03: 25% → TEST: 100% drop damit alle Waffen schnell getestet werden können
	if randf() < 1.0:
		var part_id: String = CAR_PART_IDS[randi() % CAR_PART_IDS.size()]
		$PickupSpawner.spawn.call_deferred({"type": "car_part", "pos": pos + Vector2(10, 0), "weapon_id": part_id})
	# TEST: Sofort neuen Feind spawnen damit immer Gegner da sind
	var points := $Room1/EnemySpawnPoints.get_children()
	if points.size() > 0:
		var spawn_pos: Vector2 = points[randi() % points.size()].global_position
		$EnemySpawner.spawn.call_deferred({"pos": spawn_pos})

func _do_spawn_pickup(data: Dictionary) -> Node:
	match data.get("type", "xp_orb"):
		"xp_orb":
			var orb := ORB_SCENE.instantiate()
			orb.position = data["pos"]
			orb.name = "XpOrb_%d" % (randi() % 9999)
			return orb
		"car_part":
			var pickup := CAR_PART_SCENE.instantiate()
			pickup.position = data["pos"]
			pickup.weapon_id = data["weapon_id"]
			pickup.name = "CarPart_%d" % (randi() % 9999)
			return pickup
	return null

# ==============================================================================
# BULLET SPAWNING (CMBT-04, CMBT-05, CMBT-06)
# ==============================================================================

## CMBT-04: Client players request a bullet spawn — host validates and spawns.
## T-03-11: _client_pos is ignored; host uses server-authoritative player position.
## Signature matches Player.gd call: rpc_id(1, global_position, dir, peer_id)
## Phase 5 Plan 05 (D-17, ELEM-07, T-05-19): Optional force_burn param — defaults false so
## existing screws/bolts callers (rpc_id(1, pos, dir, peer_id)) remain valid.
@rpc("any_peer", "call_remote", "reliable")
func request_fire(_client_pos: Vector2, dir: Vector2, requester_peer_id: int, force_burn: bool = false) -> void:
	# Runs on host only
	if not multiplayer.is_server():
		return
	# Find the player node belonging to this peer to get authoritative position
	var player_node: Node = null
	for p in get_tree().get_nodes_in_group("players"):
		if p.peer_id == requester_peer_id:
			player_node = p
			break
	if player_node == null:
		return
	if player_node.is_downed:
		return  # downed players cannot fire
	$BulletSpawner.spawn({
		"pos": player_node.global_position,
		"dir": dir.normalized(),
		"owner_id": requester_peer_id,
		"fire_burst": force_burn
	})

func _do_spawn_bullet(data: Dictionary) -> Node:
	var b := BULLET_SCENE.instantiate()
	b.position      = data["pos"]
	b.direction     = data["dir"]         # Pitfall 2: bake dir into data for client simulation
	b.owner_peer_id = data["owner_id"]
	b.name = "Bullet_%d" % (randi() % 99999)
	# Phase 5 Plan 05 (D-17, ELEM-07, T-05-19): Wire force_burn for Fire Burst projectiles.
	# force_burn=true bypasses the 25% proc gate in Bullet.gd (100% guaranteed burn).
	# T-05-19: force_burn defaults false; only Fire Burst spawn path sets fire_burst=true.
	b.force_burn = data.get("fire_burst", false)
	if b.force_burn:
		b.modulate = Color(1.0, 0.5, 0.0)  # orange modulate (D-17, D-ELEM-07 visual)
	return b

# ==============================================================================
# REVIVE SYSTEM (HLTH-05, HLTH-06)
# ==============================================================================

## HLTH-05: Called by Player.gd each frame the reviver holds E near a downed player.
## Accumulates time; when >= REVIVE_DURATION calls receive_revive RPC on the target.
@rpc("any_peer", "call_remote", "reliable")
func attempt_revive(reviver_id: int, target_id: int) -> void:
	if not multiplayer.is_server():
		return
	# Validate: target must be downed, reviver must be close enough and not downed
	var reviver: Node = null
	var target: Node = null
	for p in get_tree().get_nodes_in_group("players"):
		if p.peer_id == reviver_id:
			reviver = p
		if p.peer_id == target_id:
			target = p
	if reviver == null or target == null:
		return
	if not target.is_downed:
		# Target already revived (race condition) — reset progress and ignore
		_revive_progress.erase(target_id)
		return
	if reviver.is_downed:
		return  # cannot revive while downed
	if reviver.global_position.distance_to(target.global_position) > REVIVE_PROXIMITY:
		# Reviver walked away — Pitfall 6: reset progress
		_revive_progress.erase(target_id)
		_update_revive_bar(target_id, 0.0)
		return
	# Accumulate revive progress
	var dt: float = get_physics_process_delta_time()
	var progress: float = _revive_progress.get(target_id, 0.0) + dt
	_revive_progress[target_id] = progress
	# HLTH-06: Push revive bar progress to the owning peer via RPC
	var pct: float = minf(progress / REVIVE_DURATION, 1.0)
	_update_revive_bar(target_id, pct)
	if progress >= REVIVE_DURATION:
		# Revive complete — call receive_revive RPC on the owning peer
		_revive_progress.erase(target_id)
		# receive_revive is @rpc("any_peer", "call_remote", "reliable") on Player.gd.
		# Host (any_peer) sends it to the target's owning client peer_id.
		# The owning peer calls revive() locally, setting health and is_downed,
		# which MultiplayerSynchronizer replicates outward to all clients.
		target.receive_revive.rpc_id(target.peer_id)

## HLTH-06: Push revive bar update to the owning peer — Player.set_revive_progress is an RPC
func _update_revive_bar(target_id: int, progress: float) -> void:
	for p in get_tree().get_nodes_in_group("players"):
		if p.peer_id == target_id:
			# set_revive_progress is @rpc("any_peer", "call_remote", "reliable") on Player.gd.
			# Host calls it via rpc_id so the update reaches the owning peer's client.
			p.set_revive_progress.rpc_id(target_id, progress)
			break

# ==============================================================================
# WEAPON UNLOCK (WEAP-02, WEAP-03)
# ==============================================================================

## WEAP-02 / WEAP-03: Host sends weapon unlock to the collecting player's peer.
## @rpc("authority") so only host can call this; call_remote so it runs on the target peer only.
@rpc("authority", "call_local", "reliable")
func weapon_unlocked(weapon_id: String, collector_peer_id: int) -> void:
	for p in get_tree().get_nodes_in_group("players"):
		if p.peer_id == collector_peer_id:
			if p.has_node("WeaponManager"):
				p.get_node("WeaponManager").add_weapon(weapon_id)
			return

# ==============================================================================
# ENGINEER HEAL DRONE (ROLE-07, ROLE-08, ROLE-09 — Phase 5 Plan 03)
# ==============================================================================

## P8: host-only _process for Engineer passive heal timer.
## Clients skip all passive heal logic — host broadcasts via receive_heal rpc_id.
func _process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	_tick_engineer_passive(delta)

## D-13 (ROLE-07): Engineer passive — every 5s, +10 HP to all OTHER players within 200px.
## Pitfall 6: uses rpc_id routing (direct on host, rpc_id on remote) — mirrors Enemy.gd lines 91-94.
func _tick_engineer_passive(delta: float) -> void:
	_engineer_passive_accum += delta
	if _engineer_passive_accum < 5.0:
		return
	_engineer_passive_accum = 0.0
	# Find all Engineers (by role_label) that are not downed
	for eng in get_tree().get_nodes_in_group("players"):
		if eng.role_label != "Engineer" or eng.is_downed:
			continue
		# Heal all OTHER nearby players within 200px
		for target in get_tree().get_nodes_in_group("players"):
			if target == eng:
				continue  # Engineer does not heal themselves via this passive
			if target.is_downed:
				continue
			if eng.global_position.distance_to(target.global_position) > 200.0:
				continue
			# receive_heal routing — Pitfall 6: direct on host peer, rpc_id on remote
			if target.peer_id == multiplayer.get_unique_id():
				target.receive_heal(10)
			else:
				target.receive_heal.rpc_id(target.peer_id, 10)

## D-14 (ROLE-08): Client Engineer requests drone deploy → host validates + spawns.
## Mirrors request_fire structure exactly. Max 1 drone per engineer (D-14).
@rpc("any_peer", "call_remote", "reliable")
func request_deploy_drone(requester_peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	# D-14: Remove existing drone for this engineer (max 1 active)
	for child in get_children():
		if child.name == "HealDrone_%d" % requester_peer_id:
			child.queue_free()
	# Validate: engineer must exist and not be downed
	var player_node: Node = null
	for p in get_tree().get_nodes_in_group("players"):
		if p.peer_id == requester_peer_id:
			player_node = p
			break
	if player_node == null or player_node.is_downed:
		return
	$DroneSpawner.spawn({
		"pos": player_node.global_position,
		"peer_id": requester_peer_id,
		"stage": player_node.evolution_stage
	})

## Spawn function registered with DroneSpawner (P7 pattern — called on all peers via replication).
func _do_spawn_drone(data: Dictionary) -> Node:
	var drone := HEAL_DRONE_SCENE.instantiate()
	drone.position = data["pos"]
	drone.owning_peer = data["peer_id"]
	drone.stage = data.get("stage", 1)
	drone.name = "HealDrone_%d" % data["peer_id"]
	return drone

# ==============================================================================
# ICE TRAIL SPAWN (D-18, ELEM-04 — Phase 5 Plan 05)
# ==============================================================================

## D-18 (ELEM-04): Ice element player requests a frost zone spawn at their position.
## Pitfall 4: call_deferred required — this is called from _physics_process via rpc_id;
## direct spawn inside a physics callback causes "Can't change state while flushing queries".
## T-05-16: RPC guard ensures only host actually spawns — a forged call only places a visual zone.
## ELEM-07: Ice Trail spawn fires "ac" HUD indicator (D-19, per D-ELEM-07 mapping).
@rpc("any_peer", "call_remote", "reliable")
func request_ice_trail(pos: Vector2) -> void:
	if not multiplayer.is_server():
		return
	# Pitfall 4: call_deferred prevents physics-state mutation during flushing
	$IceTrailSpawner.spawn.call_deferred({"pos": pos})
	GameEvents.emit_hud("ac")

## Spawn function registered with IceTrailSpawner (P7 pattern — replicates zone to all peers).
func _do_spawn_ice_trail(data: Dictionary) -> Node:
	var zone := ICE_TRAIL_SCENE.instantiate()
	zone.position = data["pos"]
	zone.name = "IceTrail_%d" % (randi() % 99999)
	return zone
