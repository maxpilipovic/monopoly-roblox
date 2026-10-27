# Builds the card and tile emblems into one collection each: Question (Chance), Chest (Community
# Chest), Locomotive (railroads), Bulb (Electric Company), Tap (Water Works). Parts are tinted in
# Roblox: Body takes the main finish, Trim the gold accent, Drop (tap only) the water.
# Fronts face Blender +Y (Roblox +Z). Run inside Blender after common.py.

GOLD = (0.83, 0.62, 0.22)
INK = (0.06, 0.06, 0.07)
IVORY = (0.95, 0.93, 0.85)
STEEL = (0.75, 0.77, 0.8)
WATER = (0.35, 0.65, 0.95)

UPRIGHT = Matrix.Rotation(math.pi / 2, 4, "X")  # the XY plane stood up into XZ, facing +Y
ALONG_X = Matrix.Rotation(math.pi / 2, 4, "Y")  # a Z-axis cylinder laid along X
ALONG_Y = Matrix.Rotation(math.pi / 2, 4, "X")  # a Z-axis cylinder laid along Y


def question():
	col = collection("Question")
	body = Part("Body")
	# The hook: three quarters of a ring, open on the viewer's left. Seen from the front (+Y),
	# Blender -X is on the right, so the ring runs from +X round over the top to the bottom.
	body.torus(0.36, 0.13, (0, 0, 1.17), major_segs=28, minor_segs=10, rot=UPRIGHT, arc=1.5 * math.pi, start=0.0)
	body.sphere(0.13, (0.36, 0, 1.17), segs=12, rings=6)
	body.cylinder(0.13, 0.3, (0, 0, 0.66), segments=12)
	body.sphere(0.13, (0, 0, 0.51), segs=12, rings=6)
	body.sphere(0.16, (0, 0, 0.24), segs=16, rings=8)
	body.cylinder(0.36, 0.06, (0, 0, 0.03), segments=24, bevel=0.015)
	body.finish(col, color=GOLD)
	return col


def chest():
	col = collection("Chest")
	body = Part("Body")
	body.box((1.4, 0.9, 0.6), (0, 0, 0.3), bevel=0.04)
	lid = [(0.45 * math.cos(a), 0.6 + 0.45 * math.sin(a)) for a in (math.pi * i / 12 for i in range(13))]
	body.prism(lid, 1.36, (0, 0, 0), axis="X", bevel=0.02)
	trim = Part("Trim")
	trim.box((1.46, 0.96, 0.07), (0, 0, 0.6), bevel=0.015)
	for x in (-0.45, 0.45):
		trim.torus(0.46, 0.035, (x, 0, 0.6), major_segs=12, minor_segs=6, rot=Matrix.Rotation(math.pi / 2, 4, "Y"), arc=math.pi, start=math.pi / 2)
		trim.box((0.08, 0.03, 0.6), (x, 0.465, 0.3))
		trim.box((0.08, 0.03, 0.6), (x, -0.465, 0.3))
	trim.box((0.24, 0.06, 0.3), (0, 0.47, 0.56), bevel=0.02)
	trim.box((0.06, 0.07, 0.1), (0, 0.5, 0.5))
	for x in (-0.66, 0.66):
		for y in (-0.42, 0.42):
			trim.sphere(0.06, (x, y, 0.05), segs=8, rings=4)
	body.finish(col, color=INK)
	trim.finish(col, color=GOLD)
	return col


def locomotive():
	col = collection("Locomotive")
	body = Part("Body")
	body.cylinder(0.28, 1.1, (0.2, 0, 0.66), segments=20, rot=ALONG_X)
	body.box((0.55, 0.72, 0.8), (-0.62, 0, 0.68), bevel=0.03)
	body.box((1.8, 0.5, 0.14), (-0.05, 0, 0.32), bevel=0.02)
	body.cylinder(0.09, 0.34, (0.55, 0, 1.03), segments=12)
	for x in (-0.6, -0.15, 0.3):
		for y in (-0.3, 0.3):
			body.cylinder(0.2, 0.08, (x, y, 0.2), segments=16, rot=ALONG_Y, bevel=0.012)
	body.prism([(-0.27, 0.06), (0.27, 0.06), (0.0, 0.3)], 0.22, (0.88, 0, 0), axis="Y")
	trim = Part("Trim")
	trim.box((0.68, 0.82, 0.07), (-0.62, 0, 1.11), bevel=0.015)
	trim.cylinder(0.09, 0.12, (0.55, 0, 1.25), segments=12, radius2=0.15)
	trim.sphere(0.12, (0.05, 0, 0.94), segs=12, rings=6)
	trim.cylinder(0.25, 0.04, (0.76, 0, 0.66), segments=20, rot=ALONG_X)
	for x in (-0.15, 0.55):
		trim.torus(0.285, 0.025, (x, 0, 0.66), major_segs=20, minor_segs=6, rot=ALONG_X)
	for y in (-0.36, 0.36):
		trim.box((1.0, 0.025, 0.05), (-0.15, y, 0.22))
	body.finish(col, color=INK)
	trim.finish(col, color=GOLD)
	return col


