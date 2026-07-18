extends Node
## GameState autoload — host-authoritative run state.
## Clients read via MultiplayerSynchronizer (Phase 6).
## D-13: Only host writes; all writes guarded by multiplayer.is_server().

var loop_timer: float = 0.0  # seconds remaining; host only writes
var loop_number: int = 1  # D-16: starts at 1; Phase 8 increments via start_next_loop()
var revives_used: Dictionary = {}  # peer_id → int (count used this loop)

## Current wave within the active room (1..WAVES_PER_ROOM). Written on every peer by
## Game._announce_wave (call_local RPC); polled by CarHUD to drive the "WELLE x/3" line.
var display_wave: int = 1
const WAVES_PER_ROOM: int = 3

## Debug/QoL: which room the run begins in (1 = Erba, 2 = Altstadt, 3 = Burg).
## Set on every peer via Lobby.start_game(start_room) before the scene change;
## read once by Game._ready(). Later loops always cycle 1 → 2 → 3 as usual.
var start_room: int = 1

## Difficulty tier, host-picked in the lobby. Set on every peer via
## Lobby.start_game(start_room, difficulty) (call_local RPC) before the scene change —
## same delivery channel as start_room, so it's already correct before any enemy spawns.
const DIFFICULTY_EASY: int = 0
const DIFFICULTY_NORMAL: int = 1
const DIFFICULTY_HARD: int = 2
var difficulty: int = DIFFICULTY_NORMAL

## Tier → multiplier tables. Stats lean lighter than spawn density (blended scaling design).
## Stat tiers bumped after playtest feedback that Hard still felt easy (2026-07-18):
## Normal gets a modest bump, Hard a meaningful one.
const DIFFICULTY_STAT_MULT: Dictionary = {
	DIFFICULTY_EASY: 0.80,
	DIFFICULTY_NORMAL: 1.15,
	DIFFICULTY_HARD: 1.6,
}
const DIFFICULTY_SPAWN_MULT: Dictionary = {
	DIFFICULTY_EASY: 0.75,
	DIFFICULTY_NORMAL: 1.0,
	DIFFICULTY_HARD: 1.35,
}

## Continuous in-run ramp (2026-07-18 playtest feedback): enemies should keep getting
## stronger the longer a run goes, not just jump at loop boundaries. +5% stat mult per
## minute survived (tuned down from an initial 10% — felt too steep). Host-only write
## (see _process); not synced to clients (same convention as loop_number/loop_timer).
var run_elapsed_time: float = 0.0
const TIME_STAT_MULT_PER_MINUTE: float = 0.05

## Small stat bump per weapon any player has picked up this run (host-authoritative,
## incremented identically on every peer inside Game.gd's weapon_unlocked call_local RPC —
## see 2026-07-18 playtest feedback: enemies should keep pace as the team gets stronger).
var weapons_acquired_count: int = 0
const WEAPON_STAT_MULT_PER_WEAPON: float = 0.05

## Live player count, same lookup team_xp_threshold() already uses to scale the team XP bar —
## reused here so enemy scaling and XP scaling agree on party size via one consistent source.
func get_player_count() -> int:
	return maxi(1, get_tree().get_nodes_in_group("players").size())

## Combined difficulty-tier + player-count + time + weapon-count factor for enemy HP/damage.
func get_difficulty_player_stat_mult() -> float:
	var tier_mult: float = DIFFICULTY_STAT_MULT.get(difficulty, 1.0)
	var player_mult: float = 1.0 + (get_player_count() - 1) * 0.20
	var time_mult: float = 1.0 + (run_elapsed_time / 60.0) * TIME_STAT_MULT_PER_MINUTE
	var weapon_mult: float = 1.0 + weapons_acquired_count * WEAPON_STAT_MULT_PER_WEAPON
	return tier_mult * player_mult * time_mult * weapon_mult

## Combined difficulty-tier + player-count factor for enemy spawn counts.
## Weighted higher than the stat mult — more players means more targets, not just tougher ones.
func get_difficulty_player_spawn_mult() -> float:
	var tier_mult: float = DIFFICULTY_SPAWN_MULT.get(difficulty, 1.0)
	return tier_mult * (1.0 + (get_player_count() - 1) * 0.40)

## Boss-only extra factor on top of get_difficulty_player_stat_mult() (2026-07-18 playtest
## feedback: the boss stayed too easy even after the general enemy scaling pass, because it
## doesn't keep pace with card/weapon/evolution stacking the way a per-loop trash mob does).
## +15% boss HP/damage per team level above 1.
const BOSS_LEVEL_STAT_MULT_PER_LEVEL: float = 0.15

func get_boss_level_mult() -> float:
	return 1.0 + (team_level - 1) * BOSS_LEVEL_STAT_MULT_PER_LEVEL

## TEAM XP: shared progression — every orb feeds one team pool (host-authoritative).
## Thresholds scale with party size so 1/2/3-player runs level at a similar pace.
const TEAM_XP_BASE: int = 200
const TEAM_XP_PER_LEVEL: int = 100

var team_xp: int = 0
var team_level: int = 1

## Handed to GameOver.tscn across the scene change — this autoload outlives the swap, so
## it is the only channel that survives it. `final_*` are snapshotted before
## reset_for_new_run() clears the live values, since the screen only renders afterwards.
const REASON_WIPE := "wipe"
const REASON_HOST_LEFT := "host_left"

var game_over_reason: String = REASON_WIPE
var final_loop: int = 1
var final_level: int = 1

