extends CharacterBody2D
## Player movement controller — handles WASD input and wall collision.
## P3: All input handling guarded by is_multiplayer_authority().
## P4: MultiplayerSynchronizer replicates position at 20 Hz (replication_interval = 0.05).

const SPEED: float = 200.0

@export var peer_id: int = 0
@export var role_label: String = ""

func _ready() -> void:
	# Set authority based on peer_id — only the owning peer controls this player
	set_multiplayer_authority(peer_id)

func _physics_process(_delta: float) -> void:
	# P3: Only the authority peer reads input and moves
	if not is_multiplayer_authority():
		return

	var dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = dir * SPEED
	move_and_slide()
