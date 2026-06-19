extends CharacterBody2D
## Enemy AI controller — host-authoritative chase and contact damage.
## P6: set_physics_process(is_multiplayer_authority()) in _ready() — clients never run AI.
## D-01: NavigationAgent2D target_position updated every frame (~60 Hz).
## D-02: Detection radius configurable; enemies idle outside radius.
## D-10: Contact damage fires once per contact (body_entered/body_exited guard).

const SPEED: float = 80.0
const DETECT_RADIUS: float = 300.0
var CONTACT_DAMAGE: int = 10  # must be var for spawn-time difficulty scaling (Pitfall 2, D-19)
var MAX_HP: int = 50           # must be var for spawn-time difficulty scaling (Pitfall 2, D-19)
## WR-02: set to true in EliteEnemy._ready() so the SUSPENSION indicator is only triggered by
## elite contacts — not by scaled normal enemies whose CONTACT_DAMAGE exceeds 15 at loop 3+.
var is_elite: bool = false

## Synced via MultiplayerSynchronizer (SceneReplicationConfig)
var current_hp: int = MAX_HP
var state: int = 0  # 0 = IDLE, 1 = CHASE

## D-10: Track which player peer_ids are currently in contact to prevent repeated damage
var _players_in_contact: Dictionary = {}

## Phase 5: Status effect fields (D-17 Burn DoT, D-18 Ice Slow)
var speed_multiplier: float = 1.0   # D-18 Ice Slow: reduces to 0.5 for 2 sec
var _slow_timer: float = 0.0        # counts down slow duration
var _burn_timer: float = 0.0        # counts down burn duration (max 3 sec)
var _burn_tick_timer: float = 0.0   # 1-sec interval for burn damage ticks

## CMBT-08: Signal for Game.gd to spawn XP orb at death position
signal died(pos: Vector2)

func _ready() -> void:
	add_to_group("enemies")
	# P6: NavigationAgent2D must not run on clients — only host runs AI
	set_physics_process(is_multiplayer_authority())
	# HurtboxArea (collision_layer=16, mask=32) detects bullet hits via area_entered
	# and player body overlap via body_entered (players on layer 2, enemy CharacterBody2D mask includes layer 2)
	$HurtboxArea.body_entered.connect(_on_hurtbox_body_entered)
	$HurtboxArea.body_exited.connect(_on_hurtbox_body_exited)

## WR-003: Health bar update runs on ALL peers so clients see synced current_hp.
## _physics_process is disabled on clients (P6 guard), so health bar must live here.
func _process(_delta: float) -> void:
	if has_node("HealthBar"):
		$HealthBar.value = float(current_hp) / float(MAX_HP) * 100.0

func _physics_process(_delta: float) -> void:
	var target := _find_nearest_player()
	if target == null or global_position.distance_to(target.global_position) > DETECT_RADIUS:
		state = 0
		velocity = Vector2.ZERO
	else:
		state = 1
		# D-01: Update target every frame for responsive chase
		$NavigationAgent2D.target_position = target.global_position
		# Pitfall 1: Check is_navigation_finished() to prevent jitter when adjacent
		if not $NavigationAgent2D.is_navigation_finished():
			var next: Vector2 = $NavigationAgent2D.get_next_path_position()
			velocity = (next - global_position).normalized() * SPEED * speed_multiplier
		else:
			velocity = Vector2.ZERO
	move_and_slide()
	# Phase 5: Burn DoT and Slow countdown (host-only — P6 guard already applied in _ready)
	_tick_status_effects(_delta)

func _find_nearest_player() -> Node:
	var nearest: Node = null
	var nearest_dist: float = INF
	for p in get_tree().get_nodes_in_group("players"):
		if p.is_downed:
			continue
		var d: float = global_position.distance_to(p.global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = p
	return nearest

## Called by host bullet hit handler in Bullet.gd (_on_area_entered)
func take_damage(amount: int) -> void:
	if not is_multiplayer_authority():
		return
	current_hp -= amount
	if current_hp <= 0:
		current_hp = 0
		# CMBT-08: emit position before freeing so Game.gd can spawn orb
		died.emit(global_position)
		# CMBT-07: queue_free on host propagates to all clients via MultiplayerSpawner
		queue_free()

## Phase 5: Status effect tick — called from _physics_process (host-only via P6 guard)
func _tick_status_effects(delta: float) -> void:
	# Ice Slow countdown
	if _slow_timer > 0.0:
		_slow_timer -= delta
		if _slow_timer <= 0.0:
			speed_multiplier = 1.0
			modulate = Color.WHITE  # clear blue tint
	# Burn DoT countdown
	if _burn_timer > 0.0:
		_burn_timer -= delta
		_burn_tick_timer -= delta
		if _burn_tick_timer <= 0.0:
			_burn_tick_timer = 1.0
			take_damage(5)  # 5 damage/sec — D-17; take_damage already has authority guard
		if _burn_timer <= 0.0:
			modulate = Color.WHITE  # clear orange tint

## Phase 5: Apply Burn DoT to this enemy (D-17). Called by Bullet.gd on host after proc check.
## Burns do not stack — refresh duration (D-17).
func apply_burn() -> void:
	_burn_timer = 3.0
	_burn_tick_timer = 1.0
	modulate = Color(1.0, 0.6, 0.2)  # orange tint

## Phase 5: Apply Ice Slow to this enemy (D-18). Called by Bullet.gd on host after proc check.
## Slows to 50% speed for 2 seconds.
func apply_slow() -> void:
	speed_multiplier = 0.5
	_slow_timer = 2.0
	modulate = Color(0.5, 0.7, 1.0)  # blue tint

## D-10: Host-only contact damage — once per contact
func _on_hurtbox_body_entered(body: Node) -> void:
	print("Hurtbox body_entered: ", body.name, " group=", body.is_in_group("players"), " auth=", is_multiplayer_authority())
	if not is_multiplayer_authority():
		return
	if not body.is_in_group("players"):
		return
	if body.is_downed:
		return
	var pid: int = body.peer_id
	if _players_in_contact.has(pid):
		return  # already tracking this contact — no repeat damage
	_players_in_contact[pid] = true
	print("Contact damage to player ", pid, " (", CONTACT_DAMAGE, " HP)")
	# HLTH-02: call_remote rpc_id to self is a no-op in Godot 4.
	# Host player (peer_id == 1) must be called directly; clients use rpc_id.
	# WR-02: pass is_elite flag so Player.receive_damage can gate SUSPENSION on elite hits only.
	if body.peer_id == multiplayer.get_unique_id():
		body.receive_damage(CONTACT_DAMAGE, "", is_elite)
	else:
		body.receive_damage.rpc_id(body.peer_id, CONTACT_DAMAGE, "", is_elite)

## D-10: Clear contact when player moves away — allows next contact to deal damage
func _on_hurtbox_body_exited(body: Node) -> void:
	if body.is_in_group("players"):
		_players_in_contact.erase(body.peer_id)
