class_name HitFlash
extends RefCounted
## HitFlash — static tween helper that flashes a CanvasItem's modulate to a bright
## color and back. Used for both the enemy white hit-pop (D-04) and the player
## red/white hit-flash (DMG-02).
##
## The tween ignores any local hit-stop cosmetic time dip (`set_ignore_time_scale`)
## so the flash always reads crisp even while `Juice.cosmetic_delta()` is slowing
## other presentation code down.

## Flashes `node`'s modulate to `color` and back to its current modulate over `dur`
## seconds (default ~0.1s per D-04/DMG-02). Safe to call on an already-freed/invalid
## node (silently does nothing).
static func flash(node: CanvasItem, color: Color, dur: float = 0.1) -> void:
	if node == null or not is_instance_valid(node):
		return
	var original: Color = node.modulate
	var tween := node.create_tween()
	tween.set_ignore_time_scale(true)
	tween.tween_property(node, "modulate", color, dur * 0.4)
	tween.tween_property(node, "modulate", original, dur * 0.6)
