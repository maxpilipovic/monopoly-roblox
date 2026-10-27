# Builds the EIU Campus scenery models: a generic panther statue sitting up on its haunches (not
# the university's mascot design). One part, Body, finished bronze in Roblox. Front faces Blender
# +Y (Roblox +Z). Run inside Blender after common.py:
#   exec(open(r"C:\dev\Monopoly\tools\blender\common.py").read())
#   exec(open(r"C:\dev\Monopoly\tools\blender\scenery_eiu.py").read())
# then export(SCENERY[0], "Scenery").

BRONZE = (0.27, 0.22, 0.16)


def tilt(degrees):
	return Matrix.Rotation(math.radians(degrees), 4, "X")


def panther():
	col = collection("Panther")
	body = Part("Body")
	# Haunches and rump, sitting on the ground.
	body.sphere(0.62, (0, -0.35, 0.55), segs=24, rings=12, scale=(1.0, 1.15, 0.9))
	for x in (-0.42, 0.42):
		body.sphere(0.42, (x, -0.2, 0.42), segs=20, rings=10, scale=(0.75, 1.2, 1.0))  # thighs
		body.sphere(0.16, (x, 0.32, 0.08), segs=14, rings=7, scale=(1.0, 1.6, 0.6))  # hind paws
	# The chest rising up and forward, the shoulders over the front legs.
	body.sphere(0.5, (0, 0.18, 1.25), segs=24, rings=12, scale=(0.9, 0.95, 1.35))
	for x in (-0.24, 0.24):
		body.cylinder(0.13, 1.1, (x, 0.42, 0.6), segments=14, radius2=0.11, rot=tilt(-6))  # front legs
		body.sphere(0.15, (x, 0.5, 0.07), segs=14, rings=7, scale=(1.0, 1.4, 0.6))  # front paws
	# The neck and head, ears up, muzzle forward.
	body.sphere(0.27, (0, 0.33, 1.8), segs=20, rings=10, scale=(0.95, 1.1, 1.3))
	body.sphere(0.32, (0, 0.46, 2.1), segs=24, rings=12, scale=(1.15, 1.0, 0.85))
	body.sphere(0.13, (0, 0.72, 2.03), segs=18, rings=9, scale=(1.3, 1.0, 0.7))  # muzzle
	for x in (-0.19, 0.19):
		body.cylinder(0.1, 0.16, (x * 1.1, 0.4, 2.34), segments=12, radius2=0.02)  # ears
	# The tail curling round the haunches on the ground.
	body.torus(0.55, 0.08, (0.1, -0.2, 0.08), major_segs=24, minor_segs=8, arc=1.3 * math.pi, start=-0.2 * math.pi)
	body.finish(col, color=BRONZE, full_smooth=True)
	return col


SCENERY = [panther()]
for c in SCENERY:
	print(report(c))
