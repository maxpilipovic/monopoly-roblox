# Renders the UI icons (coins, keys, padlocks, challenge stats, aura and rent-effect badges) as
# transparent PNGs into assets/icons, in one house style: chunky bevelled shapes, the game's own
# metals and board colours, a warm key light, a cool rim and a dark outline, seen from a three-
# quarter angle. Some icons reuse the game's exported models (assets/export/*.fbx).
# Run inside Blender:
#   exec(open(r"C:\dev\Monopoly\tools\blender\icons.py").read()); render_all()
# or one: render_icons(["Coin"]).
import bpy, bmesh, math, os
from mathutils import Vector, Matrix, Euler

exec(open(r"C:\dev\Monopoly\tools\blender\common.py").read())

OUT = os.path.join(ROOT, "icons")
SIZE = 256
OUTLINE = (0.035, 0.03, 0.05)


# Scene ----------------------------------------------------------------------------------------

def studio():
	scene = bpy.data.scenes.get("Icons")
	if scene is None:
		scene = bpy.data.scenes.new("Icons")
	bpy.context.window.scene = scene
	for engine in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
		try:
			scene.render.engine = engine
			break
		except TypeError:
			pass
	scene.render.resolution_x = SIZE
	scene.render.resolution_y = SIZE
	scene.render.film_transparent = True
	scene.render.image_settings.file_format = "PNG"
	scene.render.image_settings.color_mode = "RGBA"
	try:
		scene.view_settings.view_transform = "Standard"
		scene.view_settings.look = "None"
	except TypeError:
		pass
	world = bpy.data.worlds.get("IconsWorld") or bpy.data.worlds.new("IconsWorld")
	scene.world = world
	world.use_nodes = True
	nodes = world.node_tree.nodes
	links = world.node_tree.links
	bg = next(n for n in nodes if n.type == "BACKGROUND")
	bg.inputs[1].default_value = 1.0
	# A studio sky for the metals to reflect: bright above, a warm horizon, dark below.
	if not any(n.type == "VALTORGB" for n in nodes):
		coords = nodes.new("ShaderNodeTexCoord")
		split = nodes.new("ShaderNodeSeparateXYZ")
		ramp = nodes.new("ShaderNodeValToRGB")
		links.new(coords.outputs["Generated"], split.inputs[0])
		links.new(split.outputs["Z"], ramp.inputs[0])
		links.new(ramp.outputs[0], bg.inputs[0])
		stops = ramp.color_ramp.elements
		stops[0].position = 0.35
		stops[0].color = (0.22, 0.2, 0.22, 1)
		stops[1].position = 0.75
		stops[1].color = (1.2, 1.15, 1.05, 1)
		mid = stops.new(0.52)
		mid.color = (0.55, 0.42, 0.3, 1)
	try:
		scene.eevee.taa_render_samples = 96
	except AttributeError:
		pass
	stage = bpy.data.collections.get("IconStage")
	if stage is None:
		stage = bpy.data.collections.new("IconStage")
		scene.collection.children.link(stage)
	lights = bpy.data.collections.get("IconLights")
	if lights is None:
		lights = bpy.data.collections.new("IconLights")
		scene.collection.children.link(lights)
	if not lights.objects:
		def lamp(name, kind, energy, color, location, size=2.0):
			data = bpy.data.lights.new(name, kind)
			data.energy = energy
			data.color = color
			if kind == "AREA":
				data.size = size
			ob = bpy.data.objects.new(name, data)
			lights.objects.link(ob)
			ob.location = location
			direction = -Vector(location)
			ob.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
		lamp("Key", "AREA", 900, (1.0, 0.93, 0.82), (-4, -5, 7), 4)
		lamp("Rim", "AREA", 700, (0.62, 0.75, 1.0), (5, 5, 3), 3)
		lamp("Fill", "AREA", 220, (1.0, 1.0, 1.0), (6, -6, 1), 5)
		cam_data = bpy.data.cameras.new("IconCam")
		cam_data.lens = 85
		cam = bpy.data.objects.new("IconCam", cam_data)
		lights.objects.link(cam)
	scene.camera = bpy.data.objects["IconCam"]
	return scene, stage


def clear(stage):
	for ob in list(stage.objects):
		data = ob.data
		bpy.data.objects.remove(ob, do_unlink=True)
		if data is not None and getattr(data, "users", 1) == 0:
			if isinstance(data, bpy.types.Mesh):
				bpy.data.meshes.remove(data)
			elif isinstance(data, bpy.types.Curve):
				bpy.data.curves.remove(data)


# Materials ------------------------------------------------------------------------------------

def mat(name, color, metal=0.0, rough=0.4, emit=0.0, alpha=1.0):
	m = bpy.data.materials.get("ic_" + name) or bpy.data.materials.new("ic_" + name)
	m.use_nodes = True
	bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
	bsdf.inputs["Base Color"].default_value = (*color, 1)
	bsdf.inputs["Metallic"].default_value = metal
	bsdf.inputs["Roughness"].default_value = rough
	bsdf.inputs["Emission Color"].default_value = (*color, 1)
	bsdf.inputs["Emission Strength"].default_value = emit
	bsdf.inputs["Alpha"].default_value = alpha
	if alpha < 1:
		try:
			m.surface_render_method = "BLENDED"
		except AttributeError:
			pass
	return m


def outline_mat():
	m = mat("Outline", OUTLINE, rough=1.0)
	m.use_backface_culling = True
	return m


def srgb(r, g, b):
	def lin(c):
		c = c / 255
		return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
	return (lin(r), lin(g), lin(b))


# Half-metal: shiny, but still lit like the rest of the icon rather than mirroring the sky.
GOLD = lambda: mat("Gold", srgb(255, 196, 56), metal=0.55, rough=0.28)
GOLD_DARK = lambda: mat("GoldDark", srgb(214, 136, 28), metal=0.55, rough=0.32)
SILVER = lambda: mat("Silver", srgb(220, 226, 236), metal=0.55, rough=0.25)
PEWTER = lambda: mat("Pewter", srgb(160, 164, 176), metal=0.5, rough=0.35)
IRON = lambda: mat("Iron", srgb(84, 88, 102), metal=0.5, rough=0.4)
IVORY = lambda: mat("Ivory", srgb(244, 238, 224), rough=0.3)
INK = lambda: mat("Ink", srgb(26, 26, 32), rough=0.4)
PAPER = lambda: mat("Paper", srgb(250, 245, 230), rough=0.6)
WOOD = lambda: mat("Wood", srgb(120, 72, 38), rough=0.6)
RED = lambda: mat("Red", srgb(214, 40, 48), rough=0.35)
GREEN = lambda: mat("Green", srgb(46, 170, 90), rough=0.35)
BLUE = lambda: mat("Blue", srgb(52, 120, 230), rough=0.35)
ORANGE = lambda: mat("Orange", srgb(247, 148, 29), rough=0.35)
PURPLE = lambda: mat("Purple", srgb(150, 80, 220), rough=0.35)


