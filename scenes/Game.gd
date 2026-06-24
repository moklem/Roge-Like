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
## Phase 7 Plan 03 (D-13, HUD-07): Elite enemy scene pre-loaded for EnemySpawner dispatch
const ELITE_ENEMY_SCENE := preload("res://scenes/enemies/EliteEnemy.tscn")
## Phase 7 Plan 03 (D-01, HUD-01): CarHUD global dashboard scene
const CAR_HUD_SCENE := preload("res://scenes/ui/CarHUD.tscn")
## Phase 8 Plan 03 (P7, D-09): Boss scene pre-registered in EnemySpawner before boss fight
const BOSS_SCENE := preload("res://scenes/enemies/Boss.tscn")

## Phase 9 (D-04, MAP-08): RoomBuilder populates TileMap sub-rooms from hardcoded layout data.
## Instantiated in _ready() as _room_builder.
const ROOM_BUILDER_SCRIPT := preload("res://scenes/RoomBuilder.gd")

## D-13: Revive duration 3-4 seconds (mirrors Player.REVIVE_DURATION)
const REVIVE_DURATION: float = 3.5
## D-19: Max enemies to spawn at game start (Room 1 baseline)
const INITIAL_ENEMY_COUNT: int = 8
## Phase 8 Plan 03 (D-07): Room 2 baseline enemy count — 1.5× Room 1 baseline (8 × 1.5 = 12)
const INITIAL_ENEMY_COUNT_R2: int = 12
## Proximity range for revive validation on host
const REVIVE_PROXIMITY: float = 80.0
## Wave system: 3 waves per room before advancing (Room 3/boss excluded)
const WAVES_PER_ROOM: int = 3

## Phase 8 Plan 03 (D-04): Active room tracker — 1=Room1, 2=Room2, 3=Room3 (boss arena)
var current_room: int = 1

## Phase 9 (D-10, MAP-01): Sub-room tracker within each location. 1–5. Reset to 1 on room transition.
var current_sub_room: int = 1

## Phase 9 (D-08): Exit tile coords set by RoomBuilder; read by _open_exit_passage() RPC.
var _exit_tile_coords: Array[Vector2i] = []

## Phase 9: RoomBuilder instance. Created in _ready().
var _room_builder: RoomBuilder = null

## Phase 9 (D-03): Current sub-room pixel bounds for camera limit update.
var _current_sub_room_rect_px: Rect2 = Rect2(0, 0, 960, 640)

## Phase 9 (D-12): Connector exit trigger guard — prevents double-triggering room transition.
var _connector_triggered: bool = false

## Wave tracker — host-authoritative. Reset to 1 on each room entry via _spawn_enemies().
var _current_wave: int = 1
## Display wave — synced to all peers via _announce_wave RPC.
var _display_wave: int = 1

## Revive accumulator — keyed by target player peer_id → seconds accumulated
var _revive_progress: Dictionary = {}

## HUD labels for local player status (built programmatically in _ready)
var _hud_hp_label: Label = null
var _hud_ability_label: Label = null
var _hud_wave_label: Label = null
# WR-05: _hud_event_label removed — CarHUD (Phase 7) is now the sole HUD-event consumer.

## Phase 5 Plan 03 (D-13, ROLE-07): Engineer passive heal accumulator (host-only)
var _engineer_passive_accum: float = 0.0

## Phase 5 Plan 05 (D-19, ELEM-05/06): Earth element accumulators (host-only)
var _earth_heal_accum: float = 0.0
var _earth_shock_accum: float = 0.0

## Phase 7 Plan 03 (D-13, HUD-07): Elite enemy spawn timer accumulators (host-only)
var _elite_spawn_timer: float = 0.0
var _elite_spawn_interval: float = 0.0  # randomized in _ready via randf_range(45, 90)

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
	# Phase 7 Plan 03 (Pitfall 5, D-13): Pre-register EliteEnemy BEFORE any elite spawns occur
	$EnemySpawner.add_spawnable_scene("res://scenes/enemies/EliteEnemy.tscn")
	# Phase 8 Plan 03 (P7): Pre-register Boss BEFORE any boss fight (must precede boss spawn)
	$EnemySpawner.add_spawnable_scene("res://scenes/enemies/Boss.tscn")
	# Phase 7 Plan 03 (D-01, HUD-01, Pitfall 3): CarHUD as separate CanvasLayer on Game root
	# NOT inside $HUD — CarHUD is layer=3, must not conflict with existing HUD CanvasLayer
	var _car_hud := CAR_HUD_SCENE.instantiate()
	add_child(_car_hud)
	# Phase 7 Plan 03 (D-13): Initialize elite spawn interval; host timer uses randf_range(45, 90)
	_elite_spawn_interval = randf_range(45.0, 90.0)

	## Phase 9 (D-07, MAP-09): RoomBuilder replaces the old network-based room generator.
	## Hardcoded sub-room data is used instead of real-time Overpass API fetches.
	_room_builder = RoomBuilder.new()
	## Build sub-room 1 of Room 1 immediately on all peers (deterministic from static data; no RPC needed for first load).
	var _first_rect: Rect2 = _room_builder.build_sub_room(1, 1, self)
	_current_sub_room_rect_px = _first_rect
	## Phase 9 (D-03, MAP-07): Deferred so players are spawned before camera limits are applied.
	## _spawn_all_players() is called after _ready() completes; call_deferred ensures ordering.
	call_deferred("_update_all_camera_limits")

	# Phase 8: Disable StaticBody2D collision on hidden rooms at startup.
	# Room2 and Room3 start visible=false but Godot does NOT disable collision with visibility.
	# Without this, players immediately collide with invisible walls/blocks from all 3 rooms.
	for _rid in [2, 3]:
		var _hidden_room := get_node_or_null("Room%d" % _rid)
		if _hidden_room:
			for _body in _hidden_room.find_children("*", "StaticBody2D", true, false):
				_body.set_collision_layer_value(1, false)

	# Bake navigation polygon at runtime so new obstacles are properly carved out
	call_deferred("_bake_navigation")
	_setup_player_hud()
	if multiplayer.is_server():
		_spawn_all_players()   # existing
		_spawn_enemies()       # CMBT-03: D-19 fixed spawn points, 3-5 enemies

