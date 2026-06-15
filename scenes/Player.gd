extends CharacterBody2D
## Player movement controller — handles WASD input, wall collision, health, downed state, revive.
## P3: All input handling guarded by is_multiplayer_authority().
## P4: MultiplayerSynchronizer replicates position, health, is_downed at 20 Hz (interval = 0.05).
## D-17: health and is_downed synced via MultiplayerSynchronizer from owning peer.
## Pitfall 3: receive_damage is @rpc("any_peer") so host (any_peer) calls rpc_id(peer_id) —
##   owning peer decrements health, MultiplayerSynchronizer replicates outward.

var SPEED: float = 200.0
var MAX_HP: int = 100
const REVIVE_DURATION: float = 3.5   # D-13: 3-4 seconds
const REVIVE_PROXIMITY: float = 60.0 # pixels — must be within this range to revive

## Phase 5 Plan 02: Tank shield constants (D-08, D-09)
const TANK_SHIELD_S1: float = 3.0      # Stage-1 shield duration (seconds)
const TANK_SHIELD_S2: float = 6.0      # Stage-2 shield duration (seconds)
const TANK_SHIELD_COOLDOWN: float = 8.0 # cooldown after shield expires
const TANK_REFLECT_PCT: float = 0.5    # Stage-2: reflect 50% of blocked damage
const TANK_REFLECT_MIN: int = 5        # Stage-2: minimum reflection damage

## Phase 5 Plan 02: Speedster dash constants (D-11, D-12)
const DASH_DURATION: float = 0.3       # dash speed-burst and i-frame duration
const DASH_MULT: float = 3.0           # velocity multiplier during dash
const DASH_COOLDOWN: float = 4.0       # cooldown after dash
const DASH_WINDOW: float = 0.8         # double-dash availability window (Stage-2)
const DASH_SHOCK_RADIUS: float = 80.0  # shockwave Area2D radius (Stage-2 second dash)
const DASH_SHOCK_DAMAGE: int = 25      # shockwave damage to enemies

@export var peer_id: int = 0
@export var role_label: String = ""

## D-17: replicated via MultiplayerSynchronizer SceneReplicationConfig
var health: int = MAX_HP
var is_downed: bool = false

## Phase 5: Role/element/ability state
var evolution_stage: int = 1        # D-04: Phase 6 sets via RPC when XP threshold reached
var element: String = ""            # D-03: "fire" | "ice" | "earth" | ""
var shield_active: bool = false     # D-08/D-09: Tank shield active flag (replicated)
var dash_invincible: bool = false   # D-11: Speedster invincibility frames flag (replicated)
var _ability_cooldown: float = 0.0  # D-06: single ability cooldown timer
var _dash_window_timer: float = 0.0 # D-12: Speedster double-dash window
var _ice_trail_timer: float = 0.0   # D-18: Ice Trail spawn interval
var _fire_burst_timer: float = 0.0  # D-17: Fire Burst auto-fire interval
var _earth_heal_timer: float = 0.0  # D-19: Earth Team Heal tick interval
var _earth_shockwave_timer: float = 0.0  # D-19: Earth Shockwave interval
var _engineer_passive_timer: float = 0.0 # D-13: Engineer passive heal tick interval

## Phase 5 Plan 02: Tank shield state
var _shield_timer: float = 0.0          # counts down active shield duration
var _shield_ring: ColorRect = null       # reusable outer ring node (created on first show)
var _last_attacker_path: String = ""     # attacker NodePath for Stage-2 reflection

## Phase 5 Plan 02: Speedster dash state
var _dash_timer: float = 0.0            # counts down i-frame duration after dash

