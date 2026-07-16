extends Node
## WeaponManager — child of Player.tscn. Owns all weapon unlock state and fire logic.
## D-06: Holds unlocked_weapons Array, weapon_level Dict, per-weapon Timers.
## D-07: Authority pattern — owning peer's WM calls fire; host spawns projectile.
## D-08: ScrewsAndBolts migrated from Player._try_fire (always unlocked on start).
## D-15: Max 6 weapons; add_weapon returns false if full (silent cap, no UI in Phase 4).
## D-16: reset() called from game-over path; clears all weapons and airbag charge.

## Weapon cap: start weapon + 2 picked via the sub-room weapon-choice overlay (end of sub-rooms 2 and 4).
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
## Phase 6 D-11: Airbag death-prevention charge count (int replaces previous bool flag)
var airbag_count: int = 0            # Phase 6 D-11: int count; L3=2 charges
const MAX_AIRBAG_CHARGES: int = 2    # Level 3 dual-charge (D-11)

## Screws-and-bolts fire cooldown (migrated from Player.FIRE_INTERVAL)
const SCREWS_INTERVAL: float = 0.5
var _screws_interval: float = 0.5  # Phase 6 D-11: updated to 0.35 at Level 3 via upgrade_weapon
var _screws_cooldown: float = 0.0

## Element buff: every Nth screws/bolts volley procs this player's element effect
## (fire → burn, ice → slow) and lights the matching CarHUD indicator. Deterministic,
## replaces the old random 25% per-hit proc so the element reads as a predictable buff.
const ELEMENT_PROC_INTERVAL: int = 10
var _shot_count: int = 0

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
			# Cooldown card (XP-04): the player's multiplier shortens every fire interval
			_screws_cooldown = _screws_interval * get_parent().cooldown_mult
			if not DEBUG_WEAPON_TEST:
				_fire_screws()

## D-08: ScrewsAndBolts fire — migrated from Player._try_fire; Phase 6 D-11 adds L2/L3 spread.
func _fire_screws() -> void:
	var player: CharacterBody2D = get_parent()
	var targets: Array = _find_nearest_enemies(player, 3)
	if targets.is_empty():
		return
	var base_dir: Vector2 = (targets[0].global_position - player.global_position).normalized()
	var game := get_node_or_null("/root/Game")
	if game == null:
		return
	var level: int = weapon_level.get("screws_and_bolts", 1)
	var dirs: Array = _get_screws_dirs(base_dir, level)
	# Subtle shoot cue — _fire_screws only runs on the owning peer (tick() authority guard),
	# so each player hears their own default attack, once per volley.
	Sfx.shoot()
	# Element buff: count volleys for fire/ice players; every ELEMENT_PROC_INTERVAL-th volley
	# the bolts carry the element proc (guaranteed burn/slow + CarHUD pulse on hit).
	var element_proc: bool = false
	if player.element == "fire" or player.element == "ice":
		_shot_count += 1
		if _shot_count >= ELEMENT_PROC_INTERVAL:
			_shot_count = 0
			element_proc = true
	# Bolts converge (D-11 rework): spread volleys fan out, then every bolt curves onto its
	# own enemy — targets are distributed across the nearest enemies (bolt i → enemy i,
	# wrapping when there are fewer enemies than bolts, so nothing goes to waste).
	for i in dirs.size():
		var d: Vector2 = dirs[i]
		var target_pos: Vector2 = targets[i % targets.size()].global_position
		if multiplayer.is_server():
			if game.has_node("BulletSpawner"):
				game.get_node("BulletSpawner").spawn({
					"pos": player.global_position,
					"dir": d,
					"owner_id": player.peer_id,
					"damage_mult": player.stage3_damage_mult * player.driver_damage_mult,
					"element_proc": element_proc,
					"target_pos": target_pos
				})
		else:
			if game.has_method("request_fire"):
				game.request_fire.rpc_id(1, player.global_position, d, player.peer_id, false, element_proc, target_pos)

## Phase 6 D-11: Compute bolt fire directions per level.
## L1: 1 bolt straight ahead. L2: 2 bolts ±15°. L3: 3 bolts at 0°, +30°, -30°.
func _get_screws_dirs(base_dir: Vector2, level: int) -> Array:
	if level >= 3:
		return [
			base_dir.rotated(0.0),
			base_dir.rotated(deg_to_rad(30.0)),
			base_dir.rotated(deg_to_rad(-30.0)),
		]
	elif level >= 2:
		return [
			base_dir.rotated(deg_to_rad(15.0)),
			base_dir.rotated(deg_to_rad(-15.0)),
		]
	else:
		return [base_dir]

