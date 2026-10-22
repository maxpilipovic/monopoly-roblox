# Renders the pictures on the Chance and Community Chest cards (one per kind of card: a money bag,
# the bank, a signpost, a birthday cake...) as transparent PNGs into assets/cards, in the icon house
# style. Reuses the tile-art pipeline (trimmed renders) and the game's own models where they fit.
# Run inside Blender:
#   exec(open(r"C:\dev\Monopoly\tools\blender\card_art.py").read()); render_cards()
# or some: render_cards(["Cake"]).
import bpy, math, os
from mathutils import Vector, Matrix

exec(open(r"C:\dev\Monopoly\tools\blender\tile_art.py").read())

CARD_OUT = os.path.join(ROOT, "cards")

TAN = lambda: mat("Burlap", srgb(214, 172, 112), rough=0.75)
MONEY_GREEN = lambda: mat("MoneyGreen", srgb(40, 130, 70), rough=0.4)
CREAM = lambda: mat("Cream", srgb(255, 236, 214), rough=0.45)
PINK = lambda: mat("Frosting", srgb(250, 150, 190), rough=0.4)
LEATHER = lambda: mat("Leather", srgb(92, 52, 30), rough=0.5)
NAVY = lambda: mat("NavyCap", srgb(30, 34, 52), rough=0.5)


def place_all(obs, matrix):
	bpy.context.view_layer.update()  # apply any location/rotation set since, before reading matrix_world
	for ob in obs:
		ob.matrix_world = matrix @ ob.matrix_world
	return obs


def card_money_bag(stage):
	sack = Part("Sack")
	sack.sphere(1.0, (0, 0, 0), segs=40, rings=20, scale=(1.0, 0.85, 0.95))
	sack.cylinder(0.32, 0.5, (0, 0, 1.0), segments=24, radius2=0.42)
	sack.cylinder(0.42, 0.3, (0, 0, 1.38), segments=24, radius2=0.62)
	s = obj(sack, stage, TAN(), smooth=3.0)
	tie = Part("Tie")
	tie.torus(0.36, 0.08, (0, 0, 1.12), major_segs=32, minor_segs=8)
	t = obj(tie, stage, GOLD())
	sign = heavy_text(stage, "$", 1.1, 0.12, MONEY_GREEN())
	sign.matrix_world = Matrix.Translation((-0.1, -0.9, 0.12)) @ sign.matrix_world
	return [s, t, sign], {"yaw": -6, "pitch": 8}


def card_bank(stage):
	stone = IVORY()
	obs = []
	base = Part("Steps")
	base.box((3.4, 1.8, 0.2), (0, 0, 0.1), bevel=0.03)
	base.box((3.1, 1.6, 0.2), (0, 0, 0.3), bevel=0.03)
	base.box((3.0, 1.5, 0.25), (0, 0, 2.35), bevel=0.04)
	obs.append(obj(base, stage, stone))
	cols = Part("Columns")
	for x in (-1.15, -0.4, 0.4, 1.15):
		cols.cylinder(0.17, 1.8, (x, -0.45, 1.3), segments=20)
		cols.box((0.46, 0.46, 0.1), (x, -0.45, 0.45), bevel=0.02)
		cols.box((0.46, 0.46, 0.1), (x, -0.45, 2.17), bevel=0.02)
	obs.append(obj(cols, stage, stone))
	wall = Part("Wall")
	wall.box((2.7, 0.9, 1.8), (0, 0.25, 1.3))
	obs.append(obj(wall, stage, mat("Shade", srgb(150, 150, 160), rough=0.7)))
	roof = Part("Roof")
	roof.prism([(-1.65, 0), (1.65, 0), (0, 0.75)], 1.6, (0, 0, 2.48), axis="Y", bevel=0.04)
	obs.append(obj(roof, stage, stone))
	coin = coin_part("Coin", radius=0.24, depth=0.12, center=(0, -0.82, 2.85), rot=rx(90))
	obs.append(obj(coin, stage, GOLD()))
	sign = text_mesh(stage, "BANK", 0.22, 0.04, (0, -0.8, 2.35), INK(), rot=rx(90))
	obs.append(sign)
	return obs, {"yaw": -22, "pitch": 12}


def sign_board(name, stage, length, flip, z, material):
	profile = arrow_profile(length, 0.5, 0.5, 0.3)
	if flip:
		profile = [(-x, y) for x, y in profile]
	return flat(name, stage, profile, 0.12, (0, -0.12, z), material, bevel=0.03)


