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

## Phase 5: Stage-1 ability stub — filled by Plan 05-02 (Tank/Speedster/Engineer).
func _use_stage1_ability() -> void:
	pass

## Phase 5: Stage-2 ability stub — filled by Plan 05-02.
func _use_stage2_ability() -> void:
	pass

## Phase 5: Speedster second-dash stub — filled by Plan 05-02.
func _use_second_dash() -> void:
	pass

## Phase 5: Passive element timer tick stub — filled by Plan 05-04 (Fire/Ice/Earth elements).
## Handles Ice Trail spawn, Fire Burst auto-fire, Earth heal/shockwave timers.
func _tick_element(_delta: float) -> void:
	pass

## HLTH-02 / Pitfall 3: Called via rpc_id(peer_id) from host (Enemy.gd or Bullet.gd).
## Uses @rpc("any_peer") because the host (peer 1) is NOT the node's multiplayer authority
## (authority = owning peer via set_multiplayer_authority). "any_peer" allows host to send
## this RPC to the owning peer. Owning peer applies damage to own health —
## MultiplayerSynchronizer then replicates health outward to all clients.
@rpc("any_peer", "call_remote", "reliable")
func receive_damage(amount: int) -> void:
	print("receive_damage called! hp=", health, " -> ", health - amount)
	# D-13: Airbag Shield intercepts lethal hits — absorb hit, health stays at 1, charge consumed
	if health - amount <= 0 and has_node("WeaponManager") and $WeaponManager.airbag_active:
		health = 1
		$WeaponManager.consume_airbag()
		print("Airbag absorbed lethal hit! hp=1")
		return
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
