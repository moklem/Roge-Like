extends Node2D
## IceTrailZone — frost patch spawned by Ice element player movement.
## D-18 (ELEM-04): Freezes enemies that enter — near-total stop (5% speed) for 1.5 sec.
## Lifetime 2 seconds, then queue_free.
## Host-authoritative: spawned by Game.gd IceTrailSpawner (host-only spawn).
## Clients see zone via IceTrailSpawner replication (P7).

const FREEZE_MULT: float = 0.05
const SLOW_DURATION: float = 1.5
const LIFETIME: float = 2.0
const ZONE_RADIUS: float = 20.0

var _elapsed: float = 0.0
var _area: Area2D = null

func _ready() -> void:
	_setup_area()
	_draw_visual()

func _setup_area() -> void:
	# Copy HornShockwave._setup_area pattern with enemy collision mask (layer 3 = 4)
	_area = Area2D.new()
	_area.name = "TrailArea"
	_area.collision_layer = 0
	_area.collision_mask = 4    # layer 3 "enemies"
	_area.monitoring = true
	_area.monitorable = false
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = ZONE_RADIUS
	shape.shape = circle
	_area.add_child(shape)
	_area.body_entered.connect(_on_enemy_entered)
	add_child(_area)

func _physics_process(delta: float) -> void:
	# Host-only lifetime expiry (T-05-16: only host ticks zone logic)
	if not is_multiplayer_authority():
		return
	_elapsed += delta
	if _elapsed >= LIFETIME:
		queue_free()

func _on_enemy_entered(body: Node) -> void:
	# T-05-16: only host applies slow — clients never reach this
	if not is_multiplayer_authority():
		return
	if body.is_in_group("enemies") and body.has_method("apply_slow"):
		body.apply_slow(FREEZE_MULT, SLOW_DURATION, "ice")

## Frost-patch art, safe-loaded like the audio cues: drop the PNGs at these paths and they
## appear in game; while missing, the old ColorRect placeholder keeps working. Two variants
## are picked per-zone by deterministic hash (same on every peer — no sync needed).
const ART_PATHS: Array[String] = [
	"res://assets/active/elements/ice_trail_1.png",
	"res://assets/active/elements/ice_trail_2.png",
]
## On-screen footprint of the patch — slightly wider than the 20px slow radius so the
## art reads as the zone, not as a dot inside it.
const ART_WIDTH: float = 44.0

func _draw_visual() -> void:
	var available: Array[String] = []
	for p in ART_PATHS:
		if ResourceLoader.exists(p):
			available.append(p)
	if not available.is_empty():
		var tex: Texture2D = load(available[absi(str(name).hash()) % available.size()])
		var spr := Sprite2D.new()
		spr.texture = tex
		if tex.get_width() > 0:
			var s: float = ART_WIDTH / float(tex.get_width())
			spr.scale = Vector2(s, s)
		# Slight rotation variety so trails of patches don't read as stamped copies;
		# hash-derived, so every peer rotates the same zone the same way.
		spr.rotation = float(absi(str(name).hash()) % 4) * (PI * 0.5)
		spr.modulate = Color(1.0, 1.0, 1.0, 0.9)
		add_child(spr)
		return
	# Placeholder until the art lands: light-blue semi-transparent square
	var rect := ColorRect.new()
	rect.color = Color(0.6, 0.85, 1.0, 0.5)
	rect.size = Vector2(40.0, 40.0)
	rect.pivot_offset = Vector2(20.0, 20.0)
	rect.position = Vector2(-20.0, -20.0)
	add_child(rect)
