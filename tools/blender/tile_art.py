# Renders the artwork printed on the board's special tiles (Go arrow, Chance question mark,
# Community Chest, Free Parking car, Go To Jail officer) as transparent PNGs into assets/tiles,
# in the icon house style (icons.py): bevelled shapes, warm key light, cool rim, dark outline.
# Run inside Blender:
#   exec(open(r"C:\dev\Monopoly\tools\blender\tile_art.py").read()); render_tiles()
# or one: render_tiles(["Question"]).
import bpy, math, os
from mathutils import Vector, Matrix

exec(open(r"C:\dev\Monopoly\tools\blender\icons.py").read())

TILE_OUT = os.path.join(ROOT, "tiles")
HEAVY_FONT = r"C:\Windows\Fonts\seguibl.ttf"


def heavy_text(stage, text, size, depth, material):
	"""Extruded text in Arial Black, standing up facing the camera (-Y)."""
	curve = bpy.data.curves.new("txt", "FONT")
	curve.body = text
	curve.size = size
	curve.extrude = depth
	# Bevel inwards so the outline stays the glyph's own (an outward bevel closes the gap
	# between the question mark and its dot).
	curve.bevel_depth = depth * 0.2
	curve.bevel_resolution = 3
	curve.offset = -depth * 0.2
	curve.align_x = "CENTER"
	curve.align_y = "CENTER"
	if os.path.exists(HEAVY_FONT):
		curve.font = bpy.data.fonts.load(HEAVY_FONT, check_existing=True)
	ob = bpy.data.objects.new("Text", curve)
	stage.objects.link(ob)
	bpy.context.view_layer.update()
	ob.data.materials.append(material)
	depsgraph = bpy.context.evaluated_depsgraph_get()
	mesh = bpy.data.meshes.new_from_object(ob.evaluated_get(depsgraph))
	bpy.data.objects.remove(ob, do_unlink=True)
	bpy.data.curves.remove(curve)
	result = bpy.data.objects.new("Text", mesh)
	stage.objects.link(result)
	result.matrix_world = rx(90)
	return result


def tile_arrow(stage):
	arrow = flat("Arrow", stage, arrow_profile(4.4, 0.7, 1.5, 1.1), 0.3, (0, 0, 0), RED(), bevel=0.06)
	return [arrow], {"yaw": 0, "pitch": 0, "fill": 0.98, "size": (1024, 384)}


def tile_question(stage):
	mark = heavy_text(stage, "?", 2.4, 0.18, RED())
	return [mark], {"yaw": -8, "pitch": 4, "fill": 0.9}


def tile_chest(stage):
	obs = import_model(stage, "Emblems", "Chest", {"Body": WOOD(), "Trim": GOLD(), "*": WOOD()})
	lo, hi = bounds(obs)
	width = hi.x - lo.x
	# Coins spilling out in front: two short stacks and a couple lying flat.
	r = width * 0.13
	spots = [(-0.3, 3), (0.32, 2)]
	for i, (fx, count) in enumerate(spots):
		for k in range(count):
			p = coin_part(f"Stack{i}{k}", radius=r, depth=r * 0.32, center=(lo.x + width * (0.5 + fx), lo.y - r * 1.3, lo.z + r * 0.16 + k * r * 0.34))
			obs.append(obj(p, stage, GOLD()))
	for i, (fx, tilt) in enumerate([(0.02, 64), (0.72, 0)]):
		p = coin_part(f"Loose{i}", radius=r, depth=r * 0.32, center=(lo.x + width * (0.5 + fx - 0.25), lo.y - r * 2.5, lo.z + (r * 0.9 if tilt else r * 0.16)), rot=rx(tilt))
		obs.append(obj(p, stage, GOLD()))
	return obs, {"yaw": -24, "pitch": 18, "fill": 0.9}


def tile_car(stage):
	paint = RED()
	body = Part("Body")
	body.box((3.2, 1.5, 0.7), (0, 0, 0.75), bevel=0.22, segments=3)
	body.box((1.7, 1.36, 0.75), (-0.25, 0, 1.35), bevel=0.25, segments=3)
	b = obj(body, stage, paint)
	glass = Part("Glass")
	glass.box((1.45, 1.42, 0.5), (-0.25, 0, 1.38), bevel=0.15, segments=2)
	g = obj(glass, stage, mat("Glass", srgb(120, 180, 230), rough=0.1))
	wheels = Part("Wheels")
	hubs = Part("Hubs")
	for x in (-1.0, 1.05):
		for y in (-0.72, 0.72):
			wheels.cylinder(0.42, 0.34, (x, y, 0.42), segments=28, bevel=0.06, rot=rx(90))
			hubs.cylinder(0.2, 0.38, (x, y, 0.42), segments=20, rot=rx(90))
	w = obj(wheels, stage, INK())
	h = obj(hubs, stage, SILVER())
	lamps = Part("Lamps")
	for y in (-0.48, 0.48):
		lamps.sphere(0.15, (1.6, y, 0.85), segs=16, rings=8)
	l = obj(lamps, stage, mat("Lamp", srgb(255, 236, 160), rough=0.2, emit=0.6))
	trim = Part("Trim")
	trim.box((0.12, 1.3, 0.16), (1.66, 0, 0.5), bevel=0.05)
	trim.box((0.12, 1.3, 0.16), (-1.66, 0, 0.5), bevel=0.05)
	t = obj(trim, stage, SILVER())
	return [b, g, w, h, l, t], {"yaw": -38, "pitch": 16, "fill": 0.92}


