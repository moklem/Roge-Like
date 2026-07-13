extends Node
## GameEvents autoload — pure signal bus for HUD events and game lifecycle.
## No state, no logic. Signals fire on ALL peers via RPC (wired in Phase 6+).
## Registered here to prevent RPC signature drift later.

signal hud_event(event_name: String)
## Driver Mode: host-rolled team-wide timed effect, one per combat sub-room.
## mode ∈ "eco" | "sport" | "repair" | "overdrive"; duration is host-rolled (3-5s) so all
## peers run the effect for exactly the same time. Fires on ALL peers (CarHUD + players).
@warning_ignore("unused_signal")
signal driver_mode(mode: String, duration: float)
signal player_downed(player_id: int)
signal player_revived(player_id: int)
@warning_ignore("unused_signal")
signal loop_ended(reason: String)  # "boss_dead" | "all_dead" | "timer"
## COOP-05/D-16: team-visible "big hit" broadcast — carries the hit position since no
## existing replicated field carries it (Pattern B, 10-RESEARCH.md). Fired from the
## host-authoritative Game.notify_significant_hit debounce, never client-originated.
signal big_hit(pos: Vector2)

# Called by game systems. Host broadcasts via RPC — D-07: authority+call_local means
# host call fires hud_event signal on ALL peers simultaneously (HUD-10).
@rpc("authority", "call_local", "reliable")
func emit_hud(event_name: String) -> void:
	hud_event.emit(event_name)

# Host broadcasts the rolled Driver Mode + duration. authority+call_local fires driver_mode on
# ALL peers simultaneously so the CarHUD label and every player's effect+particles stay in sync.
@rpc("authority", "call_local", "reliable")
func emit_driver_mode(mode: String, duration: float) -> void:
	driver_mode.emit(mode, duration)

# COOP-01/COOP-03: lights up the previously-scaffolded player_downed/player_revived signals —
# mirrors emit_hud exactly (authority+call_local+reliable). Called from the host-authoritative
# Player.gd _enter_downed/revive sites so every peer's team-visible juice fires in sync.
@rpc("authority", "call_local", "reliable")
func emit_player_downed(player_id: int) -> void:
	player_downed.emit(player_id)

@rpc("authority", "call_local", "reliable")
func emit_player_revived(player_id: int) -> void:
	player_revived.emit(player_id)

# COOP-05/D-16: host-only broadcast (fired inside notify_significant_hit's is_server() guard +
# SUSPENSION_DEBOUNCE) so every peer renders a shared big-hit cue at the same position.
@rpc("authority", "call_local", "reliable")
func emit_big_hit(pos: Vector2) -> void:
	big_hit.emit(pos)
