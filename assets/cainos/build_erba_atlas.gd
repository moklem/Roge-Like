extends SceneTree
## Regenerates erba_atlas.png from the Cainos "Pixel Art Top Down - Basic" source PNGs
## in this folder. Run from the project root:
##   godot --headless --path . --script assets/cainos/build_erba_atlas.gd
##
## Atlas layout (4x2 grid of 16px tiles — source tiles are 32px, halved nearest-neighbor):
##   (0,0) grass base      (1,0) grass flower    (2,0) grass stone slabs  (3,0) stone road
##   (0,1) brick wall face (1,1) rock obstacle   (2,1) wall top cap       (3,1) grass in shadow
## Face/cap/shadow give walls a 2.5D "standing in the room" depth (Enter-the-Gungeon style):
## south-facing wall cells show the brick FACE, all others the dark CAP, and the floor row
## under a face is darkened. Coordinates consumed by RoomLayouts.ERBA_* — keep in sync.

const SRC_DIR := "res://assets/cainos"
const OUT_PATH := SRC_DIR + "/erba_atlas.png"
const T := 32   # source tile size
const O := 16   # output tile size

var grass: Image
var stone: Image
var wall: Image
var props: Image

func _init() -> void:
	grass = _load("TX Tileset Grass.png")
	stone = _load("TX Tileset Stone Ground.png")
	wall = _load("TX Tileset Wall.png")
	props = _load("TX Props.png")
	if grass == null or stone == null or wall == null or props == null:
		quit(1)
		return

	var atlas := Image.create(4 * O, 2 * O, false, Image.FORMAT_RGBA8)
	# Opaque grass base everywhere — unused cells must never be transparent
	var base := _tile(grass, 1, 1)
	for cx in range(4):
		for cy in range(2):
			atlas.blit_rect(base, Rect2i(0, 0, O, O), Vector2i(cx * O, cy * O))
	atlas.blit_rect(_tile(grass, 4, 0), Rect2i(0, 0, O, O), Vector2i(1 * O, 0))  # flower
	atlas.blit_rect(_tile(grass, 1, 5), Rect2i(0, 0, O, O), Vector2i(2 * O, 0))  # slabs
	atlas.blit_rect(_tile(stone, 1, 1), Rect2i(0, 0, O, O), Vector2i(3 * O, 0))  # road
	atlas.blend_rect(_tile(wall, 1, 7), Rect2i(0, 0, O, O), Vector2i(0, 1 * O))  # wall face over grass
	atlas.blend_rect(_rock(), Rect2i(0, 0, O, O), Vector2i(1 * O, 1 * O))        # rocks over grass
	atlas.blit_rect(_darken(_tile(wall, 1, 7), 0.32), Rect2i(0, 0, O, O), Vector2i(2 * O, 1 * O))  # wall cap: near-black brick
	atlas.blit_rect(_darken(_tile(grass, 1, 1), 0.68), Rect2i(0, 0, O, O), Vector2i(3 * O, 1 * O)) # shadowed grass

	var trans := 0
	for y in range(atlas.get_height()):
		for x in range(atlas.get_width()):
			if atlas.get_pixel(x, y).a < 0.999:
				trans += 1
	atlas.save_png(ProjectSettings.globalize_path(OUT_PATH))
	print("saved %s (transparent pixels: %d — must be 0)" % [OUT_PATH, trans])
	quit(0 if trans == 0 else 1)

func _load(file: String) -> Image:
	var img := Image.new()
	if img.load(ProjectSettings.globalize_path(SRC_DIR + "/" + file)) != OK:
		print("LOAD FAIL: ", file)
		return null
	return img

## Multiply RGB by factor (alpha untouched) — used for the wall cap and shadow tiles.
func _darken(img: Image, factor: float) -> Image:
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			var c := img.get_pixel(x, y)
			img.set_pixel(x, y, Color(c.r * factor, c.g * factor, c.b * factor, c.a))
	return img

func _tile(src: Image, cx: int, cy: int) -> Image:
	var t := Image.create(T, T, false, Image.FORMAT_RGBA8)
	t.blit_rect(src, Rect2i(cx * T, cy * T, T, T), Vector2i.ZERO)
	t.resize(O, O, Image.INTERPOLATE_NEAREST)
	return t

## Rock pile from TX Props region (0,13)-(1,14), trimmed to opaque bounds, fit to 15px.
func _rock() -> Image:
	var region := Image.create(2 * T, 2 * T, false, Image.FORMAT_RGBA8)
	region.blit_rect(props, Rect2i(0, 13 * T, 2 * T, 2 * T), Vector2i.ZERO)
	var used: Rect2i = region.get_used_rect()
	var rock := Image.create(used.size.x, used.size.y, false, Image.FORMAT_RGBA8)
	rock.blit_rect(region, used, Vector2i.ZERO)
	var s: float = 15.0 / float(maxi(used.size.x, used.size.y))
	rock.resize(maxi(1, roundi(used.size.x * s)), maxi(1, roundi(used.size.y * s)), Image.INTERPOLATE_NEAREST)
	var padded := Image.create(O, O, false, Image.FORMAT_RGBA8)
	padded.blend_rect(rock, Rect2i(0, 0, rock.get_width(), rock.get_height()),
		Vector2i((O - rock.get_width()) / 2, (O - rock.get_height()) / 2))
	return padded
