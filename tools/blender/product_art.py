# Renders the icons for the coin-pack Developer Products (Pouch, Bag, Pile, Vault) as 512 px square
# transparent PNGs into assets/products, in the icon house style. Upload each one as the product's
# image on the Creator Dashboard. Each pack looks a step richer than the one before.
# Run inside Blender:
#   exec(open(r"C:\dev\Monopoly\tools\blender\product_art.py").read()); render_products()
import bpy, math, os
from mathutils import Vector, Matrix

exec(open(r"C:\dev\Monopoly\tools\blender\card_art.py").read())

PRODUCT_OUT = os.path.join(ROOT, "products")
PRODUCT_SIZE = 512
STEEL = lambda: mat("Steel", srgb(120, 128, 142), metal=0.6, rough=0.3)
STEEL_DARK = lambda: mat("SteelDark", srgb(62, 66, 78), metal=0.5, rough=0.35)


def gold_coin(stage, name, center, radius=0.32, tilt=None, yaw=0.0):
	"""One coin: lying flat by default, or stood up `tilt` degrees about X, then turned by `yaw`."""
	rot = rx(tilt) if tilt is not None else None
	ob = obj(coin_part(name, radius=radius, depth=radius * 0.26, center=(0, 0, 0), rot=rot), stage, GOLD())
	ob.matrix_world = Matrix.Translation(center) @ rz(yaw) @ ob.matrix_world
	return ob


def stack(stage, name, x, y, count, radius=0.32, base=0.0):
	return [gold_coin(stage, f"{name}{k}", (x, y, base + radius * 0.13 + k * radius * 0.28), radius) for k in range(count)]


def sack(stage, scale):
	objects, _ = card_money_bag(stage)
	place_all(objects, Matrix.Diagonal((scale, scale, scale, 1)))
	return objects


def product_pouch(stage):
	obs = sack(stage, 0.8)
	obs.append(gold_coin(stage, "Lean", (0.55, -0.95, 0.3), tilt=72, yaw=-18))
	obs.append(gold_coin(stage, "Flat", (-0.55, -0.85, 0.04)))
	return obs, {"yaw": -14, "pitch": 12}


def product_bag(stage):
	obs = sack(stage, 1.0)
	# Coins spilling out round the base of a bigger sack.
	for i, (x, y, tilt, yaw) in enumerate([(1.2, -0.5, None, 0), (1.55, -0.1, None, 0), (1.35, -0.95, 70, -25), (-1.25, -0.55, None, 0), (-1.6, -0.05, None, 0), (-1.45, -1.0, 68, 20)]):
		obs.append(gold_coin(stage, f"Spill{i}", (x, y, 0.3 if tilt else 0.04), tilt=tilt, yaw=yaw))
	obs += stack(stage, "S", 1.25, 0.35, 5)
	obs += stack(stage, "T", -1.3, 0.35, 4)
	return obs, {"yaw": -14, "pitch": 16}


def product_pile(stage):
	obs = []
	# A heap of stacks, tallest in the middle, with loose coins round the edge.
	for i, (x, y, count) in enumerate([(0, 0.2, 10), (-0.62, 0.0, 7), (0.62, 0.05, 8), (-0.3, -0.5, 5), (0.35, -0.5, 6), (-0.95, -0.45, 3), (0.98, -0.4, 4), (0, 0.8, 7)]):
		obs += stack(stage, f"S{i}", x, y, count)
	for i, (x, y, tilt, yaw) in enumerate([(-0.6, -1.0, 70, 15), (0.55, -1.05, None, 0), (1.25, 0.2, None, 0), (-1.3, 0.25, None, 0), (0.05, -1.1, 65, -10)]):
		obs.append(gold_coin(stage, f"Loose{i}", (x, y, 0.3 if tilt else 0.04), tilt=tilt, yaw=yaw))
	return obs, {"yaw": -12, "pitch": 24}


