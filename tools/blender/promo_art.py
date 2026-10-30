# Renders the store page art: the experience icon (512 px) and the thumbnails (1920x1080), built
# from the game's own models (pieces, dice, houses, hotels, coins, chests) in the icon house style,
# with the title in heavy gold letters. Output: assets/promo. Change TITLE to rename everything.
# Run inside Blender:
#   exec(open(r"C:\dev\Monopoly\tools\blender\promo_art.py").read()); render_promo()
# or some: render_promo(["Icon", "Hero"]).
import bpy, math, os
from mathutils import Vector, Matrix

exec(open(r"C:\dev\Monopoly\tools\blender\product_art.py").read())

PROMO_OUT = os.path.join(ROOT, "promo")
TITLE = "BOARD BARONS"

PLAYER_COLOURS = {
	"Red": (232, 64, 64),
	"Blue": (52, 120, 230),
	"Green": (46, 170, 90),
	"Yellow": (250, 200, 40),
	"Purple": (150, 80, 220),
	"Orange": (247, 148, 29),
}
STREET_COLOURS = [(149, 84, 54), (170, 224, 250), (217, 58, 150), (247, 148, 29), (237, 27, 36), (254, 242, 0), (31, 178, 90), (0, 114, 187)]


def colour(name, rgb, rough=0.35, metal=0.0, emit=0.0):
	return mat(name, srgb(*rgb), metal=metal, rough=rough, emit=emit)


def fit(objects, height, base, yaw=0.0):
	"""Scales `objects` to `height` and stands them on `base`, turned by `yaw` degrees."""
	lo, hi = bounds(objects)
	scale = height / max(hi.z - lo.z, 1e-4)
	centre = Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))
	m = Matrix.Translation(Vector(base)) @ rz(yaw) @ Matrix.Diagonal((scale, scale, scale, 1)) @ Matrix.Translation(-centre)
	for ob in objects:
		ob.matrix_world = m @ ob.matrix_world
	return objects


def piece(stage, shape, rgb, height, base, yaw=0.0):
	body = colour(f"Piece{shape}{rgb}", rgb, rough=0.3)
	obs = import_model(stage, "Pieces", shape, {"Body": body, "Trim": GOLD(), "Glow": glow("PieceGlow", srgb(255, 230, 150), 2.0), "*": body})
	return fit(obs, height, base, yaw)


def building(stage, kind, height, base, yaw=0.0):
	rgb = (46, 170, 90) if kind == "House" else (214, 40, 48)
	obs = import_model(stage, "Buildings", kind, {"Body": colour(f"{kind}Body", rgb), "Roof": colour(f"{kind}Roof", tuple(int(c * 0.7) for c in rgb)), "Trim": IVORY(), "*": colour(f"{kind}Body", rgb)})
	return fit(obs, height, base, yaw)


def tumbling_die(stage, size, centre, tilt):
	obs = import_model(stage, "Dice", "Rounded", {"Body": IVORY(), "Pips": INK(), "*": IVORY()})
	fit(obs, size, (0, 0, 0))
	m = Matrix.Translation(Vector(centre) - Vector((0, 0, size / 2))) @ Matrix.Translation((0, 0, size / 2)) @ rx(tilt[0]) @ ry(tilt[1]) @ rz(tilt[2]) @ Matrix.Translation((0, 0, -size / 2))
	for ob in obs:
		ob.matrix_world = m @ ob.matrix_world
	return obs


