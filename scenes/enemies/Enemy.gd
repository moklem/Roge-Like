extends CharacterBody2D
## Enemy AI controller — host-authoritative chase and contact damage.
## P6: set_physics_process(is_multiplayer_authority()) in _ready() — clients never run AI.
## D-01: NavigationAgent2D target_position updated every frame (~60 Hz).
## D-02: Detection radius configurable; enemies idle outside radius.
## D-10: Contact damage fires once per contact (body_entered/body_exited guard).

const SPEED: float = 80.0
const DETECT_RADIUS: float = 300.0

## Enemies deliberately do NOT collide with each other physically — collision_mask omits the
## "enemies" layer, because hard bodies jam the swarm against each other in Room 2's corridors
## and at sub-room doorways. Instead they steer apart with a soft push, which stops sprites
## from stacking without ever blocking a path. Host-only, like the rest of the AI.
const SEPARATION_RADIUS: float = 28.0    # below this, two enemies read as overlapping
const SEPARATION_STRENGTH: float = 60.0  # px/s of push at full overlap, falling off to 0 at the radius
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

## Net-smoothing: the synchronizer replicates synced_position (20 Hz, on-change) instead of
## writing .position directly; .position itself is spawn-only. The host mirrors position into
## synced_position, clients glide toward it in _process — so remote movement renders at full
## frame rate instead of stepping at the replication interval. Boss/Elite inherit this as-is.
var synced_position: Vector2
const NET_SNAP_DIST: float = 128.0  # gaps larger than this snap (spawn placement, resets)
const NET_LERP_RATE: float = 18.0   # exponential smoothing rate — higher tracks tighter

## Navigation repath throttle (host-only, used in _physics_process). Writing target_position
## every frame makes NavigationAgent2D re-solve the path every frame for every enemy; at ~10 Hz
## plus a "player moved a lot" trigger the chase looks identical but costs a tenth as much.
const NAV_REPATH_INTERVAL: float = 0.1
const NAV_REPATH_MOVE_SQ: float = 24.0 * 24.0  # px² the target may drift before an early repath
var _nav_repath_timer: float = 999.0           # large seed: always repath on the very first tick
var _nav_last_target: Vector2 = Vector2.ZERO

## Phase 5: Status effect fields (D-17 Burn DoT, D-18 Ice Slow)
var speed_multiplier: float = 1.0   # D-18 Ice Slow: reduces to 0.5 for 2 sec
var _slow_timer: float = 0.0        # counts down slow duration
var _burn_timer: float = 0.0        # counts down burn duration (max 3 sec)
var _burn_tick_timer: float = 0.0   # 1-sec interval for burn damage ticks
## Which element applied the current slow ("ice" or "earth") — the slow itself is a single
## generic effect (one timer, no stacking), this field only picks the tint/VFX/impact color
## so Ice's and Earth's procs read as their own element instead of both looking like Ice.
var slow_source: String = "ice"

## Phase 10-08/ABIL-01: Synced via MultiplayerSynchronizer (SceneReplicationConfig
## properties/3, properties/4). Set/cleared host-only inside apply_burn()/apply_slow()/
## _tick_status_effects() exactly where the tint used to be written directly — the DoT
## tick and speed_multiplier math stay host-only; only these flags' VISIBILITY replicates
## so _process (below, runs on every peer) can react with the tint/element VFX on clients too.
var is_burning: bool = false
var is_slowed: bool = false

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

## Animated enemy art. Any scene that carries a CharSprite node gets it; scenes without one
## (EliteEnemy) keep the flat ColorRect placeholder.
## Two art variants; the pick derives from the node name, which the MultiplayerSpawner
## keeps identical on every peer, so all clients show the same variant.
const ENEMY_TARGET_HEIGHT: float = 42.0  # on-screen height of the drawn character (px); playtest: 50→42, a touch smaller
var _uses_char_sprite: bool = false
var _variant: int = 1

## Animation-set name on the CharSprite's SpriteFrames — the shared "<set>_idle" / "<set>_walk"
## naming contract. Subclasses with their own art override this instead of the animation names
## being hard-coded here (Boss ships one "boss" set, not the two enemy_N variants).
func _anim_set() -> String:
	return "enemy_%d" % _variant

## On-screen height of the drawn character. Overridden by subclasses whose art is a different
## size from a rank-and-file enemy (Boss).
func _char_target_height() -> float:
	return ENEMY_TARGET_HEIGHT
