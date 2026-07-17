extends Node
## Juice — local, non-networked juice execution facade (autoload).
## No RPCs of its own: callers already run identically on every peer (diff-watch
## Pattern A, or an existing broadcast RPC — Pattern B), so Juice only ever needs to
## execute a purely local, cosmetic reaction. Provides: trauma-based screen shake
## (local authority Camera2D only), local cosmetic hit-stop, pooled/aggregated floating
## damage numbers, tiered impact feedback (flash / spark / squash / ring), hit-flash,
## parametrized CPUParticles2D bursts, and the single shared element-color lookup
## reused by every later wave.
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

## Pooled damage-number constants (SYS-02, Pitfall 5).
const DAMAGE_NUMBER_POOL_SIZE: int = 24
const DAMAGE_NUMBER_AGGREGATE_WINDOW: float = 0.1
const DAMAGE_NUMBER_LIFETIME: float = 0.6

const DamageNumberScene: PackedScene = preload("res://scenes/vfx/DamageNumber.tscn")

var trauma: float = 0.0

var _hitstop_timer: float = 0.0
var _impact_hitstop_until: float = 0.0
var _damage_number_pool: Array = []  # Array[Dictionary]: node/target_id/aggregate_until/busy_until

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
# VFX texture registry — the hand-drawn/generated comic particle sprites under
# assets/active/vfx/. Safe-loaded (missing file → vfx() returns null → the textured
# spawners fall back to the flat colored-square burst), exactly like Sfx cues: every
# call site can be wired ahead of the art landing without crashing.
# ------------------------------------------------------------------------------
const VFX_DIR: String = "res://assets/active/vfx/"
## "glow_dot" is deliberately NOT here — it's a code-generated soft radial glow (see
## _make_glow_texture), registered under the same key in _ready. A flat white glow tints
## cleanly and reads better than a hard pre-colored orb.
const VFX_NAMES: Array[String] = [
	"spark", "poof", "star", "heal_plus",
	"ember", "shard", "pebble", "levelup", "revive",
	# ground speed lines, lidar spawn ring, and the AC/climate rim overlays
	"speedline", "brakeline", "scan_ring",
	"speed_streak", "brake_puff", "overdrive_spark",
	# driver-mode REPAIR plus-cross stream + the ECO/SPORT mode badges
	"repair_plus", "badge_eco", "badge_sport",
	"rim_cold", "rim_hot", "rim_massage",
]
var _vfx: Dictionary = {}   # name -> Texture2D (absent when the file isn't there)
var _glow_tex: GradientTexture2D = null

func _ready() -> void:
	for n in VFX_NAMES:
		var path: String = VFX_DIR + n + ".png"
		if ResourceLoader.exists(path):
			_vfx[n] = load(path)
	_vfx["glow_dot"] = _make_glow_texture()

## Soft white radial glow (transparent edge), generated once — the same GradientTexture2D
## idiom as the blob shadow. Used for the death-pop dots, drone deploy and big-hit sprays;
## being white it tints cleanly, unlike a pre-colored orb sprite.
func _make_glow_texture() -> GradientTexture2D:
	if _glow_tex == null:
		var grad := Gradient.new()
		grad.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
		grad.colors = PackedColorArray([
			Color(1, 1, 1, 1), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0.0),
		])
		_glow_tex = GradientTexture2D.new()
		_glow_tex.gradient = grad
		_glow_tex.fill = GradientTexture2D.FILL_RADIAL
		_glow_tex.fill_from = Vector2(0.5, 0.5)
		_glow_tex.fill_to = Vector2(0.5, 0.0)
		_glow_tex.width = 64
		_glow_tex.height = 64
	return _glow_tex

## The comic particle sprite by name, or null when it hasn't been delivered (callers
## then degrade to the flat colored burst). See VFX_NAMES for the catalog.
func vfx(name: String) -> Texture2D:
	return _vfx.get(name, null)

