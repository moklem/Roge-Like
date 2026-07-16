extends "res://scenes/enemies/Enemy.gd"
## EliteEnemy — 2× HP, 1.5× base damage, larger dark-purple visual.
## Spawned by host timer in Game.gd every 45–90s (D-12, D-13).
## Triggers LIDAR HUD indicator on spawn via Game.gd _spawn_elite_enemy() (D-10).
## D-14: separate scene extending Enemy.gd; preserves all Enemy AI via super._ready().

# ─── Art ──────────────────────────────────────────────────────────────────────
## The elite ships its own animation set ("elite_idle"/"elite_walk"), not the two enemy_N
## variants. Overriding _anim_set() routes Enemy._setup_enemy_sprite / _update_enemy_visual
## at its EliteFrames.tres art with no change to the shared sprite plumbing.
const ELITE_ANIM_SET: String = "elite"
## Bigger than a rank-and-file enemy (50px) so the elite reads as a mini-boss at a glance,
## still kept close to its hurtbox (radius 22 → 44px) so players aren't swinging at empty
## pixels — same reasoning as Boss.BOSS_TARGET_HEIGHT.
const ELITE_TARGET_HEIGHT: float = 72.0

func _anim_set() -> String:
	return ELITE_ANIM_SET

func _char_target_height() -> float:
	return ELITE_TARGET_HEIGHT

func _ready() -> void:
	# super._ready(): add_to_group("enemies"), set_physics_process(is_multiplayer_authority()),
	# connects hurtbox body_entered/body_exited. Must be called first.
	super._ready()

	# D-12: 2× base HP (Enemy.MAX_HP default 50 → elite 100).
	# D-12: 1.5× base damage (Enemy.CONTACT_DAMAGE default 10 → elite 15).
	# Both are var (converted in Plan 01, confirmed in 07-01-SUMMARY.md).
	MAX_HP = 100
	CONTACT_DAMAGE = 15
	is_elite = true  # WR-02: marks this instance so _on_hurtbox_body_entered passes from_elite=true
	# Phase 7 Plan 03 (D-19, D-20): apply difficulty scaling here — AFTER base stats are set.
	# _do_spawn_enemy cannot scale EliteEnemy stats because _ready() runs AFTER the spawn_function
	# returns (when Spawner calls add_child). Setting stats here ensures the final effective values
	# are base(100/15) × mult, not the pre-_ready defaults.
	# At loop_number=1: mult=1.0, values stay 100/15 (unchanged baseline). (D-21)
	var mult: float = 1.0 + (GameState.loop_number - 1) * 0.25
	MAX_HP = int(MAX_HP * mult)
	CONTACT_DAMAGE = int(CONTACT_DAMAGE * mult)
	current_hp = MAX_HP

	# super._ready() → _setup_enemy_sprite() has already hidden $Sprite in favour of the
	# CharSprite art, so its offsets no longer matter. Its COLOUR still does: Enemy._exit_tree
	# reads $Sprite.color for the death-burst particles, so keep it the elite's dark-purple
	# identity colour (UI-SPEC Elite Enemy).
	if has_node("Sprite"):
		$Sprite.color = Color(0.55, 0.1, 0.55, 1)
