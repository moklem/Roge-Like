extends Node2D
## HealDrone — Engineer deployable heal zone. Spawned by Game.gd DroneSpawner.
## D-14: Stage-1 stays fixed at deploy position; pulses +15 HP within 150px every 3s.
## D-15: Stage-2 follows the Engineer; +25 HP within 200px every 3s.
## Host authority: drone authority stays on host (Pitfall 2 — never transfer authority to owning peer).
## MultiplayerSynchronizer on this scene replicates position so Stage-2 follow is seen by all peers.

@export var owning_peer: int = 0
@export var stage: int = 1

## Drone art — deliberately mapped to what each stage actually DOES:
## Stage 1 is the planted, legged unit (D-14: stays fixed at the deploy position).
## Stage 2 is the hovering unit with grabber arms (D-15: follows the Engineer).
const DRONE_TEXTURES := {
	1: preload("res://assets/active/roles/heal_drone_1.png"),
	2: preload("res://assets/active/roles/heal_drone_2.png"),
}
## Target on-screen height (px) per stage — well below the player's 56-68px
## (Player.CHAR_TARGET_HEIGHT) so the drone reads as the Engineer's equipment
## rather than as a second character. Stage 2 is the SMALLER of the two on purpose:
## it flies right next to the Engineer, so it must not crowd or upstage him, while
## Stage 1 is a planted ground unit standing on its own.
const DRONE_TARGET_HEIGHT := {1: 32.0, 2: 28.0}
## Used only when the texture's image data cannot be read (256px art → ~41px on screen).
const FALLBACK_SCALE: float = 0.16

## D-15 Stage-2 follow: the drone flies diagonally above-and-right of the Engineer
## instead of sitting inside him. Y is negative because Godot's +Y points down.
##
## X must clear the player's overhead UI, or the drone covers it. In Player.tscn the
## RoleLabel spans x -40..40 (y -68..-48) and the HealthBar x -26..26 (y -46..-35).
## The drone draws ~32px wide at DRONE_TARGET_HEIGHT[2], so half of it is ~16px —
## anything under x=56 would clip the name plate. 62 keeps a visible gap beside it.
const FOLLOW_OFFSET := Vector2(62.0, -56.0)
## Exponential smoothing rate for the follow — the drone drifts after the Engineer
## rather than snapping onto him, which is what makes it read as flying alongside.
const FOLLOW_SMOOTHING: float = 9.0

## Cosmetic hover bob (Stage 2 only — Stage 1 stands on legs and must not float).
const BOB_AMPLITUDE: float = 2.5
const BOB_SPEED: float = 3.0

const PULSE_INTERVAL: float = 3.0
const LIFETIME: float = 10.0          # drone despawns after 10s
## Stage-1 stats (D-14). Both stages heal every teammate inside the radius; the tighter
## radius is what makes standing with the team a real positioning decision.
const PULSE_HEAL_S1: int = 15
const PULSE_RADIUS_S1: float = 90.0
## Stage-2 stats (D-15)
const PULSE_HEAL_S2: int = 25
const PULSE_RADIUS_S2: float = 120.0

var _pulse_timer: Timer = null
var _area: Area2D = null
var _lifetime_elapsed: float = 0.0
var _sprite: Sprite2D = null
var _sprite_base_offset: Vector2 = Vector2.ZERO   # unflipped centering offset from _fit_sprite
var _bob_t: float = 0.0

func _ready() -> void:
	# CRITICAL (Pitfall 2): drone authority stays with host (default).
	# owning_peer is a data field only — do not transfer authority to it.
	# Grouped so Game.gd can despawn active drones on sub-room / room transitions.
	add_to_group("drones")
	_setup_area()
	_setup_timer()
	_draw_visual()
	# ABIL-05/D-20: one-shot deploy pop-in burst + ring. _ready() runs identically on
	# every peer (spawner-replicated), so this needs no RPC and shows on all screens.
	_spawn_deploy_effect()