## Phase 8 Plan 03 (D-04): Generalized — bakes the active room's NavigationRegion2D.
## At loop start current_room == 1 so this resolves to Room1/NavigationRegion2D as before.
## Phase 9: await process_frame ensures all set_cell() calls from build_sub_room are reflected
## in physics/collision before the navmesh bake runs.
func _bake_navigation() -> void:
	await get_tree().process_frame  ## Phase 9: wait for TileMap set_cell() to register in physics
	var nav := get_node_or_null("Room%d/NavigationRegion2D" % current_room)
	if nav:
		nav.bake_navigation_polygon(false)

# ==============================================================================
# ROOM TRANSITION (D-02, D-03, ROOM-07, P10 — Phase 8 Plan 03)
# ==============================================================================

## D-03, ROOM-07, P10: Simultaneous room transition on ALL peers (call_local reliable).
## Hides old room + disables collision; shows new room + enables collision; teleports players.
## Host-only block: purges leftover pickups/orbs, bakes new navmesh, triggers room-specific spawns.
## T-08-01: @rpc("authority") so only host can invoke this on peers — clients cannot trigger transitions.
@rpc("authority", "call_local", "reliable")
func _transition_to_room(next_room: int) -> void:
	# --- All peers: hide old room, show new room, teleport players ---
	# Reset wave display on all peers when entering a new room
	_display_wave = 1
	var old_room_id: int = current_room
	var old_room := get_node_or_null("Room%d" % old_room_id)
	if old_room:
		old_room.visible = false
		for body in old_room.find_children("*", "StaticBody2D", true, false):
			body.set_collision_layer_value(1, false)
		## Phase 9 (Pitfall 4): Disable TileMap collision on the hidden room
		if _room_builder != null:
			_room_builder.set_tilemap_collision(old_room_id, false, self)

	var new_room := get_node_or_null("Room%d" % next_room)
	if new_room:
		new_room.visible = true
		for body in new_room.find_children("*", "StaticBody2D", true, false):
			body.set_collision_layer_value(1, true)
		## Phase 9 (Pitfall 4): Enable TileMap collision on the newly active room
		if _room_builder != null:
			_room_builder.set_tilemap_collision(next_room, true, self)

	current_room = next_room
	## Phase 9 (D-10, MAP-01): Reset sub-room counter on location transition
	current_sub_room = 1
	## Phase 9 (D-12): Reset connector exit trigger guard
	_connector_triggered = false

	## Phase 9: Build sub-room 1 of the new location on all peers (call_local context).
	if _room_builder != null:
		var _trans_rect: Rect2 = _room_builder.build_sub_room(current_room, 1, self)
		_current_sub_room_rect_px = _trans_rect
		## Phase 9 (D-03, MAP-07): Update camera limits for all players after room transition.
		_update_all_camera_limits()

	# Teleport players to the new room's first sub-room spawn points (just updated by build_sub_room)
	_teleport_players_to_spawn()

	# --- Host-only block: purge, bake, spawn ---
	if not multiplayer.is_server():
		return

	# Purge leftover XP orbs and car-part pickups from shared Entities node
	var entities := get_node_or_null("Entities")
	if entities:
		for child in entities.get_children():
			if child.is_in_group("xp_orbs") or child.is_in_group("car_parts"):
				child.queue_free()
		# Purge surviving enemies tagged to the room we just left
		for child in entities.get_children():
			if child.is_in_group("enemies"):
				if child.get_meta("room_id", old_room_id) == old_room_id:
					child.queue_free()

	# Bake the new room's navmesh (current_room is now next_room)
	_bake_navigation.call_deferred()

	# Room-specific post-transition spawns (deferred to stay physics-safe)
	if next_room == 3:
		# D-09: Boss spawns on Room 3 entry; no normal enemy wave
		_spawn_boss.call_deferred()
	elif next_room == 2:
		# D-07: Room 2 enemy wave using INITIAL_ENEMY_COUNT_R2 density
		_spawn_enemies.call_deferred()