func _ready() -> void:
	# Set authority based on peer_id — only the owning peer controls this player
	set_multiplayer_authority(peer_id)
	# Required for enemy group discovery and game-over check
	add_to_group("players")
	# Update role label display (MOVE-04)
	if has_node("RoleLabel"):
		$RoleLabel.text = role_label
	# Phase 5: Apply role-specific stats and read element from Lobby
	_apply_role_stats()
	element = Lobby.players.get(peer_id, {}).get("element", "")
	# Phase 5: Initialise element/ability timers so they don't fire immediately
	_fire_burst_timer = 4.0
	_earth_shockwave_timer = 8.0
	_earth_heal_timer = 1.0
	_engineer_passive_timer = 5.0

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
	# D-08: Delegate all weapon firing to WeaponManager (ScrewsAndBolts + future weapons)
	if has_node("WeaponManager"):
		$WeaponManager.tick(delta)
	# Phase 5: Role ability cooldown + Space input dispatch
	_tick_ability(delta)
	# Phase 5: Passive element timers (Ice Trail, Fire Burst, Earth heal/shockwave)
	_tick_element(delta)
	# HLTH-05: Check revive input (R key) each frame
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

## Phase 5: Apply role-specific stat overrides (D-05). Called from _ready() on all peers.
func _apply_role_stats() -> void:
	match role_label:
		"Tank":
			MAX_HP = 150
			health = 150   # D-07: Tank spawns with 150 HP (ROLE-01)
		"Speedster":
			SPEED = 280    # D-10: Speedster moves faster (ROLE-04)
		"Engineer":
			pass           # HP and SPEED stay at default 100 / 200 (D-05)

## Phase 5: Ability cooldown timer and Space key dispatch (D-06, Pattern 2).
## Runs only on the authority (owning) peer — guarded by _physics_process P3 check.
func _tick_ability(delta: float) -> void:
	if _ability_cooldown > 0.0:
		_ability_cooldown -= delta
	if _dash_window_timer > 0.0:
		_dash_window_timer -= delta
	# Tank shield countdown — expire when timer reaches zero
	if _shield_timer > 0.0:
		_shield_timer -= delta
		if _shield_timer <= 0.0:
			shield_active = false
			_hide_shield_ring()
	# Speedster dash i-frame countdown
	if _dash_timer > 0.0:
		_dash_timer -= delta
		if _dash_timer <= 0.0:
			dash_invincible = false
	if Input.is_action_just_pressed("role_ability"):
		if _ability_cooldown <= 0.0:
			_use_role_ability()
		elif role_label == "Speedster" and _dash_window_timer > 0.0:
			_use_second_dash()

## Phase 5: Stage gate dispatch — routes to Stage-1 or Stage-2 based on evolution_stage (D-20).
func _use_role_ability() -> void:
	if evolution_stage >= 2:
		_use_stage2_ability()
	else:
		_use_stage1_ability()

## Phase 5: Stage-1 abilities — Tank shield, Speedster dash, Engineer drone deploy (D-08, D-11, D-14).
func _use_stage1_ability() -> void:
	match role_label:
		"Tank":
			# D-08: 3-second full damage shield; cooldown starts after shield expires
			_activate_shield(TANK_SHIELD_S1)
			_ability_cooldown = TANK_SHIELD_S1 + TANK_SHIELD_COOLDOWN  # 11.0 s total
		"Speedster":
			# D-11: 0.3-second speed burst with invincibility frames; 4-second cooldown
			_do_dash()
			_ability_cooldown = DASH_COOLDOWN
		"Engineer":
			# D-14: Request host to deploy a Heal Drone at current position
			var game := get_node_or_null("/root/Game")
			if game and game.has_method("request_deploy_drone"):
				if multiplayer.is_server():
					game.request_deploy_drone(peer_id)
				else:
					game.request_deploy_drone.rpc_id(1, peer_id)
			_ability_cooldown = 1.0  # short re-deploy guard

## Phase 5: Stage-2 abilities — Tank Stage-2 shield + reflect, Speedster double-dash, Engineer Stage-2 drone (D-09, D-12, D-15).
func _use_stage2_ability() -> void:
	match role_label:
		"Tank":
			# D-09: 6-second shield + Stage-2 reflection; cooldown starts after shield expires
			_activate_shield(TANK_SHIELD_S2)
			_ability_cooldown = TANK_SHIELD_S2 + TANK_SHIELD_COOLDOWN  # 14.0 s total
		"Speedster":
			# D-12: First dash of double-dash sequence; opens second-dash window
			_do_dash()
			_dash_window_timer = DASH_WINDOW  # 0.8 s window for second dash
			_ability_cooldown = DASH_COOLDOWN  # reset if window lapses unused
		"Engineer":
			# D-15: Stage-2 drone follows Engineer — Game.gd reads evolution_stage to upgrade
			var game := get_node_or_null("/root/Game")
			if game and game.has_method("request_deploy_drone"):
				if multiplayer.is_server():
					game.request_deploy_drone(peer_id)
				else:
					game.request_deploy_drone.rpc_id(1, peer_id)
			_ability_cooldown = 1.0  # short re-deploy guard