# ------------------------------------------------------------------------------
# Frame-sequence registry — the multi-frame weapon/pickup animations delivered as
# <dir>/<name>_NN.png strips. Same safe-load contract as vfx(): frames() returns null
# when the art isn't there, so every call site keeps its ColorRect fallback.
# fps values are tuned per set: the two shield strips are authored to span the Tank
# shield durations exactly (36f/3s, 65f/6s), the loops are just pleasant cycle speeds.
# ------------------------------------------------------------------------------
const FRAME_SETS: Dictionary = {
	"screw":       {"dir": "res://assets/active/weapons/",  "count": 6,  "fps": 15.0, "loop": true},
	"tire":        {"dir": "res://assets/active/weapons/",  "count": 3,  "fps": 12.0, "loop": true},
	"exhaust":     {"dir": "res://assets/active/weapons/",  "count": 12, "fps": 24.0, "loop": false},
	"beam":        {"dir": "res://assets/active/weapons/",  "count": 15, "fps": 30.0, "loop": false},
	"shockwave":   {"dir": "res://assets/active/weapons/",  "count": 4,  "fps": 12.0, "loop": false},
	"shield3":     {"dir": "res://assets/active/weapons/",  "count": 36, "fps": 12.0, "loop": false},
	"shield6":     {"dir": "res://assets/active/weapons/",  "count": 65, "fps": 65.0 / 6.0, "loop": false},
	"xp_orb_anim": {"dir": "res://assets/active/pickups/",  "count": 26, "fps": 10.0, "loop": true},
}
var _frame_sets: Dictionary = {}  # name -> SpriteFrames (built lazily, shared by all users)

## The animation strip by name as a shared SpriteFrames ("default" animation), or null
## when the frames haven't been delivered — callers then keep their old flat visuals.
func frames(name: String) -> SpriteFrames:
	if _frame_sets.has(name):
		return _frame_sets[name]
	if not FRAME_SETS.has(name):
		return null
	var cfg: Dictionary = FRAME_SETS[name]
	var sf := SpriteFrames.new()
	sf.set_animation_speed("default", cfg["fps"])
	sf.set_animation_loop("default", cfg["loop"])
	for i in range(1, int(cfg["count"]) + 1):
		var path: String = "%s%s_%02d.png" % [cfg["dir"], name, i]
		if not ResourceLoader.exists(path):
			return null  # incomplete strip — treat as not delivered
		sf.add_frame("default", load(path))
	_frame_sets[name] = sf
	return sf

## One-shot frame animation at `pos` on the FxLayer — plays "default" once, frees itself.
## `target_px` is the on-screen height; silently no-ops when strip or layer is missing.
func spawn_anim(pos: Vector2, name: String, target_px: float, z: int = 6) -> AnimatedSprite2D:
	var sf := frames(name)
	var layer := _fx_layer()
	if sf == null or layer == null:
		return null
	var spr := AnimatedSprite2D.new()
	spr.sprite_frames = sf
	spr.z_index = z
	var tex: Texture2D = sf.get_frame_texture("default", 0)
	var s: float = target_px / float(maxi(tex.get_height(), 1))
	spr.scale = Vector2(s, s)
	layer.add_child(spr)
	spr.global_position = pos
	spr.play("default")
	spr.animation_finished.connect(spr.queue_free)
	_backstop_free(spr, float(sf.get_frame_count("default")) / maxf(sf.get_animation_speed("default"), 1.0) + 0.5)
	return spr

# ------------------------------------------------------------------------------
# Textured comic-pop spawners. These sit on top of spawn_burst/ImpactBurst but size the
# particles in ON-SCREEN pixels (the source PNGs are ~512px, so a raw scale_amount of 3
# would fill the screen) and keep the sprite's OWN colors (color=WHITE), since the art is
# already colored per element/effect and multiplying it would just muddy it.
# ------------------------------------------------------------------------------