var _last_anim_pos: Vector2 = Vector2.ZERO
var _move_timer: float = 0.0  # keeps "walk" alive between 20 Hz position syncs on clients

## Procedural walk-bounce/idle-breath state. The bob rides on the CharSprite's `offset`
## (texture-space) and `rotation` — deliberately NOT `position`/`scale`, which belong to
## Juice's recoil/stretch tweens and their once-captured rest pose (Juice._rest_pose).
var _char_base_offset: Vector2 = Vector2.ZERO  # centering offset from _setup_enemy_sprite
var _bob_phase: float = 0.0                    # per-node phase so a swarm never bobs in sync
const BOB_WALK_HZ: float = 5.0     # hops per second while moving
const BOB_WALK_AMP: float = 3.0    # hop height in SCREEN px (divided by sprite scale)
const BOB_IDLE_HZ: float = 0.9     # breathing rate when standing
const BOB_IDLE_AMP: float = 1.4    # breathing rise in SCREEN px
const LEAN_WALK_RAD: float = 0.07  # lean into the travel direction (~4°)

## Per-physics-frame group cache, shared by every enemy instance (static — subclasses included).
## Each enemy used to call get_tree().get_nodes_in_group() twice per frame, and each of those
## calls allocates a fresh Array: at 30 enemies that is 60 allocations every physics tick, which
## dominated the frame cost far more than the O(n²) distance maths itself. Now the two arrays are
## built once per tick and every enemy reads the same ones.
##
## Nodes freed later in the same tick stay in these arrays until the next refresh, so every
## consumer must check is_instance_valid() — the live group lookup used to make that implicit.
static var _cache_frame: int = -1
static var _cached_enemies: Array = []
static var _cached_players: Array = []

## Called at the top of both consumers rather than once from _physics_process: Boss overrides
## _physics_process with early-return paths, so a single call site could be skipped. The
## frame-int compare makes every call after the first one per tick essentially free.
static func _refresh_group_cache(tree: SceneTree) -> void:
	var frame: int = Engine.get_physics_frames()
	if frame == _cache_frame:
		return
	_cache_frame = frame
	_cached_enemies = tree.get_nodes_in_group("enemies")
	_cached_players = tree.get_nodes_in_group("players")

func _ready() -> void:
	add_to_group("enemies")
	# LIDAR spawn-in: scan ring + brief orange glow on every peer. Deferred so the spawner's
	# position (applied around add_child) is final before the effect reads global_position.
	call_deferred("_play_spawn_fx")
	# WR-03: set current_hp here so any bare instantiation (without _do_spawn_enemy) gets the
	# correct value. _do_spawn_enemy and EliteEnemy._ready() overwrite current_hp after this.
	current_hp = MAX_HP
	_last_hp_seen = current_hp
	# P6: NavigationAgent2D must not run on clients — only host runs AI
	set_physics_process(is_multiplayer_authority())
	# Net-smoothing seed: without this, the first client-side lerp would pull toward (0,0).
	synced_position = position
	# HurtboxArea (collision_layer=16, mask=32) detects bullet hits via area_entered
	# and player body overlap via body_entered (players on layer 2, enemy CharacterBody2D mask includes layer 2)
	$HurtboxArea.body_entered.connect(_on_hurtbox_body_entered)
	$HurtboxArea.body_exited.connect(_on_hurtbox_body_exited)
	_setup_enemy_sprite()
	# DMG-04/D-07: ghost overlay lives as a child of $HealthBar so its local coordinate space
	# matches the ProgressBar's 0..size.x == value 0..100 range. Hidden until the first hit.
	if has_node("HealthBar"):
		# Comic restyle for the over-head bar (ink track + red fill) — pure theme override,
		# the value/ghost plumbing below is untouched.
		UiStyle.health_bar($HealthBar, Color(0.88, 0.22, 0.16))
		_health_ghost = ColorRect.new()
		_health_ghost.color = Color(1.0, 0.3, 0.25, 0.85)
		_health_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_health_ghost.visible = false
		$HealthBar.add_child(_health_ghost)
	# ABIL-06/D-19: cosmetic-only materialize telegraph. _ready() is not authority-gated,
	# so this plays identically on every peer; the enemy is fully active immediately —
	# zero authoritative gameplay delay.
	_play_spawn_telegraph()