## Phase 5: Speedster Stage-2 second-dash — triggers shockwave landing (D-12).
## Called when Space pressed during _dash_window_timer > 0.0.
func _use_second_dash() -> void:
	_do_dash()
	_spawn_dash_shockwave(global_position)
	_dash_window_timer = 0.0  # close the window — sequence complete

## Phase 5 Plan 04: Passive element timer tick — Fire Burst auto-fire + Ice Trail spawn request.
## Runs inside _physics_process which is already authority-guarded — only owning peer ticks.
## D-17 (ELEM-02): Fire Burst every 4s at nearest enemy with force_burn flag.
## D-18 (ELEM-04): Ice Trail zone requested every 0.3s while moving (velocity.length() >= 10).
func _tick_element(delta: float) -> void:
	match element:
		"fire":
			# D-17 (ELEM-02): Fire Burst auto-fire timer (4s cooldown — Claude's discretion)
			_fire_burst_timer -= delta
			if _fire_burst_timer <= 0.0:
				_fire_burst_timer = 4.0
				_fire_burst()
		"ice":
			# D-18 (ELEM-04): Ice Trail — only while moving (velocity threshold)
			if velocity.length() < 10.0:
				return  # idle — no trail spawned
			_ice_trail_timer -= delta
			if _ice_trail_timer <= 0.0:
				_ice_trail_timer = 0.3
				var game := get_node_or_null("/root/Game")
				if game and game.has_method("request_ice_trail"):
					if multiplayer.is_server():
						game.request_ice_trail(global_position)
					else:
						game.request_ice_trail.rpc_id(1, global_position)

## D-17 (ELEM-02): Fire Burst — auto-fire 3-5 projectiles at nearest enemy with 100% burn proc.
## Modelled on WeaponManager._fire_screws() lines 51-69. Fires on the owning peer's authority;
## host spawns directly, client sends request_fire RPC. "fire_burst": true in dict so Plan 05
## _do_spawn_bullet extension can set force_burn on the spawned bullet.
func _fire_burst() -> void:
	var nearest := _find_nearest_enemy_global()
	if nearest == null:
		return
	var base_dir: Vector2 = (nearest.global_position - global_position).normalized()
	var game := get_node_or_null("/root/Game")
	if game == null:
		return
	var count: int = randi_range(3, 5)
	for i in range(count):
		var spread: Vector2 = base_dir.rotated(randf_range(-0.3, 0.3))
		if multiplayer.is_server():
			if game.has_node("BulletSpawner"):
				game.get_node("BulletSpawner").spawn({
					"pos": global_position,
					"dir": spread,
					"owner_id": peer_id,
					"fire_burst": true   # Plan 05 _do_spawn_bullet sets b.force_burn = true
				})
		else:
			if game.has_method("request_fire"):
				game.request_fire.rpc_id(1, global_position, spread, peer_id, true)
	# ELEM-07: HUD event — host-only (T-05-14 mitigation)
	if multiplayer.is_server():
		GameEvents.emit_hud("engine")