def board(stage, size=12.0):
	"""A board in the game's look: dark base, light tiles with colour bands, a pale centre."""
	obs = []
	base = Part("Base")
	base.box((size, size, 0.3), (0, 0, -0.15), bevel=0.06)
	obs.append(obj(base, stage, colour("BoardBase", (35, 35, 35), rough=0.6)))
	centre = Part("Centre")
	inner = size * 0.72
	centre.box((inner, inner, 0.06), (0, 0, 0.03))
	obs.append(obj(centre, stage, colour("BoardCentre", (196, 226, 200), rough=0.7)))
	tiles = Part("Tiles")
	bands = {}
	tile = (size - inner) / 2
	step = inner / 9
	for side in range(4):
		turn = rz(90 * side)
		for i in range(9):
			x = -inner / 2 + step * (i + 0.5)
			c = turn @ Vector((x, -(inner / 2 + tile / 2), 0.04))
			tiles.box((step - 0.06, tile - 0.06, 0.08), tuple(c), rot=turn)
			if i not in (2, 5):
				band = bands.setdefault((side * 2 + (0 if i < 4 else 1)) % len(STREET_COLOURS), Part(f"Band{side}{i}"))
				bc = turn @ Vector((x, -(inner / 2 + 0.22), 0.1))
				band.box((step - 0.06, 0.4, 0.05), tuple(bc), rot=turn)
		for corner in (Vector((-1, -1, 0)), Vector((1, -1, 0))):
			cc = turn @ Vector((corner.x * (inner / 2 + tile / 2), corner.y * (inner / 2 + tile / 2), 0.04))
			tiles.box((tile - 0.06, tile - 0.06, 0.08), tuple(cc))
	obs.append(obj(tiles, stage, colour("Tiles", (214, 234, 214), rough=0.6)))
	for index, band in bands.items():
		obs.append(obj(band, stage, colour(f"Band{index}", STREET_COLOURS[index], rough=0.4)))
	return obs


# Camera, backdrop and words -------------------------------------------------------------------

def aim(scene, eye, target, lens=50):
	cam = scene.camera
	cam.data.lens = lens
	cam.location = Vector(eye)
	cam.rotation_euler = (Vector(target) - Vector(eye)).to_track_quat("-Z", "Y").to_euler()
	cam.data.clip_end = 400
	bpy.context.view_layer.update()
	return cam


def half_frame(cam, distance):
	"""Half the width and height of the picture at `distance` in front of the camera."""
	scene = bpy.context.scene
	aspect = scene.render.resolution_y / scene.render.resolution_x
	half_w = distance * math.tan(cam.data.angle_x / 2)
	return half_w, half_w * aspect


def on_screen(cam, fx, fy, distance):
	"""The world point at screen position (fx, fy), each -1..1 from the centre, `distance` away."""
	hw, hh = half_frame(cam, distance)
	return cam.matrix_world @ Vector((fx * hw, fy * hh, -distance))


def in_camera(cam, ob, fx, fy, distance, scale=1.0):
	"""Places `ob` (drawn in its own XY plane, front +Z) square-on to the camera at screen (fx, fy)."""
	hw, hh = half_frame(cam, distance)
	ob.matrix_world = cam.matrix_world @ Matrix.Translation((fx * hw, fy * hh, -distance)) @ Matrix.Diagonal((scale, scale, scale, 1))
	return ob


def backdrop(stage, cam, top, bottom, distance=120.0):
	"""A glowing gradient wall square-on behind everything."""
	m = bpy.data.materials.new("Backdrop")
	m.use_nodes = True
	nodes, links = m.node_tree.nodes, m.node_tree.links
	for n in list(nodes):
		nodes.remove(n)
	coords = nodes.new("ShaderNodeTexCoord")
	split = nodes.new("ShaderNodeSeparateXYZ")
	ramp = nodes.new("ShaderNodeValToRGB")
	emit = nodes.new("ShaderNodeEmission")
	out = nodes.new("ShaderNodeOutputMaterial")
	links.new(coords.outputs["Generated"], split.inputs[0])
	links.new(split.outputs["Y"], ramp.inputs[0])
	links.new(ramp.outputs[0], emit.inputs[0])
	links.new(emit.outputs[0], out.inputs[0])
	ramp.color_ramp.elements[0].color = (*srgb(*bottom), 1)
	ramp.color_ramp.elements[1].color = (*srgb(*top), 1)
	emit.inputs[1].default_value = 1.0
	hw, hh = half_frame(cam, distance)
	wall = Part("Backdrop")
	wall.box((hw * 2.2, hh * 2.2, 0.1), (0, 0, 0))
	ob = obj(wall, stage, m)
	in_camera(cam, ob, 0, 0, distance)
	return [ob]