func _ready() -> void:
	# D-16 / Pitfall 6: ensure correct base even before peers connect
	loop_number = 1

func _process(delta: float) -> void:
	# Guard: peer must exist and be fully connected before querying is_server().
	# Without this, get_unique_id() throws "not active" during the connecting phase.
	if not multiplayer.has_multiplayer_peer():
		return
	if multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return
	if not multiplayer.is_server():
		return  # D-13: only host ticks timer
	if loop_timer > 0.0:
		loop_timer -= delta
	run_elapsed_time += delta

## XP needed to advance FROM team level lvl to lvl+1.
## Scaled by party size: more players collect more orbs, so the bar grows with the team.
func team_xp_threshold(lvl: int) -> int:
	var party_size: int = maxi(1, get_tree().get_nodes_in_group("players").size())
	return (TEAM_XP_BASE + (lvl - 1) * TEAM_XP_PER_LEVEL) * party_size

## Host-only: called from XpOrb._request_collect (already host-guarded there).
## Accumulates team XP, processes level-ups, then broadcasts the state to every peer.
func add_team_xp(amount: int) -> void:
	if not multiplayer.has_multiplayer_peer():
		return
	if multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return
	if not multiplayer.is_server():
		return
	team_xp += amount
	var levels_gained: int = 0
	var threshold: int = team_xp_threshold(team_level)
	while team_xp >= threshold:
		team_xp -= threshold
		team_level += 1
		levels_gained += 1
		threshold = team_xp_threshold(team_level)
	_sync_team_xp.rpc(team_xp, team_level, levels_gained)

## Runs on ALL peers (call_local). Mirrors team values onto the local player
## (keeps HUD, stage checks, and run-reset code working) and — on level-up —
## opens the card overlay for EVERYONE at once, each with their own card pool,
## so the team can discuss picks together.
@rpc("authority", "call_local", "reliable")
func _sync_team_xp(xp_value: int, level_value: int, levels_gained: int) -> void:
	team_xp = xp_value
	team_level = level_value
	if levels_gained > 0:
		Sfx.play("level_up")  # call_local — every peer hears the shared team level-up
	var local_id := multiplayer.get_unique_id()
	for p in get_tree().get_nodes_in_group("players"):
		if p.peer_id == local_id:
			p.xp = xp_value
			p.level = level_value
			for i in range(levels_gained):
				p._trigger_card_pick()
			if levels_gained > 0 and p.has_method("_check_stage_threshold"):
				p._check_stage_threshold()
			if p.has_method("_update_xp_hud"):
				p._update_xp_hud()
			return

## HLTH-08: Called from Player._enter_downed() — checks if ALL players are downed.
## D-14: Immediate game over with no grace period when all are downed.
func track_downed(_peer_id: int) -> void:
	# Use same guard pattern as _process() — connection must be active and this must be server
	if not multiplayer.has_multiplayer_peer():
		return
	if multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return
	if not multiplayer.is_server():
		return
	var players := get_tree().get_nodes_in_group("players")
	if players.is_empty():
		return
	var all_downed: bool = true
	for p in players:
		if not p.is_downed:
			all_downed = false
			break
	if all_downed:
		# D-14: Immediate game over — no grace period
		_broadcast_game_over.rpc()

## LOOP-03 / D-17: Called by Phase 8 after boss defeat. Hook point for next-loop setup.
## Increments loop_number, clears revives_used (HLTH-07 / D-22). Host-guarded.
func start_next_loop() -> void:
	if not multiplayer.has_multiplayer_peer():
		return
	if multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return
	if not multiplayer.is_server():
		return
	loop_number += 1
	revives_used = {}
	print("Loop %d started" % loop_number)

## CR-02 fix: Reset loop-scoped state so next run starts fresh.
## Called on host before _broadcast_game_over; also resets revives_used so
## a player who hit the revive cap last game is not blocked in the new run.
func reset_for_new_run() -> void:
	loop_number = 1
	loop_timer  = 0.0
	revives_used = {}
	team_xp = 0
	team_level = 1
	run_elapsed_time = 0.0
	weapons_acquired_count = 0

## D-14: Broadcast game over to all peers including host (call_local)
@rpc("authority", "call_local", "reliable")
func _broadcast_game_over() -> void:
	## D-16 / WEAP-08: Reset all weapon managers before scene change.
	## Runs on ALL peers (call_local) — each peer resets its own local player's WeaponManager.
	## Using get_nodes_in_group so it works on any peer without needing host authority.
	for p in get_tree().get_nodes_in_group("players"):
		if p.has_node("WeaponManager"):
			p.get_node("WeaponManager").reset()
		# Phase 6 (D-14, EVOL-06): reset progression for the next run
		p.xp = 0
		p.level = 1
		p.element_tier = 1
		p.stage3_damage_mult = 1.0
		p.is_picking_card = false
		p._pending_weapon_choice = false  # stale sub-room weapon choice must not carry into the next run
		p._pending_card_picks = 0
		p.evolution_stage = 1  # direct reset — skip deferred visual swap before scene change
	# Snapshot what the run reached BEFORE reset_for_new_run() wipes it — the GameOver
	# screen builds itself after the scene change, by which point the live values are gone.
	game_over_reason = REASON_WIPE
	final_loop = loop_number
	final_level = team_level
	# CR-02: reset loop-scoped state before scene change so next run starts at loop 1
	reset_for_new_run()
	get_tree().call_deferred("change_scene_to_file", "res://scenes/ui/GameOver.tscn")