## D-02, ROOM-07: Check if the active room's enemies are all dead; if so, fire transition.
## Host-only. Skips Room 3 — that room clears on boss death, not enemy count (Pitfall 5).
## Called deferred from _on_enemy_died so queue_free finishes before we count (RESEARCH P4).
func _check_room_clear() -> void:
	if not multiplayer.is_server():
		return
	# Room 3 clears when boss dies — boss death routes through _on_boss_died, not here
	if current_room == 3:
		return
	# Count alive enemies tagged to the current room
	var alive_count: int = 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.is_queued_for_deletion():
			continue
		var e_room: int = e.get_meta("room_id", current_room) if e.has_meta("room_id") else current_room
		if e_room == current_room:
			alive_count += 1
	if alive_count > 0:
		return
	# Wave system: advance wave or transition when all waves complete
	if _current_wave < WAVES_PER_ROOM:
		_current_wave += 1
		_announce_wave.rpc(_current_wave)
		_spawn_wave.call_deferred()
	else:
		_current_wave = 1
		_transition_to_room.rpc(current_room + 1)

# ==============================================================================
# SUB-ROOM PROGRESSION (Phase 9 — MAP-01, MAP-02, MAP-03, D-08, D-10, D-11, D-12)
# ==============================================================================

## Phase 9 (D-03, MAP-07): Updates Camera2D.limit_* on all players to match the current sub-room bounds.
## Called on all peers after every sub-room build (call_local context — no RPC needed).
## Must be called AFTER _current_sub_room_rect_px is set.
func _update_all_camera_limits() -> void:
	for p in get_tree().get_nodes_in_group("players"):
		if is_instance_valid(p) and p.has_method("update_camera_limits"):
			p.update_camera_limits(_current_sub_room_rect_px)

## Phase 9 (D-08, D-10, MAP-01, MAP-02): Advance to the next sub-room within the current location.
## Called by host when _check_sub_room_clear() detects all enemies dead.
## If next == 6: build connector. If connector end reached: call _transition_to_room.rpc(next_room).
## T-09-03: @rpc("authority") — clients cannot trigger sub-room transitions.
@rpc("authority", "call_local", "reliable")
func _transition_to_sub_room(next: int) -> void:
	current_sub_room = next
	_connector_triggered = false
	var rect: Rect2
	if next == 6:
		## Phase 9 (D-11, D-13): Connector sub-room — no enemies, pure walking corridor.
		rect = _room_builder.build_connector(current_room, self)
	elif current_room == 3 and next == 5:
		## Phase 9 (D-09, MAP-03): Sub-room 5 of Room 3 is boss arena. Build tiles, then spawn boss.
		rect = _room_builder.build_sub_room(current_room, next, self)
	else:
		rect = _room_builder.build_sub_room(current_room, next, self)
	_current_sub_room_rect_px = rect
	## Phase 9 (D-03, MAP-07): Update camera limits for all players after sub-room transition.
	_update_all_camera_limits()
	## Teleport players to this sub-room's spawn points (already updated by build_sub_room)
	_teleport_players_to_spawn()
	## Bake navmesh for new sub-room geometry (host + all peers; bake is local)
	_bake_navigation.call_deferred()
	## Host-only post-transition: spawn enemies or boss
	if not multiplayer.is_server():
		return
	if current_room == 3 and next == 5:
		## Phase 9 (MAP-03): Boss arena — spawn boss, no normal enemies
		_spawn_boss.call_deferred()
	elif next < 6:
		## Normal sub-room: spawn enemy wave
		_spawn_enemies.call_deferred()
	## If next == 6 (connector): no enemies; host waits for player to reach corridor end via _process

## Phase 9 (D-08, MAP-02): Host checks if all enemies in current sub-room are dead.
## On clear: opens exit passage. Distinct from _check_room_clear which handles room transitions.
func _check_sub_room_clear() -> void:
	if not multiplayer.is_server():
		return
	if current_room == 3 and current_sub_room == 5:
		## Boss arena — handled by _on_boss_died; skip
		return
	if current_room == 3 and current_sub_room == 6:
		return
	var alive: int = 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.is_queued_for_deletion():
			continue
		var e_room: int = e.get_meta("room_id", current_room) if e.has_meta("room_id") else current_room
		if e_room == current_room:
			alive += 1
	if alive > 0:
		return
	## All enemies dead — open the exit passage
	## After sub-rooms 1–5 (including sub-room 5 for rooms 1 and 2), open exit passage
	_open_exit_passage.rpc()

## Phase 9 (D-08, MAP-02): Host-authoritative exit passage opening on all peers simultaneously.
## Removes the exit wall tiles from the TileMap and replaces them with floor tiles.
## T-09-04: @rpc("authority", "call_local") — clients cannot open passages unilaterally.
@rpc("authority", "call_local", "reliable")
func _open_exit_passage() -> void:
	var tm: TileMap = get_node_or_null("Room%d/TileMap" % current_room)
	if tm == null:
		return
	if _exit_tile_coords.is_empty():
		return
	var layout: Dictionary = RoomLayouts.SUB_ROOM_DATA[current_room][current_sub_room]
	var floor_tile: Vector2i = layout.get("floor_tile", Vector2i(0, 3))
	var src_id: int = layout.get("tileset_src", 0)
	for coord in _exit_tile_coords:
		tm.set_cell(0, coord, src_id, floor_tile)

