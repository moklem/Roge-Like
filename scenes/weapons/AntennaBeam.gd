extends Node
## AntennaBeam — long thin Area2D aimed at nearest enemy, fires every 2s.
## D-11: Piercing — hits all enemies along the beam in one overlap query.
## Uses long Area2D (500px × 8px) with collision_mask=4 (enemies only, walls ignored).
## W2: Authority guard prevents non-owning peers from applying damage.
## Visual: tall thin ColorRect that flashes briefly on fire.

const COOLDOWN: float = 2.0
const BEAM_LENGTH: float = 500.0
const BEAM_WIDTH: float = 8.0
const DAMAGE: int = 25

var _timer: Timer = null
var _area: Area2D = null
var _beam_visual: ColorRect = null

func activate(weapon_manager: Node) -> void:
	_setup_area()
	_setup_timer(weapon_manager)

func deactivate() -> void:
	if _timer and is_instance_valid(_timer):
		_timer.stop()
		_timer.queue_free()
		_timer = null
	if _area and is_instance_valid(_area):
		_area.queue_free()
		_area = null

func _setup_area() -> void:
	_area = Area2D.new()
	_area.name = "BeamArea"
	_area.collision_layer = 0
	_area.collision_mask = 4   # layer 3 "enemies" only — beam passes through walls
	_area.monitoring = true
	_area.monitorable = false
	# Long thin box shape centered on beam midpoint
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(BEAM_LENGTH, BEAM_WIDTH)
	shape.shape = box
	# Offset shape so origin is at player, beam extends forward
	shape.position = Vector2(BEAM_LENGTH / 2.0, 0.0)
	_area.add_child(shape)
	# ColorRect beam visual
	_beam_visual = ColorRect.new()
	_beam_visual.name = "BeamVisual"
	_beam_visual.color = Color(0.0, 1.0, 0.8, 0.85)  # cyan-teal antenna beam
	_beam_visual.size = Vector2(BEAM_LENGTH, BEAM_WIDTH)
	_beam_visual.position = Vector2(0.0, -BEAM_WIDTH / 2.0)
	_beam_visual.visible = false
	_area.add_child(_beam_visual)
	add_child(_area)

func _setup_timer(weapon_manager: Node) -> void:
	_timer = Timer.new()
	_timer.wait_time = COOLDOWN
	_timer.autostart = true
	_timer.one_shot = false
	_timer.timeout.connect(_on_fire_timer.bind(weapon_manager))
	add_child(_timer)

func _on_fire_timer(weapon_manager: Node) -> void:
	var player: Node = weapon_manager.get_parent()
	if not player.is_multiplayer_authority():
		return
	if player.is_downed:
		return
	# Phase 6 D-11: Level scaling
	var level: int = weapon_manager.weapon_level.get("antenna_beam", 1)
	var nearest: Node = weapon_manager._find_nearest_enemy(player)
	if nearest == null:
		return
	var dir: Vector2 = (nearest.global_position - player.global_position).normalized()
	_show_visual.rpc(dir, player.global_position)
	# L2: Fire twice — first shot, then wait 0.2s, then second shot
	if level >= 2:
		if multiplayer.is_server():
			_apply_damage(player.global_position, dir, level, player.peer_id)
		else:
			_apply_damage.rpc_id(1, player.global_position, dir, level, player.peer_id)
		await get_tree().create_timer(0.2).timeout
		# T-06-14: Guard against self or player being freed / downed during the 0.2s await
		if not is_instance_valid(self):
			return
		if not is_instance_valid(player) or player.is_downed:
			return
	# Primary (or only for L1) beam
	if multiplayer.is_server():
		_apply_damage(player.global_position, dir, level, player.peer_id)
	else:
		_apply_damage.rpc_id(1, player.global_position, dir, level, player.peer_id)

@rpc("any_peer", "call_remote", "reliable")
func _apply_damage(origin: Vector2, dir: Vector2, level: int = 1, shooter_peer_id: int = 0) -> void:
	if not multiplayer.is_server():
		return
	# D-11 Level scaling
	var base_dmg: int = DAMAGE   # L1/L2: 25
	if level >= 3:
		base_dmg = 30            # L3: 25→30 (D-11 says 20→30; DAMAGE const is 25 in this file)
	var hit_radius: float = BEAM_WIDTH / 2.0 + 20.0
	if level >= 3:
		hit_radius *= 2.0        # L3: hitbox width doubles
	# Stage 3 damage multiplier — look up shooter's Player node by peer_id
	var stage_mult: float = 1.0
	if shooter_peer_id != 0:
		for p in get_tree().get_nodes_in_group("players"):
			if p.peer_id == shooter_peer_id:
				stage_mult = p.stage3_damage_mult
				break
	var final_dmg: int = int(float(base_dmg) * stage_mult)
	var perp: Vector2 = Vector2(-dir.y, dir.x)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var to_enemy: Vector2 = enemy.global_position - origin
		var along: float = to_enemy.dot(dir)
		if along < 0.0 or along > BEAM_LENGTH:
			continue
		if abs(to_enemy.dot(perp)) <= hit_radius:
			enemy.take_damage(final_dmg)

@rpc("any_peer", "call_local", "unreliable_ordered")
func _show_visual(dir: Vector2, pos: Vector2) -> void:
	if not is_instance_valid(_area):
		return
	_area.global_position = pos
	_area.rotation = dir.angle()
	if _beam_visual:
		_beam_visual.visible = true
		var tween := create_tween()
		tween.tween_interval(0.2)
		tween.tween_callback(func(): if is_instance_valid(_beam_visual): _beam_visual.visible = false)