def obj(part, stage, material, smooth=0.61):
	"""Finishes a common.Part into the stage with one material and an outline shell."""
	ob = part.finish(stage, smooth_angle=smooth)
	ob.data.materials.clear()
	ob.data.materials.append(material)
	return ob


def add_outline(ob, thickness):
	if ob.type != "MESH":
		return
	ob.data.materials.append(outline_mat())
	mod = ob.modifiers.new("Outline", "SOLIDIFY")
	mod.thickness = thickness
	mod.offset = 1
	mod.use_flip_normals = True
	mod.use_rim = False
	mod.material_offset = len(ob.data.materials) - 1


def text_mesh(stage, text, size, depth, center, material, rot=None, align="CENTER"):
	curve = bpy.data.curves.new("txt", "FONT")
	curve.body = text
	curve.size = size
	curve.extrude = depth
	curve.bevel_depth = depth * 0.25
	curve.align_x = align
	curve.align_y = "CENTER"
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
	m = Matrix.Translation(Vector(center))
	if rot is not None:
		m = m @ rot
	result.matrix_world = m
	return result


def import_model(stage, kind, name, finishes):
	"""Imports an exported game model; `finishes` maps part name -> material (others: "*")."""
	before = set(bpy.data.objects)
	bpy.ops.import_scene.fbx(filepath=os.path.join(ROOT, "export", kind, name + ".fbx"))
	new = [ob for ob in bpy.data.objects if ob not in before]
	for ob in new:
		for c in ob.users_collection:
			c.objects.unlink(ob)
		stage.objects.link(ob)
		if ob.type == "MESH":
			base = ob.name.split(".")[0]
			material = finishes.get(base) or finishes.get("*")
			if material is not None:
				ob.data.materials.clear()
				ob.data.materials.append(material)
	return [ob for ob in new if ob.type == "MESH"]


# Framing and render ---------------------------------------------------------------------------

def bounds(objects):
	lo = Vector((1e9, 1e9, 1e9))
	hi = Vector((-1e9, -1e9, -1e9))
	depsgraph = bpy.context.evaluated_depsgraph_get()
	for ob in objects:
		if ob.type != "MESH":
			continue
		ev = ob.evaluated_get(depsgraph)
		for v in ev.data.vertices:
			w = ob.matrix_world @ v.co
			lo = Vector(map(min, lo, w))
			hi = Vector(map(max, hi, w))
	return lo, hi


def frame(scene, objects, yaw=-32, pitch=22, fill=0.86):
	lo, hi = bounds(objects)
	centre = (lo + hi) / 2
	radius = max((hi - lo).length / 2, 0.01)
	cam = scene.camera
	# From the target towards the camera: in front (-Y), raised by `pitch`, swung round by `yaw`.
	offset = Euler((math.radians(-pitch), 0, math.radians(yaw))).to_matrix() @ Vector((0, -1, 0))
	fov = 2 * math.atan(18 / cam.data.lens)
	distance = radius / math.sin(fov / 2) / fill
	cam.location = centre + offset * distance
	cam.rotation_euler = (centre - cam.location).to_track_quat("-Z", "Y").to_euler()
	cam.data.clip_end = distance * 4


def render(scene, name):
	os.makedirs(OUT, exist_ok=True)
	scene.render.filepath = os.path.join(OUT, name + ".png")
	bpy.ops.render.render(write_still=True, scene=scene.name)
	return scene.render.filepath


# Icons ----------------------------------------------------------------------------------------
# Each builder fills the stage and returns (objects, view overrides).

def rx(deg):
	return Matrix.Rotation(math.radians(deg), 4, "X")


def ry(deg):
	return Matrix.Rotation(math.radians(deg), 4, "Y")


def rz(deg):
	return Matrix.Rotation(math.radians(deg), 4, "Z")


def coin_part(name, radius=1.0, depth=0.22, center=(0, 0, 0), rot=None):
	p = Part(name)
	p.cylinder(radius, depth, center, segments=48, bevel=0.05, rot=rot)
	return p


def icon_coin(stage):
	stand = rx(90)
	coin = obj(coin_part("Coin", depth=0.26, rot=stand), stage, GOLD())
	rim = Part("Rim")
	rim.torus(0.9, 0.08, (0, -0.1, 0), major_segs=48, minor_segs=10, rot=stand)
	rim.torus(0.9, 0.08, (0, 0.1, 0), major_segs=48, minor_segs=10, rot=stand)
	rim_ob = obj(rim, stage, GOLD())
	sign = text_mesh(stage, "$", 1.1, 0.07, (0, -0.14, 0.0), GOLD_DARK(), rot=rx(90))
	return [coin, rim_ob, sign], {"yaw": -24, "pitch": 10}


def icon_coins(stage):
	obs = []
	# Three stacks side by side, tallest at the back, and a coin leaning on the front.
	for i, (x, y, count) in enumerate([(-0.62, 0.1, 4), (0.62, 0.1, 3), (0, 0.75, 6)]):
		for k in range(count):
			p = coin_part(f"C{i}{k}", radius=0.6, depth=0.17, center=(x, y, 0.09 + k * 0.18))
			obs.append(obj(p, stage, GOLD()))
	lean = coin_part("Lean", radius=0.6, depth=0.17, center=(0.05, -0.75, 0.5), rot=rx(70))
	obs.append(obj(lean, stage, GOLD()))
	return obs, {"pitch": 26}


def icon_key(stage):
	stand = rx(90)
	p = Part("Key")
	p.torus(0.42, 0.13, (-0.75, 0, 0), major_segs=32, minor_segs=10, rot=stand)
	p.cylinder(0.11, 1.5, (0.2, 0, 0), segments=16, rot=ry(90))
	p.box((0.16, 0.2, 0.36), (0.75, 0, -0.18), bevel=0.03)
	p.box((0.16, 0.2, 0.26), (0.45, 0, -0.13), bevel=0.03)
	key = obj(p, stage, GOLD())
	key.rotation_euler = (0, math.radians(-35), 0)
	return [key], {"yaw": -18, "pitch": 15}