## Phase 9: Teleports all players to the current sub-room's spawn points.
## Called on all peers by _transition_to_sub_room() and _transition_to_room() (call_local context).
func _teleport_players_to_spawn() -> void:
	var sp_node := get_node_or_null("Room%d/SpawnPoints" % current_room)
	if sp_node == null:
		return
	var spawn_pts: Array = sp_node.get_children()
	var players := get_tree().get_nodes_in_group("players")
	var fallback := Vector2(80, 80)  ## safe default if spawn data missing
	for idx in range(players.size()):
		if idx < spawn_pts.size():
			players[idx].global_position = spawn_pts[idx].global_position
		else:
			players[idx].global_position = fallback

# ==============================================================================
# BOSS SPAWN / MOB SWARM / LOOP ADVANCE (D-09, D-14–D-17, ROOM-05, ROOM-06, LOOP-03)
# Phase 8 Plan 03
# ==============================================================================

## D-09: Spawn the boss at Room 3 arena center. Host-only.
## Boss.tscn is pre-registered in EnemySpawner._ready (P7).
## Boss's died signal is connected to _on_boss_died in _do_spawn_enemy (Pitfall 5).
## T-08-02: host-only guard — clients cannot trigger boss spawns.
func _spawn_boss() -> void:
	if not multiplayer.is_server():
		return
	# Room 3 arena center — derived from the Burg Altenburg floor polygon centroid (~400,300)
	# Keep obstacle is at (400,220); spawn boss below it in the open courtyard area
	var boss_center := Vector2(400, 380)
	$EnemySpawner.spawn({"type": "boss", "pos": boss_center, "room_id": 3})

## D-14, D-15, D-16, ROOM-05, ROOM-06: Spawn a mob swarm at a boss phase transition.
## Called from Boss._enter_phase via call_deferred (physics-safe per RESEARCH pattern).
## Normal count: 5 + (loop_number × 3); elites: 1 normally, 2 in Phase 3 (D-15).
## Each elite spawn fires GameEvents.emit_hud.rpc("lidar") (ROOM-06).
## T-08-02: host-only guard — only host spawns enemies.
func _spawn_mob_swarm(boss_phase: int) -> void:
	if not multiplayer.is_server():
		return
	var swarm_points_node := get_node_or_null("Room3/EnemySpawnPoints")
	if swarm_points_node == null:
		return
	var swarm_pts: Array = swarm_points_node.get_children()
	if swarm_pts.is_empty():
		return
	# D-16: normal count scales with loop_number
	var normal_count: int = 5 + (GameState.loop_number * 3)
	# D-15: 1 elite normally; 2 elites in Phase 3 swarm
	var elite_count: int = 2 if boss_phase == 3 else 1
	# Spawn normal enemies at random swarm points
	for _i in range(normal_count):
		var pt: Vector2 = swarm_pts[randi() % swarm_pts.size()].global_position
		$EnemySpawner.spawn.call_deferred({"pos": pt, "room_id": 3})
	# Spawn elites — each fires LIDAR (D-15, ROOM-06)
	for _j in range(elite_count):
		var pt: Vector2 = swarm_pts[randi() % swarm_pts.size()].global_position
		$EnemySpawner.spawn.call_deferred({"type": "elite", "pos": pt, "room_id": 3})
		# D-15, ROOM-06: one LIDAR indicator per elite spawned (mirrors _spawn_elite_enemy at line ~593)
		GameEvents.emit_hud.rpc("lidar")

## D-17, LOOP-03: Boss defeated — advance the loop and return all clients to Room 1.
## Called from _do_spawn_enemy's boss died signal connection (Pitfall 5 compliance).
## Host-only — boss is host-authoritative and emits died only on host.
func _on_boss_died(_pos: Vector2) -> void:
	if not multiplayer.is_server():
		return
	# D-17: increment loop_number, reset revives_used (GameState.start_next_loop handles both)
	GameState.start_next_loop()
	# Transition all clients back to Room 1 for the new harder loop
	# _transition_to_room's Room-1 branch has no auto-spawn (only Room 2 and Room 3 do)
	# so we explicitly spawn Room 1 enemies for the new loop after transition
	_transition_to_room.rpc(1)
	# Spawn Room 1 enemies for the new loop (current_room will be 1 after the RPC)
	# call_deferred ensures the transition RPC (which runs call_local) sets current_room first
	_spawn_enemies.call_deferred()

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
	_hud_wave_label = Label.new()
	_hud_wave_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.25))
	vbox.add_child(_hud_wave_label)
	# Phase 7 Plan 03 (HUD-10, RESEARCH "Deprecated"): _hud_event_label removed — CarHUD
	# is now the sole HUD-event consumer. The old hud_event signal connection to _on_hud_event
	# has been removed; CarHUD.gd connects directly in its own _ready().
	# _hud_event_label node no longer created (CarHUD renders all indicator events instead).
	hud.add_child(panel)

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
	if _hud_wave_label != null:
		if current_room < 3:
			_hud_wave_label.text = "Welle  %d / %d" % [_display_wave, WAVES_PER_ROOM]
			_hud_wave_label.visible = true
		else:
			_hud_wave_label.visible = false

