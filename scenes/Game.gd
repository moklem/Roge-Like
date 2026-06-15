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

## HUD labels for local player status (built programmatically in _ready)
var _hud_hp_label: Label = null
var _hud_ability_label: Label = null
var _hud_event_label: Label = null

## Phase 5 Plan 03 (D-13, ROLE-07): Engineer passive heal accumulator (host-only)
var _engineer_passive_accum: float = 0.0

## Phase 5 Plan 05 (D-19, ELEM-05/06): Earth element accumulators (host-only)
var _earth_heal_accum: float = 0.0
var _earth_shock_accum: float = 0.0

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
	_setup_player_hud()
	if multiplayer.is_server():
		_spawn_all_players()   # existing
		_spawn_enemies()       # CMBT-03: D-19 fixed spawn points, 3-5 enemies

func _bake_navigation() -> void:
	var nav := get_node_or_null("Room1/NavigationRegion2D")
	if nav:
		nav.bake_navigation_polygon(false)

# ==============================================================================
# PLAYER HUD (top-right: HP + Ability status for local peer)
# ==============================================================================

func _setup_player_hud() -> void:
	var hud := get_node_or_null("HUD")
	if hud == null:
		return
	var panel := PanelContainer.new()
	panel.name = "PlayerInfoPanel"
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_top = 0.0
	panel.anchor_bottom = 0.0
	panel.offset_left = -215
	panel.offset_right = -10
	panel.offset_top = 10
	panel.offset_bottom = 10  # grows with content
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.65)
	style.set_corner_radius_all(5)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	panel.add_theme_stylebox_override("panel", style)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)
	_hud_hp_label = Label.new()
	_hud_hp_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
	vbox.add_child(_hud_hp_label)
	_hud_ability_label = Label.new()
	vbox.add_child(_hud_ability_label)
	_hud_event_label = Label.new()
	_hud_event_label.visible = false
	_hud_event_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
	vbox.add_child(_hud_event_label)
	GameEvents.hud_event.connect(_on_hud_event)
	hud.add_child(panel)

func _on_hud_event(event_name: String) -> void:
	if _hud_event_label == null:
		return
	match event_name:
		"engine":       _hud_event_label.text = "FEUER BURST!"
		"ac":           _hud_event_label.text = "EIS SPUR"
		"seat_massage": _hud_event_label.text = "ERDE PULS"
		_:              _hud_event_label.text = event_name.to_upper()
	_hud_event_label.modulate = Color.WHITE
	_hud_event_label.visible = true
	var tween := _hud_event_label.create_tween()
	tween.tween_property(_hud_event_label, "modulate:a", 0.0, 1.2).set_delay(0.5)
	tween.tween_callback(func(): _hud_event_label.visible = false)

func _update_player_hud() -> void:
	if _hud_hp_label == null:
		return
	var local_id := multiplayer.get_unique_id()
	var local_player: Node = null
	for p in get_tree().get_nodes_in_group("players"):
		if p.peer_id == local_id:
			local_player = p
			break
	if local_player == null:
		_hud_hp_label.text = "HP: --"
		_hud_ability_label.text = "Fähigkeit: --"
		return
	_hud_hp_label.text = "HP  %d / %d" % [local_player.health, local_player.MAX_HP]
	var cd: float = local_player._ability_cooldown
	if cd <= 0.0:
		_hud_ability_label.text = "[SPACE]  BEREIT"
		_hud_ability_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.4))
	else:
		_hud_ability_label.text = "[SPACE]  CD: %.1fs" % cd
		_hud_ability_label.add_theme_color_override("font_color", Color(0.9, 0.7, 0.2))

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
	# D-03: 25% drop rate — restored from debug 100% override
	if randf() < 0.25:
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
	# CR-004: use get_process_delta_time() — RPC dispatch occurs in _process, not _physics_process
	var dt: float = get_process_delta_time()
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
@rpc("authority", "call_remote", "reliable")
func weapon_unlocked(weapon_id: String, collector_peer_id: int) -> void:
	for p in get_tree().get_nodes_in_group("players"):
		if p.peer_id == collector_peer_id:
			if p.has_node("WeaponManager"):
				p.get_node("WeaponManager").add_weapon(weapon_id)
			return

# ==============================================================================
# ENGINEER HEAL DRONE (ROLE-07, ROLE-08, ROLE-09 — Phase 5 Plan 03)
# ==============================================================================