def words(stage, cam, text, size, x, y, distance=6.0, material=None, depth=0.25):
	"""`size` and `depth` are as seen at 20 units; the words sit close to the camera, in front of everything."""
	k = distance / 20.0
	size, depth = size * k, depth * k
	ob = heavy_text(stage, text, size, depth, material or mat("TitleGold", srgb(255, 200, 40), metal=0.4, rough=0.25, emit=0.25))
	in_camera(cam, ob, x, y, distance)
	# A hard drop shadow rather than an outline shell: crisp at any size, no specks on the bevels.
	shadow = heavy_text(stage, text, size, depth, mat("TitleShadow", srgb(20, 14, 30), rough=1.0))
	hw, hh = half_frame(cam, distance + 0.02)
	in_camera(cam, shadow, x + size * 0.05 / hw, y - size * 0.07 / hh, distance + 0.02)
	return ob


def ribbon(stage, cam, width, height, x, y, rgb, distance=6.2):
	k = distance / 20.0
	width, height = width * k, height * k
	r = Part("Ribbon")
	r.box((width, height, 0.1), (0, 0, 0), bevel=min(height * 0.3, 0.4))
	ob = obj(r, stage, mat("Ribbon", srgb(*rgb), rough=0.5, emit=0.3))
	return in_camera(cam, ob, x, y, distance)


# Shots ------------------------------------------------------------------------------------------

def shot_hero(scene, stage):
	"""The board mid-game: pieces on the move, houses and a hotel, dice flying in the foreground."""
	obs = board(stage)
	obs += piece(stage, "RaceCar", PLAYER_COLOURS["Red"], 1.0, (-2.0, -5.2, 0.08), yaw=10)
	obs += piece(stage, "TopHat", PLAYER_COLOURS["Blue"], 1.4, (2.6, -5.1, 0.08), yaw=-20)
	obs += piece(stage, "Battleship", PLAYER_COLOURS["Green"], 1.0, (-5.2, 1.0, 0.08), yaw=80)
	obs += piece(stage, "Duck", PLAYER_COLOURS["Yellow"], 1.3, (5.2, 2.0, 0.08), yaw=-80)
	for x in (-0.6, 0.0, 0.6):
		obs += building(stage, "House", 0.7, (x + 0.6, -4.55, 0.1))
	obs += building(stage, "Hotel", 1.0, (5.0, -0.6, 0.1), yaw=90)
	obs += building(stage, "House", 0.7, (-4.6, -1.6, 0.1), yaw=90)
	obs += building(stage, "House", 0.7, (-4.6, -2.2, 0.1), yaw=90)
	cam = aim(scene, (0, -19, 12), (0, -0.4, 0), lens=42)
	obs += tumbling_die(stage, 1.6, on_screen(cam, -0.66, -0.3, 12), (25, 35, 15))
	obs += tumbling_die(stage, 1.6, on_screen(cam, -0.42, -0.05, 13), (-30, 20, 60))
	for i, (fx, fy, t) in enumerate([(0.62, 0.2, 70), (0.75, -0.05, 40), (0.55, -0.3, 85), (0.82, 0.32, 60)]):
		obs.append(gold_coin(stage, f"Fly{i}", on_screen(cam, fx, fy, 12), radius=0.4, tilt=t, yaw=i * 25))
	backdrop(stage, cam, (40, 30, 110), (230, 120, 60))
	words(stage, cam, TITLE, 1.7, 0, 0.74)
	ribbon(stage, cam, 17.0, 1.3, 0, -0.8, (20, 20, 40))
	words(stage, cam, "ROLL. BUY. BANKRUPT YOUR FRIENDS!", 0.7, 0, -0.8, material=mat("White", srgb(255, 255, 255), rough=0.4, emit=0.4), depth=0.1)
	return obs


