extends "res://scenes/enemies/Enemy.gd"
## EliteEnemy — 2× HP, 1.5× base damage, larger dark-purple visual.
## Spawned by host timer in Game.gd every 45–90s (D-12, D-13).
## Triggers LIDAR HUD indicator on spawn via Game.gd _spawn_elite_enemy() (D-10).
## D-14: separate scene extending Enemy.gd; preserves all Enemy AI via super._ready().

func _ready() -> void:
	# super._ready(): add_to_group("enemies"), set_physics_process(is_multiplayer_authority()),
	# connects hurtbox body_entered/body_exited. Must be called first.
	super._ready()

	# D-12: 2× base HP (Enemy.MAX_HP default 50 → elite 100).
	# D-12: 1.5× base damage (Enemy.CONTACT_DAMAGE default 10 → elite 15).
	# Both are var (converted in Plan 01, confirmed in 07-01-SUMMARY.md).
	MAX_HP = 100
	CONTACT_DAMAGE = 15
	# Phase 7 Plan 03 (D-19, D-20): apply difficulty scaling here — AFTER base stats are set.
	# _do_spawn_enemy cannot scale EliteEnemy stats because _ready() runs AFTER the spawn_function
	# returns (when Spawner calls add_child). Setting stats here ensures the final effective values
	# are base(100/15) × mult, not the pre-_ready defaults.
	# At loop_number=1: mult=1.0, values stay 100/15 (unchanged baseline). (D-21)
	var mult: float = 1.0 + (GameState.loop_number - 1) * 0.25
	MAX_HP = int(MAX_HP * mult)
	CONTACT_DAMAGE = int(CONTACT_DAMAGE * mult)
	current_hp = MAX_HP

	# Apply distinct visual: dark purple ColorRect, enlarged toward 48×48 (UI-SPEC).
	# Enemy.tscn uses "Sprite" as the ColorRect child name (Enemy.tscn line 28).
	if has_node("Sprite"):
		$Sprite.color = Color(0.55, 0.1, 0.55, 1)   # dark purple (UI-SPEC Elite Enemy color)
		$Sprite.offset_left  = -24.0
		$Sprite.offset_top   = -24.0
		$Sprite.offset_right  = 24.0
		$Sprite.offset_bottom = 24.0