## A short burst of `amount` copies of `tex`, each drawn ~`target_px` tall, thrown along `dir`.
## Silently no-ops if the texture is missing or the FxLayer isn't up yet (main menu).
func spawn_tex_burst(pos: Vector2, tex: Texture2D, amount: int, target_px: float, lifetime: float,
		spread: float = 180.0, vmin: float = 40.0, vmax: float = 120.0, dir: Vector2 = Vector2.UP,
		gravity: Vector2 = Vector2(0.0, 60.0), tint: Color = Color.WHITE) -> void:
	var layer := _fx_layer()
	if layer == null or tex == null:
		return
	var s: float = target_px / float(maxi(tex.get_height(), 1))
	# tint stays WHITE for the pre-colored comic sprites (shows their own colors); a caller passes
	# a real color only for the neutral white code-glow (e.g. the orange LIDAR spawn glow).
	var p := ImpactBurst.build(tint, amount, lifetime, dir, spread, vmin, vmax, s * 0.8, s * 1.25, tex)
	p.gravity = gravity
	layer.add_child(p)
	p.global_position = pos
	_backstop_free(p, lifetime + 0.5)

## Single big comic sprite that scale-pops in, drifts up and fades — for the one-shot "moment"
## art that already carries its own radiating lines (level-up arrow, revive cross). Not a burst.
func spawn_pop(pos: Vector2, tex: Texture2D, target_px: float = 72.0, rise: float = 26.0, hold: float = 0.45) -> void:
	var layer := _fx_layer()
	if layer == null or tex == null:
		return
	var s := Sprite2D.new()
	s.texture = tex
	s.z_index = 7
	var sc: float = target_px / float(maxi(tex.get_height(), 1))
	s.scale = Vector2(sc, sc) * 0.4
	layer.add_child(s)
	s.global_position = pos
	# set_ignore_time_scale so the pop still animates through the kill/heal hit-stop dip.
	var tw := s.create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_property(s, "scale", Vector2(sc, sc), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(s, "global_position:y", pos.y - rise, 0.22 + hold)
	tw.tween_interval(hold)
	tw.tween_property(s, "modulate:a", 0.0, 0.28)
	tw.tween_callback(s.queue_free)

## Death "POOF": a slow fat smoke puff plus a spray of glowing dots, both comic-colored. Falls
## back to the flat colored death burst when the art is absent (fallback_color = the dying
## enemy's own tint, so normal/Elite/Boss still read differently).
func spawn_death_pop(pos: Vector2, fallback_color: Color) -> void:
	var poof := vfx("poof")
	var dot := vfx("glow_dot")
	if poof == null and dot == null:
		spawn_burst(pos, fallback_color, 14, 0.6)  # art not delivered yet — old look
		return
	if poof != null:
		spawn_tex_burst(pos, poof, 3, 60.0, 0.55, 140.0, 8.0, 34.0, Vector2.UP, Vector2(0.0, -12.0))
	if dot != null:
		spawn_tex_burst(pos, dot, 8, 22.0, 0.5, 180.0, 70.0, 150.0)

## Heal cue: a few "+" crosses floating up. Falls back to the old green up-burst when absent.
func spawn_heal(pos: Vector2) -> void:
	var tex := vfx("heal_plus")
	if tex == null:
		spawn_burst(pos, Color(0.3, 1.0, 0.45, 0.9), 12, 0.7)
		return
	spawn_tex_burst(pos, tex, 6, 19.0, 0.7, 40.0, 28.0, 62.0, Vector2.UP, Vector2(0.0, -30.0))  # playtest: 26→19px, smaller heal crosses

## Expanding tinted ring at `pos` — the shared "pulse/shockwave" marker used by the drone heal
## pulse (same ColorRect + scale/fade idiom as _impact_ring and the deploy pop).
func spawn_pulse_ring(pos: Vector2, radius: float, color: Color) -> void:
	var layer := _fx_layer()
	if layer == null:
		return
	var ring := ColorRect.new()
	ring.color = Color(color.r, color.g, color.b, 0.5)
	ring.size = Vector2(radius * 2.0, radius * 2.0)
	ring.pivot_offset = Vector2(radius, radius)
	ring.scale = Vector2(0.35, 0.35)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ring)
	ring.global_position = pos - Vector2(radius, radius)
	var tween := ring.create_tween()
	tween.tween_property(ring, "scale", Vector2(1.0, 1.0), 0.45)
	tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.45)
	tween.tween_callback(ring.queue_free)