def bulb():
	col = collection("Bulb")
	body = Part("Body")
	body.sphere(0.48, (0, 0, 1.08), segs=24, rings=12)
	body.cylinder(0.22, 0.32, (0, 0, 0.72), segments=20, radius2=0.36)
	trim = Part("Trim")
	trim.cylinder(0.21, 0.36, (0, 0, 0.4), segments=20)
	for z in (0.28, 0.4, 0.52):
		trim.torus(0.215, 0.035, (0, 0, z), major_segs=20, minor_segs=6)
	trim.cylinder(0.1, 0.16, (0, 0, 0.14), segments=16, radius2=0.18)
	trim.sphere(0.07, (0, 0, 0.06), segs=10, rings=5)
	trim.torus(0.12, 0.02, (0, 0, 1.08), major_segs=16, minor_segs=5, rot=UPRIGHT, arc=math.pi, start=0.0)
	trim.cylinder(0.015, 0.36, (-0.12, 0, 0.9), segments=6)
	trim.cylinder(0.015, 0.36, (0.12, 0, 0.9), segments=6)
	body.finish(col, color=IVORY, full_smooth=True)
	trim.finish(col, color=GOLD)
	return col


def tap():
	col = collection("Tap")
	body = Part("Body")
	body.cylinder(0.3, 0.08, (0, -0.15, 0.04), segments=20, bevel=0.02)
	body.cylinder(0.11, 0.9, (0, -0.15, 0.53), segments=16)
	# The spout: a half ring from the top of the pipe, over and forward, then a nozzle pointing down.
	yz = Matrix(((0, 0, 1, 0), (1, 0, 0, 0), (0, 1, 0, 0), (0, 0, 0, 1)))  # XY circle into the YZ plane
	body.torus(0.25, 0.1, (0, 0.1, 0.98), major_segs=14, minor_segs=12, rot=yz, arc=math.pi, start=0.0)
	body.cylinder(0.11, 0.22, (0, 0.35, 0.88), segments=16, radius2=0.09)
	trim = Part("Trim")
	trim.cylinder(0.05, 0.14, (0, 0.1, 1.38), segments=10)
	trim.sphere(0.09, (0, 0.1, 1.46), segs=12, rings=6)
	trim.box((0.5, 0.07, 0.07), (0, 0.1, 1.46), bevel=0.02)
	trim.box((0.07, 0.5, 0.07), (0, 0.1, 1.46), bevel=0.02)
	drop = Part("Drop")
	drop.sphere(0.1, (0, 0.35, 0.5), segs=14, rings=8, scale=(1, 1, 1.15))
	drop.cylinder(0.088, 0.16, (0, 0.35, 0.64), segments=14, radius2=0.0)
	body.finish(col, color=STEEL)
	trim.finish(col, color=GOLD)
	drop.finish(col, color=WATER, full_smooth=True)
	# Turn it side-on so the spout's profile faces the players (spout towards Roblox +X).
	turn = Matrix.Rotation(math.pi / 2, 4, "Z")
	for ob in col.objects:
		ob.data.transform(turn)
	return col


# The EIU board's emblems. Hangouts are a neon OPEN sign (never a drink); the delivery spots a sub
# and a pizza box; Care Package a taped cardboard box.
NEON = (1.0, 0.27, 0.47)
BREAD = (0.87, 0.67, 0.41)
PAPER = (0.94, 0.93, 0.9)
LETTUCE = (0.43, 0.67, 0.27)
CARDBOARD = (0.69, 0.51, 0.32)
TAPE = (0.84, 0.77, 0.59)
PIZZA_RED = (0.77, 0.16, 0.16)