# ==============================================================================
# PLAYER SPAWNING (existing — unchanged)
# ==============================================================================

## Phase 8 Plan 03 (D-04): Generalized — reads active room's SpawnPoints.
## At loop start current_room == 1; after transition current_room is updated before this runs.
func _spawn_all_players() -> void:
	var spawn_points := get_node("Room%d/SpawnPoints" % current_room).get_children()
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

## Resets wave counter to 1, announces it to all peers, then spawns Wave 1.
## Called on game start (Room 1) and on each room entry that needs a normal wave.
## Room 3 skips wave entirely (boss-only, D-09) — caller must not invoke for Room 3.
func _spawn_enemies() -> void:
	_current_wave = 1
	_announce_wave.rpc(1)
	_spawn_wave()

## Spawns a wave of enemies scaled by the current wave number.
## Wave 1 = 50% of base, Wave 2 = 100%, Wave 3 = 150% + 1 elite (harder finish).
## Spawn points are shuffled each wave so enemies come from different directions.
func _spawn_wave() -> void:
	if not multiplayer.is_server():
		return
	if current_room == 3:
		return
	var pts: Array = Array(get_node("Room%d/EnemySpawnPoints" % current_room).get_children())
	if pts.is_empty():
		return
	var base_count: int = INITIAL_ENEMY_COUNT_R2 if current_room == 2 else INITIAL_ENEMY_COUNT
	var scaled_base: int = roundi(base_count * pow(1.5, GameState.loop_number - 1))
	# Wave 1=50%, Wave 2=100%, Wave 3=150% — linear ramp across three waves
	var wave_mult: float = 0.5 + (_current_wave - 1) * 0.5
	var spawn_count: int = maxi(2, roundi(scaled_base * wave_mult))
	pts.shuffle()
	for i in range(mini(spawn_count, pts.size())):
		$EnemySpawner.spawn({"pos": pts[i].global_position, "room_id": current_room})
	# Wave 3 always adds one elite to signal the final push
	if _current_wave == WAVES_PER_ROOM:
		var ep: Vector2 = pts[randi() % pts.size()].global_position
		$EnemySpawner.spawn({"type": "elite", "pos": ep, "room_id": current_room})
		GameEvents.emit_hud.rpc("lidar")

## Syncs the wave display counter to all peers and shows a brief centre banner.
@rpc("authority", "call_local", "reliable")
func _announce_wave(wave: int) -> void:
	_display_wave = wave
	_show_wave_banner(wave)

## Spawns a centred, auto-fading wave banner on the local peer's HUD.
func _show_wave_banner(wave: int) -> void:
	var hud := get_node_or_null("HUD")
	if hud == null:
		return
	# Remove any previous banner still fading
	var old := hud.get_node_or_null("WaveBanner")
	if old:
		old.queue_free()
	var lbl := Label.new()
	lbl.name = "WaveBanner"
	if wave == WAVES_PER_ROOM:
		lbl.text = "LETZTE WELLE!"
		lbl.add_theme_color_override("font_color", Color(1.0, 0.35, 0.2))
	else:
		lbl.text = "Welle  %d / %d" % [wave, WAVES_PER_ROOM]
		lbl.add_theme_color_override("font_color", Color(0.9, 0.85, 0.2))
	lbl.add_theme_font_size_override("font_size", 32)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.anchor_left   = 0.0;  lbl.anchor_right  = 1.0
	lbl.anchor_top    = 0.42; lbl.anchor_bottom = 0.58
	lbl.offset_left   = 0;    lbl.offset_right  = 0
	lbl.offset_top    = 0;    lbl.offset_bottom = 0
	hud.add_child(lbl)
	var tw := lbl.create_tween()
	tw.tween_interval(1.6)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.6)
	tw.tween_callback(lbl.queue_free)