## ABIL-06/D-19: ~0.4s fade-in (modulate.a 0 -> resting) plus a brief expanding neutral
## ground ring parented to FxLayer (never to the enemy — Pitfall 3/4). Purely cosmetic:
## no RPC, no gameplay gating. EliteEnemy/Boss inherit this via super._ready() with no
## subclass edit required.
func _play_spawn_telegraph() -> void:
	var resting_alpha: float = modulate.a
	modulate.a = 0.0
	var fade_tween := create_tween()
	fade_tween.set_ignore_time_scale(true)
	fade_tween.tween_property(self, "modulate:a", resting_alpha, 0.4)
	var layer: Node2D = get_node_or_null("/root/Game/FxLayer") as Node2D
	if layer == null:
		return
	const RING_RADIUS: float = 20.0
	var ring := ColorRect.new()
	ring.color = Color(1.0, 1.0, 1.0, 0.6)  # neutral/pale — enemy identity isn't meaningful yet (D-19)
	ring.size = Vector2(RING_RADIUS * 2.0, RING_RADIUS * 2.0)
	ring.pivot_offset = Vector2(RING_RADIUS, RING_RADIUS)
	ring.position = global_position - Vector2(RING_RADIUS, RING_RADIUS)
	ring.scale = Vector2(0.2, 0.2)
	layer.add_child(ring)
	var ring_tween := ring.create_tween()
	ring_tween.set_ignore_time_scale(true)
	ring_tween.tween_property(ring, "scale", Vector2(1.2, 1.2), 0.25)
	ring_tween.parallel().tween_property(ring, "modulate:a", 0.3, 0.25)
	ring_tween.tween_property(ring, "scale", Vector2(1.0, 1.0), 0.15)
	ring_tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.15)
	ring_tween.tween_callback(ring.queue_free)

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
	var anim_set: String = _anim_set()
	var tex: Texture2D = spr.sprite_frames.get_frame_texture("%s_idle" % anim_set, 0)
	if tex != null:
		var img: Image = tex.get_image()
		if img != null:
			if img.is_compressed():
				img.decompress()
			var used: Rect2i = img.get_used_rect()
			if used.size.y > 0:
				var s: float = _char_target_height() / float(used.size.y)
				spr.scale = Vector2(s, s)
				var canvas_center := Vector2(img.get_width(), img.get_height()) * 0.5
				var used_center := Vector2(used.position) + Vector2(used.size) * 0.5
				spr.offset = canvas_center - used_center
	_char_base_offset = spr.offset
	_bob_phase = float(str(name).hash() % 1000) / 1000.0 * TAU
	# Ground the character: soft blob shadow at the feet, drawn behind the sprite.
	Juice.add_blob_shadow(self, _char_target_height() * 0.62, _char_target_height() * 0.5)
	_last_anim_pos = global_position
	spr.play("%s_idle" % anim_set)

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
	var anim := "%s_%s" % [_anim_set(), "walk" if _move_timer > 0.0 else "idle"]
	if spr.animation != StringName(anim) or not spr.is_playing():
		spr.play(anim)
	_apply_char_bob(spr, _move_timer > 0.0, move_delta.x)

## Procedural life on top of the frame animation: a little hop + lean while walking, a slow
## breathing rise while idle. Derived from replicated position like everything else here, so
## it renders identically on every peer. Rides offset/rotation only — see _char_base_offset.
func _apply_char_bob(spr: AnimatedSprite2D, walking: bool, dir_x: float) -> void:
	var t: float = float(Time.get_ticks_msec()) / 1000.0 + _bob_phase
	var px_scale: float = maxf(spr.scale.y, 0.001)  # offset is texture-space; convert screen px
	if walking:
		var hop: float = -absf(sin(t * TAU * BOB_WALK_HZ * 0.5)) * BOB_WALK_AMP
		spr.offset = _char_base_offset + Vector2(0, hop / px_scale)
		var lean_sign: float = signf(dir_x) if absf(dir_x) > 0.05 else (1.0 if spr.flip_h else -1.0)
		spr.rotation = lerpf(spr.rotation, lean_sign * LEAN_WALK_RAD, 0.2)
	else:
		var breath: float = sin(t * TAU * BOB_IDLE_HZ) * BOB_IDLE_AMP
		spr.offset = _char_base_offset + Vector2(0, breath / px_scale)
		spr.rotation = lerpf(spr.rotation, 0.0, 0.15)