## Up to `count` enemies sorted by distance — ScrewsAndBolts spreads its bolts across them.
func _find_nearest_enemies(player: Node, count: int) -> Array:
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	enemies.sort_custom(func(a, b):
		return player.global_position.distance_squared_to(a.global_position) \
			< player.global_position.distance_squared_to(b.global_position))
	return enemies.slice(0, count)

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
## Special case: airbag_shield can be 're-armed' (charge incremented up to cap) even when already
## in unlocked_weapons, as long as under the charge cap (D-13: pick up again to re-arm).
func add_weapon(weapon_id: String) -> bool:
	if unlocked_weapons.size() >= MAX_WEAPONS:
		return false  # D-15: silent cap
	# Phase 6 D-13 special case: airbag_shield re-arm — second pickup adds a charge (up to cap)
	if weapon_id == "airbag_shield" and unlocked_weapons.has(weapon_id):
		var lvl: int = weapon_level.get("airbag_shield", 1)
		var cap: int = MAX_AIRBAG_CHARGES if lvl >= 3 else 1
		if airbag_count < cap:
			airbag_count = mini(airbag_count + 1, cap)
			return true
		return false  # already at cap — silently ignore (D-01)
	if unlocked_weapons.has(weapon_id):
		return false  # D-01: already unlocked — silent ignore (no upgrade in Phase 4)
	unlocked_weapons.append(weapon_id)
	weapon_level[weapon_id] = 1  # D-02: Phase 6 will increment this via card picks
	# Phase 6 D-11: Airbag is a passive charge, not a timer weapon
	if weapon_id == "airbag_shield":
		airbag_count = 1              # arm with 1 charge on first unlock
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
	airbag_count = 0
	_screws_interval = SCREWS_INTERVAL
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
		wep.apply_cooldown_mult(get_parent().cooldown_mult)

func _deferred_activate_tires(wep: Node) -> void:
	if is_instance_valid(wep):
		wep.activate()

func _deferred_activate_antenna(wep: Node) -> void:
	if is_instance_valid(wep):
		wep.activate(self)
		wep.apply_cooldown_mult(get_parent().cooldown_mult)

func _deferred_activate_shockwave(wep: Node) -> void:
	if is_instance_valid(wep):
		wep.activate(self)
		wep.apply_cooldown_mult(get_parent().cooldown_mult)

func _deferred_activate_airbag(wep: Node) -> void:
	if is_instance_valid(wep):
		wep.activate()

## Cooldown card (XP-04): re-scale the fire timers of every active weapon. Called from
## Game._apply_stat_boost_rpc on the owning peer whenever the multiplier changes; newly
## activated weapons pick it up in the _deferred_activate_* helpers instead.
func apply_cooldown_mult(mult: float) -> void:
	for node_name in ["ExhaustFlames", "AntennaBeam", "HornShockwave"]:
		if has_node(node_name):
			get_node(node_name).apply_cooldown_mult(mult)

## Called by Player.gd receive_damage after airbag absorbs a lethal hit.
## Phase 6 D-11: Decrements charge count; hides ring only when count reaches 0.
func consume_airbag() -> void:
	airbag_count = maxi(airbag_count - 1, 0)
	Sfx.play("airbag_break")  # owner-only, like the receive_damage path that calls this
	if airbag_count == 0:
		if has_node("AirbagShield"):
			get_node("AirbagShield").hide_ring()

## Phase 6 (XP-08, D-11): Increment weapon level for a card pick. Called on owning peer
## by host via rpc_id from Game.gd _apply_card_effect.
@rpc("any_peer", "call_remote", "reliable")
func upgrade_weapon(weapon_id: String) -> void:
	if not unlocked_weapons.has(weapon_id):
		return
	var current: int = weapon_level.get(weapon_id, 1)
	if current >= 3:
		return  # already at max (XP-05 guard)
	weapon_level[weapon_id] = current + 1
	# L3 ScrewsAndBolts: reduce fire interval to 0.35s (D-11)
	if weapon_id == "screws_and_bolts" and weapon_level[weapon_id] == 3:
		_screws_interval = 0.35