def icon_lock(stage, open_=False):
	body = Part("Body")
	body.box((1.3, 0.55, 1.0), (0, 0, 0), bevel=0.14, segments=3)
	b = obj(body, stage, GOLD())
	shackle = Part("Shackle")
	lift = 0.35 if open_ else 0.0
	shackle.torus(0.4, 0.11, (0, 0, 0.55 + lift), major_segs=24, minor_segs=8, rot=rx(90), arc=math.pi)
	shackle.cylinder(0.11, 0.3 + lift, (0.4, 0, 0.5 + lift / 2), segments=12)
	if not open_:
		shackle.cylinder(0.11, 0.3, (-0.4, 0, 0.5), segments=12)
	s = obj(shackle, stage, SILVER())
	if open_:
		# Swung open round its right leg, which stays in the body.
		s.data.transform(Matrix.Translation((-0.4, 0, 0)))
		s.location = (0.4, 0, 0)
		s.rotation_euler = (0, 0, math.radians(-60))
	hole = Part("Hole")
	hole.cylinder(0.12, 0.1, (0, -0.28, 0.08), segments=16, rot=rx(90))
	hole.box((0.08, 0.1, 0.28), (0, -0.28, -0.1))
	h = obj(hole, stage, INK())
	return [b, s, h], {"yaw": -26, "pitch": 14}


def icon_check(stage):
	p = Part("Check")
	# Profile u runs toward -X once stood up, so it's drawn mirrored.
	p.prism([(0.9, 0.1), (0.55, 0.45), (0.2, 0.1), (-0.75, 1.05), (-1.1, 0.7), (0.2, -0.6)], 0.4, (0, 0, 0), axis="Y", bevel=0.06)
	return [obj(p, stage, GREEN())], {"yaw": -14, "pitch": 10}


def star_profile(points=5, outer=1.0, inner=0.45):
	out = []
	for i in range(points * 2):
		r = outer if i % 2 == 0 else inner
		a = math.pi / 2 + math.pi * i / points
		out.append((math.cos(a) * r, math.sin(a) * r))
	return out


def icon_star(stage):
	p = Part("Star")
	p.prism(star_profile(), 0.38, (0, 0, 0), axis="Y", bevel=0.07)
	return [obj(p, stage, GOLD())], {"yaw": -20, "pitch": 12}


def flat(name, stage, profile, depth, center, material, bevel=0.05, rot=None):
	"""A 2D profile [(x, z), ...] stood up facing the camera (-Y), `depth` thick."""
	p = Part(name)
	p.prism([(-x, z) for x, z in profile], depth, (0, 0, 0), axis="Y", bevel=bevel)
	ob = obj(p, stage, material)
	m = Matrix.Translation(Vector(center))
	if rot is not None:
		m = m @ rot
	ob.matrix_world = m
	return ob


def bolt_profile():
	return [(-0.15, 1.0), (0.55, 1.0), (0.15, 0.25), (0.6, 0.25), (-0.35, -1.05), (-0.05, -0.1), (-0.5, -0.1)]


def arrow_profile(length=1.6, shaft=0.32, head=0.75, head_len=0.7):
	h = length / 2
	return [(-h, -shaft / 2), (h - head_len, -shaft / 2), (h - head_len, -head / 2), (h, 0), (h - head_len, head / 2), (h - head_len, shaft / 2), (-h, shaft / 2)]


def card(stage, name, band, center, rot=None, back=None):
	"""A title-deed card: white card, a coloured band across the top, ink lines for the text."""
	obs = []
	p = Part(name)
	p.box((1.2, 0.08, 1.6), (0, 0, 0), bevel=0.05)
	body = obj(p, stage, back or PAPER())
	obs.append(body)
	if band is not None:
		q = Part(name + "Band")
		q.box((1.02, 0.04, 0.38), (0, -0.05, 0.5), bevel=0.02)
		obs.append(obj(q, stage, band))
		lines = Part(name + "Lines")
		for k in range(4):
			lines.box((0.8 - (0.25 if k == 3 else 0), 0.03, 0.07), (0, -0.05, 0.08 - k * 0.2))
		obs.append(obj(lines, stage, INK()))
	m = Matrix.Translation(Vector(center))
	if rot is not None:
		m = m @ rot
	for ob in obs:
		ob.matrix_world = m @ ob.matrix_world
	return obs


def die(stage, center, top=1, spin=0):
	"""The game's own die; `top` 1 or 6 faces up."""
	obs = import_model(stage, "Dice", "Rounded", {"Body": IVORY(), "Pips": INK(), "*": IVORY()})
	turn = rx(180) if top == 6 else Matrix.Identity(4)
	for ob in obs:
		ob.matrix_world = Matrix.Translation(Vector(center)) @ rz(spin) @ turn @ Matrix.Translation((0, 0, -0.6)) @ ob.matrix_world
	return obs


def stars_cluster(stage, material, spots):
	obs = []
	for i, (x, z, scale) in enumerate(spots):
		obs.append(flat(f"Star{i}", stage, [(u * scale, v * scale) for u, v in star_profile(4, 1.0, 0.32)], 0.25 * scale, (x, 0, z), material, bevel=0.04 * scale))
	return obs


def glow(name, color, strength=3.0):
	return mat(name, color, rough=0.3, emit=strength)


# UI -------------------------------------------------------------------------------------------

def icon_clock(stage):
	stand = rx(90)
	body = Part("Body")
	body.cylinder(0.95, 0.5, (0, 0, 0), segments=48, bevel=0.08, rot=stand)
	b = obj(body, stage, RED())
	face = Part("Face")
	face.cylinder(0.78, 0.1, (0, -0.24, 0), segments=48, rot=stand)
	f = obj(face, stage, PAPER())
	hands = Part("Hands")
	hands.box((0.09, 0.06, 0.6), (0, -0.31, 0.22))
	hands.box((0.45, 0.06, 0.09), (0.2, -0.31, 0))
	hands.cylinder(0.08, 0.08, (0, -0.31, 0), segments=16, rot=stand)
	h = obj(hands, stage, INK())
	bells = Part("Bells")
	for side in (-1, 1):
		bells.sphere(0.32, (side * 0.62, 0, 0.9), scale=(1, 1, 0.7))
		bells.box((0.1, 0.1, 0.3), (side * 0.5, 0, -0.95), rot=ry(side * 25))
	bells.box((0.12, 0.12, 0.25), (0, 0, 1.0))
	bl = obj(bells, stage, GOLD())
	return [b, f, h, bl], {"yaw": -18, "pitch": 10}


def icon_swap(stage):
	obs = []
	for i, (z, flip) in enumerate([(0.4, 1), (-0.4, -1)]):
		ob = flat(f"Arrow{i}", stage, arrow_profile(1.9, 0.34, 0.8, 0.6), 0.32, (0, 0, z), BLUE() if i == 0 else GREEN(), rot=rz(180) if flip < 0 else None)
		obs.append(ob)
	return obs, {"yaw": -16, "pitch": 12}


