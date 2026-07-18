extends Node
## ExhaustFlames weapon — cone Area2D, fires every 1.5s at nearest enemy direction.
## D-09: 60° arc, 120px radius, host-only hit detection.
## W2: Timer fires on all peers; authority guard prevents non-owning peers from executing fire.
## Activated by WeaponManager.add_weapon("exhaust_flames") → _activate_weapon_node.

const COOLDOWN: float = 2.4  # playtest: 1.5s fired/sounded too often — spaced out
const RADIUS: float = 120.0
const HALF_ANGLE: float = deg_to_rad(30.0)  # 60° total arc = ±30° from aim direction
const DAMAGE: int = 20

var _timer: Timer = null
var _area: Area2D = null
var _flame_anim: AnimatedSprite2D = null  # comic flame strip; null → ColorRect fallback

func activate(weapon_manager: Node) -> void:
	## Called by WeaponManager._activate_weapon_node when weapon unlocked.
	_setup_area()
	_setup_timer(weapon_manager)

## Cooldown card (XP-04): scale the fire interval; called by WeaponManager.
func apply_cooldown_mult(mult: float) -> void:
	if _timer and is_instance_valid(_timer):
		_timer.wait_time = COOLDOWN * mult

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
	# Visual anchor only — it owns the flame sprite and its rotation. Hit detection is
	# direct math in _apply_damage (see the note there), so this carries no collision
	# shape and does no monitoring; a dead hitbox here would just mislead.
	_area = Area2D.new()
	_area.name = "ExhaustArea"
	_area.collision_layer = 0
	_area.collision_mask = 0
	_area.monitoring = false
	_area.monitorable = false
	# Comic flame strip (tail at origin, licking out along +X — same axis the area
	# rotates on). Falls back to the old orange rect when the art isn't delivered.
	var sf: SpriteFrames = Juice.frames("exhaust")
	if sf != null:
		_flame_anim = AnimatedSprite2D.new()
		_flame_anim.name = "ExhaustFlameAnim"
		_flame_anim.sprite_frames = sf
		_flame_anim.centered = false
		# 512×181 canvas, flame core on the horizontal midline → origin sits on the nozzle
		_flame_anim.offset = Vector2(0.0, -90.0)
		_flame_anim.scale = Vector2(0.3, 0.3)  # full lick ~154px, matches the 120-160px cone
		_flame_anim.visible = false
		_flame_anim.animation_finished.connect(func():
			if is_instance_valid(_flame_anim):
				_flame_anim.visible = false)
		_area.add_child(_flame_anim)
	else:
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
	var nearest: Node = weapon_manager._find_nearest_enemy(player)
	if nearest == null:
		return
	var aim_dir: Vector2 = (nearest.global_position - player.global_position).normalized()
	_show_visual.rpc(aim_dir, player.global_position)
	# Damage resolves host-side. A client is authority over its own player but is NOT the
	# server, so it has to ask the host to apply the hit — without this hop the client's
	# flames were visual-only and dealt no damage at all.
	if multiplayer.is_server():
		_apply_damage(player.global_position, aim_dir, level, player.peer_id)
	else:
		_apply_damage.rpc_id(1, player.global_position, aim_dir, level, player.peer_id)

## Cone hit detection by direct math over the "enemies" group rather than a physics overlap
## query. WeaponManager is a plain Node, which breaks the CanvasItem transform chain, so the
## Area2D above never followed the player — teleporting it to the player and querying
## get_overlapping_bodies() in the same frame read the overlap set from the LAST physics
## step, i.e. the PREVIOUS fire position. AntennaBeam uses this same approach.
@rpc("any_peer", "call_remote", "reliable")
func _apply_damage(origin: Vector2, aim_dir: Vector2, level: int = 1, shooter_peer_id: int = 0) -> void:
	if not multiplayer.is_server():
		return
	var half_angle: float = HALF_ANGLE                      # L1: ±30° (60° total)
	var radius: float = RADIUS                              # L1: 120px
	if level >= 2:
		half_angle = deg_to_rad(45.0)                       # L2: 90° total cone
		radius = 160.0                                      # L2: 120→160px range
	if level >= 3:
		half_angle = deg_to_rad(60.0)                       # L3: 120° total cone
	# Stage 3 damage multiplier (D-22) + Driver OVERDRIVE — look up shooter by peer_id,
	# since on the host this may be resolving a remote player's shot.
	var stage_mult: float = 1.0
	if shooter_peer_id != 0:
		for p in get_tree().get_nodes_in_group("players"):
			if p.peer_id == shooter_peer_id:
				stage_mult = p.stage3_damage_mult * p.driver_damage_mult
				break
	var damage: int = int(float(DAMAGE) * stage_mult)
	var radius_sq: float = radius * radius
	var hit_any: bool = false
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		var to_enemy: Vector2 = enemy.global_position - origin
		if to_enemy.length_squared() > radius_sq:
			continue
		if absf(aim_dir.angle_to(to_enemy.normalized())) > half_angle:
			continue
		enemy.take_damage(damage)
		hit_any = true
		# L3: Brief slow — enemy velocity halved for 1s (T-06-15 mitigation)
		if level >= 3 and is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
			enemy.velocity *= 0.5
			get_tree().create_timer(1.0).timeout.connect(func():
				if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
					enemy.velocity *= 2.0
			)
	if hit_any:
		GameEvents.emit_hud.rpc("engine")

@rpc("any_peer", "call_local", "unreliable_ordered")
func _show_visual(aim_dir: Vector2, pos: Vector2) -> void:
	if not is_instance_valid(_area):
		return
	Sfx.play("exhaust_flames")  # rides the existing every-peer visual RPC — no new sound RPC
	_area.global_position = pos
	_area.rotation = aim_dir.angle()
	if _flame_anim != null and is_instance_valid(_flame_anim):
		_flame_anim.visible = true
		_flame_anim.frame = 0
		_flame_anim.play("default")  # one-shot; animation_finished hides it again
	elif _area.has_node("ExhaustVisual"):
		var vis: ColorRect = _area.get_node("ExhaustVisual")
		vis.visible = true
		var tween := create_tween()
		tween.tween_interval(0.15)
		tween.tween_callback(func(): if is_instance_valid(vis): vis.visible = false)
