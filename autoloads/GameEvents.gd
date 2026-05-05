extends Node
## GameEvents autoload — pure signal bus for HUD events and game lifecycle.
## No state, no logic. Signals fire on ALL peers via RPC (wired in Phase 6+).
## Registered here to prevent RPC signature drift later.

signal hud_event(event_name: String)
signal player_downed(player_id: int)
signal player_revived(player_id: int)
signal loop_ended(reason: String)  # "boss_dead" | "all_dead" | "timer"

# Called by game systems. Host broadcasts via RPC (wired in Phase 6).
func emit_hud(event_name: String) -> void:
	hud_event.emit(event_name)
