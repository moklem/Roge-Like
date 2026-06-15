extends Node2D
## IceTrailZone — frost patch spawned by Ice element player movement.
## D-18 (ELEM-04): Slows enemies that enter (50% speed, 1.5 sec override).
## Lifetime 2 seconds, then queue_free.
## Host-authoritative: spawned by Game.gd IceTrailSpawner (host-only spawn).
## Clients see zone via IceTrailSpawner replication (P7).

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
		body.apply_slow()
		# Ice Trail slow is 1.5s; apply_slow() sets 2.0s — override to 1.5s (D-18)
		body._slow_timer = SLOW_DURATION

func _draw_visual() -> void:
	# Light-blue ColorRect (40x40px, semi-transparent) — Claude's discretion
	var rect := ColorRect.new()
	rect.color = Color(0.6, 0.85, 1.0, 0.5)
	rect.size = Vector2(40.0, 40.0)
	rect.pivot_offset = Vector2(20.0, 20.0)
	rect.position = Vector2(-20.0, -20.0)
	add_child(rect)