func _do_spawn_enemy(data: Dictionary) -> Node:
	# Phase 7 Plan 03 (D-19, D-20): dispatch on type; elite uses ELITE_ENEMY_SCENE
	# Phase 8 Plan 03: boss type uses BOSS_SCENE (D-09, P7)
	var enemy_type: String = data.get("type", "")
	var scene: PackedScene
	match enemy_type:
		"elite": scene = ELITE_ENEMY_SCENE
		"boss":  scene = BOSS_SCENE
		_:       scene = ENEMY_SCENE
	var e := scene.instantiate()
	e.position = data["pos"]
	e.name = "Enemy_%d" % (randi() % 9999)
	# Phase 8 Plan 03 (D-04): Tag with room_id for room-clear filtering in _check_room_clear.
	# room_id passed in data dict; defaults to current_room if not specified.
	e.set_meta("room_id", data.get("room_id", current_room))
	# Phase 7 Plan 03 (D-19, D-20, D-21): Apply difficulty scaling at spawn time.
	# For normal enemies: scaling applied here before add_to_tree (Enemy._ready() does not reset stats).
	# For elite enemies: EliteEnemy._ready() applies its own scaling after calling super._ready()
	#   (see EliteEnemy.gd _ready). Setting mult here would be overwritten by EliteEnemy._ready()
	#   so only normal enemies receive the scaling multiplication in this function.
	# Phase 8 Plan 03 (D-11): Boss applies its own loop scaling in _ready() — exclude boss too.
	# At loop_number=1: mult=1.0 → no change (baseline preserved, Pitfall 6).
	if enemy_type != "elite" and enemy_type != "boss":
		var mult: float = 1.0 + (GameState.loop_number - 1) * 0.25
		e.MAX_HP = int(e.MAX_HP * mult)
		e.CONTACT_DAMAGE = int(e.CONTACT_DAMAGE * mult)
		e.current_hp = e.MAX_HP
	# CMBT-08: Connect died signal appropriately
	# Phase 8 Plan 03 (Pitfall 5): boss death takes boss-specific path, NOT generic respawn path
	if enemy_type == "boss":
		e.died.connect(_on_boss_died)
	else:
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
	# Immediate respawn removed: conflicted with _check_room_clear (count never reached 0).
	# Phase 8 Plan 03 (D-02): After each enemy death, check if the room is cleared.
	# call_deferred so queue_free finishes before we count living enemies.
	_check_room_clear.call_deferred()
	## Phase 9 (D-08, MAP-02): Also check if current sub-room is cleared.
	_check_sub_room_clear.call_deferred()

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
		"fire_burst": force_burn,
		"damage_mult": player_node.stage3_damage_mult
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
	b.damage_mult = data.get("damage_mult", 1.0)
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
		# Phase 7 Plan 03 (HLTH-07, D-22): Revive limit — at most once per loop per player.
		# Check runs host-side (attempt_revive already guards is_server() above).
		# Silent fail: target stays downed, no error text (D-22, UI-SPEC).
		if GameState.revives_used.get(target_id, 0) >= 1:
			_update_revive_bar(target_id, 0.0)  # WR-01: reset bar so reviver sees failure, not a stuck 100%
			return  # silently blocked — player already revived once this loop
		# Increment BEFORE calling receive_revive (host-side, safe from client tampering — T-07-08)
		GameState.revives_used[target_id] = GameState.revives_used.get(target_id, 0) + 1
		# receive_revive is @rpc("any_peer", "call_remote", "reliable") on Player.gd.
		# call_remote is a no-op when sender == receiver (host cannot rpc to itself).
		# Mirror the heal/damage pattern (Enemy.gd lines 135-138, _tick_engineer_passive):
		# call directly on host player, use rpc_id for remote peers (CR-01 fix).
		if target.peer_id == multiplayer.get_unique_id():
			target.receive_revive()   # host player: direct call (call_remote is no-op to self)
		else:
			target.receive_revive.rpc_id(target.peer_id)

## Phase 7 Plan 03 (HUD-06, D-09, T-07-07): Host-routed SUSPENSION indicator trigger.
## Called by Player.receive_damage on the owning peer when delivered damage >= 15.
## Pattern: mirrors confirm_card_pick (any_peer + is_server() guard + host broadcast).
## T-07-07: @rpc("any_peer","call_remote","reliable") allows client-owned players to notify
## host; host validates by guard and emits the broadcast — clients cannot emit directly.
@rpc("any_peer", "call_remote", "reliable")
func notify_significant_hit() -> void:
	if not multiplayer.is_server():
		return  # host-only guard (T-07-07: client request received, host decides to broadcast)
	# Host is authority for GameEvents.emit_hud (D-07, Pitfall 1 in RESEARCH.md)
	GameEvents.emit_hud.rpc("suspension")

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
# CARD PICK (XP-02, XP-08 — Phase 6 Plan 03)
# ==============================================================================

## Phase 6 (XP-02, XP-08, P8): Client owning peer sends card pick index → host validates → applies effect.
## Mirrors attempt_revive pattern: "any_peer" + is_server() guard + peer lookup by peer_id.
@rpc("any_peer", "call_remote", "reliable")
func confirm_card_pick(_unused_peer_id: int, card_index: int) -> void:
	if not multiplayer.is_server():
		return
	# CR-03: use actual sender identity — never trust the client-supplied peer ID
	var requester_peer_id: int = multiplayer.get_remote_sender_id()
	if requester_peer_id == 0:
		requester_peer_id = multiplayer.get_unique_id()  # host calling locally
	var player_node: Node = null
	for p in get_tree().get_nodes_in_group("players"):
		if p.peer_id == requester_peer_id:
			player_node = p
			break
	if player_node == null:
		return
	if not player_node.is_picking_card:
		return  # race-condition guard: already confirmed
	# Rebuild pool on host to validate index (P8: host re-validates card eligibility)
	var pool: Array = _build_card_pool_for_player(player_node)
	if card_index < 0 or card_index >= pool.size():
		card_index = 0  # fallback to first card
	_apply_card_effect(requester_peer_id, player_node, pool[card_index])
	if requester_peer_id == multiplayer.get_unique_id():
		_card_pick_complete()
	else:
		_card_pick_complete.rpc_id(requester_peer_id)

