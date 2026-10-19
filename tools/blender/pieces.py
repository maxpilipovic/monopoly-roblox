# Builds the game pieces (one collection each) and the Free Parking cash bundle.
# Parts: Body (main finish), Trim (accent), Glow (lit parts: the lighthouse lamp, the UFO dome).
# Fronts face Blender +Y (Roblox +Z); long pieces lie along X so their side faces the players.
# Run inside Blender after common.py.

PEWTER = (0.7, 0.72, 0.75)
DARK = (0.3, 0.3, 0.33)
UPRIGHT = Matrix.Rotation(math.pi / 2, 4, "X")  # XY-plane shapes stood up into XZ
ALONG_X = Matrix.Rotation(math.pi / 2, 4, "Y")
ALONG_Y = Matrix.Rotation(math.pi / 2, 4, "X")


def extrude_xy(part, outline, z0, z1, bevel=0.0):
	"""An outline in the XY plane (top view), extruded upwards from z0 to z1."""
	bm = bmesh.new()
	low = [bm.verts.new((x, y, z0)) for x, y in outline]
	high = [bm.verts.new((x, y, z1)) for x, y in outline]
	n = len(outline)
	bm.faces.new(list(reversed(low)))
	bm.faces.new(high)
	for i in range(n):
		bm.faces.new((low[i], low[(i + 1) % n], high[(i + 1) % n], high[i]))
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
	part._bevel(bm, bevel, 1)
	part._append(bm)


def extrude_xz(part, profile, y0, y1, bevel=0.0):
	"""A side profile in the XZ plane, extruded across Y from y0 to y1."""
	bm = bmesh.new()
	near = [bm.verts.new((x, y0, z)) for x, z in profile]
	far = [bm.verts.new((x, y1, z)) for x, z in profile]
	n = len(profile)
	bm.faces.new(near)
	bm.faces.new(list(reversed(far)))
	for i in range(n):
		bm.faces.new((near[i], near[(i + 1) % n], far[(i + 1) % n], far[i]))
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
	part._bevel(bm, bevel, 1)
	part._append(bm)


def top_hat():
	col = collection("TopHat")
	body = Part("Body")
	body.cylinder(0.62, 0.07, (0, 0, 0.035), segments=32, bevel=0.02)
	body.cylinder(0.4, 1.0, (0, 0, 0.07 + 0.5), segments=32, radius2=0.44)
	body.cylinder(0.44, 0.05, (0, 0, 1.095), segments=32, bevel=0.02)
	trim = Part("Trim")
	trim.cylinder(0.415, 0.16, (0, 0, 0.17), segments=32, radius2=0.42)
	trim.box((0.12, 0.06, 0.12), (0.0, 0.42, 0.17), bevel=0.015)
	body.finish(col, color=PEWTER)
	trim.finish(col, color=DARK)
	return col


def battleship():
	col = collection("Battleship")
	body = Part("Body")
	hull = [(-0.95, -0.28), (0.5, -0.31), (1.05, 0.0), (0.5, 0.31), (-0.95, 0.28), (-1.0, 0.0)]
	extrude_xy(body, hull, 0.0, 0.34, bevel=0.02)
	trim = Part("Trim")
	trim.box((0.5, 0.36, 0.28), (0.0, 0, 0.48), bevel=0.02)
	trim.box((0.22, 0.2, 0.36), (0.05, 0, 0.8), bevel=0.02)
	trim.cylinder(0.02, 0.35, (0.05, 0, 1.15), segments=6)
	trim.cylinder(0.09, 0.32, (-0.32, 0, 0.5), segments=14, radius2=0.08)
	for x, facing in ((0.55, 1), (-0.62, -1)):
		trim.cylinder(0.14, 0.1, (x, 0, 0.39), segments=16, bevel=0.02)
		trim.cylinder(0.028, 0.42, (x + facing * 0.22, 0, 0.43), segments=8, rot=ALONG_X)
	body.finish(col, color=PEWTER)
	trim.finish(col, color=DARK)
	return col


