extends Node
## AirbagShield — death-prevention passive charge. NOT a timer weapon.
## D-13: Shows a visible ring while airbag_active=true. Ring disappears when charge consumed
##       (airbag_active set to false in Player.receive_damage after absorbing lethal hit).
## Visual: yellow ring (hollow ColorRect border effect via two overlapping ColorRects).
## Activated by WeaponManager.add_weapon("airbag_shield") → _activate_weapon_node.

var _ring: ColorRect = null
var _ring_inner: ColorRect = null  # inner rect to create hollow ring appearance

const RING_RADIUS: float = 28.0  # pixels from player center to ring edge
const RING_THICKNESS: float = 4.0

func activate() -> void:
	## Called by WeaponManager._deferred_activate_airbag.
	## Creates the ring visual as a child of this node (which is child of WeaponManager → Player).
	_ring = ColorRect.new()
	_ring.name = "AirbagRing"
	_ring.color = Color(1.0, 1.0, 0.0, 0.85)  # yellow ring (per CONTEXT.md specifics)
	var outer_size: float = (RING_RADIUS + RING_THICKNESS) * 2.0
	_ring.size = Vector2(outer_size, outer_size)
	_ring.pivot_offset = Vector2(outer_size / 2.0, outer_size / 2.0)
	_ring.position = Vector2(-outer_size / 2.0, -outer_size / 2.0)
	# Inner rect (cut out center) — slightly smaller, transparent to create ring appearance
	_ring_inner = ColorRect.new()
	_ring_inner.name = "AirbagRingInner"
	_ring_inner.color = Color(0, 0, 0, 0)   # transparent center (additive cut)
	var inner_size: float = RING_RADIUS * 2.0
	_ring_inner.size = Vector2(inner_size, inner_size)
	_ring_inner.position = Vector2(RING_THICKNESS, RING_THICKNESS)
	_ring.add_child(_ring_inner)
	add_child(_ring)
	show_ring()

func show_ring() -> void:
	## Called when airbag charge is active (on first activation).
	if _ring:
		_ring.visible = true

func hide_ring() -> void:
	## Called when airbag charge is consumed (airbag_active set false in Player.receive_damage).
	## WeaponManager calls this via consume_airbag() after setting airbag_active = false.
	if _ring:
		_ring.visible = false

func deactivate() -> void:
	## Called by WeaponManager.reset() — hides ring and frees node.
	if _ring and is_instance_valid(_ring):
		_ring.queue_free()
		_ring = null
