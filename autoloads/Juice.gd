extends Node
## Juice — local, non-networked juice execution facade (autoload).
## No RPCs of its own: callers already run identically on every peer (diff-watch
## Pattern A, or an existing broadcast RPC — Pattern B), so Juice only ever needs to
## execute a purely local, cosmetic reaction. Provides: trauma-based screen shake
## (local authority Camera2D only), local cosmetic hit-stop, tiered impact feedback
## (flash / spark / squash / ring), hit-flash, parametrized CPUParticles2D bursts, and
## the single shared element-color lookup reused by every later wave.
##
## Hard constraints (never violate, see RESEARCH.md Pitfall 1 / Anti-Patterns):
## hit-stop is a private cosmetic float read only by presentation code — it must
## NEVER touch the engine-global process-speed knob or pause the whole SceneTree,
## since this project's client-simulated bullets have no MultiplayerSynchronizer and
## would desync across peers. Every particle effect is CPUParticles2D only (SYS-01).

## Cosmetic hit-stop scale (NOT the engine-global process-speed knob — see file header).
const HITSTOP_SLOWED_SCALE: float = 0.06

## Trauma-accumulator shake constants (UI-SPEC "Screen Shake" section).
## Shake scales with trauma SQUARED, so these ceilings are only ever reached at trauma 1.0:
## a normal hit (trauma ~0.6) lands at ~8px / ~0.27s, an Elite/Boss hit near ~13px.
const TRAUMA_DECAY_PER_SEC: float = 2.2
const SHAKE_MAX_OFFSET: float = 22.0
const SHAKE_MAX_ROTATION: float = 0.035

## Damage vignette (local screen effect): a red pulse on every hit taken, plus a
## persistent breathing tint once HP drops below LOW_HP_THRESHOLD.
const VIGNETTE_COLOR: Color = Color(0.85, 0.06, 0.09)
const VIGNETTE_PULSE_ALPHA: float = 0.55
const VIGNETTE_PULSE_FADE: float = 0.3
const LOW_HP_THRESHOLD: float = 0.3
const LOW_HP_MAX_ALPHA: float = 0.34
const LOW_HP_BREATH_HZ: float = 1.2

## Impact tiers, expressed as a fraction of the target's max HP rather than as a raw damage
## number, so the ladder stays meaningful while both enemy HP (per loop) and weapon damage
## (per card upgrade) grow. Against a 50 HP enemy: a burn tick is 5/50 = 0.10 (light), a bolt
## or Exhaust cone 20/50 = 0.40 (medium), a Horn shockwave 30/50 = 0.60 (heavy).
const IMPACT_MEDIUM_RATIO: float = 0.18
const IMPACT_HEAVY_RATIO: float = 0.55

## Heavy hits micro-freeze — but one Horn blast lands heavy on up to 8 enemies in the SAME
## frame, and a run sustains 20-40 hits/sec across three players. Without this cooldown the
## freezes chain into a permanent stutter, so a volley reads as one freeze, not eight.
const IMPACT_HITSTOP_DURATION: float = 0.035
const IMPACT_HITSTOP_COOLDOWN: float = 0.35

var trauma: float = 0.0

var _hitstop_timer: float = 0.0
var _impact_hitstop_until: float = 0.0

## Shake writes to the camera's `offset`, which Player.tscn already uses for its own
## framing nudge — cache that base so shake is added ON TOP of it instead of erasing it.
var _shake_cam: Camera2D = null
var _cam_base_offset: Vector2 = Vector2.ZERO

var _vignette: TextureRect = null
var _vignette_pulse: float = 0.0
var _low_hp_factor: float = 0.0
## Set_low_hp_ratio() refreshes this hold; when it lapses (player downed, run over,
## scene changed) the tint decays out on its own — no explicit reset call to forget.
var _low_hp_hold: float = 0.0
var _breath_phase: float = 0.0

func _process(delta: float) -> void:
	_update_shake(delta)
	_update_vignette(delta)

