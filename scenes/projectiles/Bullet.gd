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

## Set by Game.gd _do_spawn_bullet(data) — all peers get these values via spawn_function
@export var direction: Vector2 = Vector2.RIGHT
@export var owner_peer_id: int = 0
## D-17: Fire Burst projectiles bypass the 25% proc gate and always apply burn (ELEM-02).
@export var force_burn: bool = false

var _elapsed: float = 0.0

func _ready() -> void:
	# Rotate sprite to face travel direction
	rotation = direction.angle()
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void:
	# ALL peers simulate local movement — this is what makes bullets look smooth on clients
	# without needing a MultiplayerSynchronizer (P5 anti-pattern)
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
		enemy.take_damage(BULLET_DAMAGE)
	# Phase 5 ELEM-01/03/07: Element proc — must stay inside the authority guard above (Pitfall 5).
	# force_burn=true bypasses 25% gate (D-17: Fire Burst projectiles always burn — ELEM-02).
	if force_burn:
		if enemy.has_method("apply_burn"):
			enemy.apply_burn()
		if multiplayer.is_server():
			GameEvents.emit_hud.rpc("engine")
	else:
		var owner_elem: String = Lobby.players.get(owner_peer_id, {}).get("element", "")
		match owner_elem:
			"fire":
				if randf() < 0.25:
					if enemy.has_method("apply_burn"):
						enemy.apply_burn()
					if multiplayer.is_server():
						GameEvents.emit_hud.rpc("engine")
			"ice":
				if randf() < 0.25:
					if enemy.has_method("apply_slow"):
						enemy.apply_slow()
					if multiplayer.is_server():
						GameEvents.emit_hud.rpc("ac")
	# CMBT-05: despawn bullet — propagates to all clients via BulletSpawner
	queue_free()