def tile_officer(stage):
	navy = mat("Navy", srgb(34, 52, 112), rough=0.45)
	skin = mat("Skin", srgb(240, 196, 150), rough=0.55)
	obs = []
	torso = Part("Torso")
	torso.box((1.2, 0.8, 1.4), (0, 0, 1.75), bevel=0.3, segments=3)
	for x in (-0.3, 0.3):
		torso.box((0.46, 0.6, 1.2), (x, 0, 0.6), bevel=0.15, segments=2)
	obs.append(obj(torso, stage, navy))
	shoes = Part("Shoes")
	for x in (-0.3, 0.3):
		shoes.box((0.5, 0.75, 0.25), (x, -0.08, 0.05), bevel=0.1, segments=2)
	obs.append(obj(shoes, stage, INK()))
	# Left arm down, right arm thrown out sideways, pointing.
	arms = Part("Arms")
	arms.cylinder(0.2, 1.1, (-0.75, 0, 1.75), segments=16, bevel=0.06, rot=ry(-12))
	arms.cylinder(0.2, 1.3, (1.1, 0, 2.15), segments=16, bevel=0.06, rot=ry(70))
	obs.append(obj(arms, stage, navy))
	head = Part("Head")
	head.sphere(0.55, (0, 0, 2.95), segs=32, rings=16)
	head.sphere(0.2, (-0.85, 0, 1.15), segs=16, rings=8)
	head.sphere(0.2, (1.75, 0, 2.38), segs=16, rings=8)
	head.cylinder(0.08, 0.4, (2.0, 0, 2.48), segments=12, rot=ry(70))
	obs.append(obj(head, stage, skin, smooth=3.0))
	eyes = Part("Eyes")
	for x in (-0.18, 0.18):
		eyes.sphere(0.07, (x, -0.5, 3.0), segs=12, rings=6)
	obs.append(obj(eyes, stage, INK(), smooth=3.0))
	cap = Part("Cap")
	cap.cylinder(0.6, 0.38, (0, 0, 3.45), segments=32, bevel=0.06, radius2=0.66)
	cap.cylinder(0.5, 0.08, (0, -0.25, 3.27), segments=24)
	obs.append(obj(cap, stage, navy))
	brim = Part("Brim")
	brim.cylinder(0.58, 0.07, (0, -0.22, 3.25), segments=28)
	brim.box((0.86, 0.06, 0.16), (0, 0, 2.48 - 0.88), bevel=0.02)
	obs.append(obj(brim, stage, INK()))
	badges = Part("Badges")
	badges.prism([(x * 0.18, z * 0.18) for x, z in star_profile(6, 1.0, 0.6)], 0.08, (0, -0.62, 3.47), axis="Y", bevel=0.02)
	badges.prism([(x * 0.14, z * 0.14) for x, z in star_profile(6, 1.0, 0.6)], 0.08, (-0.3, -0.42, 2.1), axis="Y", bevel=0.02)
	obs.append(obj(badges, stage, GOLD()))
	buttons = Part("Buttons")
	for z in (1.4, 1.75, 2.05):
		buttons.sphere(0.07, (0, -0.4, z), segs=12, rings=6)
	obs.append(obj(buttons, stage, GOLD(), smooth=3.0))
	return obs, {"yaw": -8, "pitch": 6, "fill": 0.9}


TILE_BUILDERS = {
	"Arrow": tile_arrow,
	"Question": tile_question,
	"Chest": tile_chest,
	"Car": tile_car,
	"Officer": tile_officer,
}


def trim(path, margin=6):
	"""Crops a render to its visible pixels (plus a margin) so the picture fills its spot on the tile."""
	import numpy as np
	image = bpy.data.images.load(path, check_existing=False)
	width, height = image.size
	pixels = np.array(image.pixels[:], dtype=np.float32).reshape(height, width, 4)
	rows = np.where(pixels[:, :, 3].max(axis=1) > 0.02)[0]
	cols = np.where(pixels[:, :, 3].max(axis=0) > 0.02)[0]
	bpy.data.images.remove(image)
	if len(rows) == 0:
		return
	top, bottom = max(rows[0] - margin, 0), min(rows[-1] + margin, height - 1)
	left, right = max(cols[0] - margin, 0), min(cols[-1] + margin, width - 1)
	cropped = pixels[top:bottom + 1, left:right + 1, :]
	out = bpy.data.images.new("trimmed", cropped.shape[1], cropped.shape[0], alpha=True)
	out.pixels[:] = cropped.ravel()
	out.filepath_raw = path
	out.file_format = "PNG"
	out.save()
	bpy.data.images.remove(out)


def render_tiles(names=None):
	scene, stage = studio()
	done = []
	for name in names or list(TILE_BUILDERS):
		clear(stage)
		objects, view = TILE_BUILDERS[name](stage)
		lo, hi = bounds(objects)
		thickness = (hi - lo).length * 0.012
		for ob in objects:
			add_outline(ob, thickness)
		width, height = view.get("size", (512, 512))
		scene.render.resolution_x = width
		scene.render.resolution_y = height
		frame(scene, objects, yaw=view.get("yaw", -32), pitch=view.get("pitch", 22), fill=view.get("fill", 0.86))
		os.makedirs(TILE_OUT, exist_ok=True)
		scene.render.filepath = os.path.join(TILE_OUT, name + ".png")
		bpy.ops.render.render(write_still=True, scene=scene.name)
		trim(scene.render.filepath)
		done.append(scene.render.filepath)
	scene.render.resolution_x = SIZE
	scene.render.resolution_y = SIZE
	return done