def icon_medal(stage):
	stand = rx(90)
	obs = []
	ribbon = Part("Ribbon")
	ribbon.box((0.36, 0.06, 1.2), (-0.32, 0.12, 0.85), rot=ry(-22))
	obs.append(obj(ribbon, stage, BLUE()))
	ribbon2 = Part("Ribbon2")
	ribbon2.box((0.36, 0.06, 1.2), (0.32, 0.1, 0.85), rot=ry(22))
	obs.append(obj(ribbon2, stage, RED()))
	disc = Part("Disc")
	disc.cylinder(0.72, 0.22, (0, 0, 0), segments=48, bevel=0.05, rot=stand)
	disc.torus(0.66, 0.06, (0, -0.1, 0), major_segs=48, minor_segs=8, rot=stand)
	obs.append(obj(disc, stage, GOLD()))
	obs.append(flat("Star", stage, [(u * 0.42, v * 0.42) for u, v in star_profile()], 0.08, (0, -0.13, 0), GOLD_DARK(), bevel=0.02))
	return obs, {"yaw": -16, "pitch": 10}


def icon_flag(stage):
	obs = []
	pole = Part("Pole")
	pole.cylinder(0.07, 2.4, (-0.85, 0, 0), segments=16)
	pole.sphere(0.12, (-0.85, 0, 1.22))
	obs.append(obj(pole, stage, SILVER()))
	white = Part("White")
	black = Part("Black")
	for col in range(4):
		for row in range(3):
			x = -0.6 + col * 0.38
			z = 0.95 - row * 0.38 - math.sin(col * 0.9) * 0.08
			target = white if (col + row) % 2 == 0 else black
			target.box((0.38, 0.06, 0.38), (x, math.sin(col * 1.3) * 0.08, z))
	obs.append(obj(white, stage, PAPER()))
	obs.append(obj(black, stage, INK()))
	return obs, {"yaw": -24, "pitch": 8}


def icon_calendar(stage):
	obs = []
	page = Part("Page")
	page.box((1.6, 0.2, 1.5), (0, 0, 0), bevel=0.06)
	obs.append(obj(page, stage, PAPER()))
	top = Part("Top")
	top.box((1.6, 0.24, 0.42), (0, 0, 0.62), bevel=0.06)
	obs.append(obj(top, stage, RED()))
	rings = Part("Rings")
	for x in (-0.45, 0.45):
		rings.torus(0.12, 0.04, (x, -0.02, 0.85), major_segs=16, minor_segs=6, rot=ry(90))
	obs.append(obj(rings, stage, SILVER()))
	grid = Part("Grid")
	for r in range(3):
		for c in range(4):
			grid.box((0.22, 0.04, 0.18), (-0.5 + c * 0.33, -0.11, 0.2 - r * 0.3), bevel=0.02)
	obs.append(obj(grid, stage, mat("GridInk", srgb(180, 186, 200), rough=0.5)))
	tick = Part("Tick")
	tick.box((0.24, 0.05, 0.2), (0.49, -0.12, -0.4), bevel=0.02)
	obs.append(obj(tick, stage, GREEN()))
	return obs, {"yaw": -18, "pitch": 12}


def icon_tree(stage):
	obs = []
	trunk = Part("Trunk")
	trunk.cylinder(0.18, 1.0, (0, 0, -0.5), segments=16, radius2=0.12)
	trunk.cylinder(0.08, 0.6, (0.22, 0, 0.0), segments=10, rot=ry(40))
	trunk.cylinder(0.08, 0.6, (-0.22, 0, 0.0), segments=10, rot=ry(-40))
	obs.append(obj(trunk, stage, WOOD()))
	leaves = Part("Leaves")
	for x, z, r in [(0, 0.55, 0.62), (-0.55, 0.25, 0.45), (0.55, 0.25, 0.45), (0, 1.0, 0.4)]:
		leaves.sphere(r, (x, 0, z), segs=20, rings=12)
	obs.append(obj(leaves, stage, GREEN(), smooth=1.2))
	for i, (x, z) in enumerate([(-0.35, 0.55), (0.3, 0.75), (0.5, 0.15), (-0.55, 0.05), (0.05, 1.15)]):
		c = coin_part(f"Coin{i}", radius=0.15, depth=0.06, center=(x, -0.48, z), rot=rx(90))
		obs.append(obj(c, stage, GOLD()))
	return obs, {"yaw": -14, "pitch": 10}


def icon_robot(stage):
	return import_model(stage, "Pieces", "Robot", {
		"Body": SILVER(),
		"Trim": glow("RobotNeon", srgb(64, 224, 255), 4.0),
		"*": SILVER(),
	}), {"yaw": -20, "pitch": 8}


# Challenge stats ------------------------------------------------------------------------------

def icon_dice(stage):
	return die(stage, (0, 0, 0), 1, 20), {"yaw": -30, "pitch": 28}


def icon_doubles(stage):
	return die(stage, (-0.75, 0.2, 0), 1, 15) + die(stage, (0.75, -0.2, 0), 1, -20), {"pitch": 30}


def icon_snake_eyes(stage):
	return die(stage, (-0.72, 0.1, 0), 1, 10) + die(stage, (0.72, -0.1, 0), 1, -12), {"pitch": 68, "yaw": -10}


def icon_boxcars(stage):
	return die(stage, (-0.72, 0.1, 0), 6, 10) + die(stage, (0.72, -0.1, 0), 6, -12), {"pitch": 68, "yaw": -10}


def icon_trophy(stage):
	return import_model(stage, "Pieces", "Trophy", {"Body": GOLD(), "Trim": WOOD(), "*": GOLD()}), {"yaw": -20, "pitch": 10}


def icon_podium(stage):
	obs = []
	for i, (x, h, material, text) in enumerate([(0, 1.2, GOLD(), "1"), (-1.02, 0.85, SILVER(), "2"), (1.02, 0.6, mat("Bronze", srgb(205, 127, 70), metal=0.55, rough=0.3), "3")]):
		p = Part(f"Step{i}")
		p.box((1.0, 0.9, h), (x, 0, h / 2), bevel=0.06)
		obs.append(obj(p, stage, material))
		obs.append(text_mesh(stage, text, 0.55, 0.05, (x, -0.47, h / 2), INK(), rot=rx(90)))
	return obs, {"yaw": -18, "pitch": 16}


