extends Node
## ExhaustFlames weapon — cone Area2D, fires every 1.5s at nearest enemy direction.
## D-09: 60° arc, 120px radius, host-only hit detection.
## W2: Timer fires on all peers; authority guard prevents non-owning peers from executing fire.
## Activated by WeaponManager.add_weapon("exhaust_flames") → _activate_weapon_node.

const COOLDOWN: float = 1.5
const RADIUS: float = 120.0
const HALF_ANGLE: float = deg_to_rad(30.0)  # 60° total arc = ±30° from aim direction
const DAMAGE: int = 20

var _timer: Timer = null
var _area: Area2D = null

func activate(weapon_manager: Node) -> void:
	## Called by WeaponManager._activate_weapon_node when weapon unlocked.
	_setup_area()
	_setup_timer(weapon_manager)

func deactivate() -> void:
	## Called by WeaponManager.reset()
	if _timer and is_instance_valid(_timer):
		_timer.stop()
		_timer.queue_free()
		_timer = null
	if _area and is_instance_valid(_area):
		_area.queue_free()
		_area = null

func _setup_area() -> void:
	_area = Area2D.new()
	_area.name = "ExhaustArea"
	_area.collision_layer = 0
	_area.collision_mask = 4  # layer 3 "enemies"
	_area.monitoring = true
	_area.monitorable = false
	# CircleShape for 120px radius (we filter the 60° arc manually in fire)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = RADIUS
	shape.shape = circle
	_area.add_child(shape)
	# ColorRect visual — orange rectangle (placeholder per project constraint)
	var visual := ColorRect.new()
	visual.name = "ExhaustVisual"
	visual.color = Color(1.0, 0.4, 0.0, 0.7)  # orange
	visual.size = Vector2(RADIUS, 30)
	visual.position = Vector2(0, -15)  # centered vertically
	visual.visible = false  # only flash on fire
	_area.add_child(visual)
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
	# Phase 6 D-11: level-specific params
	var level: int = weapon_manager.weapon_level.get("exhaust_flames", 1)
	var half_angle: float = HALF_ANGLE                      # L1: ±30° (60° total)
	var radius: float = RADIUS                              # L1: 120px
	var damage: int = int(float(DAMAGE) * player.stage3_damage_mult)  # D-22 Stage 3 mult
	if level >= 2:
		half_angle = deg_to_rad(45.0)                       # L2: 90° total cone
		radius = 160.0                                      # L2: 120→160px range
	if level >= 3:
		half_angle = deg_to_rad(60.0)                       # L3: 120° total cone
	# Update area shape radius to match current level
	if is_instance_valid(_area):
		for child in _area.get_children():
			if child is CollisionShape2D and child.shape is CircleShape2D:
				child.shape.radius = radius
				break
	var nearest: Node = weapon_manager._find_nearest_enemy(player)
	if nearest == null:
		return
	var aim_dir: Vector2 = (nearest.global_position - player.global_position).normalized()
	_show_visual.rpc(aim_dir, player.global_position)
	if not multiplayer.is_server():
		return
	_area.global_position = player.global_position
	for body in _area.get_overlapping_bodies():
		if not body.is_in_group("enemies"):
			continue
		var to_enemy: Vector2 = (body.global_position - player.global_position).normalized()
		if abs(aim_dir.angle_to(to_enemy)) <= half_angle:
			body.take_damage(damage)
			# L3: Brief slow — enemy velocity halved for 1s (T-06-15 mitigation)
			if level >= 3 and is_instance_valid(body) and not body.is_queued_for_deletion():
				body.velocity *= 0.5
				get_tree().create_timer(1.0).timeout.connect(func():
					if is_instance_valid(body) and not body.is_queued_for_deletion():
						body.velocity *= 2.0
				)

@rpc("any_peer", "call_local", "unreliable_ordered")
func _show_visual(aim_dir: Vector2, pos: Vector2) -> void:
	if not is_instance_valid(_area):
		return
	_area.global_position = pos
	_area.rotation = aim_dir.angle()
	if _area.has_node("ExhaustVisual"):
		var vis: ColorRect = _area.get_node("ExhaustVisual")
		vis.visible = true
		var tween := create_tween()
		tween.tween_interval(0.15)
		tween.tween_callback(func(): if is_instance_valid(vis): vis.visible = false)