def race_car():
	col = collection("RaceCar")
	body = Part("Body")
	side = [(-1.0, 0.1), (1.0, 0.1), (1.02, 0.2), (0.45, 0.28), (0.12, 0.46), (-0.42, 0.46), (-0.62, 0.32), (-1.0, 0.3)]
	extrude_xz(body, side, -0.32, 0.32, bevel=0.03)
	trim = Part("Trim")
	for x in (-0.62, 0.64):
		for y in (-0.37, 0.37):
			trim.cylinder(0.17, 0.12, (x, y, 0.17), segments=18, rot=ALONG_Y, bevel=0.02)
	trim.box((0.12, 0.7, 0.05), (-0.95, 0, 0.58), bevel=0.01)
	for y in (-0.22, 0.22):
		trim.box((0.04, 0.04, 0.22), (-0.92, y, 0.44))
	trim.sphere(0.13, (-0.12, 0, 0.52), segs=14, rings=8)
	body.finish(col, color=PEWTER)
	trim.finish(col, color=DARK)
	return col


def duck():
	col = collection("Duck")
	body = Part("Body")
	body.sphere(0.45, (0, 0, 0.42), segs=24, rings=12, scale=(1.25, 0.95, 0.85))
	body.sphere(0.3, (0.32, 0, 0.98), segs=20, rings=10)
	body.cylinder(0.14, 0.3, (-0.55, 0, 0.62), segments=12, radius2=0.0, rot=Matrix.Rotation(math.radians(-55), 4, "Y"))
	trim = Part("Trim")
	trim.cylinder(0.13, 0.28, (0.68, 0, 0.94), segments=14, radius2=0.03, rot=ALONG_X)
	body.finish(col, color=(1, 0.8, 0.1), full_smooth=True)
	trim.finish(col, color=(1, 0.5, 0.1))
	return col


def cactus():
	col = collection("Cactus")
	body = Part("Body")
	body.cylinder(0.2, 1.0, (0, 0, 0.95), segments=16)
	body.sphere(0.2, (0, 0, 1.45), segs=16, rings=8)
	for side in (-1, 1):
		x = side * 0.36
		body.cylinder(0.12, 0.22, (side * 0.24, 0, 0.95), segments=12, rot=ALONG_X)
		body.cylinder(0.12, 0.36, (x, 0, 1.12), segments=12)
		body.sphere(0.12, (x, 0, 1.3), segs=12, rings=6)
	trim = Part("Trim")
	trim.cylinder(0.32, 0.45, (0, 0, 0.225), segments=20, radius2=0.4)
	trim.cylinder(0.43, 0.08, (0, 0, 0.45), segments=20, bevel=0.02)
	body.finish(col, color=(0.3, 0.6, 0.32), full_smooth=True)
	trim.finish(col, color=(0.75, 0.4, 0.25))
	return col


def anchor():
	col = collection("Anchor")
	body = Part("Body")
	body.cylinder(0.07, 1.25, (0, 0, 0.85), segments=12)
	body.torus(0.13, 0.04, (0, 0, 1.6), major_segs=16, minor_segs=6, rot=UPRIGHT)
	body.torus(0.48, 0.065, (0, 0, 0.62), major_segs=24, minor_segs=8, rot=UPRIGHT, arc=math.radians(150), start=math.radians(195))
	for side in (-1, 1):
		angle = math.radians(195) if side < 0 else math.radians(345)
		tip = (0.48 * math.cos(angle), 0, 0.62 + 0.48 * math.sin(angle))
		body.cylinder(0.12, 0.22, (tip[0], 0, tip[2] + 0.08), segments=10, radius2=0.0)
	trim = Part("Trim")
	trim.cylinder(0.05, 0.8, (0, 0, 1.35), segments=10, rot=ALONG_X)
	for side in (-1, 1):
		trim.sphere(0.07, (side * 0.4, 0, 1.35), segs=10, rings=5)
	body.finish(col, color=(0.25, 0.27, 0.32))
	trim.finish(col, color=(0.8, 0.6, 0.2))
	return col


def robot():
	col = collection("Robot")
	body = Part("Body")
	body.box((0.72, 0.5, 0.7), (0, 0, 0.75), bevel=0.06)
	body.box((0.52, 0.44, 0.42), (0, 0, 1.33), bevel=0.06)
	for side in (-1, 1):
		body.box((0.22, 0.26, 0.38), (side * 0.18, 0, 0.19), bevel=0.04)
		body.cylinder(0.08, 0.55, (side * 0.46, 0, 0.78), segments=12)
		body.sphere(0.1, (side * 0.46, 0, 0.48), segs=12, rings=6)
	body.cylinder(0.025, 0.2, (0, 0, 1.64), segments=6)
	trim = Part("Trim")
	for side in (-1, 1):
		trim.box((0.12, 0.04, 0.08), (side * 0.12, 0.23, 1.36), bevel=0.01)
	trim.box((0.3, 0.04, 0.05), (0, 0.23, 1.22))
	trim.box((0.34, 0.04, 0.26), (0, 0.26, 0.8), bevel=0.02)
	trim.sphere(0.07, (0, 0, 1.77), segs=10, rings=5)
	body.finish(col, color=(0.8, 0.82, 0.86))
	trim.finish(col, color=(0.25, 0.85, 1.0))
	return col