def icon_swords(stage):
	obs = []
	for i, side in enumerate((-1, 1)):
		blade = Part(f"Blade{i}")
		blade.box((0.18, 0.06, 1.9), (0, 0, 0.45), bevel=0.02)
		blade.cylinder(0.13, 0.25, (0, 0, 1.45), segments=4, radius2=0.0)
		b = obj(blade, stage, SILVER())
		hilt = Part(f"Hilt{i}")
		hilt.box((0.75, 0.14, 0.14), (0, 0, -0.5), bevel=0.04)
		hilt.cylinder(0.08, 0.55, (0, 0, -0.85), segments=12)
		hilt.sphere(0.13, (0, 0, -1.15))
		h = obj(hilt, stage, GOLD())
		for ob in (b, h):
			ob.matrix_world = ry(side * 40) @ ob.matrix_world
			ob.location.y = side * 0.05
		obs += [b, h]
	return obs, {"yaw": -10, "pitch": 8}


def icon_go(stage):
	arrow = flat("Arrow", stage, arrow_profile(2.2, 0.62, 1.3, 0.85), 0.36, (0, 0, 0), RED(), rot=rz(0))
	label = text_mesh(stage, "GO", 0.52, 0.06, (-0.3, -0.2, -0.02), PAPER(), rot=rx(90))
	return [arrow, label], {"yaw": -16, "pitch": 12}


def icon_deed(stage):
	return card(stage, "Deed", GREEN(), (0, 0, 0)), {"yaw": -18, "pitch": 10}


def icon_cash(stage):
	return import_model(stage, "Props", "CashStack", {}), {"yaw": -28, "pitch": 26}


def icon_house(stage):
	return import_model(stage, "Buildings", "House", {
		"Body": GREEN(), "Roof": mat("GreenRoof", srgb(24, 110, 56), rough=0.4), "Trim": PAPER(), "*": GREEN(),
	}), {"yaw": -30, "pitch": 18}


def icon_hotel(stage):
	return import_model(stage, "Buildings", "Hotel", {
		"Body": RED(), "Roof": mat("RedRoof", srgb(120, 16, 22), rough=0.4), "Trim": PAPER(), "*": RED(),
	}), {"yaw": -30, "pitch": 16}


def icon_color_set(stage):
	navy = mat("Navy", srgb(0, 104, 190), rough=0.35)
	obs = []
	for i, angle in enumerate((-22, 0, 22)):
		obs += card(stage, f"Card{i}", navy, (math.sin(math.radians(angle)) * 0.9, -i * 0.12, -0.2 + math.cos(math.radians(angle)) * 0.25 - 0.25), rot=ry(-angle))
	return obs, {"yaw": -8, "pitch": 8}


def icon_jail(stage):
	obs = []
	frame_part = Part("Frame")
	frame_part.box((1.8, 0.3, 0.22), (0, 0, 0.9), bevel=0.05)
	frame_part.box((1.8, 0.3, 0.22), (0, 0, -0.9), bevel=0.05)
	frame_part.box((0.22, 0.3, 2.0), (-0.8, 0, 0), bevel=0.05)
	frame_part.box((0.22, 0.3, 2.0), (0.8, 0, 0), bevel=0.05)
	obs.append(obj(frame_part, stage, IRON()))
	bars = Part("Bars")
	for x in (-0.4, 0, 0.4):
		bars.cylinder(0.08, 1.7, (x, 0, 0), segments=12)
	bars.box((1.5, 0.12, 0.1), (0, 0, 0.1))
	obs.append(obj(bars, stage, PEWTER()))
	back = Part("Back")
	back.box((1.5, 0.05, 1.6), (0, 0.18, 0))
	obs.append(obj(back, stage, mat("Cell", srgb(30, 34, 48), rough=0.8)))
	return obs, {"yaw": -16, "pitch": 8}


def icon_chance(stage):
	orange = mat("ChanceOrange", srgb(247, 148, 29), rough=0.4)
	obs = card(stage, "Chance", None, (0.25, 0.1, 0), rot=rz(-8) @ ry(10), back=mat("ChestBlue", srgb(80, 160, 230), rough=0.4))
	obs += card(stage, "Front", None, (-0.2, -0.15, -0.05), rot=ry(-8), back=orange)
	obs.append(text_mesh(stage, "?", 1.0, 0.06, (-0.2, -0.24, -0.05), PAPER(), rot=rx(90) @ Matrix.Rotation(math.radians(8), 4, "Y")))
	return obs, {"yaw": -12, "pitch": 8}


def icon_gavel(stage):
	obs = []
	head = Part("Head")
	head.cylinder(0.32, 1.2, (0, 0, 0), segments=24, bevel=0.04, rot=ry(90))
	head.cylinder(0.36, 0.14, (-0.6, 0, 0), segments=24, rot=ry(90))
	head.cylinder(0.36, 0.14, (0.6, 0, 0), segments=24, rot=ry(90))
	handle = Part("Handle")
	handle.cylinder(0.11, 1.6, (0, 0, -0.95), segments=16)
	h1 = obj(head, stage, WOOD())
	h2 = obj(handle, stage, mat("WoodLight", srgb(170, 110, 60), rough=0.55))
	for ob in (h1, h2):
		ob.matrix_world = Matrix.Translation((0.1, 0, 0.5)) @ ry(-35) @ ob.matrix_world
	block = Part("Block")
	block.cylinder(0.75, 0.28, (-0.25, 0, -1.0), segments=32, bevel=0.05)
	b = obj(block, stage, WOOD())
	return [h1, h2, b], {"yaw": -22, "pitch": 18}


def icon_trade(stage):
	obs = card(stage, "Left", RED(), (-0.45, 0.1, 0), rot=ry(12))
	obs += card(stage, "Right", BLUE(), (0.45, -0.1, 0), rot=ry(-12))
	obs.append(flat("Top", stage, arrow_profile(1.3, 0.2, 0.5, 0.4), 0.2, (0, -0.35, 0.95), GOLD()))
	obs.append(flat("Bottom", stage, arrow_profile(1.3, 0.2, 0.5, 0.4), 0.2, (0, -0.35, -0.95), GOLD(), rot=rz(180)))
	return obs, {"yaw": -12, "pitch": 8}


def icon_mortgage(stage):
	obs = card(stage, "Deed", ORANGE(), (0, 0, 0))
	stamp = Part("Stamp")
	stamp.box((1.5, 0.05, 0.34), (0, -0.09, -0.1), rot=ry(28))
	obs.append(obj(stamp, stage, mat("Stamp", srgb(214, 40, 48), rough=0.5)))
	return obs, {"yaw": -14, "pitch": 8}


