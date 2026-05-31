extends Node
## SpinningTires — 3 Area2D nodes orbit player continuously.
## D-10: 120° apart, 50px radius, ORBIT_SPEED radians/sec.
## D-14: Visual orbit runs on ALL peers (children of Player via WeaponManager child).
##       Damage detection is HOST-ONLY (multiplayer.is_server() guard on damage path).
## Uses _hit_times Dictionary per-enemy to avoid damage faster than HIT_COOLDOWN (0.5s).

const ORBIT_RADIUS: float = 50.0
const ORBIT_SPEED: float = 2.0   # radians/sec
const DAMAGE: int = 15
const HIT_COOLDOWN: float = 0.5

var _angle: float = 0.0
var _hit_times: Dictionary = {}  # enemy node path (String) → float (unix time of last hit)
var _tires: Array[Area2D] = []
var _active: bool = false

func activate() -> void:
	## Called by WeaponManager._activate_weapon_node("spinning_tires")
	for i in range(3):
		var tire := Area2D.new()
		tire.name = "Tire%d" % i
		tire.collision_layer = 0
		tire.collision_mask = 4  # layer 3 "enemies"
		tire.monitoring = true
		tire.monitorable = false
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 14.0
		shape.shape = circle
		tire.add_child(shape)
		# ColorRect visual — small dark circle (tire placeholder)
		var visual := ColorRect.new()
		visual.color = Color(0.2, 0.2, 0.2)  # dark grey tire
		visual.size = Vector2(16, 16)
		visual.position = Vector2(-8, -8)
		tire.add_child(visual)
		add_child(tire)
		_tires.append(tire)
	_active = true

func deactivate() -> void:
	## Called by WeaponManager.reset()
	_active = false
	_hit_times = {}
	for tire in _tires:
		if is_instance_valid(tire):
			tire.queue_free()
	_tires = []

func _physics_process(delta: float) -> void:
	if not _active or _tires.is_empty():
		return
	_angle += ORBIT_SPEED * delta
	# get_parent() == WeaponManager, get_parent().get_parent() == Player
	var player: Node = get_parent().get_parent()
	if not is_instance_valid(player):
		return
	# Update orbit positions — runs on ALL peers for visual sync (D-14 visual half)
	for i in range(_tires.size()):
		var angle_offset: float = _angle + (float(i) * TAU / 3.0)
		_tires[i].global_position = player.global_position + Vector2(
			cos(angle_offset), sin(angle_offset)
		) * ORBIT_RADIUS
	# D-14: Host-only damage detection (CR-03 fix: use is_server(), not is_multiplayer_authority())
	if not multiplayer.is_server():
		return
	var now: float = Time.get_unix_time_from_system()
	for tire in _tires:
		for body in tire.get_overlapping_bodies():
			if not body.is_in_group("enemies"):
				continue
			var key: String = str(body.get_path())
			var last_hit: float = _hit_times.get(key, -INF)
			if now - last_hit >= HIT_COOLDOWN:
				_hit_times[key] = now
				body.take_damage(DAMAGE)
