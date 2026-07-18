extends "res://scenes/enemies/Enemy.gd"
## Boss — host-authoritative 3-phase state machine extending Enemy.gd.
## D-11: 1000 base HP scaled by 1.0 + (loop_number-1)*0.25 per loop, further scaled by
## difficulty tier, player count, run time, and weapon count (GameState.get_difficulty_player_stat_mult).
## D-12: Phase 1 (100-66% HP) slow melee charge; Phase 2 (66-33% HP) adds ranged volley;
##       Phase 3 (33-0% HP) both + 1.5x speed enrage.
## D-13: Phase transitions broadcast color change to all peers via RPC.
## D-14: On entering Phase 2 and Phase 3, requests mob swarm from Game node.
## P6:   AI runs host-only (inherited set_physics_process guard from Enemy._ready).

# ─── Phase State ──────────────────────────────────────────────────────────────
var phase: int = 1
var _boss_max_hp: int = 1000

# ─── Art ──────────────────────────────────────────────────────────────────────
## The boss ships one animation set ("boss_idle"/"boss_walk"), not the two enemy_N variants.
const BOSS_ANIM_SET: String = "boss"
## Roughly the footprint of the 80x80 collision box / 48px hurtbox radius. Kept close to them
## on purpose: art much larger than the hurtbox would invite players to swing at empty pixels.
## Trimmed 168 → 144 (2026-07-16): still clearly the biggest thing in the arena, but less of
## a wall — especially at the tighter per-player camera zoom.
const BOSS_TARGET_HEIGHT: float = 144.0

## Phase tint applied to the CharSprite as the boss enrages. These are MULTIPLIERS over the
## artwork, not replacements for it (the old ColorRect took a flat fill), so they stay light —
## the near-black reds the ColorRect used would crush the art into an unreadable silhouette.
const PHASE_TINT := {
	1: Color(1.0, 1.0, 1.0),    # untinted — the art's own colours
	2: Color(1.0, 0.78, 0.78),  # flushing red
	3: Color(1.0, 0.45, 0.45),  # enraged
}

func _anim_set() -> String:
	return BOSS_ANIM_SET

func _char_target_height() -> float:
	return BOSS_TARGET_HEIGHT

# ─── Movement Constants ────────────────────────────────────────────────────────
const PHASE1_SPEED: float = 80.0
const PHASE2_SPEED: float = 110.0
const PHASE3_SPEED: float = 165.0   # 1.5× Phase 2 (D-12 enrage)
const CHARGE_SPEED: float = 300.0   # burst velocity during charge
const CHARGE_DURATION: float = 0.8  # seconds of charge burst

# ─── Attack Timers ────────────────────────────────────────────────────────────
var _charge_timer: float = 0.0
var _shoot_timer: float = 0.0
var _charging: bool = false
var _charge_elapsed: float = 0.0
var _phase_pause_timer: float = 0.0  # brief attack pause on phase entry (Claude's Discretion)

## Telegraph wind-ups: attacks no longer release instantly when their cooldown expires — a
## short, host-driven wind-up runs first and broadcasts a subtle presentation cue to every
## peer, so the burst/volley stops feeling like it came from nowhere. Deliberately short:
## a tell, not a cutscene.
const CHARGE_WINDUP: float = 0.5
const VOLLEY_WINDUP: float = 0.35
## How hard the boss brakes while winding up a charge — the sudden stop is itself the tell.
const WINDUP_BRAKE: float = 900.0
var _charge_windup: float = 0.0
var _volley_windup: float = 0.0

# Cooldowns per phase (tuned for playability — Claude's Discretion in CONTEXT)
const CHARGE_COOLDOWN_P1: float = 2.5
const CHARGE_COOLDOWN_P3: float = 1.8
const SHOOT_COOLDOWN_P2: float = 1.8
const SHOOT_COOLDOWN_P3: float = 1.2