func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return
	# Lifetime — host despawns after LIFETIME seconds (replicates to clients via DroneSpawner)
	_lifetime_elapsed += delta
	if _lifetime_elapsed >= LIFETIME:
		queue_free()
		return
	# Stage-2: fly alongside the owning Engineer (D-15). Offset diagonally up-and-right
	# so the drone sits BESIDE him, not on top of him, and ease toward that point instead
	# of snapping to it — the lag is what sells it as a flying companion.
	if stage < 2:
		return
	var owner_player: Node2D = _find_owner()
	if owner_player == null:
		return
	var target: Vector2 = owner_player.global_position + FOLLOW_OFFSET
	# Frame-rate-independent exponential smoothing (physics tick can vary).
	global_position = global_position.lerp(target, 1.0 - exp(-FOLLOW_SMOOTHING * delta))

## The owning Engineer, or null if he is gone (downed players stay in the group, so this
## keeps working while the drone's remaining lifetime runs out).
func _find_owner() -> Node2D:
	for p in get_tree().get_nodes_in_group("players"):
		if p is Node2D and p.peer_id == owning_peer:
			return p
	return null

func _setup_area() -> void:
	_area = Area2D.new()
	_area.name = "DroneArea"
	_area.collision_layer = 0
	_area.collision_mask = 2   # layer 2 "players"
	_area.monitoring = true
	_area.monitorable = false
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = PULSE_RADIUS_S2  # use max radius for the area; pulse uses distance check
	shape.shape = circle
	_area.add_child(shape)
	add_child(_area)

func _setup_timer() -> void:
	_pulse_timer = Timer.new()
	_pulse_timer.wait_time = PULSE_INTERVAL
	_pulse_timer.autostart = true
	_pulse_timer.one_shot = false
	_pulse_timer.timeout.connect(_on_pulse)
	add_child(_pulse_timer)

func _on_pulse() -> void:
	if not is_multiplayer_authority():
		return
	var radius: float = PULSE_RADIUS_S2 if stage >= 2 else PULSE_RADIUS_S1
	var heal: int    = PULSE_HEAL_S2  if stage >= 2 else PULSE_HEAL_S1
	for p in get_tree().get_nodes_in_group("players"):
		if p.is_downed:
			continue
		if global_position.distance_to(p.global_position) <= radius:
			# host→peer heal routing — exact Enemy.gd lines 91-94 pattern
			if p.peer_id == multiplayer.get_unique_id():
				p.receive_heal(heal)
			else:
				p.receive_heal.rpc_id(p.peer_id, heal)

## ABIL-05/D-20: one-shot pop-in burst + brief expanding ring at the deploy point, captured
## at spawn global_position. Uses the Juice facade (spawn_burst) for the particle pop plus
## a _show_dash_shockwave-style ring tween, both parented to FxLayer. Degrades gracefully
## (no crash) if FxLayer is not yet present — e.g. main menu / very early scene load.
func _spawn_deploy_effect() -> void:
	const DEPLOY_COLOR: Color = Color(0.2, 0.9, 0.3, 0.9)  # matches the drone's own green
	Sfx.play("drone_deploy")  # _ready() runs on every peer (spawner-replicated) — no RPC needed
	Juice.spawn_burst(global_position, DEPLOY_COLOR, 10, 0.5)
	var layer := Juice._fx_layer()
	if layer == null:
		return
	const RADIUS: float = 26.0
	var ring := ColorRect.new()
	ring.color = Color(DEPLOY_COLOR.r, DEPLOY_COLOR.g, DEPLOY_COLOR.b, 0.7)
	ring.size = Vector2(RADIUS * 2.0, RADIUS * 2.0)
	ring.pivot_offset = Vector2(RADIUS, RADIUS)
	ring.scale = Vector2(0.2, 0.2)
	layer.add_child(ring)
	ring.global_position = global_position - Vector2(RADIUS, RADIUS)
	var tween := ring.create_tween()
	tween.tween_property(ring, "scale", Vector2(1.4, 1.4), 0.35)
	tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.35)
	tween.tween_callback(ring.queue_free)