## Phase 6: Rebuild card pool on the host side for validation.
## Reads synced weapon_level, unlocked_weapons, element_tier from Player node.
func _build_card_pool_for_player(player_node: Node) -> Array:
	var pool: Array = []
	var wm: Node = player_node.get_node_or_null("WeaponManager")
	if wm:
		for wid in ["exhaust_flames", "spinning_tires", "antenna_beam", "horn_shockwave", "airbag_shield"]:
			if not wm.unlocked_weapons.has(wid):
				if wm.unlocked_weapons.size() < wm.MAX_WEAPONS:
					pool.append({"type": "weapon_unlock", "weapon_id": wid})
		for wid in wm.unlocked_weapons:
			var lvl: int = wm.weapon_level.get(wid, 1)
			if lvl < 3:
				pool.append({"type": "weapon_upgrade", "weapon_id": wid, "new_level": lvl + 1})
	if player_node.element_tier < 3:
		pool.append({"type": "element_upgrade", "new_tier": player_node.element_tier + 1})
	for stat in ["Speed", "Max HP", "Damage"]:
		pool.append({"type": "stat_boost", "stat": stat, "amount": 10})
	if pool.size() == 0:
		pool.append({"type": "fallback"})
	return pool

## Phase 6: Apply the selected card's effect on the owning peer. Host-only.
func _apply_card_effect(peer_id: int, player_node: Node, card: Dictionary) -> void:
	match card.get("type", ""):
		"weapon_unlock":
			if peer_id == multiplayer.get_unique_id():
				weapon_unlocked(card["weapon_id"], peer_id)
			else:
				weapon_unlocked.rpc_id(peer_id, card["weapon_id"], peer_id)
		"weapon_upgrade":
			var wm := player_node.get_node_or_null("WeaponManager")
			if wm:
				if peer_id == multiplayer.get_unique_id():
					wm.upgrade_weapon(card["weapon_id"])
				else:
					wm.upgrade_weapon.rpc_id(peer_id, card["weapon_id"])
		"element_upgrade":
			if peer_id == multiplayer.get_unique_id():
				player_node.receive_element_tier_up()
			else:
				player_node.receive_element_tier_up.rpc_id(peer_id)
		"stat_boost":
			if peer_id == multiplayer.get_unique_id():
				_apply_stat_boost_rpc(card.get("stat", ""), card.get("amount", 10))
			else:
				_apply_stat_boost_rpc.rpc_id(peer_id, card.get("stat", ""), card.get("amount", 10))
		"fallback":
			if peer_id == multiplayer.get_unique_id():
				_apply_stat_boost_rpc("Damage", 5)
			else:
				_apply_stat_boost_rpc.rpc_id(peer_id, "Damage", 5)

## Phase 6 (XP-08): Apply stat boost to the owning peer. Runs on owning peer via rpc_id.
@rpc("authority", "call_remote", "reliable")
func _apply_stat_boost_rpc(stat: String, amount: int) -> void:
	# Find local player node (owning peer)
	var local_id := multiplayer.get_unique_id()
	for p in get_tree().get_nodes_in_group("players"):
		if p.peer_id == local_id:
			match stat:
				"Speed":      p.SPEED += int(float(p.SPEED) * float(amount) / 100.0)
				"Max HP":     p.MAX_HP += int(float(p.MAX_HP) * float(amount) / 100.0)
				"Damage":     p.stage3_damage_mult += float(amount) / 100.0
				"Cooldown":   pass  # TODO Phase 7: cooldown reduction not yet wired
			return

## Phase 6: Signal owning peer that card pick is complete — clear overlay and flag.
@rpc("authority", "call_remote", "reliable")
func _card_pick_complete() -> void:
	# Runs on the owning peer
	var local_id := multiplayer.get_unique_id()
	for p in get_tree().get_nodes_in_group("players"):
		if p.peer_id == local_id:
			p.is_picking_card = false
			if p.has_node("CardOverlay"):
				p.get_node("CardOverlay").hide_overlay()
			if p.has_method("_update_xp_hud"):
				p._update_xp_hud()
			return

# ==============================================================================
# ENGINEER HEAL DRONE (ROLE-07, ROLE-08, ROLE-09 — Phase 5 Plan 03)
# ==============================================================================

## P8: host runs Engineer passive + Earth effects + elite spawn; all peers update local HUD.
## Phase 9: host also checks connector exit detection.
func _process(delta: float) -> void:
	if multiplayer.is_server():
		_tick_engineer_passive(delta)
		_tick_earth_effects(delta)
		# Phase 7 Plan 03 (D-13, HUD-07): Elite enemy spawn timer tick (host-only)
		_tick_elite_spawn(delta)
		## Phase 9 (D-12): Connector corridor exit detection — when player reaches right edge,
		## transition to the next location. Guard with _connector_triggered to prevent double-trigger.
		if current_sub_room == 6 and not _connector_triggered:
			for p in get_tree().get_nodes_in_group("players"):
				if is_instance_valid(p) and p.global_position.x >= _current_sub_room_rect_px.end.x - RoomLayouts.TILE_SIZE * 4:
					_connector_triggered = true
					_transition_to_room.rpc(current_room + 1)
					break
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