## WR-003: Health bar update runs on ALL peers so clients see synced current_hp.
## _physics_process is disabled on clients (P6 guard), so health bar must live here.
func _process(_delta: float) -> void:
	# Net-smoothing (see synced_position above): host publishes, clients interpolate.
	if is_multiplayer_authority():
		synced_position = position
	elif position.distance_squared_to(synced_position) > NET_SNAP_DIST * NET_SNAP_DIST:
		position = synced_position
	else:
		position = position.lerp(synced_position, 1.0 - exp(-NET_LERP_RATE * _delta))
	if has_node("HealthBar"):
		$HealthBar.value = float(current_hp) / float(MAX_HP) * 100.0
	# ABIL-01 fix: react to the now-replicated is_burning/is_slowed flags. Only the RGB
	# channels are driven here (alpha is left untouched) so this never fights the spawn-
	# telegraph fade-in tween (which animates modulate:a) or a HitFlash tween in flight —
	# both restore/animate the full modulate, and this reasserts the resting tint as soon
	# as they finish, so the two never end up in a persistent tug-of-war.
	var status_tint: Color = Color.WHITE
	if is_burning:
		status_tint = Color(1.0, 0.6, 0.2)  # orange tint
	elif is_slowed:
		# Ice reads blue (element_color). Earth deliberately does NOT reuse element_color's
		# green here — on an enemy sprite that reads as poison/nature, not "stuck in rock".
		# Pebble-brown instead, matching the pebble hit fleck below.
		status_tint = Color(0.62, 0.42, 0.2) if slow_source == "earth" else Juice.element_color(slow_source)
	if modulate.r != status_tint.r or modulate.g != status_tint.g or modulate.b != status_tint.b:
		modulate = Color(status_tint.r, status_tint.g, status_tint.b, modulate.a)
	# Subtle hit cue on damage. current_hp is replicated, so this fires on every peer
	# (host applies damage directly; clients see the synced drop) for any damage source.
	if current_hp < _last_hp_seen:
		# The killing blow (hp hits 0) skips the full-volume tick here — _exit_tree lays the quiet
		# "hit_kill" layer under the death cue instead, so a kill isn't a loud hit + a death sound.
		if current_hp > 0:
			Sfx.hit()
		# DMG-01/D-04: pooled damage number (element-colored via _impact_color, white for a
		# plain hit) plus the tiered impact reaction (flash always, spark/squash/recoil from
		# medium, hit-stop + ring on heavy). Runs on every peer, no authority guard, no new
		# RPC — it reacts to the already-replicated current_hp diff, and both calls only ever
		# touch presentation, never the body's position or any authoritative field.
		var dmg: int = _last_hp_seen - current_hp
		var visual: CanvasItem = $CharSprite if _uses_char_sprite else null
		Juice.spawn_damage_number(global_position, dmg, _impact_color(), get_instance_id())
		Juice.impact(self, visual, _hit_direction(), float(dmg) / float(maxi(MAX_HP, 1)), _impact_color())
		# DMG-07/D-05: burst-only (~0.4s) element hit VFX for burning/slowed enemies, reusing
		# the shared bounded Juice.spawn_burst/FxLayer pool — no second uncapped spawn path.
		# Reads the now-replicated flags, so this renders identically on host and client.
		if is_burning or is_slowed:
			# Element-specific comic fleck: ember for fire, ice shard for Ice's slow, pebble for
			# Earth's slow. Falls back to the flat element-colored burst when the art isn't there.
			var elem_tex: Texture2D = Juice.vfx("ember") if is_burning \
				else (Juice.vfx("pebble") if slow_source == "earth" else Juice.vfx("shard"))
			if elem_tex != null:
				Juice.spawn_tex_burst(global_position, elem_tex, 6, 24.0, 0.4)
			else:
				Juice.spawn_burst(global_position, _impact_color(), 8, 0.4)
		# DMG-04/D-07: HP bar ghost chip-away for the segment just lost.
		_update_health_ghost(_last_hp_seen, current_hp)
	_last_hp_seen = current_hp
	if _uses_char_sprite:
		_update_enemy_visual(_delta)

## Direction the hit is treated as having come FROM, used to aim the spark cone and the
## recoil kick. Derived from the nearest player rather than from the actual damage source:
## take_damage(amount) carries no origin, and threading one through Bullet, all six weapons
## and every ability would be an authoritative-path change for a purely cosmetic gain. The
## shooter is nearly always the nearest player anyway, and because it is computed from
## replicated positions it resolves identically on every peer.
func _hit_direction() -> Vector2:
	var src: Node = _find_nearest_player()
	if src == null or not (src is Node2D):
		return Vector2.UP
	var away: Vector2 = global_position - (src as Node2D).global_position
	return away.normalized() if away.length() > 0.01 else Vector2.UP