# ------------------------------------------------------------------------------
# Shared element-color lookup (single source of truth, reused by every later wave:
# damage numbers, element hit VFX, level-up burst, evolution burst — UI-SPEC table).
# ------------------------------------------------------------------------------
func element_color(element: String) -> Color:
	match element.to_lower():
		"fire":
			return Color(1.0, 0.55, 0.1)
		"ice":
			return Color(0.49, 0.78, 1.0)
		"earth":
			return Color(0.30, 0.69, 0.42)
		_:
			return Color(1.0, 1.0, 1.0)

# ------------------------------------------------------------------------------
# Trauma-accumulator screen shake — local authority Camera2D only (DMG-03/SYS-02).
# ------------------------------------------------------------------------------

## Adds shake trauma, scaled by Settings.shake_multiplier() at add time so the
## off/low/normal setting governs shake only (D-08/D-11), clamped 0..1.
func add_trauma(amount: float) -> void:
	trauma = clampf(trauma + amount * Settings.shake_multiplier(), 0.0, 1.0)

func _update_shake(delta: float) -> void:
	var cam := _local_camera()
	if cam != _shake_cam:
		# Camera swapped (respawn / new run). Restore the old one's framing offset, re-cache
		# the new one's, and drop any in-flight trauma so a mid-shake offset never gets
		# mistaken for the base and baked in permanently.
		if is_instance_valid(_shake_cam):
			_shake_cam.offset = _cam_base_offset
			_shake_cam.rotation = 0.0
		_shake_cam = cam
		_cam_base_offset = cam.offset if cam != null else Vector2.ZERO
		trauma = 0.0
	if cam == null:
		return
	if trauma <= 0.0:
		cam.offset = _cam_base_offset
		cam.rotation = 0.0
		return
	trauma = maxf(trauma - TRAUMA_DECAY_PER_SEC * delta, 0.0)
	var shake_amount := trauma * trauma
	cam.offset = _cam_base_offset + Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * SHAKE_MAX_OFFSET * shake_amount
	cam.rotation = randf_range(-1.0, 1.0) * SHAKE_MAX_ROTATION * shake_amount

## Finds the local authority player's Camera2D (each Player.tscn owns its own,
## `enabled` only for the local authority peer — Phase 9 D-01 convention).
func _local_camera() -> Camera2D:
	for player in get_tree().get_nodes_in_group("players"):
		if player.is_multiplayer_authority() and player.has_node("Camera2D"):
			return player.get_node("Camera2D") as Camera2D
	return null

# ------------------------------------------------------------------------------
# Damage vignette — a red screen-edge tint owned by this autoload, so it survives
# scene changes and needs no node in any gameplay scene. Purely local: only the
# owning peer's own damage tints their own screen, never a teammate's.
# ------------------------------------------------------------------------------

## Flashes the vignette on a hit. `strength` 0..1 scales the peak alpha; a stronger
## hit already in flight is never shortened by a weaker one.
func vignette_pulse(strength: float = 1.0) -> void:
	_vignette_pulse = maxf(_vignette_pulse, clampf(strength, 0.0, 1.0) * VIGNETTE_PULSE_ALPHA)

## Feeds the persistent low-HP tint, called every frame by the local player while alive.
## `hp_ratio` is current/max HP; above LOW_HP_THRESHOLD the tint is off, and it ramps to
## full as HP approaches zero. Stopping the calls (downed, dead, menu) fades it out.
func set_low_hp_ratio(hp_ratio: float) -> void:
	_low_hp_hold = 0.25
	if hp_ratio >= LOW_HP_THRESHOLD:
		_low_hp_factor = 0.0
	else:
		_low_hp_factor = clampf(1.0 - hp_ratio / LOW_HP_THRESHOLD, 0.0, 1.0)