def card_signpost(stage):
	post = Part("Post")
	post.box((0.22, 0.22, 3.2), (0, 0, 1.6), bevel=0.04)
	obs = [obj(post, stage, WOOD())]
	obs.append(sign_board("Top", stage, 2.0, False, 2.75, RED()))
	obs.append(sign_board("Bottom", stage, 1.8, True, 2.05, mat("SignBlue", srgb(40, 110, 210), rough=0.35)))
	ground = Part("Ground")
	ground.cylinder(0.6, 0.12, (0, 0, 0.06), segments=24, bevel=0.03)
	obs.append(obj(ground, stage, GREEN()))
	return obs, {"yaw": -16, "pitch": 8}


def card_locomotive(stage):
	return import_model(stage, "Emblems", "Locomotive", {"Body": INK(), "Trim": GOLD(), "*": INK()}), {"yaw": -34, "pitch": 14}


def card_utilities(stage):
	bulb = import_model(stage, "Emblems", "Bulb", {
		"Body": mat("BulbGlass", srgb(255, 240, 190), rough=0.15, emit=0.5),
		"Trim": GOLD(),
	})
	tap = import_model(stage, "Emblems", "Tap", {
		"Body": SILVER(),
		"Trim": GOLD(),
		"Drop": mat("Water", srgb(110, 170, 235), rough=0.1),
	})
	blo, bhi = bounds(bulb)
	tlo, thi = bounds(tap)
	place_all(bulb, Matrix.Translation((-(bhi.x - blo.x) * 0.55 - (blo.x + bhi.x) / 2, 0, -blo.z)))
	place_all(tap, Matrix.Translation(((thi.x - tlo.x) * 0.55 - (tlo.x + thi.x) / 2, 0, -tlo.z)))
	return bulb + tap, {"yaw": -14, "pitch": 8}


def card_key(stage):
	lock, _ = icon_lock(stage, True)
	key, _ = icon_key(stage)
	place_all(lock, Matrix.Translation((-0.55, 0.3, 0)))
	place_all(key, Matrix.Translation((0.55, -0.4, -0.35)) @ ry(-20))
	return lock + key, {"yaw": -18, "pitch": 12}


def card_uturn(stage):
	r, w, head = 0.85, 0.24, 0.5
	a0, a1 = math.radians(-20), math.radians(200)
	steps = 28
	outer, inner = [], []
	for k in range(steps + 1):
		a = a0 + (a1 - a0) * k / steps
		outer.append(((r + w) * math.cos(a), (r + w) * math.sin(a)))
		inner.append(((r - w) * math.cos(a), (r - w) * math.sin(a)))
	centre = (r * math.cos(a1), r * math.sin(a1))
	normal = (math.cos(a1), math.sin(a1))
	tangent = (-math.sin(a1), math.cos(a1))
	tip = (centre[0] + tangent[0] * head * 1.3, centre[1] + tangent[1] * head * 1.3)
	wide = (centre[0] + normal[0] * (w + 0.26), centre[1] + normal[1] * (w + 0.26))
	narrow = (centre[0] - normal[0] * (w + 0.26), centre[1] - normal[1] * (w + 0.26))
	profile = outer + [wide, tip, narrow] + list(reversed(inner))
	arrow = flat("Back", stage, profile, 0.32, (0, 0, 0), mat("SignBlue", srgb(40, 110, 210), rough=0.35), bevel=0.05)
	three = heavy_text(stage, "3", 0.9, 0.12, RED())
	three.matrix_world = Matrix.Translation((0, -0.1, -0.05)) @ three.matrix_world
	return [arrow, three], {"yaw": -10, "pitch": 6}


def card_tools(stage):
	handle = Part("Handle")
	handle.box((0.2, 0.2, 2.4), (0, 0, 0), bevel=0.06)
	h = obj(handle, stage, mat("WoodLight", srgb(190, 130, 70), rough=0.55))
	head = Part("Head")
	head.box((1.1, 0.34, 0.36), (0.15, 0, 1.15), bevel=0.06)
	head.box((0.3, 0.3, 0.3), (-0.45, 0, 1.15), bevel=0.05)
	hd = obj(head, stage, IRON())
	hammer = place_all([h, hd], Matrix.Translation((0.3, 0, 0)) @ ry(30))
	wrench = Part("Wrench")
	wrench.box((0.26, 0.14, 2.2), (0, 0, 0), bevel=0.05)
	wrench.box((0.7, 0.16, 0.24), (0, 0, 1.1), bevel=0.05)
	wrench.box((0.18, 0.16, 0.45), (-0.26, 0, 1.38), bevel=0.05)
	wrench.box((0.18, 0.16, 0.45), (0.26, 0, 1.38), bevel=0.05)
	wrench.cylinder(0.24, 0.16, (0, 0, -1.12), segments=24, rot=rx(90))
	wr = obj(wrench, stage, SILVER())
	place_all([wr], Matrix.Translation((-0.3, -0.25, 0)) @ ry(-30))
	return hammer + [wr], {"yaw": -10, "pitch": 8}


