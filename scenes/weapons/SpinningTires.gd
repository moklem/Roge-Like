extends Node
## SpinningTires — 3 Area2D nodes orbit player continuously.
## D-10: 120° apart, 50px radius, ORBIT_SPEED radians/sec.
## D-14: Visual orbit runs on ALL peers (children of Player via WeaponManager child).
##       Damage detection is HOST-ONLY (multiplayer.is_server() guard on damage path).
## Uses _hit_times Dictionary per-enemy to avoid damage faster than HIT_COOLDOWN (0.5s).

const ORBIT_RADIUS: float = 50.0
const ORBIT_SPEED: float = 2.0   # radians/sec
const HIT_COOLDOWN: float = 0.5

var _angle: float = 0.0
var _hit_times: Dictionary = {}  # enemy node path (String) → float (unix time of last hit)
var _tires: Array[Area2D] = []
var _active: bool = false

func activate() -> void:
	## Called by WeaponManager._activate_weapon_node("spinning_tires")
	## Phase 6 D-11: Create 5 tires (max for L3) so L2/L3 work without re-create; extras hidden.
	for i in range(5):
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
		# Comic tire art (rolling 3-frame loop), staggered per orbit slot so the five
		# tires don't spin in lockstep. Falls back to the flat dark square when missing.
		var sf: SpriteFrames = Juice.frames("tire")
		if sf != null:
			var spr := AnimatedSprite2D.new()
			spr.sprite_frames = sf
			spr.scale = Vector2(0.234, 0.234)  # 128px canvas → ~30px, matches the 14px hitbox
			tire.add_child(spr)
			spr.play("default")
			spr.frame = i % sf.get_frame_count("default")
		else:
			# ColorRect visual — small dark circle (tire placeholder)
			var visual := ColorRect.new()
			visual.color = Color(0.2, 0.2, 0.2)  # dark grey tire
			visual.size = Vector2(16, 16)
			visual.position = Vector2(-8, -8)
			tire.add_child(visual)
		# Tires beyond index 2 start hidden (visible only when level allows)
		if i >= 3:
			tire.visible = false
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
	# Phase 6 D-11: Read weapon level for speed, count, and damage scaling
	var weapon_manager: Node = get_parent()
	var level: int = weapon_manager.weapon_level.get("spinning_tires", 1)
	var speed_mult: float = 1.25 if level >= 2 else 1.0   # L2: +25% rotation speed
	var damage_per_tick: int = 18 if level >= 3 else 12   # L1/L2: 12 (base), L3: 18
	_angle += ORBIT_SPEED * speed_mult * delta
	# get_parent() == WeaponManager, get_parent().get_parent() == Player
	var player: Node = weapon_manager.get_parent()
	if not is_instance_valid(player) or player.is_downed:
		return
	# Stage 3 damage multiplier (D-22)
	damage_per_tick = int(float(damage_per_tick) * player.stage3_damage_mult * player.driver_damage_mult)
	# D-11: Active orbit count: L1=3, L2=4, L3=5
	var active_count: int = mini(3 + maxi(level - 1, 0), _tires.size())
	# Update orbit positions — runs on ALL peers for visual sync (D-14 visual half)
	for i in range(_tires.size()):
		if i < active_count:
			var angle_offset: float = _angle + (float(i) * TAU / float(active_count))
			_tires[i].global_position = player.global_position + Vector2(
				cos(angle_offset), sin(angle_offset)
			) * ORBIT_RADIUS
			_tires[i].visible = true
		else:
			_tires[i].visible = false
	# D-14: Host-only damage detection (CR-03 fix: use is_server(), not is_multiplayer_authority())
	if not multiplayer.is_server():
		return
	var now: float = Time.get_unix_time_from_system()
	for i in range(active_count):
		for body in _tires[i].get_overlapping_bodies():
			if not body.is_in_group("enemies"):
				continue
			var key: String = str(body.get_path())
			var last_hit: float = _hit_times.get(key, -INF)
			if now - last_hit >= HIT_COOLDOWN:
				_hit_times[key] = now
				body.take_damage(damage_per_tick)