def hangout():
	col = collection("Hangout")
	body = Part("Body")
	body.box((1.9, 0.12, 0.8), (0, 0, 0.62), bevel=0.04)  # the sign's dark backing
	for x in (-0.6, 0.6):
		body.cylinder(0.03, 0.22, (x, 0, 1.12), segments=8)  # hanging wires
	trim = Part("Trim")
	trim.box((2.0, 0.16, 0.06), (0, 0, 1.05), bevel=0.02)
	trim.box((2.0, 0.16, 0.06), (0, 0, 0.19), bevel=0.02)
	trim.box((0.06, 0.16, 0.86), (-0.97, 0, 0.62), bevel=0.02)
	trim.box((0.06, 0.16, 0.86), (0.97, 0, 0.62), bevel=0.02)
	trim.box((1.2, 0.5, 0.16), (0, 0, 0.08), bevel=0.04)  # foot
	trim.box((0.2, 0.14, 0.12), (0, 0, 0.2))
	glow = Part("Glow")
	# OPEN in neon tube, read from the front (+Y). Seen from the front, Blender -X is on the right,
	# so the first letter sits at +X.
	y, z, t, h = 0.09, 0.62, 0.045, 0.24  # tube depth, letter centre, tube radius, half letter height
	o, p, e, n = 0.66, 0.22, -0.22, -0.66

	def bar(a, b):
		ax, az = a
		bx, bz = b
		length = math.hypot(bx - ax, bz - az)
		angle = math.atan2(bx - ax, bz - az)
		glow.cylinder(t, length, ((ax + bx) / 2, y, (az + bz) / 2), segments=8, rot=Matrix.Rotation(angle, 4, "Y"))

	glow.torus(0.17, t, (o, y, z), major_segs=20, minor_segs=6, rot=UPRIGHT @ Matrix.Diagonal((1, 1.4, 1, 1)))
	bar((p + 0.12, z - h), (p + 0.12, z + h))
	glow.torus(0.1, t, (p + 0.02, y, z + h - 0.1), major_segs=14, minor_segs=6, rot=UPRIGHT, arc=math.pi, start=math.pi / 2)  # bowl to the viewer's right
	bar((e + 0.12, z - h), (e + 0.12, z + h))
	for dz in (-h, 0, h):
		bar((e + 0.12, z + dz), (e - 0.1, z + dz))
	bar((n + 0.13, z - h), (n + 0.13, z + h))
	bar((n - 0.13, z - h), (n - 0.13, z + h))
	bar((n + 0.13, z + h), (n - 0.13, z - h))
	body.finish(col, color=INK)
	trim.finish(col, color=GOLD)
	glow.finish(col, color=NEON, full_smooth=True)
	return col


def sub():
	col = collection("Sub")
	body = Part("Body")
	body.sphere(0.5, (0, 0, 0.2), segs=24, rings=10, scale=(2.2, 0.75, 0.42))  # bottom of the roll
	body.sphere(0.5, (0, 0, 0.48), segs=24, rings=10, scale=(2.15, 0.72, 0.5))  # top of the roll
	filling = Part("Filling")
	for i in range(9):
		x = -0.9 + i * 0.225
		filling.sphere(0.2, (x, 0, 0.33), segs=10, rings=5, scale=(1.2, 1.9, 0.35))  # lettuce frills
	trim = Part("Trim")
	trim.box((0.6, 0.86, 0.66), (0.55, 0, 0.32), bevel=0.06)  # paper wrap round one end
	body.finish(col, color=BREAD, full_smooth=True)
	filling.finish(col, color=LETTUCE, full_smooth=True)
	trim.finish(col, color=PAPER)
	return col


def pizza():
	col = collection("Pizza")
	body = Part("Body")
	body.box((1.5, 1.5, 0.22), (0, 0, 0.11), bevel=0.03)
	body.box((1.5, 1.5, 0.22), (0, 0, 0.34), bevel=0.03, rot=Matrix.Rotation(math.radians(9), 4, "Z"))
	trim = Part("Trim")
	# The pizzeria's print on the top lid: a ring round a slice.
	trim.torus(0.42, 0.035, (0, 0, 0.455), major_segs=28, minor_segs=6)
	trim.cylinder(0.28, 0.02, (0, 0, 0.455), segments=3)  # a flat triangle: the slice
	body.finish(col, color=CARDBOARD)
	trim.finish(col, color=PIZZA_RED)
	return col


def care_package():
	col = collection("CarePackage")
	body = Part("Body")
	body.box((1.2, 0.9, 0.85), (0, 0, 0.425), bevel=0.03)
	# The two top flaps, folded down and taped.
	body.box((1.18, 0.44, 0.04), (0, 0.22, 0.86), bevel=0.01)
	body.box((1.18, 0.44, 0.04), (0, -0.22, 0.86), bevel=0.01)
	trim = Part("Trim")
	trim.box((1.24, 0.2, 0.03), (0, 0, 0.885))  # tape along the seam
	trim.box((0.03, 0.2, 0.3), (0.615, 0, 0.73))  # and down each end
	trim.box((0.03, 0.2, 0.3), (-0.615, 0, 0.73))
	trim.box((0.5, 0.02, 0.18), (0.25, 0.46, 0.5))  # shipping label on the front
	body.finish(col, color=CARDBOARD)
	trim.finish(col, color=TAPE)
	return col


EMBLEMS = [question(), chest(), locomotive(), bulb(), tap(), hangout(), sub(), pizza(), care_package()]
for c in EMBLEMS:
	print(report(c))
