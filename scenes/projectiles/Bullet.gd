extends Area2D
## Screw/bolt projectile — spawned via MultiplayerSpawner (BulletSpawner in Game.gd).
## P5: NO MultiplayerSynchronizer — clients simulate movement locally from baked direction.
## D-07: Only host runs hit detection (body_entered / area_entered guarded).
## D-08: Players are immune to own bullets. This is geometrically guaranteed by collision_mask = 17:
##   layer 1 (walls, value 1) + layer 5 (enemy_hurtbox, value 16) = 17.
##   Layer 2 (players, value 2) is NOT in the mask — bullets never collide with player shapes.
##   owner_peer_id is retained for kill attribution / XP credit; no immunity check needed.

const SPEED: float = 400.0
const LIFETIME: float = 3.0
const BULLET_DAMAGE: int = 20
## Homing: spread bolts fly straight for HOMING_DELAY (visible fan-out), then curve
## onto the baked target point so multi-bolt volleys all converge on the enemy.
const HOMING_DELAY: float = 0.12
const TURN_RATE: float = 10.0  # rad/s

## Set by Game.gd _do_spawn_bullet(data) — all peers get these values via spawn_function
@export var direction: Vector2 = Vector2.RIGHT
@export var owner_peer_id: int = 0
@export var damage_mult: float = 1.0
## D-17: Fire Burst projectiles bypass the proc gate and always apply burn (ELEM-02).
@export var force_burn: bool = false
## Element buff: WeaponManager marks every Nth volley so it deterministically applies the
## owner's element effect (fire→burn, ice→slow) and lights the CarHUD on hit.
@export var element_proc: bool = false
## Enemy position snapshot at fire time (Vector2.INF = no homing). Deterministic on all
## peers — baked into spawn data, so clients simulate the same curve without a synchronizer.
@export var target_pos: Vector2 = Vector2.INF

var _elapsed: float = 0.0
var _homing_done: bool = false

func _ready() -> void:
	# Grouped so Game.gd can purge stray projectiles on sub-room / room transitions.
	add_to_group("bullets")
	# Rotate sprite to face travel direction
	rotation = direction.angle()
	_setup_screw_visual()
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

## Comic screw art (head left, tip right — matches the +X flight axis this node rotates
## along). Safe-loaded via Juice.frames: when the strip is missing the yellow ColorRect
## in Bullet.tscn simply stays visible instead.
func _setup_screw_visual() -> void:
	var sf: SpriteFrames = Juice.frames("screw")
	if sf == null:
		return
	$Sprite.visible = false
	var spr := AnimatedSprite2D.new()
	spr.sprite_frames = sf
	# 128px canvas, screw body ~124px long → ~20px on screen; the offset re-centers the
	# node origin on the screw body (the art sits slightly high in its canvas).
	spr.scale = Vector2(0.16, 0.16)
	spr.offset = Vector2(-1.0, 11.5)
	add_child(spr)
	spr.play("default")

func _physics_process(delta: float) -> void:
	# ALL peers simulate local movement — this is what makes bullets look smooth on clients
	# without needing a MultiplayerSynchronizer (P5 anti-pattern)
	if target_pos != Vector2.INF and not _homing_done and _elapsed >= HOMING_DELAY:
		var to_target := target_pos - position
		# Stop steering once the target point is reached or passed — never boomerang.
		if to_target.length_squared() < 100.0 or direction.dot(to_target) <= 0.0:
			_homing_done = true
		else:
			var err := direction.angle_to(to_target.normalized())
			direction = direction.rotated(clampf(err, -TURN_RATE * delta, TURN_RATE * delta))
			rotation = direction.angle()
	position += direction * SPEED * delta
	_elapsed += delta
	if _elapsed >= LIFETIME:
		# Only host calls queue_free — propagates to all clients via BulletSpawner
		if is_multiplayer_authority():
			queue_free()

func _on_body_entered(_body: Node) -> void:
	# CMBT-05: Wall hit (collision_mask includes layer 1 walls, bitmask value 1)
	# D-07: host-only despawn
	if not is_multiplayer_authority():
		return
	queue_free()

func _on_area_entered(area: Node) -> void:
	# CMBT-05/06: Enemy hurtbox hit — host-only damage and despawn
	# collision_mask includes layer 5 enemy_hurtbox (bitmask value 16) — only enemy hurtboxes enter
	if not is_multiplayer_authority():
		return
	var enemy := area.get_parent()
	if not enemy.is_in_group("enemies"):
		return
	# CMBT-06: apply damage to enemy (host-authoritative — take_damage guards itself too)
	if enemy.has_method("take_damage"):
		enemy.take_damage(int(float(BULLET_DAMAGE) * damage_mult))
	# Phase 5 ELEM-01/03/07: Element proc — must stay inside the authority guard above (Pitfall 5).
	# force_burn=true (Fire Burst, ELEM-02) and element_proc=true (every-Nth-shot buff) both
	# guarantee the effect; element_proc dispatches on the owner's element (fire/ice/earth).
	if force_burn:
		if enemy.has_method("apply_burn"):
			enemy.apply_burn()
		if multiplayer.is_server():
			GameEvents.emit_hud.rpc("engine")
	elif element_proc:
		var owner_elem: String = Lobby.players.get(owner_peer_id, {}).get("element", "").to_lower()
		match owner_elem:
			"fire":
				if enemy.has_method("apply_burn"):
					enemy.apply_burn()
				if multiplayer.is_server():
					GameEvents.emit_hud.rpc("engine")
			"ice":
				if enemy.has_method("apply_slow"):
					enemy.apply_slow(0.5, 2.0, "ice")
				if multiplayer.is_server():
					GameEvents.emit_hud.rpc("ac")
			"earth":
				# Earth's on-hit proc — same 50%/2s slow Ice's proc uses, tagged "earth" so
				# Enemy._process tints it green and pops pebble fleck instead of ice shard.
				# No emit_hud here (unlike fire/ice): "seat_massage" is Earth's heal cue —
				# firing it on every combat hit too would spam the green screen rim/CarHUD
				# panel on top of the heal's own pulse. The enemy tint + pebble are proc
				# feedback enough; the screen stays quiet for this one.
				if enemy.has_method("apply_slow"):
					enemy.apply_slow(0.5, 2.0, "earth")
	# CMBT-05: despawn bullet — propagates to all clients via BulletSpawner
	queue_free()