# ─── Ready ────────────────────────────────────────────────────────────────────
func _ready() -> void:
	super._ready()
	# D-11: scale HP by loop — same formula as regular enemies, plus difficulty tier + player
	# count + run time + weapon count, plus a boss-only team-level factor (2026-07-18: the
	# boss needs to keep pace with card/weapon/evolution stacking, which trash mobs don't
	# need to since they don't survive long enough to matter).
	var mult: float = (1.0 + (GameState.loop_number - 1) * 0.25) * GameState.get_difficulty_player_stat_mult() * GameState.get_boss_level_mult()
	_boss_max_hp = int(1000 * mult)
	MAX_HP = _boss_max_hp
	current_hp = MAX_HP
	# Contact damage: 25 base (2.5× normal 10) scaled by loop mult (D-12 boss spec)
	CONTACT_DAMAGE = int(25 * mult)
	# Phase-1 visual baseline. super._ready() has already run _setup_enemy_sprite(), which hides
	# $Sprite in favour of the CharSprite art — the ColorRect's offsets no longer matter, but its
	# colour does (Enemy._exit_tree reads it for the death burst), so route through the same sink
	# the phase transitions use instead of setting it by hand here.
	_apply_phase_visual(1)
	# Initialise timers so boss starts attacking immediately
	_charge_timer = CHARGE_COOLDOWN_P1
	_shoot_timer  = SHOOT_COOLDOWN_P2

# ─── Damage / Phase Logic ─────────────────────────────────────────────────────
## Override take_damage (called by Bullet.gd line 55 via enemy.take_damage(BULLET_DAMAGE)).
## Host-only. Double-fire-safe: checks phase == N BEFORE HP threshold (RESEARCH Pitfall 4).
func take_damage(amount: int) -> void:
	if not is_multiplayer_authority():
		return
	current_hp = max(current_hp - amount, 0)
	# Phase-advance guards: phase check prevents double-fire on multi-bullet frames
	if phase == 1 and current_hp <= _boss_max_hp * 0.66:
		_enter_phase(2)
	elif phase == 2 and current_hp <= _boss_max_hp * 0.33:
		_enter_phase(3)
	if current_hp <= 0:
		died.emit(global_position)
		queue_free()

## Advance to a new phase: update state, broadcast color, request mob swarm.
func _enter_phase(new_phase: int) -> void:
	phase = new_phase
	_notify_phase_change.rpc(new_phase)
	# Reset attack timers on phase entry
	var charge_cd := CHARGE_COOLDOWN_P3 if new_phase == 3 else CHARGE_COOLDOWN_P1
	_charge_timer = charge_cd
	var shoot_cd := SHOOT_COOLDOWN_P3 if new_phase == 3 else SHOOT_COOLDOWN_P2
	_shoot_timer = shoot_cd
	_charging = false
	_charge_elapsed = 0.0
	# Cancel any wind-up in flight — its attack must not release into the phase pause
	_charge_windup = 0.0
	_volley_windup = 0.0
	# Brief attack pause on phase entry (Claude's Discretion in CONTEXT)
	_phase_pause_timer = 2.0
	# D-14: request mob swarm from Game node (call_deferred is physics-safe — RESEARCH pattern)
	var game := get_tree().get_root().get_node_or_null("Game")
	if game and game.has_method("_spawn_mob_swarm"):
		game._spawn_mob_swarm.call_deferred(new_phase)

## RPC: broadcast phase color change to all peers (D-13).
@rpc("authority", "call_local", "reliable")
func _notify_phase_change(new_phase: int) -> void:
	_apply_phase_visual(new_phase)
	Sfx.play("boss_phase")  # reserved voice — must cut through the swarm it summons

