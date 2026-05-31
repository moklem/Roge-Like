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
	# W2: Only owning peer's WeaponManager may fire
	if not weapon_manager.get_parent().is_multiplayer_authority():
		return
	_try_fire(weapon_manager)

func _try_fire(weapon_manager: Node) -> void:
	var player: Node = weapon_manager.get_parent()
	var nearest := weapon_manager._find_nearest_enemy(player)
	if nearest == null:
		return  # Pitfall: no enemies alive — safe exit
	# Aim beam from player toward nearest enemy
	var dir: Vector2 = (nearest.global_position - player.global_position).normalized()
	_area.global_position = player.global_position
	# Rotate the Area2D so the beam shape points at the enemy
	_area.rotation = dir.angle()
	# Flash the beam visual briefly
	if _beam_visual:
		_beam_visual.visible = true
		var tween := _area.create_tween()
		tween.tween_property(_beam_visual, "visible", false, 0.2)
	# Host-only: apply damage to all enemies inside the beam Area2D
	if not multiplayer.is_server():
		return
	for body in _area.get_overlapping_bodies():
		if body.is_in_group("enemies"):
			body.take_damage(DAMAGE)