## Enemy spawn-in "materialize": a scan_ring that expands + rotates + fades, plus a brief simple
## orange glow (kept short/light on purpose). No-ops without the art. Runs on every peer from
## Enemy._ready (spawner-replicated), so no RPC.
func spawn_lidar_spawn(pos: Vector2, attach_to: Node2D = null) -> void:
	var layer := _fx_layer()
	if layer == null:
		return
	var ring_tex := vfx("scan_ring")
	if ring_tex != null:
		var ring := Sprite2D.new()
		ring.texture = ring_tex
		ring.z_index = 6
		# ~130px on screen: the art is thin radar arcs on a 512px canvas, so a small target would
		# thin the lines below a pixel and vanish. A detection-reticle-sized ring keeps them crisp.
		var sc: float = 130.0 / float(maxi(ring_tex.get_height(), 1))
		ring.scale = Vector2(sc, sc) * 0.55
		# Parent to the spawning enemy when given, so the reticle sits ON the enemy (and rides its
		# position) instead of a captured world point. Falls back to the FxLayer at `pos` otherwise.
		if attach_to != null and is_instance_valid(attach_to):
			attach_to.add_child(ring)
			ring.position = Vector2.ZERO
		else:
			layer.add_child(ring)
			ring.global_position = pos
		var tw := ring.create_tween()
		tw.set_parallel(true)
		tw.tween_property(ring, "scale", Vector2(sc, sc), 0.5).set_ease(Tween.EASE_OUT)
		tw.tween_property(ring, "rotation", 0.6, 0.5)
		tw.tween_property(ring, "modulate:a", 0.0, 0.5).set_delay(0.15)
		tw.chain().tween_callback(ring.queue_free)
	# Short, simple orange glow — the code glow tinted, just a few quick specks.
	spawn_tex_burst(pos, _make_glow_texture(), 5, 18.0, 0.25, 180.0, 30.0, 80.0,
		Vector2.UP, Vector2.ZERO, Color(0.95, 0.5, 0.12, 1.0))

# ------------------------------------------------------------------------------
# Screen-edge rim overlay — a brief colored glow around the viewport rim for the CarHUD
# climate/comfort events (AC COLD blue / AC HOT red / Seat Massage green). Same fullscreen
# TextureRect-on-a-CanvasLayer idiom as the damage vignette, but the texture is swapped per
# call (pre-colored rim_* art) and pulsed out. Local/cosmetic; caller runs on every peer.
# ------------------------------------------------------------------------------
var _rim: TextureRect = null
var _rim_tween: Tween = null

## Flash the rim overlay with `tex` (one of the pre-colored rim_* textures), fading out after a
## short hold. A new flash replaces any in-flight one. No-ops if the texture is missing.
func rim_flash(tex: Texture2D, peak: float = 0.5) -> void:
	if tex == null:
		return
	var r := _ensure_rim()
	r.texture = tex
	r.visible = true
	if _rim_tween != null and _rim_tween.is_valid():
		_rim_tween.kill()
	r.modulate.a = peak
	_rim_tween = create_tween()
	_rim_tween.tween_interval(0.5)
	_rim_tween.tween_property(r, "modulate:a", 0.0, 0.7)
	_rim_tween.tween_callback(func() -> void:
		if is_instance_valid(r):
			r.visible = false
	)

func _ensure_rim() -> TextureRect:
	if is_instance_valid(_rim):
		return _rim
	var layer := CanvasLayer.new()
	layer.name = "RimLayer"
	layer.layer = 4  # same band as the vignette, above the HUD layers
	add_child(layer)
	var rect := TextureRect.new()
	rect.name = "RimOverlay"
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.visible = false
	layer.add_child(rect)
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rim = rect
	return _rim

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
# Blob shadow — soft radial ellipse under a character's feet. Purely cosmetic and
# built in _ready on every peer (no RPC, no sync). Parented to the character (NOT
# FxLayer): the shadow must follow every frame with zero bookkeeping, and unlike
# transient VFX it dies with its owner by design.
# ------------------------------------------------------------------------------
var _blob_shadow_tex: GradientTexture2D = null

