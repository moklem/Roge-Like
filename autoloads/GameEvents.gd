extends Node
## GameEvents autoload — pure signal bus for HUD events and game lifecycle.
## No state, no logic. Signals fire on ALL peers via RPC (wired in Phase 6+).
## Registered here to prevent RPC signature drift later.

signal hud_event(event_name: String)
@warning_ignore("unused_signal")
signal player_downed(player_id: int)
@warning_ignore("unused_signal")
signal player_revived(player_id: int)
@warning_ignore("unused_signal")
signal loop_ended(reason: String)  # "boss_dead" | "all_dead" | "timer"

# Called by game systems. Host broadcasts via RPC — D-07: authority+call_local means
# host call fires hud_event signal on ALL peers simultaneously (HUD-10).
@rpc("authority", "call_local", "reliable")
func emit_hud(event_name: String) -> void:
	hud_event.emit(event_name)
