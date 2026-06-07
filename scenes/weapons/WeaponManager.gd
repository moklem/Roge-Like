extends Node
## WeaponManager — child of Player.tscn. Owns all weapon unlock state and fire logic.
## D-06: Holds unlocked_weapons Array, weapon_level Dict, per-weapon Timers.
## D-07: Authority pattern — owning peer's WM calls fire; host spawns projectile.
## D-08: ScrewsAndBolts migrated from Player._try_fire (always unlocked on start).
## D-15: Max 6 weapons; add_weapon returns false if full (silent cap, no UI in Phase 4).
## D-16: reset() called from game-over path; clears all weapons and airbag charge.

const MAX_WEAPONS: int = 3
const WEAPON_IDS: Array[String] = [
	"screws_and_bolts", "exhaust_flames", "spinning_tires",
	"antenna_beam", "horn_shockwave", "airbag_shield"
]

## Set true to skip screws auto-fire and start with a random weapon for testing.
const DEBUG_WEAPON_TEST: bool = false

## D-02: weapon_id → int (always 1 at unlock in Phase 4; Phase 6 card picks increment this)
var unlocked_weapons: Array[String] = []
var weapon_level: Dictionary = {}
## D-13: Airbag death-prevention charge flag (synced via MultiplayerSynchronizer)
var airbag_active: bool = false

## Screws-and-bolts fire cooldown (migrated from Player.FIRE_INTERVAL)
const SCREWS_INTERVAL: float = 0.5
var _screws_cooldown: float = 0.0

func _ready() -> void:
	# D-08: ScrewsAndBolts is always unlocked — migrated from Player._try_fire
	add_weapon("screws_and_bolts")
	if DEBUG_WEAPON_TEST:
		var others: Array[String] = ["exhaust_flames", "spinning_tires", "antenna_beam", "horn_shockwave", "airbag_shield"]
		add_weapon(others[absi(get_parent().peer_id) % others.size()])

## Called by Player._physics_process each frame (replaces _fire_cooldown block in Player.gd).
## D-07 / W2: Authority guard is inside each weapon's fire path.
func tick(delta: float) -> void:
	# W2: Only owning peer ticks — all other peers' WeaponManagers tick but the authority
	# guard inside _fire_screws prevents any spawn action on non-owning peers.
	if not get_parent().is_multiplayer_authority():
		return
	# ScrewsAndBolts cooldown (always active if weapon is unlocked)
	if unlocked_weapons.has("screws_and_bolts"):
		_screws_cooldown -= delta
		if _screws_cooldown <= 0.0:
			_screws_cooldown = SCREWS_INTERVAL
			if not DEBUG_WEAPON_TEST:
				_fire_screws()

## D-08: ScrewsAndBolts fire — migrated from Player._try_fire exactly.
func _fire_screws() -> void:
	var player: CharacterBody2D = get_parent()
	var nearest := _find_nearest_enemy(player)
	if nearest == null:
		return
	var dir: Vector2 = (nearest.global_position - player.global_position).normalized()
	var game := get_node_or_null("/root/Game")
	if game == null:
		return
	if multiplayer.is_server():
		if game.has_node("BulletSpawner"):
			game.get_node("BulletSpawner").spawn({
				"pos": player.global_position,
				"dir": dir,
				"owner_id": player.peer_id
			})
	else:
		if game.has_method("request_fire"):
			game.request_fire.rpc_id(1, player.global_position, dir, player.peer_id)