## One shared radial-gradient texture for every shadow in the run.
func _shadow_texture() -> GradientTexture2D:
	if _blob_shadow_tex == null:
		var grad := Gradient.new()
		grad.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
		grad.colors = PackedColorArray([
			Color(0, 0, 0, 1), Color(0, 0, 0, 0.75), Color(0, 0, 0, 0),
		])
		_blob_shadow_tex = GradientTexture2D.new()
		_blob_shadow_tex.gradient = grad
		_blob_shadow_tex.fill = GradientTexture2D.FILL_RADIAL
		_blob_shadow_tex.fill_from = Vector2(0.5, 0.5)
		_blob_shadow_tex.fill_to = Vector2(0.5, 0.0)
		_blob_shadow_tex.width = 64
		_blob_shadow_tex.height = 64
	return _blob_shadow_tex

## Adds the shadow as the FIRST child so tree order draws it behind the sprite while
## staying above the floor (same z as the body — never z_index, which would drop it
## below the TileMap). Returns the sprite so callers can reposition it (e.g. player
## evolution changes the character height).
func add_blob_shadow(owner_node: Node2D, width: float, foot_y: float) -> Sprite2D:
	var sh := Sprite2D.new()
	sh.name = "BlobShadow"
	sh.texture = _shadow_texture()
	sh.modulate = Color(1, 1, 1, 0.35)
	set_blob_shadow_size(sh, width, foot_y)
	owner_node.add_child(sh)
	owner_node.move_child(sh, 0)
	return sh

## Ellipse proportions: flat (~34% of width) so it reads as ground contact, not a hole.
func set_blob_shadow_size(sh: Sprite2D, width: float, foot_y: float) -> void:
	sh.scale = Vector2(width / 64.0, width * 0.34 / 64.0)
	sh.position = Vector2(0, foot_y)

## Free-standing blob shadow for static map props (obstacles, houses): same texture,
## alpha and proportions as the character shadows, but parented to an explicit container
## at an explicit position (local to `parent`). RoomBuilder grounds tile props with this.
func add_prop_shadow(parent: Node, pos: Vector2, width: float) -> Sprite2D:
	var sh := Sprite2D.new()
	sh.name = "PropShadow"
	sh.texture = _shadow_texture()
	sh.modulate = Color(1, 1, 1, 0.35)
	sh.scale = Vector2(width / 64.0, width * 0.34 / 64.0)
	sh.position = pos
	parent.add_child(sh)
	return sh

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
# Tiered impact feedback — runs ALONGSIDE the floating damage numbers (DMG-01).
#
# Numbers carry the information (how much, element color via the per-target aggregation
# in spawn_damage_number), impact carries the weight: a light hit is just flash + number
# like it always was, while medium/heavy hits add squash, recoil, sparks and the ring so
# a Horn blast still lands like a truck.
#
# Everything here is presentation-only and runs on every peer off the replicated current_hp
# diff. Note this means "recoil" is the SPRITE kicking back inside the enemy, never the
# physics body being displaced: displacing it would be an authoritative state change, would
# fight NavigationAgent2D, and would desync (SYS/Phase-10 hard constraint).
# ------------------------------------------------------------------------------