def icon_broken_coin(stage):
	"""Bankrupt: a gold coin cracked in two, the halves falling apart."""
	zig = [(0.0, 1.0), (0.12, 0.6), (-0.1, 0.25), (0.14, -0.1), (-0.08, -0.45), (0.1, -0.75), (0.0, -1.0)]
	obs = []
	for side in (-1, 1):
		# Round side from top to bottom, then the crack back up.
		arc = []
		for k in range(25):
			a = math.pi / 2 + (math.pi * k / 24 if side < 0 else -math.pi * k / 24)
			arc.append((math.cos(a), math.sin(a)))
		outline = arc + list(reversed(zig))[1:-1]
		if side > 0:
			outline.reverse()
		ob = flat(f"Half{side}", stage, outline, 0.26, (0, 0, 0), GOLD(), bevel=0.04)
		ob.matrix_world = Matrix.Translation((side * 0.25, 0, -0.1 if side > 0 else 0.06)) @ ry(side * 16) @ ob.matrix_world
		obs.append(ob)
	return obs, {"yaw": -12, "pitch": 8}


def icon_chest(stage):
	return import_model(stage, "Emblems", "Chest", {"Body": WOOD(), "Trim": GOLD(), "*": WOOD()}), {"yaw": -28, "pitch": 16}


# Auras and rent effects -------------------------------------------------------------------------

def icon_stardust(stage):
	white = glow("StarWhite", srgb(235, 240, 255), 1.5)
	return stars_cluster(stage, white, [(0, 0.1, 1.0), (-0.95, 0.75, 0.45), (0.9, -0.7, 0.5), (0.85, 0.85, 0.3)]), {"yaw": -10, "pitch": 6}


def icon_bubbles(stage):
	glass = mat("Bubble", srgb(150, 210, 255), rough=0.05, alpha=0.55)
	obs = []
	for i, (x, z, r) in enumerate([(0, 0, 0.75), (-0.85, 0.75, 0.4), (0.8, 0.85, 0.3), (0.85, -0.55, 0.35)]):
		p = Part(f"Bubble{i}")
		p.sphere(r, (x, 0, z), segs=24, rings=16)
		obs.append(obj(p, stage, glass, smooth=3.0))
		shine = Part(f"Shine{i}")
		shine.sphere(r * 0.22, (x - r * 0.4, -r * 0.75, z + r * 0.4))
		obs.append(obj(shine, stage, glow("Shine", (1, 1, 1), 2.0)))
	return obs, {"yaw": -10, "pitch": 6}


def flame_profile():
	pts = []
	for i in range(25):
		t = i / 24
		a = math.pi * 2 * t
		r = 0.7 * (1 - 0.55 * (1 - math.cos(a)) / 2)
		x = math.sin(a) * 0.7 * (1 - t * 0.0)
		z = -math.cos(a) * 0.75
		if z > 0:
			x *= (1 - z / 0.75) ** 0.8
			z *= 2.0
		pts.append((x, z))
	return pts[:-1]


def icon_embers(stage):
	outer = flat("Outer", stage, flame_profile(), 0.4, (0, 0, 0), glow("FlameOuter", srgb(255, 110, 20), 2.5), bevel=0.08)
	inner = flat("Inner", stage, [(x * 0.55, z * 0.55 - 0.3) for x, z in flame_profile()], 0.45, (0, -0.06, 0), glow("FlameInner", srgb(255, 220, 90), 3.0), bevel=0.06)
	return [outer, inner], {"yaw": -10, "pitch": 6}


def icon_snowflake(stage):
	p = Part("Flake")
	for k in range(6):
		r = rz(0) @ Matrix.Rotation(math.radians(60 * k), 4, "Y")
		p.box((0.16, 0.12, 2.0), (0, 0, 0), bevel=0.03, rot=Matrix.Rotation(math.radians(60 * k), 4, "Y"))
		for d in (0.55, 0.8):
			for side in (-1, 1):
				a = math.radians(60 * k)
				cx, cz = math.sin(a) * d, math.cos(a) * d
				p.box((0.1, 0.1, 0.42), (cx + math.sin(a + side * 0.9) * 0.15, 0, cz + math.cos(a + side * 0.9) * 0.15), bevel=0.02, rot=Matrix.Rotation(a + side * math.radians(45), 4, "Y"))
	return [obj(p, stage, glow("Ice", srgb(200, 235, 255), 0.8))], {"yaw": -10, "pitch": 6}


def icon_storm(stage):
	cloud = Part("Cloud")
	for x, z, r in [(0, 0.55, 0.55), (-0.55, 0.35, 0.42), (0.55, 0.35, 0.45), (0.25, 0.85, 0.42)]:
		cloud.sphere(r, (x, 0.1, z), segs=20, rings=12)
	c = obj(cloud, stage, mat("Cloud", srgb(120, 128, 150), rough=0.8), smooth=1.2)
	bolt = flat("Bolt", stage, [(x * 0.6, z * 0.7) for x, z in bolt_profile()], 0.3, (0.05, -0.2, -0.45), glow("Bolt", srgb(255, 220, 60), 2.0))
	return [c, bolt], {"yaw": -10, "pitch": 6}


def icon_rainbow(stage):
	colors = [(255, 70, 70), (255, 160, 40), (255, 230, 60), (70, 210, 100), (60, 150, 255), (160, 90, 240)]
	obs = []
	for i, color in enumerate(colors):
		p = Part(f"Band{i}")
		p.torus(1.25 - i * 0.16, 0.085, (0, 0, -0.4), major_segs=40, minor_segs=8, rot=rx(90), arc=math.pi)
		obs.append(obj(p, stage, glow(f"Rainbow{i}", srgb(*color), 0.6)))
	cloud = Part("Clouds")
	for side in (-1, 1):
		for x, z, r in [(0, 0, 0.3), (0.28, 0.05, 0.24), (-0.25, 0.02, 0.22)]:
			cloud.sphere(r, (side * 0.95 + x, -0.05, -0.4 + z), segs=16, rings=10)
	obs.append(obj(cloud, stage, PAPER(), smooth=1.2))
	return obs, {"yaw": -8, "pitch": 6}


def icon_gold_dust(stage):
	return stars_cluster(stage, GOLD(), [(0, 0.1, 1.0), (-0.9, 0.8, 0.45), (0.95, -0.7, 0.45), (0.9, 0.8, 0.3), (-0.8, -0.75, 0.28)]), {"yaw": -10, "pitch": 6}


def icon_blueprint(stage):
	blue = mat("Blueprint", srgb(40, 110, 220), rough=0.5)
	sheet = Part("Sheet")
	sheet.box((1.9, 0.06, 1.4), (0, 0.1, 0), bevel=0.03)
	s = obj(sheet, stage, blue)
	lines = Part("Lines")
	lines.box((1.2, 0.03, 0.05), (0, 0.05, 0.4))
	lines.box((0.05, 0.03, 0.8), (-0.6, 0.05, 0.0))
	lines.box((0.05, 0.03, 0.8), (0.6, 0.05, 0.0))
	lines.box((1.2, 0.03, 0.05), (0, 0.05, -0.4))
	lines.box((0.05, 0.03, 0.45), (0, 0.05, -0.17))
	l = obj(lines, stage, glow("Chalk", srgb(220, 240, 255), 0.8))
	square = flat("Square", stage, [(-0.6, -0.55), (0.55, -0.55), (-0.6, 0.6)], 0.1, (0.45, -0.1, -0.25), mat("SetSquare", srgb(255, 200, 60), rough=0.4), rot=rz(0))
	return [s, l, square], {"yaw": -14, "pitch": 18}