def lighthouse():
	col = collection("Lighthouse")
	body = Part("Body")
	body.cylinder(0.36, 1.35, (0, 0, 0.12 + 0.675), segments=24, radius2=0.24)
	trim = Part("Trim")
	trim.cylinder(0.47, 0.12, (0, 0, 0.06), segments=24, bevel=0.02)
	for z, r in ((0.45, 0.335), (0.95, 0.29)):
		trim.cylinder(r + 0.012, 0.2, (z * 0 + 0, 0, z), segments=24)
	trim.cylinder(0.32, 0.06, (0, 0, 1.5), segments=24)
	trim.cylinder(0.26, 0.28, (0, 0, 1.92), segments=20, radius2=0.0)
	glow = Part("Glow")
	glow.cylinder(0.2, 0.26, (0, 0, 1.66), segments=16)
	body.finish(col, color=(0.95, 0.95, 0.92))
	trim.finish(col, color=(0.85, 0.15, 0.15))
	glow.finish(col, color=(1, 0.9, 0.5))
	return col


def trophy():
	col = collection("Trophy")
	body = Part("Body")
	body.cylinder(0.24, 0.55, (0, 0, 1.12), segments=24, radius2=0.42)
	body.cylinder(0.42, 0.04, (0, 0, 1.4), segments=24)
	body.cylinder(0.06, 0.36, (0, 0, 0.66), segments=12)
	body.cylinder(0.2, 0.08, (0, 0, 0.48), segments=16, radius2=0.12)
	for side in (-1, 1):
		body.torus(0.16, 0.035, (side * 0.38, 0, 1.15), major_segs=14, minor_segs=6, rot=UPRIGHT,
			arc=math.pi, start=(-math.pi / 2 if side > 0 else math.pi / 2))
	trim = Part("Trim")
	trim.box((0.6, 0.6, 0.26), (0, 0, 0.13), bevel=0.03)
	trim.box((0.44, 0.44, 0.18), (0, 0, 0.35), bevel=0.02)
	body.finish(col, color=(0.9, 0.7, 0.25))
	trim.finish(col, color=(0.3, 0.18, 0.1))
	return col


def rocket():
	col = collection("Rocket")
	body = Part("Body")
	body.cylinder(0.25, 1.15, (0, 0, 0.32 + 0.575), segments=24)
	body.cylinder(0.2, 0.18, (0, 0, 0.23), segments=20, radius2=0.25)
	trim = Part("Trim")
	trim.cylinder(0.25, 0.5, (0, 0, 1.72), segments=24, radius2=0.0)
	trim.torus(0.11, 0.025, (0, 0.24, 1.15), major_segs=16, minor_segs=6, rot=UPRIGHT)
	for i in range(3):
		a = i * 2 * math.pi / 3 + math.pi / 2
		trim.box((0.04, 0.32, 0.42), (math.cos(a) * 0.32, math.sin(a) * 0.32, 0.42), bevel=0.01,
			rot=Matrix.Rotation(a - math.pi / 2, 4, "Z"))
	body.finish(col, color=(0.95, 0.95, 0.95))
	trim.finish(col, color=(0.85, 0.2, 0.2))
	return col


def ghost():
	col = collection("Ghost")
	body = Part("Body")
	body.sphere(0.46, (0, 0, 1.12), segs=24, rings=12)
	body.cylinder(0.46, 0.72, (0, 0, 0.76), segments=24)
	for i in range(8):
		a = i * 2 * math.pi / 8
		body.sphere(0.13, (math.cos(a) * 0.38, math.sin(a) * 0.38, 0.4), segs=10, rings=6)
	trim = Part("Trim")
	for side in (-1, 1):
		trim.sphere(0.08, (side * 0.16, 0.42, 1.18), segs=12, rings=6, scale=(0.8, 0.5, 1.3))
	trim.sphere(0.07, (0, 0.44, 0.96), segs=12, rings=6, scale=(1.2, 0.5, 0.9))
	body.finish(col, color=(0.95, 0.96, 1.0), full_smooth=True)
	trim.finish(col, color=(0.05, 0.05, 0.08))
	return col


