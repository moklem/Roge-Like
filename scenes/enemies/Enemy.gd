extends CharacterBody2D
## Enemy AI controller — host-authoritative chase and contact damage.
## P6: set_physics_process(is_multiplayer_authority()) in _ready() — clients never run AI.
## D-01: NavigationAgent2D target_position updated every frame (~60 Hz).
## D-02: Detection radius configurable; enemies idle outside radius.
## D-10: Contact damage fires once per contact (body_entered/body_exited guard).

const SPEED: float = 80.0
const DETECT_RADIUS: float = 300.0
var CONTACT_DAMAGE: int = 10  # must be var for spawn-time difficulty scaling (Pitfall 2, D-19)
var MAX_HP: int = 50           # must be var for spawn-time difficulty scaling (Pitfall 2, D-19)
## WR-02: set to true in EliteEnemy._ready() so the SUSPENSION indicator is only triggered by
## elite contacts — not by scaled normal enemies whose CONTACT_DAMAGE exceeds 15 at loop 3+.
var is_elite: bool = false

## Synced via MultiplayerSynchronizer (SceneReplicationConfig)
var current_hp: int  # WR-03: not initialised here — _ready() sets it to MAX_HP so any
					 # spawn-time MAX_HP override (e.g. _do_spawn_enemy or EliteEnemy._ready)
					 # is reflected correctly rather than always defaulting to 50.
var state: int = 0  # 0 = IDLE, 1 = CHASE

## D-10: Track which player peer_ids are currently in contact to prevent repeated damage
var _players_in_contact: Dictionary = {}

## Phase 5: Status effect fields (D-17 Burn DoT, D-18 Ice Slow)
var speed_multiplier: float = 1.0   # D-18 Ice Slow: reduces to 0.5 for 2 sec
var _slow_timer: float = 0.0        # counts down slow duration
var _burn_timer: float = 0.0        # counts down burn duration (max 3 sec)
var _burn_tick_timer: float = 0.0   # 1-sec interval for burn damage ticks

## CMBT-08: Signal for Game.gd to spawn XP orb at death position
signal died(pos: Vector2)

## Tracks last-seen hp so _process can fire a subtle hit cue when it drops (all peers).
var _last_hp_seen: int = 0

## DMG-04/D-07: Reddish ghost overlay child of $HealthBar that spans old→new HP value and
## shrinks toward the new-value edge while fading to alpha 0 over ~0.4s. Created in _ready()
## so it shares the ProgressBar's local coordinate space (0..size.x maps to value 0..100).
## Same visual approach is reused for the Player HP bar in Plan 10-04.
var _health_ghost: ColorRect = null
var _health_ghost_tween: Tween = null

## Animated enemy art (standard enemies only — Elite/Boss scenes have no CharSprite node).
## Two art variants; the pick derives from the node name, which the MultiplayerSpawner
## keeps identical on every peer, so all clients show the same variant.
const ENEMY_TARGET_HEIGHT: float = 50.0  # on-screen height of the drawn character (px)
var _uses_char_sprite: bool = false
var _variant: int = 1
var _last_anim_pos: Vector2 = Vector2.ZERO
var _move_timer: float = 0.0  # keeps "walk" alive between 20 Hz position syncs on clients

func _ready() -> void:
	add_to_group("enemies")
	# WR-03: set current_hp here so any bare instantiation (without _do_spawn_enemy) gets the
	# correct value. _do_spawn_enemy and EliteEnemy._ready() overwrite current_hp after this.
	current_hp = MAX_HP
	_last_hp_seen = current_hp
	# P6: NavigationAgent2D must not run on clients — only host runs AI
	set_physics_process(is_multiplayer_authority())
	# HurtboxArea (collision_layer=16, mask=32) detects bullet hits via area_entered
	# and player body overlap via body_entered (players on layer 2, enemy CharacterBody2D mask includes layer 2)
	$HurtboxArea.body_entered.connect(_on_hurtbox_body_entered)
	$HurtboxArea.body_exited.connect(_on_hurtbox_body_exited)
	_setup_enemy_sprite()
	# DMG-04/D-07: ghost overlay lives as a child of $HealthBar so its local coordinate space
	# matches the ProgressBar's 0..size.x == value 0..100 range. Hidden until the first hit.
	if has_node("HealthBar"):
		_health_ghost = ColorRect.new()
		_health_ghost.color = Color(1.0, 0.3, 0.25, 0.85)
		_health_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_health_ghost.visible = false
		$HealthBar.add_child(_health_ghost)

