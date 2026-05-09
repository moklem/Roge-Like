extends CharacterBody2D
## Enemy AI controller — host-authoritative chase and contact damage.
## P6: set_physics_process(is_multiplayer_authority()) in _ready() — clients never run AI.
## D-01: NavigationAgent2D target_position updated every frame (~60 Hz).
## D-02: Detection radius configurable; enemies idle outside radius.
## D-10: Contact damage fires once per contact (body_entered/body_exited guard).

const SPEED: float = 80.0
const DETECT_RADIUS: float = 300.0
const CONTACT_DAMAGE: int = 10
const MAX_HP: int = 50

## Synced via MultiplayerSynchronizer (SceneReplicationConfig)
var current_hp: int = MAX_HP
var state: int = 0  # 0 = IDLE, 1 = CHASE

## D-10: Track which player peer_ids are currently in contact to prevent repeated damage
var _players_in_contact: Dictionary = {}

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
			var next := $NavigationAgent2D.get_next_path_position()
			velocity = (next - global_position).normalized() * SPEED
		else:
			velocity = Vector2.ZERO
	move_and_slide()
	# Update health bar on all peers (reads synced current_hp)
	$HealthBar.value = float(current_hp) / float(MAX_HP) * 100.0

func _find_nearest_player() -> Node:
	var nearest: Node = null
	var nearest_dist: float = INF
	for p in get_tree().get_nodes_in_group("players"):
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

## D-10: Host-only contact damage — once per contact
func _on_hurtbox_body_entered(body: Node) -> void:
	if not is_multiplayer_authority():
		return
	if not body.is_in_group("players"):
		return
	var pid: int = body.peer_id
	if _players_in_contact.has(pid):
		return  # already tracking this contact — no repeat damage
	_players_in_contact[pid] = true
	# HLTH-02: Damage player via RPC to owning peer (Pitfall 3 resolution: option 2)
	# receive_damage is @rpc("any_peer", "call_remote", "reliable") on Player.gd.
	# Host calls rpc_id(player.peer_id, ...) — owning peer decrements health,
	# MultiplayerSynchronizer replicates health outward.
	body.receive_damage.rpc_id(body.peer_id, CONTACT_DAMAGE)

## D-10: Clear contact when player moves away — allows next contact to deal damage
func _on_hurtbox_body_exited(body: Node) -> void:
	if body.is_in_group("players"):
		_players_in_contact.erase(body.peer_id)