## P8: host runs Engineer passive + Earth effects; all peers update local HUD.
func _process(delta: float) -> void:
	if multiplayer.is_server():
		_tick_engineer_passive(delta)
		_tick_earth_effects(delta)
	_update_player_hud()

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

## ROLE-08: Client Engineer requests drone deploy → host validates + spawns.
## Max 2 active drones per engineer; blocks silently when cap is reached.
@rpc("any_peer", "call_remote", "reliable")
func request_deploy_drone(requester_peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	# Count drones currently owned by this engineer
	var entities := get_node_or_null("Room1/Entities")
	var active_count := 0
	if entities:
		for child in entities.get_children():
			if child.get("owning_peer") == requester_peer_id:
				active_count += 1
	if active_count >= 1:
		return  # still active — wait for it to expire
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

# ==============================================================================
# EARTH ELEMENT (D-19, ELEM-05/06/07 — Phase 5 Plan 05)
# ==============================================================================

## D-19 (ELEM-05/06/07): Tick Earth element passive heal and periodic shockwave.
## Runs ONLY on host (inside _process which guards is_server()).
## Determines if at least one Earth player is alive; if so, accumulates timers.
## T-05-15: All damage and heal calls are host-only; HUD emit is host-only (T-05-18).
func _tick_earth_effects(delta: float) -> void:
	# Collect all alive Earth players — effects active when at least one exists
	var earth_players: Array = []
	for p in get_tree().get_nodes_in_group("players"):
		if p.element == "earth" and not p.is_downed:
			earth_players.append(p)
	if earth_players.is_empty():
		return

	# --- ELEM-05: Team Heal +2 HP/sec to ALL players (no proximity) ---
	_earth_heal_accum += delta
	if _earth_heal_accum >= 1.0:
		_earth_heal_accum = 0.0
		for target in get_tree().get_nodes_in_group("players"):
			if target.is_downed:
				continue
			# Pitfall 6: direct call on host peer, rpc_id for remote peers (T-05-17)
			if target.peer_id == multiplayer.get_unique_id():
				target.receive_heal(2)
			else:
				target.receive_heal.rpc_id(target.peer_id, 2)
		# ELEM-07: Earth heal fires SEAT MASSAGE HUD (T-05-18: host-only emit)
		GameEvents.emit_hud("seat_massage")

	# --- ELEM-06: Shockwave every 8s — knockback + 15 damage to enemies in 120px ---
	_earth_shock_accum += delta
	if _earth_shock_accum >= 8.0:
		_earth_shock_accum = 0.0
		for earth_player in earth_players:
			var earth_pos: Vector2 = earth_player.global_position
			# Visual ring broadcast to all peers (call_local so host also sees it)
			_show_earth_shockwave.rpc(earth_pos)
			# Host-only damage + knockback (T-05-15)
			for enemy in get_tree().get_nodes_in_group("enemies"):
				var dist: float = enemy.global_position.distance_to(earth_pos)
				if dist <= 120.0:
					enemy.take_damage(15)
					# Knockback: push enemy away from Earth player (D-19)
					if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
						enemy.velocity += (enemy.global_position - earth_pos).normalized() * 350.0
		# ELEM-07: Earth shockwave fires SEAT MASSAGE HUD (T-05-18: host-only, one emit per wave)
		GameEvents.emit_hud("seat_massage")

## D-19 (ELEM-06): Broadcast expanding green ring visual to all peers.
## Clone of HornShockwave._show_visual with RADIUS=120 and Earth green color.
## call_local so host also renders the ring.
@rpc("any_peer", "call_local", "unreliable_ordered")
func _show_earth_shockwave(pos: Vector2) -> void:
	const RADIUS: float = 120.0
	var ring := ColorRect.new()
	ring.color = Color(0.4, 0.8, 0.2, 0.8)
	ring.size = Vector2(RADIUS * 2.0, RADIUS * 2.0)
	ring.pivot_offset = Vector2(RADIUS, RADIUS)
	ring.position = pos - Vector2(RADIUS, RADIUS)
	ring.scale = Vector2(0.1, 0.1)
	add_child(ring)
	var tween := ring.create_tween()
	tween.tween_property(ring, "scale", Vector2(2.0, 2.0), 0.35)
	tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.35)
	tween.tween_callback(ring.queue_free)
