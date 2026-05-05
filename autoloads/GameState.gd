extends Node
## GameState autoload — host-authoritative run state.
## Clients read via MultiplayerSynchronizer (Phase 6).
## D-13: Only host writes; all writes guarded by multiplayer.is_server().

var loop_timer: float = 0.0  # seconds remaining; host only writes
var loop_number: int = 0
var revives_used: Dictionary = {}  # peer_id → int (count used this loop)

func _ready() -> void:
	pass  # Minimal until Phase 6 wires loop timer and difficulty scaling

func _process(delta: float) -> void:
	if not multiplayer.is_server():
		return  # D-13: only host ticks timer
	if loop_timer > 0.0:
		loop_timer -= delta