def ufo():
	col = collection("UFO")
	body = Part("Body")
	body.sphere(0.72, (0, 0, 0.62), segs=32, rings=12, scale=(1, 1, 0.26))
	body.cylinder(0.05, 0.45, (0, 0, 0.22), segments=8)
	body.cylinder(0.24, 0.04, (0, 0, 0.02), segments=16, bevel=0.01)
	trim = Part("Trim")
	trim.torus(0.62, 0.035, (0, 0, 0.6), major_segs=32, minor_segs=6)
	for i in range(8):
		a = i * 2 * math.pi / 8
		trim.sphere(0.05, (math.cos(a) * 0.5, math.sin(a) * 0.5, 0.52), segs=8, rings=4)
	glow = Part("Glow")
	glow.sphere(0.3, (0, 0, 0.76), segs=20, rings=10, scale=(1, 1, 0.8))
	body.finish(col, color=(0.8, 0.82, 0.86))
	trim.finish(col, color=(0.4, 1, 0.5))
	glow.finish(col, color=(0.6, 0.9, 1), full_smooth=True)
	return col


def crown():
	col = collection("Crown")
	body = Part("Body")
	body.cylinder(0.44, 0.38, (0, 0, 0.19 + 0.06), segments=32)
	body.torus(0.45, 0.05, (0, 0, 0.08), major_segs=32, minor_segs=8)
	body.torus(0.45, 0.04, (0, 0, 0.45), major_segs=32, minor_segs=8)
	for i in range(5):
		a = i * 2 * math.pi / 5 + math.pi / 2
		body.cylinder(0.13, 0.42, (math.cos(a) * 0.38, math.sin(a) * 0.38, 0.66), segments=10, radius2=0.0)
	trim = Part("Trim")
	for i in range(5):
		a = i * 2 * math.pi / 5 + math.pi / 2
		trim.sphere(0.065, (math.cos(a) * 0.38, math.sin(a) * 0.38, 0.9), segs=10, rings=5)
		b = a + math.pi / 5
		trim.sphere(0.07, (math.cos(b) * 0.45, math.sin(b) * 0.45, 0.26), segs=10, rings=5)
	body.finish(col, color=(0.9, 0.7, 0.25))
	trim.finish(col, color=(0.8, 0.1, 0.2))
	return col


def diamond():
	col = collection("Diamond")
	body = Part("Body")
	body.cylinder(0.0, 0.62, (0, 0, 0.31), segments=10, radius2=0.6)
	body.cylinder(0.6, 0.28, (0, 0, 0.76), segments=10, radius2=0.34)
	body.finish(col, color=(0.65, 0.9, 1.0), smooth_angle=0.05)
	return col


def skull():
	col = collection("Skull")
	body = Part("Body")
	body.sphere(0.45, (0, 0, 0.85), segs=24, rings=12, scale=(0.95, 1.0, 0.95))
	body.box((0.44, 0.36, 0.26), (0, 0.06, 0.48), bevel=0.06)
	for angle in (math.radians(30), math.radians(-30)):
		body.cylinder(0.05, 1.0, (0, 0, 0.12), segments=8, rot=Matrix.Rotation(angle, 4, "Z") @ ALONG_X)
	trim = Part("Trim")
	for side in (-1, 1):
		trim.sphere(0.1, (side * 0.16, 0.38, 0.88), segs=12, rings=6, scale=(1, 0.6, 1.1))
	trim.cylinder(0.05, 0.1, (0, 0.43, 0.72), segments=6, radius2=0.0, rot=Matrix.Rotation(math.pi, 4, "X"))
	body.finish(col, color=(0.9, 0.88, 0.82), full_smooth=True)
	trim.finish(col, color=(0.65, 0.3, 1.0))
	return col


def cash_stack():
	col = collection("CashStack")
	body = Part("Body")
	body.box((2.2, 1.0, 0.3), (0, 0, 0.15), bevel=0.02)
	trim = Part("Band")
	trim.box((0.42, 1.04, 0.32), (0, 0, 0.15), bevel=0.01)
	body.finish(col, color=(0.6, 0.78, 0.5))
	trim.finish(col, color=(0.85, 0.68, 0.33))
	return col


PIECES = [top_hat(), battleship(), race_car(), duck(), cactus(), anchor(), robot(), lighthouse(), trophy(),
	rocket(), ghost(), ufo(), crown(), diamond(), skull()]
PROPS = [cash_stack()]
for c in PIECES + PROPS:
	print(report(c))
