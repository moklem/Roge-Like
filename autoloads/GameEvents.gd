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

# Host broadcasts the rolled Driver Mode + duration. authority+call_local fires driver_mode on
# ALL peers simultaneously so the CarHUD label and every player's effect+particles stay in sync.
@rpc("authority", "call_local", "reliable")
func emit_driver_mode(mode: String, duration: float) -> void:
	driver_mode.emit(mode, duration)