## Shared utility — used by ScrewsAndBolts and timer-based weapons (Wave 3).
func _find_nearest_enemy(player: Node) -> Node:
	var nearest: Node = null
	var nearest_dist: float = INF
	for e in get_tree().get_nodes_in_group("enemies"):
		var d: float = player.global_position.distance_to(e.global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = e
	return nearest

## WEAP-03: Add weapon by ID. Returns false silently if at cap (D-15) or already unlocked (D-01).
## Special case: airbag_shield can be 're-armed' (airbag_active set back to true) even when already
## in unlocked_weapons, as long as the charge was previously consumed (D-13: pick up again to re-arm).
func add_weapon(weapon_id: String) -> bool:
	if unlocked_weapons.size() >= MAX_WEAPONS:
		return false  # D-15: silent cap
	# D-13 special case: airbag_shield re-arm — second pickup re-arms the charge without re-adding
	if weapon_id == "airbag_shield" and unlocked_weapons.has(weapon_id):
		if not airbag_active:
			airbag_active = true
			return true  # charge re-armed
		return false  # already armed — silently ignore (D-01)
	if unlocked_weapons.has(weapon_id):
		return false  # D-01: already unlocked — silent ignore (no upgrade in Phase 4)
	unlocked_weapons.append(weapon_id)
	weapon_level[weapon_id] = 1  # D-02: Phase 6 will increment this via card picks
	# Airbag is a passive charge, not a timer weapon
	if weapon_id == "airbag_shield":
		airbag_active = true
	_activate_weapon_node(weapon_id)
	return true

## WEAP-08 / D-16: Reset all weapons on death/game-over.
## Called from GameState._broadcast_game_over (wired in Plan 05).
func reset() -> void:
	# Deactivate all weapon nodes
	for weapon_id in ["exhaust_flames", "spinning_tires", "antenna_beam", "horn_shockwave", "airbag_shield"]:
		var node_names := {"exhaust_flames": "ExhaustFlames", "spinning_tires": "SpinningTires",
						   "antenna_beam": "AntennaBeam", "horn_shockwave": "HornShockwave",
						   "airbag_shield": "AirbagShield"}
		var node_name: String = node_names.get(weapon_id, "")
		if node_name != "" and has_node(node_name):
			get_node(node_name).deactivate()
			get_node(node_name).queue_free()
	unlocked_weapons = []
	weapon_level = {}
	airbag_active = false
	_screws_cooldown = 0.0

## Called by add_weapon() to instantiate and activate a weapon node.
func _activate_weapon_node(weapon_id: String) -> void:
	match weapon_id:
		"exhaust_flames":
			var wep: Node = load("res://scenes/weapons/ExhaustFlames.gd").new()
			wep.name = "ExhaustFlames"
			call_deferred("add_child", wep)
			# activate() called via deferred to avoid physics-frame add_child error
			call_deferred("_deferred_activate_exhaust", wep)
		"spinning_tires":
			var wep: Node = load("res://scenes/weapons/SpinningTires.gd").new()
			wep.name = "SpinningTires"
			call_deferred("add_child", wep)
			call_deferred("_deferred_activate_tires", wep)
		"antenna_beam":
			var wep: Node = load("res://scenes/weapons/AntennaBeam.gd").new()
			wep.name = "AntennaBeam"
			call_deferred("add_child", wep)
			call_deferred("_deferred_activate_antenna", wep)
		"horn_shockwave":
			var wep: Node = load("res://scenes/weapons/HornShockwave.gd").new()
			wep.name = "HornShockwave"
			call_deferred("add_child", wep)
			call_deferred("_deferred_activate_shockwave", wep)
		"airbag_shield":
			var wep: Node = load("res://scenes/weapons/AirbagShield.gd").new()
			wep.name = "AirbagShield"
			call_deferred("add_child", wep)
			call_deferred("_deferred_activate_airbag", wep)

func _deferred_activate_exhaust(wep: Node) -> void:
	if is_instance_valid(wep):
		wep.activate(self)

func _deferred_activate_tires(wep: Node) -> void:
	if is_instance_valid(wep):
		wep.activate()

func _deferred_activate_antenna(wep: Node) -> void:
	if is_instance_valid(wep):
		wep.activate(self)

func _deferred_activate_shockwave(wep: Node) -> void:
	if is_instance_valid(wep):
		wep.activate(self)

func _deferred_activate_airbag(wep: Node) -> void:
	if is_instance_valid(wep):
		wep.activate()

## Called by Player.gd receive_damage after airbag absorbs a lethal hit.
## Hides the visual ring to reflect consumed charge.
func consume_airbag() -> void:
	airbag_active = false
	if has_node("AirbagShield"):
		get_node("AirbagShield").hide_ring()