func _update_vignette(delta: float) -> void:
	var v := _ensure_vignette()
	if v == null:
		return
	_vignette_pulse = maxf(_vignette_pulse - (VIGNETTE_PULSE_ALPHA / VIGNETTE_PULSE_FADE) * delta, 0.0)
	# Nobody fed a ratio this frame — the player is downed, dead, or we left the game
	# scene entirely. Decay out rather than leaving a red screen behind on GameOver.
	_low_hp_hold = maxf(_low_hp_hold - delta, 0.0)
	if _low_hp_hold <= 0.0:
		_low_hp_factor = maxf(_low_hp_factor - delta * 2.0, 0.0)

	_breath_phase = fmod(_breath_phase + delta * LOW_HP_BREATH_HZ * TAU, TAU)
	var breath := 0.65 + 0.35 * sin(_breath_phase)
	var low_alpha := _low_hp_factor * LOW_HP_MAX_ALPHA * breath

	var alpha := maxf(_vignette_pulse, low_alpha)
	v.visible = alpha > 0.002
	v.modulate.a = alpha

## Builds the vignette lazily: a radial GradientTexture2D (clear centre → solid red at
## the rim) stretched over the whole viewport. GradientTexture2D is used instead of a
## shader so this stays safe under the project's gl_compatibility renderer.
func _ensure_vignette() -> TextureRect:
	if is_instance_valid(_vignette):
		return _vignette

	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	gradient.colors = PackedColorArray([
		Color(VIGNETTE_COLOR, 0.0),
		Color(VIGNETTE_COLOR, 0.0),
		VIGNETTE_COLOR,
	])
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 256
	tex.height = 256

	var layer := CanvasLayer.new()
	layer.name = "VignetteLayer"
	layer.layer = 4  # above PlayerHUD (1), CardOverlay (2) and CarHUD (3)
	add_child(layer)

	var rect := TextureRect.new()
	rect.name = "DamageVignette"
	rect.texture = tex
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.visible = false
	layer.add_child(rect)
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_vignette = rect
	return _vignette

# ------------------------------------------------------------------------------
# Local cosmetic hit-stop (Pattern C) — a private per-peer float, never the
# engine-global process-speed knob, never a SceneTree-wide pause. Read ONLY by
# presentation code (camera shake decay, sprite flash tweens, particle timestep).
# ------------------------------------------------------------------------------

## Requests a cosmetic hit-stop dip of `duration` seconds (D-06: ~60-80ms on a
## normal kill, up to ~120ms on Elite/Boss). Never shortens an already-longer dip.
func hitstop(duration: float) -> void:
	_hitstop_timer = maxf(_hitstop_timer, duration)

## Presentation code calls this INSTEAD OF delta directly during an active hit-stop
## dip. Never call from gameplay code (movement, AI, cooldowns, RPC dispatch).
func cosmetic_delta(delta: float) -> float:
	if _hitstop_timer > 0.0:
		_hitstop_timer = maxf(_hitstop_timer - delta, 0.0)
		return delta * HITSTOP_SLOWED_SCALE
	return delta

# ------------------------------------------------------------------------------
# Hit-flash (delegates to scenes/vfx/HitFlash.gd).
# ------------------------------------------------------------------------------
func flash(node: CanvasItem, color: Color = Color(2.0, 2.0, 2.0, 1.0), dur: float = 0.1) -> void:
	HitFlash.flash(node, color, dur)

# ------------------------------------------------------------------------------
# Particle bursts (delegates to scenes/vfx/ImpactBurst.gd) — always parented to the
# persistent FxLayer, never to the triggering node (Pitfall 3/4), with a backstop
# cleanup timer alongside the particle's own `finished` cleanup (SYS-03).
# ------------------------------------------------------------------------------
func spawn_burst(pos: Vector2, color: Color, amount: int = 14, lifetime: float = 0.6) -> void:
	var layer := _fx_layer()
	if layer == null:
		return
	var p := ImpactBurst.build(color, amount, lifetime)
	layer.add_child(p)
	p.global_position = pos
	_backstop_free(p, lifetime + 0.5)