def icon_clover(stage):
	green = mat("Clover", srgb(60, 190, 80), rough=0.4)
	obs = []
	for k in range(4):
		a = math.radians(45 + 90 * k)
		leaf = Part(f"Leaf{k}")
		cx, cz = math.cos(a) * 0.45, math.sin(a) * 0.45
		leaf.sphere(0.36, (cx + math.cos(a + 0.8) * 0.12, 0, cz + math.sin(a + 0.8) * 0.12), scale=(1, 0.35, 1))
		leaf.sphere(0.36, (cx + math.cos(a - 0.8) * 0.12, 0, cz + math.sin(a - 0.8) * 0.12), scale=(1, 0.35, 1))
		obs.append(obj(leaf, stage, green, smooth=1.2))
	stem = Part("Stem")
	stem.cylinder(0.07, 0.9, (0.3, 0, -0.75), segments=10, rot=ry(-25))
	obs.append(obj(stem, stage, mat("Stem", srgb(40, 140, 60), rough=0.5)))
	return obs, {"yaw": -10, "pitch": 6}


def icon_shadow(stage):
	smoke = mat("Smoke", srgb(70, 50, 110), rough=0.9)
	p = Part("Smoke")
	for x, z, r in [(0, 0, 0.6), (-0.5, -0.2, 0.42), (0.55, -0.15, 0.45), (0.2, 0.5, 0.42), (-0.3, 0.45, 0.35), (0.7, 0.4, 0.28)]:
		p.sphere(r, (x, 0, z), segs=20, rings=12)
	puff = obj(p, stage, smoke, smooth=1.2)
	eyes = Part("Eyes")
	eyes.sphere(0.09, (-0.18, -0.55, 0.12), scale=(1, 0.5, 1.4))
	eyes.sphere(0.09, (0.18, -0.55, 0.12), scale=(1, 0.5, 1.4))
	return [puff, obj(eyes, stage, glow("Eyes", srgb(200, 120, 255), 4.0))], {"yaw": -10, "pitch": 6}


def note(stage, name, center, rot=None, material=None):
	obs = []
	bill = Part(name)
	bill.box((1.5, 0.05, 0.75), (0, 0, 0), bevel=0.02)
	obs.append(obj(bill, stage, material or mat("Bill", srgb(130, 200, 120), rough=0.6)))
	seal = Part(name + "Seal")
	seal.cylinder(0.22, 0.04, (0, -0.03, 0), segments=24, rot=rx(90))
	obs.append(obj(seal, stage, mat("BillInk", srgb(40, 110, 60), rough=0.6)))
	m = Matrix.Translation(Vector(center))
	if rot is not None:
		m = m @ rot
	for ob in obs:
		ob.matrix_world = m @ ob.matrix_world
	return obs


def icon_cash_flow(stage):
	obs = []
	for i, (x, z, angle) in enumerate([(-0.3, -0.3, -12), (0, 0, 4), (0.3, 0.32, 18)]):
		obs += note(stage, f"Note{i}", (x, -i * 0.08, z), rot=ry(angle))
	return obs, {"yaw": -14, "pitch": 10}


def icon_starburst(stage):
	obs = []
	rays = Part("Rays")
	for k in range(12):
		a = math.radians(30 * k)
		length = 0.75 if k % 2 == 0 else 0.5
		rays.cylinder(0.12, length, (math.sin(a) * (0.75 + length / 2), 0.05, math.cos(a) * (0.75 + length / 2)), segments=4, radius2=0.0, rot=Matrix.Rotation(a, 4, "Y"))
	obs.append(obj(rays, stage, glow("Rays", srgb(255, 230, 140), 1.5)))
	obs.append(flat("Star", stage, [(u * 0.85, v * 0.85) for u, v in star_profile()], 0.32, (0, -0.05, 0), GOLD()))
	return obs, {"yaw": -8, "pitch": 6}


def icon_coin_burst(stage):
	"""Coins flying out of a bright flash."""
	obs = []
	flash = flat("Flash", stage, [(u * 0.75, v * 0.75) for u, v in star_profile(8, 1.0, 0.5)], 0.12, (0, 0.3, 0), glow("Flash", srgb(255, 236, 150), 1.8), bevel=0.02)
	obs.append(flash)
	for i, (x, z, tilt, r) in enumerate([(0, 0, 0, 0.5), (-0.95, 0.55, 35, 0.34), (0.95, 0.5, -35, 0.36), (-0.8, -0.65, -30, 0.3), (0.85, -0.6, 30, 0.32)]):
		c = coin_part(f"Coin{i}", radius=r, depth=r * 0.28, center=(0, 0, 0), rot=rx(90))
		ob = obj(c, stage, GOLD())
		ob.matrix_world = Matrix.Translation((x, -0.1, z)) @ rz(tilt) @ ob.matrix_world
		obs.append(ob)
	return obs, {"yaw": -8, "pitch": 6}