## Two sinks, because they serve two different consumers:
##
## $Sprite (the ColorRect) is now hidden behind the artwork, but Enemy._exit_tree still reads
## its `.color` to pick the death-burst particle colour — so it stays the boss's saturated
## identity colour and must keep being updated.
##
## $CharSprite.modulate is what the player actually sees. It deliberately does NOT go on the
## boss node's own `modulate`: Enemy._process rewrites that every frame from the burn/slow
## status tint, so a phase tint there would be wiped within a frame. The child's modulate
## multiplies through instead, so the phase tint, the status tint and Juice.flash's overbright
## pop all compose rather than fight.
func _apply_phase_visual(new_phase: int) -> void:
	if has_node("Sprite"):
		match new_phase:
			1: $Sprite.color = Color(0.15, 0.05, 0.05, 1)  # near-black red — Phase 1
			2: $Sprite.color = Color(0.4,  0.05, 0.05, 1)  # dark red — Phase 2
			3: $Sprite.color = Color(0.6,  0.0,  0.0,  1)  # bright red — Phase 3 enrage
	if has_node("CharSprite"):
		$CharSprite.modulate = PHASE_TINT.get(new_phase, Color.WHITE)

# ─── Physics / Attack Loop ────────────────────────────────────────────────────
## Override _physics_process to add phase-gated attacks.
## P6: inherited set_physics_process(is_multiplayer_authority()) in Enemy._ready() already
## ensures this only runs on host — do NOT re-add that guard here.
func _physics_process(delta: float) -> void:
	# Phase pause: no attacks immediately after phase transition
	if _phase_pause_timer > 0.0:
		_phase_pause_timer -= delta
		# Still move toward player during pause (just no attacks)
		_chase_player(delta)
		move_and_slide()
		_tick_status_effects(delta)
		return

	# Tick attack timers
	_charge_timer -= delta
	if phase >= 2:
		_shoot_timer -= delta

	# Handle active charge burst
	if _charging:
		_charge_elapsed += delta
		if _charge_elapsed >= CHARGE_DURATION:
			_charging = false
			_charge_elapsed = 0.0
		else:
			# During charge: full speed directly toward nearest player
			var target := _find_nearest_player()
			if target:
				velocity = (target.global_position - global_position).normalized() * CHARGE_SPEED
			move_and_slide()
			_tick_status_effects(delta)
			return

	# Charge wind-up in progress: brake hard instead of chasing, release the burst when done.
	# The stop plus the crouch cue broadcast at wind-up start is the whole telegraph.
	if _charge_windup > 0.0:
		_charge_windup -= delta
		if _charge_windup <= 0.0:
			_charging = true
			_charge_elapsed = 0.0
		velocity = velocity.move_toward(Vector2.ZERO, WINDUP_BRAKE * delta)
		move_and_slide()
		_tick_status_effects(delta)
		return

	# Phase 1+: melee charge trigger — telegraph first, the burst releases when it ends
	if _charge_timer <= 0.0:
		var cd := CHARGE_COOLDOWN_P3 if phase == 3 else CHARGE_COOLDOWN_P1
		_charge_timer = cd
		_charge_windup = CHARGE_WINDUP
		_show_telegraph.rpc("charge")

	# Volley wind-up in progress: keeps moving (subtle) — fires when the blink ends
	if _volley_windup > 0.0:
		_volley_windup -= delta
		if _volley_windup <= 0.0:
			_fire_volley()
	# Phase 2+: ranged volley trigger — telegraph first
	elif phase >= 2 and _shoot_timer <= 0.0:
		var cd := SHOOT_COOLDOWN_P3 if phase == 3 else SHOOT_COOLDOWN_P2
		_shoot_timer = cd
		_volley_windup = VOLLEY_WINDUP
		_show_telegraph.rpc("volley")

	# Normal chase movement
	_chase_player(delta)
	move_and_slide()
	_tick_status_effects(delta)

## Chase logic extracted to a helper (reuses Enemy.gd NavigationAgent2D pattern).
func _chase_player(_delta: float) -> void:
	var base_speed := PHASE3_SPEED if phase == 3 else (PHASE2_SPEED if phase == 2 else PHASE1_SPEED)
	var target := _find_nearest_player()
	if target == null or global_position.distance_to(target.global_position) > DETECT_RADIUS:
		state = 0
		velocity = Vector2.ZERO
		return
	state = 1
	$NavigationAgent2D.target_position = target.global_position
	if not $NavigationAgent2D.is_navigation_finished():
		var next: Vector2 = $NavigationAgent2D.get_next_path_position()
		velocity = (next - global_position).normalized() * base_speed * speed_multiplier
	else:
		velocity = Vector2.ZERO

