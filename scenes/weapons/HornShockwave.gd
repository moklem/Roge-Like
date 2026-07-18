extends Node
## HornShockwave — 360° radial burst centered on player. Fires every 3s.
## D-12: ~150px radius, hits all enemies in range simultaneously.
## Visual: brief expanding ring (comic strip, ColorRect fallback).
## W2: Authority guard prevents non-owning peers from triggering damage.
##
## Hit detection is direct distance math over the "enemies" group, NOT a physics overlap
## query. WeaponManager is a plain Node, which breaks the CanvasItem transform chain, so an
## Area2D parented under here does not follow the player — it stays wherever it was last
## placed. Teleporting it to the player and calling get_overlapping_bodies() in the same
## frame then reads the overlap set from the LAST physics step, i.e. the PREVIOUS fire
## position 3s ago. AntennaBeam uses this same math approach for the same reason.

const COOLDOWN: float = 3.0
const RADIUS: float = 150.0
const DAMAGE: int = 30

var _timer: Timer = null
## Base fire interval before the Cooldown card multiplier — L2 lowers it to 2.5.
var _base_cooldown: float = COOLDOWN
## Cooldown card (XP-04): current multiplier, applied whenever wait_time is written.
var _cd_mult: float = 1.0

func activate(weapon_manager: Node) -> void:
	_setup_timer(weapon_manager)

func apply_cooldown_mult(mult: float) -> void:
	_cd_mult = mult
	if _timer and is_instance_valid(_timer):
		_timer.wait_time = _base_cooldown * _cd_mult

func deactivate() -> void:
	if _timer and is_instance_valid(_timer):
		_timer.stop()
		_timer.queue_free()
		_timer = null

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
	# Phase 6 D-11: Level scaling for Horn Shockwave
	var level: int = weapon_manager.weapon_level.get("horn_shockwave", 1)
	if level >= 2 and _base_cooldown != 2.5:
		_base_cooldown = 2.5        # L2: 3s→2.5s cooldown (D-11) — applied once
		_timer.wait_time = _base_cooldown * _cd_mult
	_show_visual.rpc(player.global_position)
	# Damage resolves host-side. A client is authority over its own player but is NOT the
	# server, so it has to ask the host to apply the hit — without this hop the client's
	# shockwave was visual-only and dealt no damage at all.
	if multiplayer.is_server():
		_apply_damage(player.global_position, level, player.peer_id)
	else:
		_apply_damage.rpc_id(1, player.global_position, level, player.peer_id)

@rpc("any_peer", "call_remote", "reliable")
func _apply_damage(origin: Vector2, level: int = 1, shooter_peer_id: int = 0) -> void:
	if not multiplayer.is_server():
		return
	var radius: float = RADIUS if level < 2 else 220.0   # L2: 150→220px
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
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		if origin.distance_squared_to(enemy.global_position) > radius_sq:
			continue
		enemy.take_damage(damage)
		# take_damage frees the enemy on the killing blow — re-check before touching it.
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			continue
		# L2: Knockback — push enemy away from the blast origin
		if level >= 2:
			var knockback: float = 300.0 if level < 3 else 600.0  # L3: ×2 knockback
			enemy.velocity += (enemy.global_position - origin).normalized() * knockback
		# L3: Brief stun — zero velocity (enemy AI will re-path naturally after).
		# NOTE: this cancels the L3 knockback applied just above, so L3 is stun-only in
		# practice. Pre-existing behaviour, preserved here deliberately — see the balance
		# discussion before changing it.
		if level >= 3:
			enemy.velocity = Vector2.ZERO

@rpc("any_peer", "call_local", "unreliable_ordered")
func _show_visual(pos: Vector2) -> void:
	if not is_inside_tree():
		return
	Sfx.play("horn_shockwave")  # rides the existing every-peer visual RPC — no new sound RPC
	# Comic shockwave strip (4 expanding arc rings, ~0.33s) — the final frame's ring sits
	# just past the 150px damage radius, same read as the old 0.1→2.0 ring tween.
	if Juice.spawn_anim(pos, "shockwave", RADIUS * 2.3, 6) != null:
		return
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
