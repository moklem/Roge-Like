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
	var player: Node = weapon_manager.get_parent()
	if not player.is_multiplayer_authority():
		return
	if player.is_downed:
		return
	_show_visual.rpc(player.global_position)
	if not multiplayer.is_server():
		return
	_area.global_position = player.global_position
	for body in _area.get_overlapping_bodies():
		if body.is_in_group("enemies"):
			body.take_damage(DAMAGE)

@rpc("any_peer", "call_local", "unreliable_ordered")
func _show_visual(pos: Vector2) -> void:
	if not is_instance_valid(_area):
		return
	_area.global_position = pos
	var game := get_node_or_null("/root/Game")
	if game == null:
		return
	var ring := ColorRect.new()
	ring.color = Color(1.0, 0.9, 0.0, 0.8)
	ring.size = Vector2(RADIUS * 2.0, RADIUS * 2.0)
	ring.pivot_offset = Vector2(RADIUS, RADIUS)
	ring.position = pos - Vector2(RADIUS, RADIUS)
	ring.scale = Vector2(0.1, 0.1)
	game.add_child(ring)
	var tween := ring.create_tween()
	tween.tween_property(ring, "scale", Vector2(2.0, 2.0), 0.35)
	tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.35)
	tween.tween_callback(ring.queue_free)
