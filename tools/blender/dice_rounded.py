# Builds the Rounded die into collection "Rounded": Body (finish) and Pips (accent).
# Run inside Blender: exec(open(r"C:\dev\Monopoly\tools\blender\dice_rounded.py").read())
# 1 Blender unit = 1 stud; origin at the centre of the base.
import bpy, bmesh
from mathutils import Vector

S = 1.2
H = S / 2
CENTRE = Vector((0, 0, H))
PIP_OFFSET = 0.3

# Measured in Studio after upload (FBX export axis_forward=-Z, axis_up=Y):
# Roblox +Y = Blender +Z, Roblox +Z = Blender +Y, Roblox +X = Blender -X.
# Spec: 1 faces +Y, 2 faces +Z, 3 faces +X; opposite faces sum to 7.
FACES = {
	1: (Vector((0, 0, 1)), Vector((1, 0, 0)), Vector((0, 1, 0))),
	6: (Vector((0, 0, -1)), Vector((1, 0, 0)), Vector((0, 1, 0))),
	2: (Vector((0, 1, 0)), Vector((1, 0, 0)), Vector((0, 0, 1))),
	5: (Vector((0, -1, 0)), Vector((1, 0, 0)), Vector((0, 0, 1))),
	3: (Vector((-1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))),
	4: (Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))),
}
o = PIP_OFFSET
LAYOUTS = {
	1: [(0, 0)],
	2: [(-o, -o), (o, o)],
	3: [(-o, -o), (0, 0), (o, o)],
	4: [(-o, -o), (o, -o), (-o, o), (o, o)],
	5: [(-o, -o), (o, -o), (0, 0), (-o, o), (o, o)],
	6: [(-o, -o), (o, -o), (-o, 0), (o, 0), (-o, o), (o, o)],
}


def sphere_mesh(name, radius, offset, segs, rings):
	bm = bmesh.new()
	for n, (nrm, u, v) in FACES.items():
		for a, b in LAYOUTS[n]:
			p = CENTRE + nrm * (H + offset) + u * a + v * b
			res = bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=rings, radius=radius)
			bmesh.ops.translate(bm, verts=res["verts"], vec=p)
	me = bpy.data.meshes.new(name)
	bm.to_mesh(me)
	bm.free()
	return me


def material(name, rgb, rough):
	m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
	m.use_nodes = True
	bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
	bsdf.inputs["Base Color"].default_value = (*rgb, 1)
	bsdf.inputs["Roughness"].default_value = rough
	return m


def tris(ob):
	return sum(len(p.vertices) - 2 for p in ob.data.polygons)


col = bpy.data.collections.get("Rounded") or bpy.data.collections.new("Rounded")
if col.name not in bpy.context.scene.collection.children:
	bpy.context.scene.collection.children.link(col)
for ob in list(col.objects):
	bpy.data.objects.remove(ob, do_unlink=True)

bm = bmesh.new()
bmesh.ops.create_cube(bm, size=S)
bmesh.ops.translate(bm, verts=bm.verts, vec=CENTRE)
me = bpy.data.meshes.new("Body")
bm.to_mesh(me)
bm.free()
body = bpy.data.objects.new("Body", me)
col.objects.link(body)
bev = body.modifiers.new("Bevel", "BEVEL")
bev.width = 0.14
bev.segments = 4
bev.limit_method = "NONE"

# Cutters sit slightly proud of the face so each pip is a shallow cup.
cutter = bpy.data.objects.new("PipCutter", sphere_mesh("PipCutter", 0.12, 0.04, 10, 6))
col.objects.link(cutter)
boo = body.modifiers.new("Engrave", "BOOLEAN")
boo.operation = "DIFFERENCE"
boo.object = cutter
boo.solver = "EXACT"

bpy.context.view_layer.objects.active = body
for m in list(body.modifiers):
	bpy.ops.object.modifier_apply(modifier=m.name)
cutter_mesh = cutter.data
bpy.data.objects.remove(cutter, do_unlink=True)
bpy.data.meshes.remove(cutter_mesh)

# Only the cap shows inside each cup, so the pips can be low-poly.
pips = bpy.data.objects.new("Pips", sphere_mesh("Pips", 0.1, -0.1, 8, 4))
col.objects.link(pips)

# Smooth by angle keeps the boolean-cut faces flat while the bevels round off.
body.data.validate()
pips.data.validate()
bpy.ops.object.select_all(action="DESELECT")
body.select_set(True)
bpy.context.view_layer.objects.active = body
bpy.ops.object.shade_smooth_by_angle(angle=0.61)
for p in pips.data.polygons:
	p.use_smooth = True
body.data.materials.append(material("DieBody", (0.92, 0.9, 0.85), 0.25))
pips.data.materials.append(material("DiePips", (0.05, 0.05, 0.06), 0.4))

print("tris body", tris(body), "pips", tris(pips), "total", tris(body) + tris(pips))
print("dims", tuple(round(x, 3) for x in body.dimensions))