## Impact color hook (DMG-07/D-02). Reads the replicated is_burning/is_slowed flags
## (ABIL-01) so sparks/bursts are element-colored. is_slowed now carries either Ice or
## Earth's proc (see slow_source) — Ice follows the shared element_color, Earth uses the
## same pebble-brown as the status tint (not element_color's green — see _process).
func _impact_color() -> Color:
	if is_burning:
		return Juice.element_color("fire")
	if is_slowed:
		return Color(0.62, 0.42, 0.2) if slow_source == "earth" else Juice.element_color(slow_source)
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
	_nav_repath_timer += _delta
	var target := _find_nearest_player()
	if target == null or global_position.distance_to(target.global_position) > DETECT_RADIUS:
		state = 0
		velocity = Vector2.ZERO
	else:
		state = 1
		# D-01 revised: the target used to be written every frame, which re-dirtied the agent's
		# path and forced a fresh path solve per enemy per tick — the single biggest cost in a
		# large swarm. Now it repaths at NAV_REPATH_INTERVAL, or immediately if the player has
		# moved far enough that the existing path is stale. get_next_path_position() below still
		# runs every frame, so movement stays smooth against the cached path.
		var tgt: Vector2 = target.global_position
		if _nav_repath_timer >= NAV_REPATH_INTERVAL \
				or tgt.distance_squared_to(_nav_last_target) >= NAV_REPATH_MOVE_SQ:
			_nav_repath_timer = 0.0
			_nav_last_target = tgt
			$NavigationAgent2D.target_position = tgt
		# Pitfall 1: Check is_navigation_finished() to prevent jitter when adjacent
		if not $NavigationAgent2D.is_navigation_finished():
			var next: Vector2 = $NavigationAgent2D.get_next_path_position()
			velocity = (next - global_position).normalized() * SPEED * speed_multiplier
		else:
			velocity = Vector2.ZERO
	# Applied in both states: idle enemies that were spawned on top of each other still
	# need to unstack, and move_and_slide() keeps the push from shoving anyone into a wall.
	velocity += _separation_push()
	move_and_slide()
	# Phase 5: Burn DoT and Slow countdown (host-only — P6 guard already applied in _ready)
	_tick_status_effects(_delta)

## Steering force away from every other enemy that is closer than SEPARATION_RADIUS, with a
## linear falloff so a barely-touching neighbour barely pushes. Still O(n²) over the enemy group,
## but it reads the shared per-frame cache instead of allocating its own array, so the constant
## factor is now a squared-distance compare per pair.
func _separation_push() -> Vector2:
	_refresh_group_cache(get_tree())
	var push := Vector2.ZERO
	var radius_sq: float = SEPARATION_RADIUS * SEPARATION_RADIUS
	for other in _cached_enemies:
		if other == self or not is_instance_valid(other) or not other is Node2D:
			continue
		var offset: Vector2 = global_position - other.global_position
		# Squared compare first — most pairs in a swarm are out of range and this skips the sqrt.
		if offset.length_squared() >= radius_sq:
			continue
		var dist: float = offset.length()
		if dist < 0.01:
			# Exactly stacked — two enemies off the same spawn point. There is no meaningful
			# direction to push along, so pick one at random and let the falloff sort it out.
			push += Vector2.RIGHT.rotated(randf() * TAU) * SEPARATION_STRENGTH
			continue
		push += (offset / dist) * SEPARATION_STRENGTH * (1.0 - dist / SEPARATION_RADIUS)
	return push

func _find_nearest_player() -> Node:
	_refresh_group_cache(get_tree())
	var nearest: Node = null
	var nearest_dist: float = INF
	for p in _cached_players:
		if not is_instance_valid(p):
			continue
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

