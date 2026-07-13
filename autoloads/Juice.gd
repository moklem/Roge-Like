extends Node
## Juice — local, non-networked juice execution facade (autoload).
## No RPCs of its own: callers already run identically on every peer (diff-watch
## Pattern A, or an existing broadcast RPC — Pattern B), so Juice only ever needs to
## execute a purely local, cosmetic reaction. Provides: trauma-based screen shake
## (local authority Camera2D only), local cosmetic hit-stop, pooled/aggregated
## floating damage numbers, hit-flash, parametrized CPUParticles2D bursts, and the
## single shared element-color lookup reused by every later wave.
##
## Hard constraints (never violate, see RESEARCH.md Pitfall 1 / Anti-Patterns):
## hit-stop is a private cosmetic float read only by presentation code — it must
## NEVER touch the engine-global process-speed knob or pause the whole SceneTree,
## since this project's client-simulated bullets have no MultiplayerSynchronizer and
## would desync across peers. Every particle effect is CPUParticles2D only (SYS-01).

## Cosmetic hit-stop scale (NOT the engine-global process-speed knob — see file header).
const HITSTOP_SLOWED_SCALE: float = 0.06

## Trauma-accumulator shake constants (UI-SPEC "Screen Shake" section).
const TRAUMA_DECAY_PER_SEC: float = 2.5
const SHAKE_MAX_OFFSET: float = 16.0
const SHAKE_MAX_ROTATION: float = 0.05

## Pooled damage-number constants (SYS-02, Pitfall 5).
const DAMAGE_NUMBER_POOL_SIZE: int = 24
const DAMAGE_NUMBER_AGGREGATE_WINDOW: float = 0.1
const DAMAGE_NUMBER_LIFETIME: float = 0.6

const DamageNumberScene: PackedScene = preload("res://scenes/vfx/DamageNumber.tscn")

var trauma: float = 0.0

var _hitstop_timer: float = 0.0
var _damage_number_pool: Array = []  # Array[Dictionary]: node/target_id/aggregate_until/busy_until

func _process(delta: float) -> void:
	_update_shake(delta)

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
	if trauma <= 0.0:
		if cam != null:
			cam.offset = Vector2.ZERO
			cam.rotation = 0.0
		return
	trauma = maxf(trauma - TRAUMA_DECAY_PER_SEC * delta, 0.0)
	if cam == null:
		return
	var shake_amount := trauma * trauma
	if shake_amount <= 0.0:
		cam.offset = Vector2.ZERO
		cam.rotation = 0.0
		return
	cam.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * SHAKE_MAX_OFFSET * shake_amount
	cam.rotation = randf_range(-1.0, 1.0) * SHAKE_MAX_ROTATION * shake_amount

## Finds the local authority player's Camera2D (each Player.tscn owns its own,
## `enabled` only for the local authority peer — Phase 9 D-01 convention).
func _local_camera() -> Camera2D:
	for player in get_tree().get_nodes_in_group("players"):
		if player.is_multiplayer_authority() and player.has_node("Camera2D"):
			return player.get_node("Camera2D") as Camera2D
	return null

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
	# Backstop cleanup (SYS-03) — queue_free() on an already-freed node is a safe no-op.
	get_tree().create_timer(lifetime + 0.5).timeout.connect(func() -> void:
		if is_instance_valid(p):
			p.queue_free()
	)

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
				entry["node"].global_position = pos
				entry["node"].show_number(entry["amount"], color)
				return

	for entry in _damage_number_pool:
		if now >= entry["busy_until"]:
			entry["target_id"] = target_id
			entry["amount"] = amount
			entry["aggregate_until"] = now + DAMAGE_NUMBER_AGGREGATE_WINDOW
			entry["busy_until"] = now + DAMAGE_NUMBER_LIFETIME
			entry["node"].global_position = pos
			entry["node"].show_number(amount, color)
			return
	# Pool exhausted — drop silently, never grow (SYS-02).

func _ensure_damage_number_pool() -> void:
	if not _damage_number_pool.is_empty():
		return
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