## Swap the ColorRect placeholder for the animated art and normalize its size: measure the
## opaque bounding box of the idle frame (same approach as Player._compute_char_fit) so the
## DRAWN character — not the padded 256px canvas — is ENEMY_TARGET_HEIGHT px tall.
func _setup_enemy_sprite() -> void:
	_uses_char_sprite = has_node("CharSprite")
	if not _uses_char_sprite:
		return
	_variant = 1 + (str(name).hash() % 2)
	if has_node("Sprite"):
		$Sprite.visible = false
	var spr: AnimatedSprite2D = $CharSprite
	spr.visible = true
	var tex: Texture2D = spr.sprite_frames.get_frame_texture("enemy_%d_idle" % _variant, 0)
	if tex != null:
		var img: Image = tex.get_image()
		if img != null:
			if img.is_compressed():
				img.decompress()
			var used: Rect2i = img.get_used_rect()
			if used.size.y > 0:
				var s: float = ENEMY_TARGET_HEIGHT / float(used.size.y)
				spr.scale = Vector2(s, s)
				var canvas_center := Vector2(img.get_width(), img.get_height()) * 0.5
				var used_center := Vector2(used.position) + Vector2(used.size) * 0.5
				spr.offset = canvas_center - used_center
	_last_anim_pos = global_position
	spr.play("enemy_%d_idle" % _variant)

## Drive walk/idle + facing on ALL peers from the replicated position (clients run no AI,
## so velocity is meaningless there — the synced position delta is the only movement signal).
func _update_enemy_visual(delta_t: float) -> void:
	var spr: AnimatedSprite2D = $CharSprite
	var move_delta: Vector2 = global_position - _last_anim_pos
	_last_anim_pos = global_position
	if absf(move_delta.x) > 0.5:
		spr.flip_h = move_delta.x > 0.0  # art faces left natively
	if move_delta.length() > 0.5:
		_move_timer = 0.15
	else:
		_move_timer = maxf(0.0, _move_timer - delta_t)
	var anim := "enemy_%d_%s" % [_variant, "walk" if _move_timer > 0.0 else "idle"]
	if spr.animation != StringName(anim) or not spr.is_playing():
		spr.play(anim)

## WR-003: Health bar update runs on ALL peers so clients see synced current_hp.
## _physics_process is disabled on clients (P6 guard), so health bar must live here.
func _process(_delta: float) -> void:
	if has_node("HealthBar"):
		$HealthBar.value = float(current_hp) / float(MAX_HP) * 100.0
	# Subtle hit cue on damage. current_hp is replicated, so this fires on every peer
	# (host applies damage directly; clients see the synced drop) for any damage source.
	if current_hp < _last_hp_seen:
		Sfx.hit()
		# DMG-01/D-04: pooled damage number + white over-bright flash pop. Runs on every peer,
		# no authority guard, no new RPC — reacts to the already-replicated current_hp diff.
		var dmg: int = _last_hp_seen - current_hp
		Juice.spawn_damage_number(global_position, dmg, _damage_number_color(), get_instance_id())
		Juice.flash(self, Color(2, 2, 2, 1), 0.1)
		# DMG-04/D-07: HP bar ghost chip-away for the segment just lost.
		_update_health_ghost(_last_hp_seen, current_hp)
	_last_hp_seen = current_hp
	if _uses_char_sprite:
		_update_enemy_visual(_delta)

## Damage-number color hook. Always white for now; Plan 10-08 extends this to read
## is_burning/is_slowed once those flags are replicated, kept as its own function so that
## extension is purely additive.
func _damage_number_color() -> Color:
	return Color.WHITE

## DMG-04/D-07: Positions the ghost overlay to span the just-lost HP segment (old_hp→new_hp)
## and tweens it to shrink toward the new-value edge while fading to alpha 0 over ~0.4s. The
## primary $HealthBar.value already snapped to the new percentage this same frame (above).
func _update_health_ghost(old_hp: int, new_hp: int) -> void:
	if _health_ghost == null:
		return
	var bar: ProgressBar = $HealthBar
	var bar_size: Vector2 = bar.size
	var old_pct: float = clampf(float(old_hp) / float(MAX_HP), 0.0, 1.0)
	var new_pct: float = clampf(float(new_hp) / float(MAX_HP), 0.0, 1.0)
	var old_x: float = old_pct * bar_size.x
	var new_x: float = new_pct * bar_size.x
	if _health_ghost_tween != null and _health_ghost_tween.is_valid():
		_health_ghost_tween.kill()
	_health_ghost.color = Color(1.0, 0.3, 0.25, 0.85)
	_health_ghost.position = Vector2(new_x, 0.0)
	_health_ghost.size = Vector2(maxf(old_x - new_x, 0.0), bar_size.y)
	_health_ghost.visible = true
	_health_ghost_tween = create_tween()
	_health_ghost_tween.set_parallel(true)
	_health_ghost_tween.tween_property(_health_ghost, "size:x", 0.0, 0.4)
	_health_ghost_tween.tween_property(_health_ghost, "color:a", 0.0, 0.4)
	_health_ghost_tween.chain().tween_callback(func() -> void:
		_health_ghost.visible = false
	)