func _draw_visual() -> void:
	var s: int = 2 if stage >= 2 else 1
	var tex: Texture2D = DRONE_TEXTURES[s]
	var spr := Sprite2D.new()
	spr.texture = tex
	_fit_sprite(spr, tex, DRONE_TARGET_HEIGHT[s])
	add_child(spr)
	_sprite = spr

## Presentation-only, and deliberately in _process rather than _physics_process: the latter
## early-returns for non-authority peers (the host owns the drone), so clients would never
## see the bob or the facing. Both are local cosmetics, so every peer just runs them.
##
## The bob drives the SPRITE's local position, never `global_position` — that one is
## replicated and is what the heal pulse measures range from, so bobbing it would jitter
## both the network state and the heal zone.
func _process(delta: float) -> void:
	if stage < 2 or _sprite == null:
		return
	_bob_t += delta * BOB_SPEED
	_sprite.position = Vector2(0.0, sin(_bob_t) * BOB_AMPLITUDE)
	_face_like_owner()

## Mirror the Engineer's facing so the drone looks where he looks. Rather than deriving
## facing ourselves, copy the player's own CharSprite.flip_h — the same trick the dash
## afterimage uses (Player.gd `g.flip_h = spr.flip_h`). That value is already computed
## locally on every peer from replicated position deltas (Player.gd `_update_facing`), and
## it already accounts for per-role quirks like Tank stage-2's inverted art, so copying it
## needs no new sync and cannot drift out of step with the character.
func _face_like_owner() -> void:
	var owner_player: Node2D = _find_owner()
	if owner_player == null:
		return
	var char_spr: Node = owner_player.get_node_or_null("CharSprite")
	if char_spr == null:
		return
	_set_flip(char_spr.flip_h)

## flip_h mirrors the art inside its own canvas, so the centering shift from _fit_sprite
## has to mirror with it — otherwise the drone jumps sideways every time it turns around.
## Same correction as Player._apply_char_fit.
func _set_flip(flip: bool) -> void:
	if _sprite.flip_h == flip:
		return
	_sprite.flip_h = flip
	_sprite.offset = Vector2(-_sprite_base_offset.x if flip else _sprite_base_offset.x, _sprite_base_offset.y)

## Scale and centre the sprite on its opaque pixels, mirroring the `_compute_char_fit`
## idiom in Player.gd. The art is a 256x256 canvas with wide transparent margins, so
## scaling against the raw texture size would render the drone both too small and
## visibly off its own origin (the heal ring in _draw() is centred on that origin).
func _fit_sprite(spr: Sprite2D, tex: Texture2D, target_height: float) -> void:
	var img: Image = tex.get_image()
	if img == null:
		spr.scale = Vector2(FALLBACK_SCALE, FALLBACK_SCALE)
		return
	var used: Rect2i = img.get_used_rect()
	if used.size.y <= 0:
		spr.scale = Vector2(FALLBACK_SCALE, FALLBACK_SCALE)
		return
	var s: float = target_height / float(used.size.y)
	spr.scale = Vector2(s, s)
	var canvas_center := Vector2(img.get_width(), img.get_height()) * 0.5
	var used_center := Vector2(used.position) + Vector2(used.size) * 0.5
	spr.offset = canvas_center - used_center
	_sprite_base_offset = spr.offset   # _set_flip mirrors this when the drone turns

## Heal radius indicator — runs on all peers so everyone sees the drone's reach.
## Drawn below the drone rect; stage is set by the spawner before add_child, so the
## radius matches the actual pulse range (150px S1 / 200px S2).
func _draw() -> void:
	var radius: float = PULSE_RADIUS_S2 if stage >= 2 else PULSE_RADIUS_S1
	draw_circle(Vector2.ZERO, radius, Color(0.2, 0.9, 0.3, 0.07))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, Color(0.2, 0.9, 0.3, 0.45), 2.0)