## Helper: find the nearest enemy node in group "enemies" using global_position.
## Cloned from WeaponManager._find_nearest_enemy but operates on self.global_position.
func _find_nearest_enemy_global() -> Node:
	var nearest: Node = null
	var nearest_dist: float = INF
	for e in get_tree().get_nodes_in_group("enemies"):
		var d: float = global_position.distance_to(e.global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = e
	return nearest

# ──────────────────────────────────────────────────────────────────────────────
# Plan 02 helpers — Tank shield
# ──────────────────────────────────────────────────────────────────────────────

## Activate the Tank damage shield for the given duration.
## Sets shield_active (replicated via MultiplayerSynchronizer) and shows the blue ring.
func _activate_shield(duration: float) -> void:
	shield_active = true
	_shield_timer = duration
	_show_shield_ring()

## Show (or create) the blue hollow-ring visual around the player.
## Mirrors AirbagShield.gd ring construction; blue instead of yellow.
func _show_shield_ring() -> void:
	const RING_RADIUS: float = 32.0
	const RING_THICKNESS: float = 5.0
	if _shield_ring == null:
		# Create once; reuse on subsequent activations
		_shield_ring = ColorRect.new()
		_shield_ring.name = "TankShieldRing"
		_shield_ring.color = Color(0.3, 0.6, 1.0, 0.85)  # blue (not yellow like AirbagShield)
		var outer_size: float = (RING_RADIUS + RING_THICKNESS) * 2.0
		_shield_ring.size = Vector2(outer_size, outer_size)
		_shield_ring.pivot_offset = Vector2(outer_size / 2.0, outer_size / 2.0)
		_shield_ring.position = Vector2(-outer_size / 2.0, -outer_size / 2.0)
		var ring_inner := ColorRect.new()
		ring_inner.name = "TankShieldRingInner"
		ring_inner.color = Color(0, 0, 0, 0)  # transparent cutout
		var inner_size: float = RING_RADIUS * 2.0
		ring_inner.size = Vector2(inner_size, inner_size)
		ring_inner.position = Vector2(RING_THICKNESS, RING_THICKNESS)
		_shield_ring.add_child(ring_inner)
		add_child(_shield_ring)
	_shield_ring.visible = true

## Hide the shield ring when the shield expires.
func _hide_shield_ring() -> void:
	if _shield_ring and is_instance_valid(_shield_ring):
		_shield_ring.visible = false

## Stage-2 shield reflection — compute reflect amount and route to host.
## Pitfall 3: enemy.take_damage() is host-only; must send RPC to host if we're a client.
func _request_reflect(amount: int, attacker_path: String) -> void:
	if attacker_path == "":
		return  # no attacker info — reflection skipped (best-effort per deferred scope)
	var reflect_amount: int = maxi(int(amount * TANK_REFLECT_PCT), TANK_REFLECT_MIN)
	if multiplayer.is_server():
		request_reflect(attacker_path, reflect_amount)
	else:
		request_reflect.rpc_id(1, attacker_path, reflect_amount)

## Host-side RPC: resolve attacker path and apply reflected damage to the enemy.
## T-05-04 mitigation: only host runs enemy.take_damage (Enemy.take_damage also self-guards).
@rpc("any_peer", "call_remote", "reliable")
func request_reflect(attacker_path: String, reflect_amount: int) -> void:
	if not multiplayer.is_server():
		return
	var enemy := get_node_or_null(attacker_path)
	if enemy and enemy.has_method("take_damage"):
		enemy.take_damage(reflect_amount)

# ──────────────────────────────────────────────────────────────────────────────
# Plan 02 helpers — Speedster dash
# ──────────────────────────────────────────────────────────────────────────────

## Apply a burst of velocity in the current input direction with i-frames active.
## Sets dash_invincible (replicated) and _dash_timer for duration countdown.
func _do_dash() -> void:
	dash_invincible = true
	_dash_timer = DASH_DURATION
	var dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT  # fallback direction when no input held
	velocity = dir * SPEED * DASH_MULT
	move_and_slide()  # apply burst immediately

## Spawn the Speedster Stage-2 shockwave at the landing position.
## Visual: yellow expanding ring (clone of HornShockwave._show_visual, RADIUS=80, yellow).
## Damage: host-only, enemies within DASH_SHOCK_RADIUS take DASH_SHOCK_DAMAGE + knockback.
func _spawn_dash_shockwave(pos: Vector2) -> void:
	_show_dash_shockwave.rpc(pos)  # call_local via annotation — visual on all peers
	if not multiplayer.is_server():
		return
	# Host-only: apply damage and knockback to enemies within radius (T-05-05 mitigation)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.global_position.distance_to(pos) <= DASH_SHOCK_RADIUS:
			if enemy.has_method("take_damage"):
				enemy.take_damage(DASH_SHOCK_DAMAGE)
			# Knockback: push enemy away from shockwave origin
			# CR-005: guard against freed enemy (take_damage may queue_free if enemy dies)
			if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
				continue
			enemy.velocity += (enemy.global_position - pos).normalized() * 300.0

## Visual-only RPC for Speedster shockwave ring — yellow, 80px radius.
## Mirrors HornShockwave._show_visual exactly; no game-state mutation.
@rpc("any_peer", "call_local", "unreliable_ordered")
func _show_dash_shockwave(pos: Vector2) -> void:
	const RADIUS: float = 80.0
	var game := get_node_or_null("/root/Game")
	if game == null:
		return
	var ring := ColorRect.new()
	ring.color = Color(1.0, 1.0, 0.0, 0.8)  # yellow (Speedster shockwave — Claude's discretion)
	ring.size = Vector2(RADIUS * 2.0, RADIUS * 2.0)
	ring.pivot_offset = Vector2(RADIUS, RADIUS)
	ring.position = pos - Vector2(RADIUS, RADIUS)
	ring.scale = Vector2(0.1, 0.1)
	game.add_child(ring)
	var tween := ring.create_tween()
	tween.tween_property(ring, "scale", Vector2(2.0, 2.0), 0.35)
	tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.35)
	tween.tween_callback(ring.queue_free)