## Backstop cleanup (SYS-03) for a particle that normally frees itself on `finished`.
##
## The node is held through a WeakRef rather than captured directly by the lambda: in the
## common case the particle has ALREADY freed itself by the time this timer fires, and a
## lambda that captured the node directly errors out on invocation ("lambda capture was
## freed") rather than quietly no-opping. A WeakRef stays valid and simply hands back null.
func _backstop_free(node: Node, delay: float) -> void:
	var ref: WeakRef = weakref(node)  # explicit: weakref() returns Variant, and := on a Variant is an error here
	get_tree().create_timer(delay).timeout.connect(func() -> void:
		var n: Object = ref.get_ref()
		if n != null and is_instance_valid(n):
			(n as Node).queue_free()
	)

# ------------------------------------------------------------------------------
# Tiered impact feedback (replaces the floating damage numbers of DMG-01).
#
# Floating numbers do not survive this game's hit density: three players fielding up to
# three weapons each plus auto-firing bolts land 20-40 damage instances per second, and a
# single AoE blast can hit 8-12 enemies in one frame. Rendered as text that is unreadable
# confetti, so the feedback lives ON the enemy instead, and escalates with how hard the hit
# actually was — chip damage stays quiet, a Horn blast lands like a truck.
#
# Everything here is presentation-only and runs on every peer off the replicated current_hp
# diff. Note this means "recoil" is the SPRITE kicking back inside the enemy, never the
# physics body being displaced: displacing it would be an authoritative state change, would
# fight NavigationAgent2D, and would desync (SYS/Phase-10 hard constraint).
# ------------------------------------------------------------------------------

## Tiered impact reaction on `target`, whose visual is `sprite` (they differ: the body owns
## the world position, the sprite owns the scale/offset that get deformed).
##   every hit  -> white flash + a spark cone thrown along `hit_dir`
##   medium+    -> squash-and-stretch plus a sprite recoil kick
##   heavy      -> rate-limited micro hit-stop plus an expanding impact ring
## `severity` is damage / max_hp, clamped 0..1.
func impact(target: Node2D, sprite: CanvasItem, hit_dir: Vector2, severity: float, color: Color) -> void:
	if target == null or not is_instance_valid(target):
		return
	severity = clampf(severity, 0.0, 1.0)
	var pos: Vector2 = target.global_position
	var dir: Vector2 = hit_dir.normalized() if hit_dir.length() > 0.01 else Vector2.UP

	flash(target, Color(2.2, 2.2, 2.2, 1.0), 0.08)
	_spawn_spark(pos, dir, color, severity)

	if severity < IMPACT_MEDIUM_RATIO:
		return
	_recoil(sprite, dir, severity)

	if severity < IMPACT_HEAVY_RATIO:
		return
	var now := _now()
	if now >= _impact_hitstop_until:
		_impact_hitstop_until = now + IMPACT_HITSTOP_COOLDOWN
		hitstop(IMPACT_HITSTOP_DURATION)
	_impact_ring(pos, color)

## Spark cone thrown ALONG the hit direction rather than puffed out symmetrically — the
## directionality is what makes a hit read as having come from somewhere. Gravity is zeroed
## because this is a top-down view: sparks skid away flat, they don't fall.
func _spawn_spark(pos: Vector2, dir: Vector2, color: Color, severity: float) -> void:
	var layer := _fx_layer()
	if layer == null:
		return
	var amount: int = 4 + int(round(severity * 8.0))      # ~4 on a chip hit, ~12 on a heavy one
	var speed: float = 90.0 + severity * 160.0
	var p := ImpactBurst.build(color, amount, 0.28, dir, 38.0, speed * 0.5, speed, 1.6, 3.0)
	p.gravity = Vector2.ZERO
	layer.add_child(p)
	p.global_position = pos
	_backstop_free(p, 0.8)