## Presentation-only attack telegraph, broadcast right when a wind-up starts. Subtle by
## design (a tell, not a stinger): the charge crouches the sprite wide-and-low and drops a
## faint phase-tinted ground ring under the boss; the volley is a quick warm overbright
## blink. No gameplay state changes here — release timing lives in _physics_process.
@rpc("authority", "call_local", "reliable")
func _show_telegraph(kind: String) -> void:
	var spr: CanvasItem = get_node_or_null("CharSprite")
	if spr == null:
		return
	match kind:
		"charge":
			# Negative amount inverts the stretch: wider + shorter = pre-pounce crouch
			Juice.stretch(spr, Vector2.DOWN, -0.14, CHARGE_WINDUP)
			_spawn_telegraph_ring()
		"volley":
			Juice.flash(spr, Color(1.7, 1.5, 1.1, 1.0), VOLLEY_WINDUP)

## Faint expanding ring under the boss during the charge wind-up — same ColorRect idiom as
## Enemy._play_spawn_telegraph, but phase-tinted and quieter (alpha 0.35). Parented to
## FxLayer, never to the boss (Pitfall 3/4), and self-frees when the tween ends.
func _spawn_telegraph_ring() -> void:
	var layer: Node2D = get_node_or_null("/root/Game/FxLayer") as Node2D
	if layer == null:
		return
	const RING_RADIUS: float = 34.0
	var ring := ColorRect.new()
	var tint: Color = PHASE_TINT.get(phase, Color.WHITE)
	ring.color = Color(tint.r, tint.g * 0.55, tint.b * 0.55, 0.35)
	ring.size = Vector2(RING_RADIUS * 2.0, RING_RADIUS * 2.0)
	ring.pivot_offset = Vector2(RING_RADIUS, RING_RADIUS)
	ring.position = global_position - Vector2(RING_RADIUS, RING_RADIUS)
	ring.scale = Vector2(0.3, 0.3)
	layer.add_child(ring)
	var tw := ring.create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_property(ring, "scale", Vector2(1.0, 1.0), CHARGE_WINDUP * 0.8)
	tw.parallel().tween_property(ring, "modulate:a", 0.0, CHARGE_WINDUP)
	tw.tween_callback(ring.queue_free)

# ─── Ranged Volley ────────────────────────────────────────────────────────────
## Fire a spread of bullets toward the nearest player (Phase 2+).
## Uses existing BulletSpawner data contract (keys: pos, dir, owner_id, fire_burst).
## owner_id = -1 for boss bullets (no player owner — RESEARCH Open Question 1).
## Guard: multiplayer.is_server() — only host spawns bullets.
func _fire_volley() -> void:
	if not multiplayer.is_server():
		return
	var target := _find_nearest_player()
	if target == null:
		return
	var game := get_tree().get_root().get_node_or_null("Game")
	if game == null:
		return
	var spawner := game.get_node_or_null("BulletSpawner")
	if spawner == null:
		return

	# Direction to nearest player
	var base_dir: Vector2 = (target.global_position - global_position).normalized()

	# Spread angles: Phase 2 = 4 bullets at ±20°, ±40°; Phase 3 = 5 bullets at 0°, ±15°, ±30°
	var angles_deg: Array
	if phase == 3:
		angles_deg = [0.0, 15.0, -15.0, 30.0, -30.0]
	else:
		angles_deg = [20.0, -20.0, 40.0, -40.0]

	for deg in angles_deg:
		var rad: float = deg_to_rad(deg)
		var spread_dir: Vector2 = base_dir.rotated(rad)
		spawner.spawn({
			"pos":       global_position,
			"dir":       spread_dir,
			"owner_id":  -1,
			"fire_burst": false
		})