func _physics_process(_delta: float) -> void:
	var target := _find_nearest_player()
	if target == null or global_position.distance_to(target.global_position) > DETECT_RADIUS:
		state = 0
		velocity = Vector2.ZERO
	else:
		state = 1
		# D-01: Update target every frame for responsive chase
		$NavigationAgent2D.target_position = target.global_position
		# Pitfall 1: Check is_navigation_finished() to prevent jitter when adjacent
		if not $NavigationAgent2D.is_navigation_finished():
			var next: Vector2 = $NavigationAgent2D.get_next_path_position()
			velocity = (next - global_position).normalized() * SPEED * speed_multiplier
		else:
			velocity = Vector2.ZERO
	move_and_slide()
	# Phase 5: Burn DoT and Slow countdown (host-only — P6 guard already applied in _ready)
	_tick_status_effects(_delta)

func _find_nearest_player() -> Node:
	var nearest: Node = null
	var nearest_dist: float = INF
	for p in get_tree().get_nodes_in_group("players"):
		if p.is_downed:
			continue
		if p.is_picking_card:
			continue  # invisible to enemies while on the upgrade screen (is_picking_card is synced)
		var d: float = global_position.distance_to(p.global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = p
	return nearest

## Called by host bullet hit handler in Bullet.gd (_on_area_entered)
func take_damage(amount: int) -> void:
	if not is_multiplayer_authority():
		return
	current_hp -= amount
	if current_hp <= 0:
		current_hp = 0
		# CMBT-08: emit position before freeing so Game.gd can spawn orb
		died.emit(global_position)
		# CMBT-07: queue_free on host propagates to all clients via MultiplayerSpawner
		queue_free()

## Phase 5: Status effect tick — called from _physics_process (host-only via P6 guard)
func _tick_status_effects(delta: float) -> void:
	# Ice Slow countdown
	if _slow_timer > 0.0:
		_slow_timer -= delta
		if _slow_timer <= 0.0:
			speed_multiplier = 1.0
			modulate = Color.WHITE  # clear blue tint
	# Burn DoT countdown
	if _burn_timer > 0.0:
		_burn_timer -= delta
		_burn_tick_timer -= delta
		if _burn_tick_timer <= 0.0:
			_burn_tick_timer = 1.0
			take_damage(5)  # 5 damage/sec — D-17; take_damage already has authority guard
		if _burn_timer <= 0.0:
			modulate = Color.WHITE  # clear orange tint

## Phase 5: Apply Burn DoT to this enemy (D-17). Called by Bullet.gd on host after proc check.
## Burns do not stack — refresh duration (D-17).
func apply_burn() -> void:
	_burn_timer = 3.0
	_burn_tick_timer = 1.0
	modulate = Color(1.0, 0.6, 0.2)  # orange tint

## Phase 5: Apply Ice Slow to this enemy (D-18). Called by Bullet.gd on host after proc check.
## Slows to 50% speed for 2 seconds.
func apply_slow() -> void:
	speed_multiplier = 0.5
	_slow_timer = 2.0
	modulate = Color(0.5, 0.7, 1.0)  # blue tint

## D-10: Host-only contact damage — once per contact
func _on_hurtbox_body_entered(body: Node) -> void:
	if not is_multiplayer_authority():
		return
	if not body.is_in_group("players"):
		return
	if body.is_downed:
		return
	var pid: int = body.peer_id
	if _players_in_contact.has(pid):
		return  # already tracking this contact — no repeat damage
	_players_in_contact[pid] = true
	# HLTH-02: call_remote rpc_id to self is a no-op in Godot 4.
	# Host player (peer_id == 1) must be called directly; clients use rpc_id.
	# WR-02: pass is_elite flag so Player.receive_damage can gate SUSPENSION on elite hits only.
	if body.peer_id == multiplayer.get_unique_id():
		body.receive_damage(CONTACT_DAMAGE, "", is_elite)
	else:
		body.receive_damage.rpc_id(body.peer_id, CONTACT_DAMAGE, "", is_elite)

## D-10: Clear contact when player moves away — allows next contact to deal damage
func _on_hurtbox_body_exited(body: Node) -> void:
	if body.is_in_group("players"):
		_players_in_contact.erase(body.peer_id)