def product_vault(stage):
	obs = []
	# A steel safe with its round door swung open on gold stacked to the roof, coins spilling out.
	body = Part("Safe")  # open at the front (-Y): floor, roof, two sides and the back
	body.box((2.2, 1.7, 0.2), (0, 0.2, 0.1), bevel=0.05)
	body.box((2.2, 1.7, 0.2), (0, 0.2, 2.1), bevel=0.05)
	body.box((0.2, 1.7, 2.2), (-1.0, 0.2, 1.1), bevel=0.05)
	body.box((0.2, 1.7, 2.2), (1.0, 0.2, 1.1), bevel=0.05)
	body.box((2.2, 0.2, 2.2), (0, 1.05, 1.1), bevel=0.05)
	obs.append(obj(body, stage, STEEL_DARK()))
	inside = Part("Inside")
	inside.box((1.8, 0.05, 1.8), (0, 0.93, 1.1))  # the back wall, lit warm by the gold
	obs.append(obj(inside, stage, mat("VaultInside", srgb(70, 52, 30), rough=0.6)))
	for i, x in enumerate((-0.55, 0.0, 0.55)):
		obs += stack(stage, f"In{i}", x, 0.5, 12, radius=0.26, base=0.2)
		obs += stack(stage, f"Front{i}", x, -0.05, 9, radius=0.26, base=0.2)
	door = Part("Door")
	door.cylinder(1.0, 0.3, (0, 0, 0), segments=48, bevel=0.05, rot=rx(90))
	d = obj(door, stage, STEEL())
	wheel = Part("Wheel")
	wheel.torus(0.42, 0.06, (0, -0.2, 0), major_segs=32, minor_segs=8, rot=rx(90))
	for a in range(0, 180, 60):
		wheel.box((0.9, 0.08, 0.08), (0, -0.2, 0), rot=ry(a))
	wheel.cylinder(0.12, 0.2, (0, -0.2, 0), segments=20, rot=rx(90))
	w = obj(wheel, stage, GOLD())
	hinge = Matrix.Translation((-1.1, -0.65, 1.1)) @ rz(-115) @ Matrix.Translation((1.0, 0, 0))
	d.matrix_world = hinge @ d.matrix_world
	w.matrix_world = hinge @ w.matrix_world
	obs += [d, w]
	for i, (x, y, tilt, yaw) in enumerate([(0.3, -0.95, None, 0), (0.85, -1.1, 70, -20), (-0.1, -1.3, None, 0), (0.65, -0.6, None, 0)]):
		obs.append(gold_coin(stage, f"Out{i}", (x, y, 0.3 if tilt else 0.04), tilt=tilt, yaw=yaw))
	obs += stack(stage, "Out", 1.05, -0.55, 4)
	return obs, {"yaw": -26, "pitch": 14}


PRODUCT_BUILDERS = {
	"Pouch": product_pouch,
	"Bag": product_bag,
	"Pile": product_pile,
	"Vault": product_vault,
}


def render_products(names=None):
	scene, stage = studio()
	done = []
	for name in names or list(PRODUCT_BUILDERS):
		clear(stage)
		objects, view = PRODUCT_BUILDERS[name](stage)
		lo, hi = bounds(objects)
		thickness = (hi - lo).length * 0.01
		for ob in objects:
			add_outline(ob, thickness)
		scene.render.resolution_x = PRODUCT_SIZE
		scene.render.resolution_y = PRODUCT_SIZE
		frame(scene, objects, yaw=view.get("yaw", -32), pitch=view.get("pitch", 22), fill=1.0)
		os.makedirs(PRODUCT_OUT, exist_ok=True)
		scene.render.filepath = os.path.join(PRODUCT_OUT, name + ".png")
		bpy.ops.render.render(write_still=True, scene=scene.name)
		done.append(name)
	scene.render.resolution_x = SIZE
	scene.render.resolution_y = SIZE
	return done