## Tiered impact reaction on `target`, whose visual is `sprite` (they differ: the body owns
## the world position, the sprite owns the scale/offset that get deformed).
##   every hit  -> white flash (the damage number spawns at the call site)
##   medium+    -> spark cone along `hit_dir` plus squash-and-stretch and a recoil kick
##   heavy      -> rate-limited micro hit-stop plus an expanding impact ring
## `severity` is damage / max_hp, clamped 0..1.
func impact(target: Node2D, sprite: CanvasItem, hit_dir: Vector2, severity: float, color: Color) -> void:
	if target == null or not is_instance_valid(target):
		return
	severity = clampf(severity, 0.0, 1.0)
	var pos: Vector2 = target.global_position
	var dir: Vector2 = hit_dir.normalized() if hit_dir.length() > 0.01 else Vector2.UP

	flash(target, Color(2.2, 2.2, 2.2, 1.0), 0.08)

	# Light hits stay quiet on purpose: flash + the floating damage number and nothing else —
	# that's the pre-Phase-10 "normal hit" look. Sparks/recoil/ring only join from medium up.
	if severity < IMPACT_MEDIUM_RATIO:
		return
	_spawn_spark(pos, dir, color, severity)
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
	# The spark sprite (a small comic twinkle) carries its own color, so pass WHITE and size it
	# in on-screen px; without the art we keep the original tiny colored-streak look (color/scale).
	var tex := vfx("spark")
	var p: CPUParticles2D
	if tex != null:
		var s: float = 18.0 / float(maxi(tex.get_height(), 1))
		p = ImpactBurst.build(Color.WHITE, amount, 0.28, dir, 38.0, speed * 0.5, speed, s * 0.7, s * 1.2, tex)
	else:
		p = ImpactBurst.build(color, amount, 0.28, dir, 38.0, speed * 0.5, speed, 1.6, 3.0)
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

# ------------------------------------------------------------------------------
# Pooled/aggregated floating damage numbers (DMG-01, SYS-02).
# ------------------------------------------------------------------------------

## Spawns (or aggregates into) a pooled floating damage number at `pos`. Rapid
## repeat hits on the same `target_id` within ~100ms are summed into the still-
## active number instead of spawning a second (SYS-02). If the fixed pool is
## exhausted, drops silently rather than growing (Pitfall 5).
func spawn_damage_number(pos: Vector2, amount: int, color: Color, target_id: int = 0) -> void:
	_ensure_damage_number_pool()
	if _damage_number_pool.is_empty():
		return  # FxLayer not present yet (e.g. main menu) — drop silently.

	var now := _now()

	if target_id != 0:
		for entry in _damage_number_pool:
			if entry["target_id"] == target_id and now < entry["aggregate_until"]:
				entry["amount"] += amount
				entry["aggregate_until"] = now + DAMAGE_NUMBER_AGGREGATE_WINDOW
				entry["busy_until"] = now + DAMAGE_NUMBER_LIFETIME
				_position_number(entry["node"], pos)
				entry["node"].show_number(entry["amount"], color)
				return

	for entry in _damage_number_pool:
		if now >= entry["busy_until"]:
			entry["target_id"] = target_id
			entry["amount"] = amount
			entry["aggregate_until"] = now + DAMAGE_NUMBER_AGGREGATE_WINDOW
			entry["busy_until"] = now + DAMAGE_NUMBER_LIFETIME
			_position_number(entry["node"], pos)
			entry["node"].show_number(amount, color)
			return
	# Pool exhausted — drop silently, never grow (SYS-02).

## A Control's position is its top-left corner, so handing the enemy position straight to the
## 120x40 label parks the text 60px right / 20px below the target. Center the rect on the
## enemy instead, lifted a touch so the number reads just above the sprite.
func _position_number(node: Control, pos: Vector2) -> void:
	node.global_position = pos - node.size * 0.5 - Vector2(0.0, 10.0)

func _ensure_damage_number_pool() -> void:
	if not _damage_number_pool.is_empty():
		# The pool lives under FxLayer, which dies with the Game scene — rebuild after a
		# scene change instead of holding freed nodes forever.
		if is_instance_valid(_damage_number_pool[0]["node"]):
			return
		_damage_number_pool.clear()
	var layer := _fx_layer()
	if layer == null:
		return
	for _i in range(DAMAGE_NUMBER_POOL_SIZE):
		var node := DamageNumberScene.instantiate()
		layer.add_child(node)
		_damage_number_pool.append({
			"node": node,
			"target_id": 0,
			"aggregate_until": 0.0,
			"busy_until": 0.0,
		})

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

# ------------------------------------------------------------------------------
# FxLayer resolution — every transient VFX parents here, never to the triggering
# node (Pitfall 3/4). Returns null safely when absent (e.g. at the main menu).
# ------------------------------------------------------------------------------
func _fx_layer() -> Node2D:
	return get_node_or_null("/root/Game/FxLayer") as Node2D
