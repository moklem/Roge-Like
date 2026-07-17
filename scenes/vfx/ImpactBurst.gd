class_name ImpactBurst
extends RefCounted
## ImpactBurst — parametrized one-shot CPUParticles2D factory (SYS-01).
## Follows the exact `_spawn_heal_particles`/`_spawn_driver_particles` idiom already
## established in scenes/Player.gd (one_shot=true, high explosiveness, emitting=true,
## finished.connect(queue_free)), but parametrized so every later burst (death, element
## hit, level-up, evolution, revive-success, drone-deploy, spawn-telegraph) shares one
## builder instead of ~10 near-duplicate hand-rolled factories.
##
## CPUParticles2D only — never GPUParticles2D (silently fails to render under this
## project's gl_compatibility renderer, SYS-01).

## Builds (but does not parent) a one-shot CPUParticles2D burst. Caller is responsible
## for `add_child()` (Juice.gd parents every burst to the persistent FxLayer, never to
## the triggering node — Pitfall 3/4) and for any backstop cleanup timer (SYS-03); this
## factory already wires the particle's own `finished -> queue_free` cleanup.
static func build(
	color: Color,
	amount: int = 14,
	lifetime: float = 0.6,
	direction: Vector2 = Vector2.UP,
	spread: float = 180.0,
	initial_velocity_min: float = 40.0,
	initial_velocity_max: float = 120.0,
	scale_min: float = 2.5,
	scale_max: float = 4.5,
	texture: Texture2D = null
) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.amount = amount
	p.lifetime = lifetime
	p.explosiveness = 0.9
	p.direction = direction
	p.spread = spread
	p.initial_velocity_min = initial_velocity_min
	p.initial_velocity_max = initial_velocity_max
	p.gravity = Vector2(0.0, 60.0)
	p.scale_amount_min = scale_min
	p.scale_amount_max = scale_max
	p.color = color
	p.z_index = 5
	# Textured bursts carry the pre-colored comic sprites (glow_dot, poof, ember, …). The caller
	# passes color=WHITE so the sprite's OWN colors show through, and this alpha ramp fades each
	# particle out over its life instead of hard-vanishing (the flat colored-square bursts, texture
	# left null, keep their original pop-out look). Godot's CPUParticles2D.color_ramp is a Gradient.
	if texture != null:
		p.texture = texture
		var ramp := Gradient.new()
		ramp.offsets = PackedFloat32Array([0.0, 0.7, 1.0])
		ramp.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.85), Color(1, 1, 1, 0.0)])
		p.color_ramp = ramp
	p.emitting = true
	p.finished.connect(p.queue_free)
	return p