def shot_crazy(scene, stage):
	"""A purple Crazy Chance card bursting with lightning, pieces flung into the air."""
	obs = []
	card = Part("Card")
	card.box((5.2, 0.25, 7.4), (0, 0, 3.7), bevel=0.3)
	obs.append(obj(card, stage, colour("CrazyCard", (120, 60, 200), rough=0.35, emit=0.15)))
	face = Part("Face")
	face.box((4.6, 0.1, 6.8), (0, -0.16, 3.7), bevel=0.25)
	obs.append(obj(face, stage, colour("CrazyFace", (175, 120, 255), rough=0.4)))
	bolt = flat("Bolt", stage, [(-0.5, 2.2), (0.9, 2.2), (0.2, 0.4), (1.1, 0.4), (-0.7, -2.4), (-0.1, -0.2), (-1.0, -0.2)], 0.4, (0, -0.4, 4.0), glow("Bolt", srgb(255, 230, 80), 2.5), bevel=0.06)
	obs.append(bolt)
	q = heavy_text(stage, "?", 1.6, 0.2, glow("CardQ", srgb(255, 255, 255), 1.5))
	q.matrix_world = Matrix.Translation((1.6, -0.35, 6.2)) @ q.matrix_world
	obs.append(q)
	cam = aim(scene, (0, -21, 4.5), (0, 0, 3.6), lens=40)
	flung = [("RaceCar", "Red", (-0.62, 0.05), 1.0, 30), ("Rocket", "Blue", (0.62, 0.1), 2.0, -25), ("UFO", "Green", (-0.6, -0.5), 1.1, 15), ("Robot", "Orange", (0.6, -0.5), 1.8, -10)]
	for shape, name, at, height, yaw in flung:
		obs += piece(stage, shape, PLAYER_COLOURS[name], height, on_screen(cam, at[0], at[1], 19), yaw=yaw)
	for i, (x, z) in enumerate([(-3.4, 7.8), (3.6, 8.2), (-3.0, -0.2), (3.2, 0.1), (0.2, 8.8)]):
		obs.append(gold_coin(stage, f"Spark{i}", (x, -1.2, z), radius=0.5, tilt=60 + i * 9, yaw=i * 40))
	backdrop(stage, cam, (60, 20, 120), (200, 60, 200))
	words(stage, cam, "CRAZY CHANCE", 1.7, 0, 0.74)
	ribbon(stage, cam, 18.0, 1.3, 0, -0.8, (20, 10, 40))
	words(stage, cam, "SWAP PLACES. STEAL STREETS. JAIL EVERYONE.", 0.58, 0, -0.8, material=mat("White", srgb(255, 255, 255), rough=0.4, emit=0.4), depth=0.1)
	return obs


def shot_collect(scene, stage):
	"""A line-up of pieces on gold podiums with the three chests: what you can unlock."""
	obs = []
	line = [("Crown", "Purple"), ("Rocket", "Red"), ("Ghost", "Blue"), ("TopHat", "Yellow"), ("Diamond", "Blue"), ("Lighthouse", "Orange"), ("Trophy", "Green")]
	for i, (shape, name) in enumerate(line):
		x = (i - 3) * 2.6
		depth = abs(i - 3) * 0.6
		pod = Part(f"Podium{i}")
		pod.cylinder(1.0, 0.6, (x, depth, 0.3), segments=40, bevel=0.06)
		obs.append(obj(pod, stage, GOLD()))
		obs += piece(stage, shape, PLAYER_COLOURS[name], 2.2 if i == 3 else 1.8, (x, depth, 0.6), yaw=-10 + i * 3)
	for i, (chest, x) in enumerate([("Silver", -5.5), ("Gold", 0.0), ("Diamond", 5.5)]):
		finish = {"Silver": SILVER(), "Gold": GOLD(), "Diamond": glow("Diamond", srgb(120, 220, 255), 0.8)}[chest]
		c = import_model(stage, "Emblems", "Chest", {"Body": INK(), "Trim": finish, "*": INK()})
		obs += fit(c, 1.3, (x * 1.15, -4.6, 0), yaw=180 + (i - 1) * 14)
	cam = aim(scene, (0, -20, 9.5), (0, -1.0, 1.4), lens=40)
	backdrop(stage, cam, (20, 60, 120), (40, 170, 160))
	words(stage, cam, "COLLECT THEM ALL", 1.3, 0, 0.74)
	ribbon(stage, cam, 18.0, 1.3, 0, -0.8, (10, 30, 50))
	words(stage, cam, "PIECES • AURAS • DICE SKINS • RENT EFFECTS", 0.58, 0, -0.8, material=mat("White", srgb(255, 255, 255), rough=0.4, emit=0.4), depth=0.1)
	return obs