## Phase 7 Plan 03 (D-13, HUD-07): Host-only elite enemy spawn timer.
## Mirrors _tick_engineer_passive pattern (Game.gd lines 462-468).
## Accumulates delta; when interval reached, spawns one elite at a random spawn point.
## Interval resets to a new randf_range(45, 90) value after each spawn.
func _tick_elite_spawn(delta: float) -> void:
	_elite_spawn_timer += delta
	if _elite_spawn_timer < _elite_spawn_interval:
		return
	_elite_spawn_timer = 0.0
	_elite_spawn_interval = randf_range(45.0, 90.0)
	_spawn_elite_enemy()

## Phase 7 Plan 03 (D-13, HUD-07): Spawn one elite enemy at a random EnemySpawnPoint.
## Uses call_deferred to avoid "Can't change state while flushing queries" (Pitfall, Game.gd lines 196-205).
## Fires LIDAR on all peers via emit_hud.rpc (D-10, HUD-07; host is authority so RPC is valid).
func _spawn_elite_enemy() -> void:
	# Phase 8 Plan 03 (D-04): Use current room's EnemySpawnPoints; skip in Room 3 (boss-only, D-09)
	if current_room == 3:
		return
	var points := get_node("Room%d/EnemySpawnPoints" % current_room).get_children()
	if points.is_empty():
		return
	var pos: Vector2 = points[randi() % points.size()].global_position
	# call_deferred — physics-safe spawn (mirrors _on_enemy_died call_deferred pattern)
	$EnemySpawner.spawn.call_deferred({"type": "elite", "pos": pos, "room_id": current_room})
	# LIDAR fires only on elite spawn (D-10, D-13) — host-only emit, valid as authority RPC
	GameEvents.emit_hud.rpc("lidar")

## ROLE-08: Client Engineer requests drone deploy → host validates + spawns.
## Max 2 active drones per engineer; blocks silently when cap is reached.
@rpc("any_peer", "call_remote", "reliable")
func request_deploy_drone(requester_peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	# Count drones currently owned by this engineer
	# Phase 8 Plan 01: DroneSpawner spawn_path now points to shared Game-root Entities node
	var entities := get_node_or_null("Entities")
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
	GameEvents.emit_hud.rpc("ac")  # CR-03: must use .rpc() so client CarHUDs receive the event

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
## Phase 6 D-21: heal rate and shockwave cooldown scale with element_tier.
func _tick_earth_effects(delta: float) -> void:
	# Collect all alive Earth players — effects active when at least one exists
	var earth_players: Array = []
	for p in get_tree().get_nodes_in_group("players"):
		if p.element == "earth" and not p.is_downed:
			earth_players.append(p)
	if earth_players.is_empty():
		return

	# D-21: Use highest element_tier among alive Earth players for tier-scaled values
	var element_tier: int = 1
	for ep in earth_players:
		element_tier = maxi(element_tier, ep.element_tier)
	element_tier = clamp(element_tier, 1, 3)
	# D-21 tier arrays: index by tier (T1=2 HP/s, T2=4, T3=6; cooldown T1=8s, T2=6s, T3=5s)
	var heal_rate: int = [2, 2, 4, 6][element_tier]
	var sw_cooldown: float = [8.0, 8.0, 6.0, 5.0][element_tier]

	# --- ELEM-05: Team Heal scaled by element_tier HP/sec to ALL players (no proximity) ---
	_earth_heal_accum += delta
	if _earth_heal_accum >= 1.0:
		_earth_heal_accum = 0.0
		for target in get_tree().get_nodes_in_group("players"):
			if target.is_downed:
				continue
			# Pitfall 6: direct call on host peer, rpc_id for remote peers (T-05-17)
			if target.peer_id == multiplayer.get_unique_id():
				target.receive_heal(heal_rate)
			else:
				target.receive_heal.rpc_id(target.peer_id, heal_rate)
		# ELEM-07: Earth heal fires SEAT MASSAGE HUD (T-05-18: host-only emit)
		GameEvents.emit_hud.rpc("seat_massage")  # CR-03: .rpc() broadcasts to all client CarHUDs

	# --- ELEM-06: Shockwave at element_tier-scaled interval — knockback + 15 damage ---
	_earth_shock_accum += delta
	if _earth_shock_accum >= sw_cooldown:
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
					# D-21 Tier 3: shockwave also briefly slows enemies (×0.5 for 1s)
					if element_tier >= 3 and is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
						enemy.velocity *= 0.5
						get_tree().create_timer(1.0).timeout.connect(func():
							if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
								enemy.velocity *= 2.0
						)
		# ELEM-07: Earth shockwave fires SEAT MASSAGE HUD (T-05-18: host-only, one emit per wave)
		GameEvents.emit_hud.rpc("seat_massage")  # CR-03: .rpc() broadcasts to all client CarHUDs

## D-19 (ELEM-06): Broadcast expanding green ring visual to all peers.
## Clone of HornShockwave._show_visual with RADIUS=120 and Earth green color.
## call_local so host also renders the ring.
@rpc("authority", "call_local", "unreliable_ordered")
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
