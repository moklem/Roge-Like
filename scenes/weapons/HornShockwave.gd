extends Node
## HornShockwave — 360° radial Area2D burst centered on player. Fires every 3s.
## D-12: ~150px radius, hits all enemies in range simultaneously.
## Visual: brief expanding ring (ColorRect scaled up then freed via Tween).
## W2: Authority guard prevents non-owning peers from triggering damage.

const COOLDOWN: float = 3.0
const RADIUS: float = 150.0
const DAMAGE: int = 30

var _timer: Timer = null
var _area: Area2D = null

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
	_area.name = "ShockwaveArea"
	_area.collision_layer = 0
	_area.collision_mask = 4   # layer 3 "enemies"
	_area.monitoring = true
	_area.monitorable = false
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = RADIUS
	shape.shape = circle
	_area.add_child(shape)
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
	# Center the shockwave Area2D at the player's position
	_area.global_position = player.global_position
	# Visual expanding ring — Tween scales up a temporary ColorRect then frees it
	_spawn_ring_visual(player)
	# Host-only: damage all enemies within the full 360° radius
	if not multiplayer.is_server():
		return
	for body in _area.get_overlapping_bodies():
		if body.is_in_group("enemies"):
			body.take_damage(DAMAGE)

func _spawn_ring_visual(player: Node) -> void:
	## Tween-based expanding ring (from RESEARCH.md Don't Hand-Roll section).
	## ColorRect sized to RADIUS*2 × RADIUS*2, centered, scales from 0.1 to 2.0 and fades.
	var parent_node: Node = player.get_parent()
	if parent_node == null:
		return  # Null check: player might not be in scene tree yet
	var ring := ColorRect.new()
	ring.color = Color(1.0, 0.9, 0.0, 0.8)   # yellow horn blast ring
	ring.size = Vector2(RADIUS * 2.0, RADIUS * 2.0)
	ring.pivot_offset = Vector2(RADIUS, RADIUS)
	ring.position = player.global_position - Vector2(RADIUS, RADIUS)
	ring.scale = Vector2(0.1, 0.1)
	parent_node.add_child(ring)  # add to Game scene so it's world-space
	var tween := ring.create_tween()
	tween.tween_property(ring, "scale", Vector2(2.0, 2.0), 0.35)
	tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.35)
	tween.tween_callback(ring.queue_free)