def sunburst(stage, cam, rgb, distance, count=16, strength=1.2):
	"""Rays fanning out from the middle of the picture, between the backdrop and the scene."""
	hw, hh = half_frame(cam, distance)
	reach = max(hw, hh) * 2
	mesh = bpy.data.meshes.new("Rays")
	verts, faces = [(0, 0, 0)], []
	for i in range(count):
		a = 2 * math.pi * i / count
		b = a + math.pi / count
		verts += [(reach * math.cos(a), reach * math.sin(a), 0), (reach * math.cos(b), reach * math.sin(b), 0)]
		faces.append((0, len(verts) - 2, len(verts) - 1))
	mesh.from_pydata(verts, [], faces)
	ob = bpy.data.objects.new("Rays", mesh)
	stage.objects.link(ob)
	ob.data.materials.append(mat("Rays", srgb(*rgb), rough=1.0, emit=strength))
	return in_camera(cam, ob, 0, 0.1, distance)


def shot_icon(scene, stage):
	"""Square icon: a gold top hat on a pile of coins, two dice tumbling, a hotel behind, rays
	bursting from the middle and the title in two big gold lines along the bottom."""
	obs = []
	cam = aim(scene, (0, -14, 2.0), (0, 0, 1.0), lens=50)
	for i, (x, y, count) in enumerate([(0.3, 0.4, 5), (-0.5, 0.2, 3), (1.1, 0.1, 4), (0.2, -0.6, 2)]):
		obs += stack(stage, f"Pile{i}", x, y, count, radius=0.55)
	obs += piece(stage, "TopHat", (255, 196, 56), 2.6, (0.3, 0.4, 5 * 0.55 * 0.28 + 0.05), yaw=-20)
	obs += building(stage, "Hotel", 2.2, (2.6, 2.5, 0), yaw=-30)
	obs += tumbling_die(stage, 1.7, on_screen(cam, -0.55, 0.05, 11), (20, -25, 35))
	obs += tumbling_die(stage, 1.5, on_screen(cam, -0.3, 0.5, 12), (-35, 15, 70))
	for i, (fx, fy, t) in enumerate([(0.72, 0.62, 60), (-0.75, 0.75, 75), (0.82, 0.05, 40), (0.05, 0.85, 80)]):
		obs.append(gold_coin(stage, f"Coin{i}", on_screen(cam, fx, fy, 11), radius=0.42, tilt=t, yaw=i * 30))
	backdrop(stage, cam, (30, 90, 220), (10, 20, 90))
	sunburst(stage, cam, (60, 140, 255), 100)
	ribbon(stage, cam, 30.0, 5.0, 0, -0.73, (14, 18, 46))
	words(stage, cam, "BOARD", 3.1, 0, -0.52)
	words(stage, cam, "BARONS", 3.1, 0, -0.8)
	return obs


SHOTS = {
	"Icon": (shot_icon, 512, 512),
	"Hero": (shot_hero, 1920, 1080),
	"CrazyChance": (shot_crazy, 1920, 1080),
	"Collect": (shot_collect, 1920, 1080),
}


def render_promo(names=None):
	scene, stage = studio()
	transparent = scene.render.film_transparent
	scene.render.film_transparent = False
	done = []
	try:
		for name in names or list(SHOTS):
			build, width, height = SHOTS[name]
			clear(stage)
			scene.render.resolution_x = width
			scene.render.resolution_y = height
			objects = build(scene, stage)
			lo, hi = bounds(objects)
			thickness = (hi - lo).length * 0.004
			for ob in objects:
				add_outline(ob, thickness)
			os.makedirs(PROMO_OUT, exist_ok=True)
			scene.render.filepath = os.path.join(PROMO_OUT, name + ".png")
			bpy.ops.render.render(write_still=True, scene=scene.name)
			done.append(name)
	finally:
		scene.render.film_transparent = transparent
		scene.render.resolution_x = SIZE
		scene.render.resolution_y = SIZE
		scene.camera.data.lens = 85
	return done