def card_top_hat(stage):
	return import_model(stage, "Pieces", "TopHat", {"Body": INK(), "Trim": RED(), "*": INK()}), {"yaw": -24, "pitch": 16}


def card_cash(stage):
	return import_model(stage, "Props", "CashStack", {}), {"yaw": -28, "pitch": 26}


def card_doctor_bag(stage):
	bag = Part("Bag")
	bag.box((2.4, 1.1, 1.4), (0, 0, 0.7), bevel=0.3, segments=4)
	b = obj(bag, stage, LEATHER())
	rim = Part("Rim")
	rim.box((2.3, 1.16, 0.12), (0, 0, 1.3), bevel=0.05)
	rim.torus(0.42, 0.07, (0, 0, 1.45), major_segs=24, minor_segs=8, rot=rx(90), arc=math.pi)
	rim.box((0.3, 0.1, 0.22), (0, -0.58, 1.18), bevel=0.03)
	r = obj(rim, stage, GOLD())
	badge = Part("Badge")
	badge.cylinder(0.42, 0.06, (0, -0.57, 0.62), segments=32, rot=rx(90))
	bd = obj(badge, stage, PAPER())
	cross = Part("Cross")
	cross.box((0.5, 0.06, 0.16), (0, -0.62, 0.62), bevel=0.02)
	cross.box((0.16, 0.06, 0.5), (0, -0.62, 0.62), bevel=0.02)
	c = obj(cross, stage, RED())
	return [b, r, bd, c], {"yaw": -22, "pitch": 14}


def card_chart(stage):
	obs = []
	board = Part("Board")
	board.box((2.6, 0.12, 2.0), (0, 0.1, 1.0), bevel=0.05)
	obs.append(obj(board, stage, PAPER()))
	bars = Part("Bars")
	for i, height in enumerate((0.5, 0.85, 1.25, 1.6)):
		bars.box((0.4, 0.16, height), (-0.9 + i * 0.6, -0.02, 0.15 + height / 2), bevel=0.03)
	obs.append(obj(bars, stage, GREEN()))
	arrow = flat("Rise", stage, arrow_profile(2.5, 0.16, 0.42, 0.34), 0.14, (0, -0.16, 1.15), RED(), bevel=0.03, rot=ry(-32))
	obs.append(arrow)
	return obs, {"yaw": -14, "pitch": 6}


def card_gift(stage):
	box = Part("Box")
	box.box((1.8, 1.8, 1.4), (0, 0, 0.7), bevel=0.06)
	b = obj(box, stage, RED())
	ribbon = Part("Ribbon")
	ribbon.box((0.32, 1.86, 1.46), (0, 0, 0.7), bevel=0.02)
	ribbon.box((1.86, 0.32, 1.46), (0, 0, 0.7), bevel=0.02)
	ribbon.torus(0.32, 0.1, (-0.32, 0, 1.6), major_segs=24, minor_segs=8, rot=rx(90) @ ry(30))
	ribbon.torus(0.32, 0.1, (0.32, 0, 1.6), major_segs=24, minor_segs=8, rot=rx(90) @ ry(-30))
	ribbon.sphere(0.16, (0, 0, 1.45), segs=16, rings=8)
	r = obj(ribbon, stage, GOLD())
	return [b, r], {"yaw": -28, "pitch": 18}