## Squash-and-stretch plus a positional kick, both sprung back to rest. Squats and widens the
## sprite — the classic "took a punch" deformation.
func _recoil(sprite: CanvasItem, dir: Vector2, severity: float) -> void:
	if sprite == null or not is_instance_valid(sprite) or not (sprite is Node2D):
		return
	var s := sprite as Node2D
	var rest := _rest_pose(s)
	var rest_scale: Vector2 = rest["scale"]
	var rest_position: Vector2 = rest["position"]
	_kill_pose_tween(s)

	var squash: float = 0.16 + 0.14 * severity
	s.scale = Vector2(rest_scale.x * (1.0 + squash), rest_scale.y * (1.0 - squash))
	s.position = rest_position + dir * (5.0 + 9.0 * severity)

	var tw := s.create_tween()
	tw.set_ignore_time_scale(true)
	tw.set_parallel(true)
	tw.tween_property(s, "scale", rest_scale, 0.18).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(s, "position", rest_position, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	s.set_meta("juice_pose_tween", tw)

## Axis-aligned stretch pop, sprung back to rest: the axis nearest `along` gets longer while
## the other narrows, which sells volume preservation without rotating the sprite (rotation
## would fight the flip_h that the walk animation drives). Used by the Speedster dash.
func stretch(sprite: CanvasItem, along: Vector2, amount: float = 0.22, duration: float = 0.3) -> void:
	if sprite == null or not is_instance_valid(sprite) or not (sprite is Node2D):
		return
	var s := sprite as Node2D
	var rest := _rest_pose(s)
	var rest_scale: Vector2 = rest["scale"]
	_kill_pose_tween(s)

	var horizontal: bool = absf(along.x) >= absf(along.y)
	var factor := Vector2(1.0 + amount, 1.0 - amount) if horizontal else Vector2(1.0 - amount, 1.0 + amount)
	s.scale = rest_scale * factor

	var tw := s.create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_property(s, "scale", rest_scale, duration).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	s.set_meta("juice_pose_tween", tw)

## Captures a sprite's rest scale/position ONCE, on first deformation, and returns it forever
## after. Re-reading them live would let a second hit landing mid-tween mistake a half-squashed
## frame for the rest pose and compound the deformation until the sprite is a smear. Node
## metadata is used rather than a dictionary on this autoload so the entry dies with the node
## and cannot leak across a run.
func _rest_pose(s: Node2D) -> Dictionary:
	if not s.has_meta("juice_rest_scale"):
		s.set_meta("juice_rest_scale", s.scale)
		s.set_meta("juice_rest_position", s.position)
	return {
		"scale": s.get_meta("juice_rest_scale"),
		"position": s.get_meta("juice_rest_position"),
	}

## Cancels any deformation still springing back, so a dash landing mid-recoil (or a second hit
## mid-dash) restarts cleanly from the rest pose instead of two tweens fighting over `scale`.
## has_meta() is checked first: get_meta()'s default argument is not a safe "missing" fallback
## — passing null as the default still raises on a key that was never set.
func _kill_pose_tween(s: Node2D) -> void:
	if not s.has_meta("juice_pose_tween"):
		return
	var running: Variant = s.get_meta("juice_pose_tween")
	if running is Tween and (running as Tween).is_valid():
		(running as Tween).kill()

## Expanding ring at the impact point — the "that one hurt" marker reserved for heavy hits.
## Same ColorRect + scale/fade tween idiom as the dash shockwave and the drone deploy pop.
func _impact_ring(pos: Vector2, color: Color) -> void:
	var layer := _fx_layer()
	if layer == null:
		return
	const RADIUS: float = 18.0
	var ring := ColorRect.new()
	ring.color = Color(color.r, color.g, color.b, 0.55)
	ring.size = Vector2(RADIUS * 2.0, RADIUS * 2.0)
	ring.pivot_offset = Vector2(RADIUS, RADIUS)
	ring.scale = Vector2(0.25, 0.25)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ring)
	ring.global_position = pos - Vector2(RADIUS, RADIUS)
	var tween := ring.create_tween()
	tween.set_ignore_time_scale(true)
	tween.tween_property(ring, "scale", Vector2(1.5, 1.5), 0.22)
	tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.22)
	tween.tween_callback(ring.queue_free)

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

# ------------------------------------------------------------------------------
# FxLayer resolution — every transient VFX parents here, never to the triggering
# node (Pitfall 3/4). Returns null safely when absent (e.g. at the main menu).
# ------------------------------------------------------------------------------
func _fx_layer() -> Node2D:
	return get_node_or_null("/root/Game/FxLayer") as Node2D