## HLTH-02 / Pitfall 3: Called via rpc_id(peer_id) from host (Enemy.gd or Bullet.gd).
## Uses @rpc("any_peer") because the host (peer 1) is NOT the node's multiplayer authority
## (authority = owning peer via set_multiplayer_authority). "any_peer" allows host to send
## this RPC to the owning peer. Owning peer applies damage to own health —
## MultiplayerSynchronizer then replicates health outward to all clients.
## Plan 02: attacker_path optional param added (Open Question 3) — callers may omit it;
##   reflection is best-effort and skipped when path is empty.
@rpc("any_peer", "call_remote", "reliable")
func receive_damage(amount: int, attacker_path: String = "") -> void:
	print("receive_damage called! hp=", health, " -> ", health - amount)
	# Plan 02 D-11: Speedster i-frames ignore ALL damage (checked before everything else)
	if dash_invincible:
		return
	# D-13: Airbag Shield intercepts lethal hits — absorb hit, health stays at 1, charge consumed
	if health - amount <= 0 and has_node("WeaponManager") and $WeaponManager.airbag_active:
		health = 1
		$WeaponManager.consume_airbag()
		print("Airbag absorbed lethal hit! hp=1")
		return
	# Plan 02 D-08/D-09: Tank shield intercept — block all damage while active
	if shield_active:
		_last_attacker_path = attacker_path
		if evolution_stage >= 2:
			# Stage-2: reflect 50% (min 5) of blocked damage back to attacker via host
			_request_reflect(amount, attacker_path)
		return  # block damage regardless of stage
	health -= amount
	print("receive_damage done! hp=", health)
	if health <= 0:
		health = 0
		_enter_downed()

## Phase 5: Heal this player by amount, clamped to MAX_HP (Pattern 6).
## Called by host via rpc_id(peer_id, amount) for Engineer passive, Earth heal, Drone pulse.
@rpc("any_peer", "call_remote", "reliable")
func receive_heal(amount: int) -> void:
	if is_downed:
		return
	health = mini(health + amount, MAX_HP)

## Phase 5: Set evolution stage (D-04/D-20). Called by Phase 6 when XP threshold reached.
@rpc("any_peer", "call_remote", "reliable")
func set_evolution_stage(stage: int) -> void:
	evolution_stage = stage

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

## Called by Game.gd attempt_revive when revive duration is complete.
## @rpc("any_peer") allows host (any_peer) to send this to the owning peer.
## Owning peer calls revive() locally — health and is_downed sync outward via
## MultiplayerSynchronizer.
@rpc("any_peer", "call_remote", "reliable")
func receive_revive() -> void:
	revive()