def icon_confetti(stage):
	obs = []
	cone = Part("Popper")
	cone.cylinder(0.5, 1.4, (0, 0, 0), segments=24, radius2=0.08)
	c = obj(cone, stage, mat("Popper", srgb(150, 80, 220), rough=0.4))
	c.matrix_world = Matrix.Translation((-0.4, 0, -0.45)) @ ry(-140) @ c.matrix_world
	obs.append(c)
	colors = [(255, 90, 90), (255, 220, 80), (90, 200, 255), (150, 255, 120), (255, 140, 220)]
	for i in range(14):
		x = 0.15 + (i % 5) * 0.28 + math.sin(i * 2.1) * 0.15
		z = -0.3 + (i // 5) * 0.45 + math.cos(i * 1.7) * 0.2
		bit = Part(f"Bit{i}")
		bit.box((0.18, 0.04, 0.09), (x, 0, z), rot=Matrix.Rotation(i * 0.9, 4, "Y") @ rx(i * 37))
		obs.append(obj(bit, stage, mat(f"Confetti{i % 5}", srgb(*colors[i % 5]), rough=0.4)))
	return obs, {"yaw": -10, "pitch": 8}


def icon_money_rain(stage):
	obs = []
	for i, (x, z, a) in enumerate([(-0.55, 0.6, -20), (0.5, 0.75, 25), (0, 0, -5), (-0.4, -0.7, 30), (0.55, -0.55, -30)]):
		obs += note(stage, f"Note{i}", (x, (i % 2) * 0.2, z), rot=ry(a) @ rx(25 if i % 2 == 0 else -20))
	return obs, {"yaw": -10, "pitch": 8}


def icon_golden_aura(stage):
	ring = Part("Halo")
	ring.torus(0.9, 0.12, (0, 0, 0.6), major_segs=48, minor_segs=10, rot=rx(70))
	halo = obj(ring, stage, glow("Halo", srgb(255, 210, 90), 2.0))
	orb = Part("Orb")
	orb.sphere(0.6, (0, 0, -0.2), segs=32, rings=16)
	o = obj(orb, stage, GOLD(), smooth=3.0)
	return [halo, o] + stars_cluster(stage, glow("Spark", srgb(255, 236, 160), 2.0), [(-0.95, -0.4, 0.25), (0.95, -0.2, 0.3)]), {"yaw": -10, "pitch": 10}


def icon_lightning(stage):
	return [flat("Bolt", stage, bolt_profile(), 0.4, (0, 0, 0), glow("BoltBig", srgb(255, 214, 50), 1.5))], {"yaw": -14, "pitch": 8}


def icon_fireworks(stage):
	obs = []
	colors = [(255, 80, 80), (255, 210, 70), (90, 190, 255), (160, 255, 120), (230, 120, 255), (255, 150, 60)]
	for k in range(12):
		a = math.radians(30 * k)
		color = colors[k % len(colors)]
		ray = Part(f"Ray{k}")
		ray.cylinder(0.05, 0.6, (math.sin(a) * 0.55, 0, math.cos(a) * 0.55), segments=8, rot=Matrix.Rotation(a, 4, "Y"))
		ray.sphere(0.12, (math.sin(a) * 0.95, 0, math.cos(a) * 0.95))
		obs.append(obj(ray, stage, glow(f"Spark{k % 6}", srgb(*color), 2.0)))
	core = Part("Core")
	core.sphere(0.18, (0, 0, 0))
	obs.append(obj(core, stage, glow("Core", (1, 1, 1), 3.0)))
	return obs, {"yaw": -8, "pitch": 6}


def icon_black_hole(stage):
	ring = Part("Disk")
	ring.torus(1.05, 0.2, (0, 0, 0), major_segs=48, minor_segs=10, rot=rx(14))
	disk = obj(ring, stage, glow("Accretion", srgb(255, 96, 20), 0.9))
	hole = Part("Hole")
	hole.sphere(0.62, (0, 0, 0), segs=32, rings=16)
	h = obj(hole, stage, mat("Void", (0.005, 0.005, 0.01), rough=1.0), smooth=3.0)
	return [disk, h], {"yaw": -10, "pitch": 10}


def speaker(stage):
	"""A loudspeaker facing right: a box with a flared cone."""
	body = Part("Speaker")
	body.box((0.55, 0.5, 0.75), (-0.55, 0, 0), bevel=0.08)
	body.cylinder(0.25, 0.7, (-0.05, 0, 0), segments=24, rot=ry(90), radius2=0.75)
	return obj(body, stage, SILVER())


def icon_speaker(stage):
	waves = Part("Waves")
	for radius in (0.55, 0.95):
		waves.torus(radius, 0.08, (0.15, 0, 0), major_segs=32, minor_segs=8, rot=rx(90) @ rz(-50), arc=math.radians(100))
	return [speaker(stage), obj(waves, stage, GOLD())], {"yaw": -14, "pitch": 6}


def icon_speaker_muted(stage):
	cross = Part("Cross")
	cross.box((0.16, 0.2, 1.0), (0.75, 0, 0), bevel=0.05, rot=ry(45))
	cross.box((0.16, 0.2, 1.0), (0.75, 0, 0), bevel=0.05, rot=ry(-45))
	return [speaker(stage), obj(cross, stage, RED())], {"yaw": -14, "pitch": 6}


BUILDERS = {
	"Speaker": icon_speaker,
	"SpeakerMuted": icon_speaker_muted,
	# UI
	"Coin": icon_coin,
	"Coins": icon_coins,
	"Key": icon_key,
	"Lock": lambda s: icon_lock(s, False),
	"LockOpen": lambda s: icon_lock(s, True),
	"Check": icon_check,
	"Star": icon_star,
	"Clock": icon_clock,
	"Swap": icon_swap,
	"Medal": icon_medal,
	"Flag": icon_flag,
	"Calendar": icon_calendar,
	"Tree": icon_tree,
	"Robot": icon_robot,
	# Challenge stats
	"Dice": icon_dice,
	"Doubles": icon_doubles,
	"SnakeEyes": icon_snake_eyes,
	"Boxcars": icon_boxcars,
	"Trophy": icon_trophy,
	"Podium": icon_podium,
	"Swords": icon_swords,
	"Go": icon_go,
	"Deed": icon_deed,
	"Cash": icon_cash,
	"House": icon_house,
	"Hotel": icon_hotel,
	"ColorSet": icon_color_set,
	"Jail": icon_jail,
	"Chance": icon_chance,
	"Gavel": icon_gavel,
	"Trade": icon_trade,
	"Mortgage": icon_mortgage,
	"BrokenCoin": icon_broken_coin,
	"Chest": icon_chest,
	# Auras
	"Stardust": icon_stardust,
	"Bubbles": icon_bubbles,
	"Embers": icon_embers,
	"Snowfall": icon_snowflake,
	"Storm": icon_storm,
	"Rainbow": icon_rainbow,
	"GoldDust": icon_gold_dust,
	"Blueprint": icon_blueprint,
	"Clover": icon_clover,
	"Shadow": icon_shadow,
	"CashFlow": icon_cash_flow,
	"Starburst": icon_starburst,
	# Rent effects
	"CoinBurst": icon_coin_burst,
	"ConfettiPop": icon_confetti,
	"MoneyRain": icon_money_rain,
	"GoldenAura": icon_golden_aura,
	"Lightning": icon_lightning,
	"Fireworks": icon_fireworks,
	"BlackHole": icon_black_hole,
}


def render_icons(names):
	scene, stage = studio()
	done = []
	for name in names:
		clear(stage)
		objects, view = BUILDERS[name](stage)
		lo, hi = bounds(objects)
		thickness = (hi - lo).length * 0.012
		for ob in objects:
			add_outline(ob, thickness)
		frame(scene, objects, yaw=view.get("yaw", -32), pitch=view.get("pitch", 22), fill=view.get("fill", 0.86))
		done.append(render(scene, name))
	return done


def render_all():
	return render_icons(list(BUILDERS))
