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
	# W2: Only owning peer's WeaponManager reaches this logic
	# weapon_manager is the WeaponManager node (parent of ExhaustFlames)
	if not weapon_manager.get_parent().is_multiplayer_authority():
		return
	_try_fire(weapon_manager)

func _try_fire(weapon_manager: Node) -> void:
	var player: Node = weapon_manager.get_parent()
	var nearest := weapon_manager._find_nearest_enemy(player)
	if nearest == null:
		return
	var aim_dir: Vector2 = (nearest.global_position - player.global_position).normalized()
	# Position the cone area at the player's location
	_area.global_position = player.global_position
	# Flash visual briefly
	if _area.has_node("ExhaustVisual"):
		_area.get_node("ExhaustVisual").visible = true
		var tween := _area.create_tween()
		tween.tween_property(_area.get_node("ExhaustVisual"), "visible", false, 0.15)
	# Host-only damage detection
	if not multiplayer.is_server():
		return
	# Check all overlapping bodies — filter to the 60° cone behind player
	# "behind" = opposite of aim_dir (exhaust comes from rear of car)
	var cone_dir: Vector2 = -aim_dir
	for body in _area.get_overlapping_bodies():
		if not body.is_in_group("enemies"):
			continue
		var to_enemy: Vector2 = (body.global_position - player.global_position).normalized()
		var angle: float = cone_dir.angle_to(to_enemy)
		if abs(angle) <= HALF_ANGLE:
			body.take_damage(DAMAGE)
