# Builds the classic house (a cottage) and hotel (an inn) into collections "House" and "Hotel".
# Parts: Body (walls), Roof, Trim (plinth, door, windows, cornice). Doors face Blender +Y, which is
# Roblox +Z: the tile's outer edge, towards the players.
# Run inside Blender:
#   exec(open(r"C:\dev\Monopoly\tools\blender\common.py").read())
#   exec(open(r"C:\dev\Monopoly\tools\blender\buildings_classic.py").read())

RED = (0.70, 0.06, 0.06)
ROOF_RED = (0.42, 0.03, 0.04)
CREAM = (0.93, 0.89, 0.80)


def frustum(part, bottom, top, z0, z1):
	"""A box narrowing from `bottom` (x, y) at z0 to `top` (x, y) at z1, capped."""
	bm = bmesh.new()
	(bx, by), (tx, ty) = bottom, top
	lower = [bm.verts.new(v) for v in ((-bx / 2, -by / 2, z0), (bx / 2, -by / 2, z0), (bx / 2, by / 2, z0), (-bx / 2, by / 2, z0))]
	upper = [bm.verts.new(v) for v in ((-tx / 2, -ty / 2, z1), (tx / 2, -ty / 2, z1), (tx / 2, ty / 2, z1), (-tx / 2, ty / 2, z1))]
	bm.faces.new(list(reversed(lower)))
	bm.faces.new(upper)
	for i in range(4):
		bm.faces.new((lower[i], lower[(i + 1) % 4], upper[(i + 1) % 4], upper[i]))
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
	part._bevel(bm, 0.015, 1)
	part._append(bm)


def house():
	col = collection("House")
	body = Part("Body")
	body.box((0.78, 0.78, 0.56), (0, 0, 0.34), bevel=0.025)
	roof = Part("Roof")
	roof.prism([(-0.5, 0.6), (0.5, 0.6), (0.5, 0.65), (0, 1.02), (-0.5, 0.65)], 0.92, (0, 0, 0), axis="X", bevel=0.012)
	roof.box((0.12, 0.12, 0.3), (0.22, -0.16, 0.94), bevel=0.012)
	trim = Part("Trim")
	trim.box((0.86, 0.86, 0.06), (0, 0, 0.03), bevel=0.012)
	trim.box((0.2, 0.03, 0.3), (0, 0.405, 0.06 + 0.15), bevel=0.008)
	for x in (-0.24, 0.24):
		trim.box((0.15, 0.03, 0.15), (x, 0.405, 0.4), bevel=0.008)
		trim.box((0.15, 0.03, 0.15), (x, -0.405, 0.4), bevel=0.008)
	for x in (-0.405, 0.405):
		trim.box((0.03, 0.15, 0.15), (x, 0, 0.4), bevel=0.008)
	body.finish(col, color=RED)
	roof.finish(col, color=ROOF_RED)
	trim.finish(col, color=CREAM)
	return col


def hotel():
	col = collection("Hotel")
	body = Part("Body")
	body.box((1.96, 1.16, 1.42), (0, 0, 0.08 + 0.71), bevel=0.03)
	roof = Part("Roof")
	frustum(roof, (2.04, 1.24), (1.5, 0.7), 1.56, 1.86)
	trim = Part("Trim")
	trim.box((2.1, 1.3, 0.08), (0, 0, 0.04), bevel=0.015)
	trim.box((2.06, 1.26, 0.06), (0, 0, 1.53), bevel=0.012)
	front, back = 0.58 + 0.0125, -(0.58 + 0.0125)
	for z in (0.55, 0.92, 1.29):
		for x in (-0.76, -0.38, 0.0, 0.38, 0.76):
			if not (z == 0.55 and x == 0.0):
				trim.box((0.18, 0.025, 0.24), (x, front, z))
			trim.box((0.18, 0.025, 0.24), (x, back, z))
		for y in (-0.25, 0.25):
			trim.box((0.025, 0.18, 0.24), (0.98 + 0.0125, y, z))
			trim.box((0.025, 0.18, 0.24), (-(0.98 + 0.0125), y, z))
	trim.box((0.3, 0.03, 0.4), (0, 0.595, 0.08 + 0.2), bevel=0.008)
	trim.box((0.5, 0.16, 0.04), (0, 0.66, 0.52), bevel=0.01)
	body.finish(col, color=RED)
	roof.finish(col, color=ROOF_RED)
	trim.finish(col, color=CREAM)
	return col


BUILDINGS = [house(), hotel()]
for c in BUILDINGS:
	print(report(c))