## DMG-05/DMG-06/D-04: Death burst + kill hit-stop, fired on every peer with zero new RPC.
## take_damage() is host-only and calls queue_free() on death; the MultiplayerSpawner
## propagates that free to every client, so _exit_tree runs identically on every peer
## (Pitfall 3/4 — never RPC-target a randi()-named Enemy node). Guarded to real deaths only:
## the group-purge path (Game.gd room-transition cleanup) frees enemies with HP still
## remaining and must not spawn death VFX.
## LIDAR materialize effect at the spawn point. Guarded against the node already being gone by
## the time this deferred call runs (fast spawn→purge on room transitions).
func _play_spawn_fx() -> void:
	if not is_inside_tree():
		return
	# LIDAR reticle is reserved for ELITE spawns — the "something big just showed up" tell — not
	# every trash mob. is_elite is set in EliteEnemy._ready(), which has already run by the time
	# this deferred call fires (call_deferred resolves after the whole _ready chain).
	if not is_elite:
		return
	# Pass self so the scan reticle parents to THIS enemy (sits on it, rides its position) rather
	# than a captured world point that could read as being at the player.
	Juice.spawn_lidar_spawn(global_position, self)

func _exit_tree() -> void:
	if current_hp > 0:
		return
	# Read the dying enemy's own live color so normal/Elite/Boss read differently (D-04)
	# with no per-subclass edit — EliteEnemy/Boss both set their own $Sprite.color.
	var death_color: Color = $Sprite.color if has_node("Sprite") else Color(0.8, 0.2, 0.2, 1)
	# Kid-friendly comic "POOF" (smoke puff + glow dots), never gore. death_color is the fallback
	# tint used only until the vfx art is delivered — see Juice.spawn_death_pop.
	Juice.spawn_death_pop(global_position, death_color)
	# Boss overrides _enter_phase (EliteEnemy does not), so has_method is a cheap boss check
	# alongside is_elite — both get the heavier ~0.12s hit-stop; normal kills stay ~0.07s.
	var is_boss: bool = has_method("_enter_phase")
	var stop_dur: float = 0.12 if (is_elite or is_boss) else 0.07
	Juice.hitstop(stop_dur)
	# Quiet confirming click, laid UNDER whichever death cue fires below so every kill lands with a
	# hit-marker tick even though the full-volume "hit" was suppressed on the fatal blow (see _process).
	Sfx.play("hit_kill")
	# Death cue rides the same every-peer path as the burst above. The three kill tiers get three
	# different cues so a swarm kill never sounds like the boss going down: routine scrap crunch,
	# a reserved-voice fanfare for elites, and a full stinger + music resolve for the boss.
	if is_boss:
		Sfx.play("boss_death")
		Music.play_boss_death_sting()
	elif is_elite:
		Sfx.play("kill_fanfare")
	else:
		Sfx.play("enemy_die")

## Phase 5: Status effect tick — called from _physics_process (host-only via P6 guard).
## Phase 10-08/ABIL-01: sets/clears the replicated is_burning/is_slowed flags exactly where
## the tint used to be written directly — the actual tint REACTION now lives in _process
## (runs on every peer) so clients see it too. This DoT tick / speed_multiplier math stays
## host-only and untouched.
func _tick_status_effects(delta: float) -> void:
	# Ice Slow countdown
	if _slow_timer > 0.0:
		_slow_timer -= delta
		if _slow_timer <= 0.0:
			speed_multiplier = 1.0
			is_slowed = false  # clears the replicated flag; _process reacts on every peer
	# Burn DoT countdown
	if _burn_timer > 0.0:
		_burn_timer -= delta
		_burn_tick_timer -= delta
		if _burn_tick_timer <= 0.0:
			_burn_tick_timer = 1.0
			take_damage(5)  # 5 damage/sec — D-17; take_damage already has authority guard
		if _burn_timer <= 0.0:
			is_burning = false  # clears the replicated flag; _process reacts on every peer

## Phase 5: Apply Burn DoT to this enemy (D-17). Called by Bullet.gd on host after proc check.
## Burns do not stack — refresh duration (D-17).
func apply_burn() -> void:
	_burn_timer = 3.0
	_burn_tick_timer = 1.0
	is_burning = true  # ABIL-01: replicated flag; _process (every peer) applies the orange tint

## Phase 5: Apply a Slow to this enemy — Ice's on-hit proc (D-18), Earth's on-hit proc, and
## IceTrailZone's stronger freeze all funnel through here with their own mult/duration.
## Called by Bullet.gd / IceTrailZone.gd on host after their own proc check. Does not stack —
## a fresh application always overwrites the timer and source (matches apply_burn's refresh).
func apply_slow(mult: float = 0.5, duration: float = 2.0, source: String = "ice") -> void:
	speed_multiplier = mult
	_slow_timer = duration
	slow_source = source
	is_slowed = true  # ABIL-01: replicated flag; _process (every peer) applies the tint

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
