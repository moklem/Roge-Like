extends Node2D
## HealDrone — Engineer deployable heal zone. Spawned by Game.gd DroneSpawner.
## D-14: Stage-1 stays fixed at deploy position; pulses +15 HP within 150px every 3s.
## D-15: Stage-2 follows the Engineer; +25 HP within 200px every 3s.
## Host authority: drone authority stays on host (Pitfall 2 — never transfer authority to owning peer).
## MultiplayerSynchronizer on this scene replicates position so Stage-2 follow is seen by all peers.

@export var owning_peer: int = 0
@export var stage: int = 1

const PULSE_INTERVAL: float = 3.0
const LIFETIME: float = 10.0          # drone despawns after 10s
## Stage-1 stats (D-14)
const PULSE_HEAL_S1: int = 15
const PULSE_RADIUS_S1: float = 150.0
## Stage-2 stats (D-15)
const PULSE_HEAL_S2: int = 25
const PULSE_RADIUS_S2: float = 200.0

var _pulse_timer: Timer = null
var _area: Area2D = null
var _lifetime_elapsed: float = 0.0

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
	# Stage-2: follow owning Engineer position
	if stage < 2:
		return
	for p in get_tree().get_nodes_in_group("players"):
		if p.peer_id == owning_peer:
			global_position = p.global_position
			break

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
	# Small green ColorRect 20x20 — placeholder visual, distinct from SpinningTires
	var rect := ColorRect.new()
	rect.color = Color(0.2, 0.9, 0.3, 0.9)
	rect.size = Vector2(20.0, 20.0)
	rect.pivot_offset = Vector2(10.0, 10.0)
	rect.position = Vector2(-10.0, -10.0)
	add_child(rect)

## Heal radius indicator — runs on all peers so everyone sees the drone's reach.
## Drawn below the drone rect; stage is set by the spawner before add_child, so the
## radius matches the actual pulse range (150px S1 / 200px S2).
func _draw() -> void:
	var radius: float = PULSE_RADIUS_S2 if stage >= 2 else PULSE_RADIUS_S1
	draw_circle(Vector2.ZERO, radius, Color(0.2, 0.9, 0.3, 0.07))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, Color(0.2, 0.9, 0.3, 0.45), 2.0)