def card_cake(stage):
	obs = []
	plate = Part("Plate")
	plate.cylinder(1.5, 0.1, (0, 0, 0.05), segments=48, bevel=0.03)
	obs.append(obj(plate, stage, SILVER()))
	cake = Part("Cake")
	cake.cylinder(1.2, 0.8, (0, 0, 0.5), segments=48, bevel=0.06)
	cake.cylinder(0.8, 0.65, (0, 0, 1.22), segments=48, bevel=0.06)
	obs.append(obj(cake, stage, CREAM()))
	icing = Part("Icing")
	icing.torus(1.2, 0.09, (0, 0, 0.88), major_segs=48, minor_segs=8)
	icing.torus(0.8, 0.08, (0, 0, 1.53), major_segs=48, minor_segs=8)
	icing.cylinder(0.78, 0.06, (0, 0, 1.55), segments=48)
	obs.append(obj(icing, stage, PINK()))
	candles = Part("Candles")
	flames = Part("Flames")
	for k in range(5):
		a = math.radians(90 + k * 72)
		x, y = math.cos(a) * 0.45, math.sin(a) * 0.45
		candles.cylinder(0.06, 0.45, (x, y, 1.8), segments=12)
		flames.sphere(0.09, (x, y, 2.1), segs=12, rings=6, scale=(1, 1, 1.7))
	obs.append(obj(candles, stage, BLUE()))
	obs.append(obj(flames, stage, glow("Flame", srgb(255, 190, 60), 4.0), smooth=3.0))
	return obs, {"yaw": -20, "pitch": 18}


def card_grad_cap(stage):
	cap = Part("Cap")
	cap.cylinder(0.75, 0.6, (0, 0, 0.3), segments=40, radius2=0.8)
	c = obj(cap, stage, NAVY())
	board = Part("Board")
	board.box((2.0, 2.0, 0.1), (0, 0, 0.66), bevel=0.02, rot=rz(45))
	bo = obj(board, stage, NAVY())
	tassel = Part("Tassel")
	tassel.sphere(0.11, (0, 0, 0.75), segs=12, rings=6)
	tassel.cylinder(0.035, 0.75, (0.55, -0.55, 0.69), segments=8, rot=ry(90) @ rx(45))
	tassel.cylinder(0.035, 0.6, (1.02, -0.02, 0.38), segments=8)
	tassel.cylinder(0.08, 0.3, (1.02, -0.02, 0.0), segments=12, radius2=0.04)
	t = obj(tassel, stage, GOLD())
	return [c, bo, t], {"yaw": -24, "pitch": 20}


def card_briefcase(stage):
	case = Part("Case")
	case.box((2.4, 0.8, 1.6), (0, 0, 0.8), bevel=0.14, segments=3)
	c = obj(case, stage, LEATHER())
	trim = Part("Trim")
	trim.torus(0.36, 0.08, (0, 0, 1.62), major_segs=24, minor_segs=8, rot=rx(90), arc=math.pi)
	for x in (-0.7, 0.7):
		trim.box((0.26, 0.1, 0.3), (x, -0.42, 1.32), bevel=0.03)
	trim.box((2.42, 0.82, 0.08), (0, 0, 1.12), bevel=0.02)
	t = obj(trim, stage, GOLD())
	return [c, t], {"yaw": -24, "pitch": 12}


def card_trophy(stage):
	return import_model(stage, "Pieces", "Trophy", {"Body": GOLD(), "Trim": GOLD_DARK(), "*": GOLD()}), {"yaw": -20, "pitch": 12}


def card_go(stage):
	return icon_go(stage)


CARD_BUILDERS = {
	"MoneyBag": card_money_bag,
	"Bank": card_bank,
	"Signpost": card_signpost,
	"Locomotive": card_locomotive,
	"Utilities": card_utilities,
	"Key": card_key,
	"UTurn": card_uturn,
	"Tools": card_tools,
	"TopHat": card_top_hat,
	"Cash": card_cash,
	"DoctorBag": card_doctor_bag,
	"Chart": card_chart,
	"Gift": card_gift,
	"Cake": card_cake,
	"GradCap": card_grad_cap,
	"Briefcase": card_briefcase,
	"Trophy": card_trophy,
	"Go": card_go,
}


def render_cards(names=None):
	scene, stage = studio()
	done = []
	for name in names or list(CARD_BUILDERS):
		clear(stage)
		objects, view = CARD_BUILDERS[name](stage)
		lo, hi = bounds(objects)
		thickness = (hi - lo).length * 0.012
		for ob in objects:
			add_outline(ob, thickness)
		scene.render.resolution_x = 512
		scene.render.resolution_y = 512
		frame(scene, objects, yaw=view.get("yaw", -32), pitch=view.get("pitch", 22), fill=view.get("fill", 0.9))
		os.makedirs(CARD_OUT, exist_ok=True)
		scene.render.filepath = os.path.join(CARD_OUT, name + ".png")
		bpy.ops.render.render(write_still=True, scene=scene.name)
		trim(scene.render.filepath)
		done.append(name)
	scene.render.resolution_x = SIZE
	scene.render.resolution_y = SIZE
	return done
