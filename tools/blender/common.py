# Shared helpers for the model scripts. Load first in the same namespace:
#   exec(open(r"C:\dev\Monopoly\tools\blender\common.py").read())
# 1 Blender unit = 1 stud; origin at the centre of the base. Roblox +Y = Blender +Z,
# Roblox +Z = Blender +Y, Roblox +X = Blender -X (measured with the Rounded die).
import bpy, bmesh, math, os
from mathutils import Vector, Matrix

ROOT = r"C:\dev\Monopoly\assets"


def collection(name):
	col = bpy.data.collections.get(name) or bpy.data.collections.new(name)
	if col.name not in bpy.context.scene.collection.children:
		bpy.context.scene.collection.children.link(col)
	for ob in list(col.objects):
		mesh = ob.data
		bpy.data.objects.remove(ob, do_unlink=True)
		if mesh and mesh.users == 0:
			bpy.data.meshes.remove(mesh)
	return col


class Part:
	"""Accumulates primitives into one mesh object; each primitive is bevelled on its own."""

	def __init__(self, name):
		self.name = name
		self.bm = bmesh.new()

	def _append(self, bm, matrix=None):
		if matrix is not None:
			bmesh.ops.transform(bm, matrix=matrix, verts=bm.verts)
		mesh = bpy.data.meshes.new("tmp")
		bm.to_mesh(mesh)
		bm.free()
		self.bm.from_mesh(mesh)
		bpy.data.meshes.remove(mesh)

	def _bevel(self, bm, width, segments):
		if width > 0:
			bmesh.ops.bevel(bm, geom=list(bm.edges), offset=width, segments=segments, profile=0.5, affect="EDGES", clamp_overlap=True)

	def box(self, size, center, bevel=0.0, segments=2, rot=None):
		bm = bmesh.new()
		bmesh.ops.create_cube(bm, size=1.0)
		bmesh.ops.scale(bm, vec=Vector(size), verts=bm.verts)
		self._bevel(bm, bevel, segments)
		m = Matrix.Translation(Vector(center))
		if rot is not None:
			m = m @ rot
		self._append(bm, m)

	def cylinder(self, radius, depth, center, segments=16, bevel=0.0, rot=None, radius2=None):
		bm = bmesh.new()
		bmesh.ops.create_cone(bm, cap_ends=True, segments=segments, radius1=radius, radius2=radius if radius2 is None else radius2, depth=depth)
		self._bevel(bm, bevel, 1)
		m = Matrix.Translation(Vector(center))
		if rot is not None:
			m = m @ rot
		self._append(bm, m)

	def sphere(self, radius, center, segs=16, rings=8, scale=(1, 1, 1)):
		bm = bmesh.new()
		bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=rings, radius=radius)
		bmesh.ops.scale(bm, vec=Vector(scale), verts=bm.verts)
		self._append(bm, Matrix.Translation(Vector(center)))

	def torus(self, major, minor, center, major_segs=24, minor_segs=8, rot=None, arc=2 * math.pi, start=0.0):
		bm = bmesh.new()
		rings = []
		closed = abs(arc - 2 * math.pi) < 1e-6
		count = major_segs if closed else major_segs + 1
		for i in range(count):
			a = start + arc * i / major_segs
			ring = []
			for j in range(minor_segs):
				b = 2 * math.pi * j / minor_segs
				r = major + minor * math.cos(b)
				ring.append(bm.verts.new((r * math.cos(a), r * math.sin(a), minor * math.sin(b))))
			rings.append(ring)
		pairs = len(rings) if closed else len(rings) - 1
		for i in range(pairs):
			r1, r2 = rings[i], rings[(i + 1) % len(rings)]
			for j in range(minor_segs):
				bm.faces.new((r1[j], r1[(j + 1) % minor_segs], r2[(j + 1) % minor_segs], r2[j]))
		if not closed:
			bm.faces.new(list(reversed(rings[0])))
			bm.faces.new(rings[-1])
		m = Matrix.Translation(Vector(center))
		if rot is not None:
			m = m @ rot
		self._append(bm, m)

	def prism(self, profile, depth, center, axis="X", bevel=0.0):
		"""Extrudes a 2D profile [(u, v), ...] (u across, v up) by `depth` along `axis`."""
		bm = bmesh.new()
		half = depth / 2
		front = [bm.verts.new((-half, u, v)) for u, v in profile]
		back = [bm.verts.new((half, u, v)) for u, v in profile]
		n = len(profile)
		bm.faces.new(list(reversed(front)))
		bm.faces.new(back)
		for i in range(n):
			bm.faces.new((front[i], front[(i + 1) % n], back[(i + 1) % n], back[i]))
		bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
		self._bevel(bm, bevel, 1)
		rot = Matrix.Identity(4) if axis == "X" else Matrix.Rotation(math.pi / 2, 4, "Z")
		self._append(bm, Matrix.Translation(Vector(center)) @ rot)

	def finish(self, col, smooth_angle=0.61, color=(0.8, 0.8, 0.8), full_smooth=False):
		mesh = bpy.data.meshes.new(self.name)
		bmesh.ops.remove_doubles(self.bm, verts=self.bm.verts, dist=1e-5)
		self.bm.to_mesh(mesh)
		self.bm.free()
		ob = bpy.data.objects.new(self.name, mesh)
		col.objects.link(ob)
		mesh.validate()
		bpy.ops.object.select_all(action="DESELECT")
		ob.select_set(True)
		bpy.context.view_layer.objects.active = ob
		if full_smooth:
			bpy.ops.object.shade_smooth()
		else:
			bpy.ops.object.shade_smooth_by_angle(angle=smooth_angle)
		mat_name = col.name + self.name
		mat = bpy.data.materials.get(mat_name) or bpy.data.materials.new(mat_name)
		mat.use_nodes = True
		bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
		bsdf.inputs["Base Color"].default_value = (*color, 1)
		bsdf.inputs["Roughness"].default_value = 0.35
		mesh.materials.append(mat)
		return ob


def tris(col):
	return sum(len(p.vertices) - 2 for ob in col.objects for p in ob.data.polygons)


def report(col):
	lo = Vector((1e9, 1e9, 1e9))
	hi = Vector((-1e9, -1e9, -1e9))
	for ob in col.objects:
		for v in ob.data.vertices:
			w = ob.matrix_world @ v.co
			lo = Vector(map(min, lo, w))
			hi = Vector(map(max, hi, w))
	size = hi - lo
	return f"{col.name}: tris {tris(col)} size x{size.x:.2f} y{size.y:.2f} z{size.z:.2f} minz {lo.z:.3f}"


def export(col, kind):
	folder = os.path.join(ROOT, "export", kind)
	os.makedirs(folder, exist_ok=True)
	path = os.path.join(folder, col.name + ".fbx")
	bpy.ops.object.select_all(action="DESELECT")
	for ob in col.objects:
		ob.select_set(True)
	bpy.ops.export_scene.fbx(filepath=path, use_selection=True, object_types={"MESH"},
		apply_scale_options="FBX_SCALE_UNITS", axis_forward="-Z", axis_up="Y",
		bake_space_transform=True, mesh_smooth_type="FACE", use_mesh_modifiers=True, add_leaf_bones=False)
	return path


def lay_out(cols, spacing=3.0):
	"""Spreads collections along X for viewing (object offsets only; exports reset them)."""
	for i, col in enumerate(cols):
		for ob in col.objects:
			ob.location.x = (i - (len(cols) - 1) / 2) * spacing


def reset(cols):
	for col in cols:
		for ob in col.objects:
			ob.location = (0, 0, 0)
